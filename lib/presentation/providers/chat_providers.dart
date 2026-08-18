import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/llm_service_exception.dart';
import '../../domain/engines/llm_orchestrator.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/conversation_repository.dart';
import 'database_providers.dart';
import 'llm_providers.dart';
import 'settings_providers.dart';

/// State of the AI conversation.
class ChatState {
  final String? conversationId;

  /// Server-recognized scenario identifier; privileged prompts stay server-side.
  final String scenarioId;

  /// Human-readable scenario name for the app bar (e.g. "At the Doctor").
  final String scenarioTitle;
  final CEFRLevel level;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  /// Short Czech replies suggested for the learner's next turn. Cleared
  /// when the learner sends a message.
  final List<String> suggestedReplies;

  /// Tutor turns left in today's allowance, as of the last reply. Null until
  /// a reply arrives, or when the deployed function does not report it.
  final int? remainingToday;

  /// Condensed memory of turns that have fallen out of the request window.
  ///
  /// Rebuilt in-session rather than stored: the full transcript is already in
  /// the database, so a resumed conversation can reconstruct this on demand
  /// and no schema change is needed to keep it.
  final String? earlierSummary;

  const ChatState({
    this.conversationId,
    this.scenarioId = 'casual_chat',
    this.scenarioTitle = 'AI Tutor',
    this.level = CEFRLevel.a1,
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.suggestedReplies = const [],
    this.remainingToday,
    this.earlierSummary,
  });

  /// Whether the allowance is close enough to spend that saying so helps.
  /// Announcing "17 left" every turn is noise; the last few are worth knowing
  /// before a conversation stops mid-sentence.
  bool get shouldWarnAboutQuota =>
      remainingToday != null && remainingToday! <= 3;

  ChatState copyWith({
    String? conversationId,
    String? scenarioId,
    String? scenarioTitle,
    CEFRLevel? level,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    List<String>? suggestedReplies,
    int? remainingToday,
    String? earlierSummary,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioTitle: scenarioTitle ?? this.scenarioTitle,
      level: level ?? this.level,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      suggestedReplies: suggestedReplies ?? this.suggestedReplies,
      remainingToday: remainingToday ?? this.remainingToday,
      earlierSummary: earlierSummary ?? this.earlierSummary,
    );
  }
}

/// Conversation scenarios available for role-play.
class ChatScenario {
  final String id;
  final String title;
  final String description;

  const ChatScenario({
    required this.id,
    required this.title,
    required this.description,
  });

  static const List<ChatScenario> all = [
    ChatScenario(
      id: 'casual_chat',
      title: 'Casual Chat',
      description: 'Everyday small talk — greetings, weather, how are you',
    ),
    ChatScenario(
      id: 'restaurant',
      title: 'At the Restaurant',
      description: 'Order food, ask about menu, pay the bill',
    ),
    ChatScenario(
      id: 'directions',
      title: 'Asking Directions',
      description: 'Ask for and give directions in the city',
    ),
    ChatScenario(
      id: 'shopping',
      title: 'Shopping',
      description: 'Buy items, ask prices, negotiate',
    ),
    ChatScenario(
      id: 'doctor',
      title: 'At the Doctor',
      description: 'Describe symptoms, make an appointment',
    ),
    ChatScenario(
      id: 'job_interview',
      title: 'Job Interview',
      description: 'Practice a basic job interview in Czech',
    ),
  ];
}

/// Notifier that manages the AI conversation lifecycle.
class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  /// Start a new conversation with the given scenario.
  /// Defaults to the learner's level from onboarding/settings.
  Future<void> startConversation({
    required ChatScenario scenario,
    CEFRLevel? level,
  }) async {
    // Pre-A1 learners still converse at A1 — it's the simplest tutor level.
    final settingsLevel = ref.read(settingsProvider).startingLevel;
    final effectiveLevel =
        level ?? (settingsLevel == CEFRLevel.a2 ? CEFRLevel.a2 : CEFRLevel.a1);

    final convRepo = ref.read(conversationRepositoryProvider);

    final convId = await convRepo.createConversation(
      scenario.title,
      effectiveLevel.label,
    );

    state = ChatState(
      conversationId: convId,
      scenarioId: scenario.id,
      scenarioTitle: scenario.title,
      level: effectiveLevel,
      messages: [],
    );

    // Send initial greeting from tutor
    await _sendTutorGreeting();
  }

  /// Send a user message and get the AI tutor's response.
  Future<void> sendMessage(String text) async {
    if (state.conversationId == null) return;
    if (state.isLoading) return;

    // Capture the history BEFORE appending the new user message —
    // the orchestrator adds `text` itself, so including it in the
    // history would send it to the model twice.
    final history = state.messages;

    final userMsg = ChatMessage.user(
      text,
      conversationId: state.conversationId,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
      suggestedReplies: const [],
    );

    // Persist user message
    final convRepo = ref.read(conversationRepositoryProvider);
    await convRepo.saveMessage(userMsg);

    await _completeTutorTurn(text, history);
  }

  /// Re-run the tutor completion for the last user message after a failure —
  /// the message is already in the transcript, so only the LLM call repeats.
  Future<void> retryLastMessage() async {
    if (state.conversationId == null || state.isLoading) return;
    final messages = state.messages;
    final lastUserIndex = messages.lastIndexWhere(
      (m) => m.role == MessageRole.user,
    );
    if (lastUserIndex < 0) return;

    state = state.copyWith(isLoading: true, error: null);
    await _completeTutorTurn(
      messages[lastUserIndex].content,
      messages.sublist(0, lastUserIndex),
    );
  }

  /// Condenses the turns this request will drop, folding in whatever was
  /// already summarized. Returns the summary to send with this turn.
  ///
  /// Best-effort by design: on any failure the conversation proceeds with the
  /// previous (or no) summary. This is machinery the learner did not ask for,
  /// so it must never be the reason their message goes unanswered.
  Future<String?> _summarizeIfNeeded(
    LLMOrchestrator orchestrator,
    String text,
    List<ChatMessage> history,
  ) async {
    final dropped = orchestrator.messagesFallingOutOfWindow(
      history: history,
      userMessage: text,
    );
    if (dropped.isEmpty) return state.earlierSummary;

    try {
      final llm = ref.read(llmServiceProvider);
      final response = await llm.complete(
        orchestrator.buildConversationSummaryRequest(
          level: state.level,
          messages: dropped,
          previousSummary: state.earlierSummary,
        ),
      );
      final summary = orchestrator.parseConversationSummary(response);
      if (summary == null) return state.earlierSummary;
      state = state.copyWith(earlierSummary: summary);
      return summary;
    } catch (_) {
      return state.earlierSummary;
    }
  }

  Future<void> _completeTutorTurn(
    String text,
    List<ChatMessage> history,
  ) async {
    final convRepo = ref.read(conversationRepositoryProvider);
    try {
      // Build LLM request via orchestrator
      final orchestrator = ref.read(llmOrchestratorProvider);

      // Compress whatever this turn is about to push out of the window, so a
      // long conversation loses its oldest turns from the request but not from
      // the tutor's memory of it.
      final summary = await _summarizeIfNeeded(orchestrator, text, history);

      final request = orchestrator.buildConversationRequest(
        level: state.level,
        scenarioId: state.scenarioId,
        userMessage: text,
        history: history,
        earlierSummary: summary,
      );

      // Call LLM
      final llm = ref.read(llmServiceProvider);
      final response = await llm.complete(request);

      final parsed = orchestrator.parseTutorResponseSafe(response);
      if (parsed case TutorParseError(:final reason)) {
        state = state.copyWith(isLoading: false, error: reason);
        return;
      }
      final tutorResponse = (parsed as TutorParseOk).response;

      final tutorMsg = ChatMessage.tutor(
        text: tutorResponse.tutorReplyCz,
        translation: tutorResponse.tutorReplyEn,
        corrections: tutorResponse.corrections,
        newVocabulary: tutorResponse.newVocabulary,
        conversationId: state.conversationId,
      );

      state = state.copyWith(
        messages: [...state.messages, tutorMsg],
        isLoading: false,
        suggestedReplies: tutorResponse.suggestedReplies,
        remainingToday: response.remainingToday,
      );

      // Persist tutor message
      await convRepo.saveMessage(tutorMsg);
    } on LlmServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong getting the tutor\'s reply.',
      );
    }
  }

  /// Load an existing conversation by ID.
  Future<void> loadConversation(String conversationId) async {
    final convRepo = ref.read(conversationRepositoryProvider);
    final messages = await convRepo.getHistory(conversationId);
    state = state.copyWith(conversationId: conversationId, messages: messages);
  }

  /// Resume a past conversation with its scenario and level restored, so the
  /// tutor continues in the same role instead of defaulting to casual chat.
  Future<void> resumeConversation(ConversationSummary summary) async {
    final convRepo = ref.read(conversationRepositoryProvider);
    final messages = await convRepo.getHistory(summary.id);
    // The table stores the scenario title; map back to its server-side id.
    final scenario = ChatScenario.all.firstWhere(
      (s) => s.title == summary.scenario,
      orElse: () => ChatScenario.all.first,
    );
    state = ChatState(
      conversationId: summary.id,
      scenarioId: scenario.id,
      scenarioTitle: summary.scenario,
      level:
          summary.cefrLevel.toLowerCase().contains('a2')
              ? CEFRLevel.a2
              : CEFRLevel.a1,
      messages: messages,
    );
  }

  /// Clear the current conversation.
  void resetConversation() {
    state = const ChatState();
  }

  /// Permanently delete a saved conversation and its messages.
  ///
  /// Conversations accumulated with no way to remove them: starting a new one
  /// left the old one behind forever. Deleting the conversation currently on
  /// screen also clears it, otherwise the tutor would keep replying into a
  /// thread whose history no longer exists.
  Future<void> deleteConversation(String conversationId) async {
    await ref
        .read(conversationRepositoryProvider)
        .clearConversation(conversationId);
    if (state.conversationId == conversationId) {
      state = const ChatState();
    }
    // The list is keyed off the active conversation id, which does not change
    // when an *inactive* one is deleted — so refresh it explicitly rather than
    // leaving a deleted conversation on screen.
    ref.invalidate(recentConversationsProvider);
  }

  /// Send an initial greeting from the tutor.
  Future<void> _sendTutorGreeting() async {
    try {
      final orchestrator = ref.read(llmOrchestratorProvider);
      final request = orchestrator.buildConversationRequest(
        level: state.level,
        scenarioId: state.scenarioId,
        userMessage: 'Start the conversation by greeting me.',
        history: [],
      );

      final llm = ref.read(llmServiceProvider);
      final response = await llm.complete(request);
      final parsed = orchestrator.parseTutorResponseSafe(response);
      if (parsed is TutorParseError) {
        throw LlmServiceException(parsed.reason);
      }
      final tutorResponse = (parsed as TutorParseOk).response;

      final greeting = ChatMessage.tutor(
        text: tutorResponse.tutorReplyCz,
        translation: tutorResponse.tutorReplyEn,
        conversationId: state.conversationId,
      );

      state = state.copyWith(
        messages: [greeting],
        suggestedReplies: tutorResponse.suggestedReplies,
      );

      final convRepo = ref.read(conversationRepositoryProvider);
      await convRepo.saveMessage(greeting);
    } catch (e) {
      // If greeting fails, provide a fallback
      final greeting = ChatMessage.tutor(
        text: 'Ahoj! Jsem tvůj učitel češtiny. Jak se jmenuješ?',
        translation: 'Hi! I\'m your Czech teacher. What\'s your name?',
        conversationId: state.conversationId,
      );

      state = state.copyWith(messages: [greeting]);

      final convRepo = ref.read(conversationRepositoryProvider);
      await convRepo.saveMessage(greeting);
    }
  }
}

/// Provider for the chat state.
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

/// Recent conversations for the scenario picker's "continue" section.
final recentConversationsProvider = FutureProvider<List<ConversationSummary>>((
  ref,
) {
  // Recompute when the active conversation changes (a new one was created).
  ref.watch(chatProvider.select((s) => s.conversationId));
  // Enough to clear a backlog. The list previously fetched five and showed
  // three, so conversations accumulated out of sight with no way to remove
  // them.
  return ref
      .read(conversationRepositoryProvider)
      .getRecentConversations(limit: 25);
});
