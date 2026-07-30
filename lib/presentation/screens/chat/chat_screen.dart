import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/repositories/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/chat_message.dart';
import '../../providers/chat_providers.dart';
import '../../providers/stt_providers.dart';
import '../../providers/tts_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/review_providers.dart';
import '../../widgets/common/lesson_ui.dart';
import '../../widgets/common/soft_ui.dart';

/// Icon + soft-tint colors for each conversation scenario.
({IconData icon, Color tint, Color fg}) _scenarioStyle(
  BuildContext context,
  String title,
) {
  final t = context.tokens;
  return switch (title) {
    'Casual Chat' => (
      icon: Icons.local_cafe_outlined,
      tint: t.amberSoft,
      fg: t.amber,
    ),
    'At the Restaurant' => (
      icon: Icons.restaurant_outlined,
      tint: t.redSoft,
      fg: t.red,
    ),
    'Asking Directions' => (
      icon: Icons.map_outlined,
      tint: t.priSoft,
      fg: t.pri,
    ),
    'Shopping' => (
      icon: Icons.shopping_bag_outlined,
      tint: t.violetSoft,
      fg: t.violet,
    ),
    'At the Doctor' => (
      icon: Icons.medical_services_outlined,
      tint: t.redSoft,
      fg: t.red,
    ),
    'Job Interview' => (
      icon: Icons.work_outline,
      tint: t.greenSoft,
      fg: t.green,
    ),
    _ => (icon: Icons.chat_bubble_outline, tint: t.priSoft, fg: t.pri),
  };
}

/// AI conversation screen — role-play scenarios with AI Czech tutor.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isListening = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Capture Czech speech and put the transcription into the input field
  /// for the learner to review (and fix) before sending.
  Future<void> _startVoiceInput() async {
    if (_isListening) return;
    setState(() => _isListening = true);
    try {
      final stt = ref.read(sttServiceProvider) as NativeSttService;
      final transcription = await stt.listenFor(
        timeout: const Duration(seconds: 10),
      );
      if (!mounted) return;
      if (transcription.isNotEmpty) {
        _inputController.text = transcription;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Speech recognition failed. Check microphone permissions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    // Scroll to the bottom whenever a new message arrives (including the
    // async tutor reply) or the typing indicator toggles.
    ref.listen(chatProvider, (prev, next) {
      if (prev == null) return;
      if (prev.messages.length != next.messages.length ||
          prev.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar:
          chat.conversationId == null
              ? null
              : AppBar(
                backgroundColor: t.bg,
                surfaceTintColor: Colors.transparent,
                titleSpacing: 0,
                shape: Border(bottom: BorderSide(color: t.line)),
                leading: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: t.muted,
                  tooltip: 'Back to scenarios',
                  onPressed:
                      () => ref.read(chatProvider.notifier).resetConversation(),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.scenarioTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      '${chat.messages.length} '
                      '${chat.messages.length == 1 ? 'turn' : 'turns'} in',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
      body:
          chat.conversationId == null
              ? const SafeArea(bottom: false, child: _ScenarioPicker())
              : Column(
                children: [
                  // Messages list
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          chat.messages.length + (chat.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chat.messages.length && chat.isLoading) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(message: chat.messages[index]);
                      },
                    ),
                  ),
                  // Error message with a one-tap retry — the message is already
                  // in the transcript, so retry only repeats the tutor call.
                  if (chat.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.error!,
                              style: TextStyle(
                                color: t.redInk,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                () =>
                                    ref
                                        .read(chatProvider.notifier)
                                        .retryLastMessage(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(AppLocalizations.of(context).retry),
                          ),
                        ],
                      ),
                    ),
                  // Suggested replies — tap to prefill, learner reviews
                  // before sending.
                  if (chat.suggestedReplies.isNotEmpty && !chat.isLoading)
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        itemCount: chat.suggestedReplies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final suggestion = chat.suggestedReplies[i];
                          return Material(
                            color: t.priSoft,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              // Prefills rather than sends — the learner still
                              // reads it before it goes.
                              onTap: () => _inputController.text = suggestion,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: t.priInk,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Input bar
                  _InputBar(
                    controller: _inputController,
                    onSend: _sendMessage,
                    isLoading: chat.isLoading,
                    isListening: _isListening,
                    onMic: _startVoiceInput,
                  ),
                ],
              ),
    );
  }
}

/// Confirm before permanently removing a conversation.
///
/// Chat history is the learner's own writing and cannot be recovered once
/// gone, so this asks first and names what is being deleted.
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ConversationSummary summary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Delete this conversation?'),
          content: Text(
            'Your chat about "${summary.scenario}" will be permanently removed. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
  );
  if (confirmed ?? false) {
    await ref.read(chatProvider.notifier).deleteConversation(summary.id);
  }
}

String _describeDay(DateTime when) {
  final now = DateTime.now();
  final days =
      DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(when.year, when.month, when.day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}

/// Scenario picker — shown when no conversation is active.
class _ScenarioPicker extends ConsumerWidget {
  const _ScenarioPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final recent = ref.watch(recentConversationsProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const DisplayText('AI Tutor', size: 29, weight: FontWeight.w800),
        const SizedBox(height: 6),
        Text(
          'Real situations you will hit this week in Czechia. The tutor adapts '
          'to your level.',
          style: TextStyle(fontSize: 15, color: t.muted, height: 1.5),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          const LessonKicker('Unfinished'),
          const SizedBox(height: 8),
          ...recent.map((summary) {
            final s = _scenarioStyle(context, summary.scenario);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                onTap:
                    () => ref
                        .read(chatProvider.notifier)
                        .resumeConversation(summary),
                child: Row(
                  children: [
                    IconTile(
                      icon: s.icon,
                      tint: s.tint,
                      fg: s.fg,
                      size: 44,
                      radius: 16,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.scenario,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _describeDay(summary.createdAt),
                            style: TextStyle(fontSize: 13, color: t.faint),
                          ),
                        ],
                      ),
                    ),
                    // Deleting chat history cannot be undone, so it is a
                    // deliberate tap with a confirmation rather than a swipe
                    // that can happen while scrolling.
                    IconButton(
                      onPressed: () => _confirmDelete(context, ref, summary),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: t.faint,
                      ),
                      tooltip: 'Delete conversation',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('Pick a situation'),
            Text(
              '${ChatScenario.all.length} rooms',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // A fixed extent rather than an aspect ratio: with an aspect ratio
          // the two cards in a row were sized from the column width and ended
          // up visibly unequal once the descriptions differed in length.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 176,
          ),
          itemCount: ChatScenario.all.length,
          itemBuilder: (context, i) {
            final scenario = ChatScenario.all[i];
            final s = _scenarioStyle(context, scenario.title);
            return SoftCard(
              padding: const EdgeInsets.all(16),
              onTap:
                  () => ref
                      .read(chatProvider.notifier)
                      .startConversation(scenario: scenario),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: s.icon,
                    tint: s.tint,
                    fg: s.fg,
                    size: 44,
                    radius: 16,
                    iconSize: 20,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    scenario.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      scenario.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Chat message bubble with corrections and TTS.
class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  /// Add a tutor-suggested word to the SRS deck and confirm via snackbar.
  Future<void> _addVocabToDeck(
    BuildContext context,
    WidgetRef ref,
    NewVocabulary v,
  ) async {
    final repo = ref.read(vocabularyRepositoryProvider);
    final added = await repo.addManualCard(cz: v.cz, en: v.en, ipa: v.ipa);
    ref.invalidate(dueCardCountProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added "${v.cz}" to your review deck'
              : '"${v.cz}" is already in your deck',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: isUser ? t.userBubble : t.card,
            border: Border.all(color: isUser ? Colors.transparent : t.line),
            boxShadow: t.shadow,
            // Notched toward its own speaker: who said what is legible from
            // the shape, not only from the alignment and colour.
            borderRadius: BorderRadius.circular(24).copyWith(
              bottomLeft:
                  isUser ? const Radius.circular(24) : const Radius.circular(6),
              bottomRight:
                  isUser ? const Radius.circular(6) : const Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Czech text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: isUser ? t.userBubbleTxt : t.ink,
                      ),
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(width: 8),
                    _TtsIconButton(text: message.content),
                  ],
                ],
              ),
              // English translation (tutor only)
              if (!isUser && message.translation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.line)),
                  ),
                  child: Text(
                    message.translation!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
              // Corrections
              if (message.corrections != null &&
                  message.corrections!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...message.corrections!.map(
                  (c) => _CorrectionCard(correction: c),
                ),
              ],
              // New vocabulary
              if (message.newVocabulary != null &&
                  message.newVocabulary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      message.newVocabulary!.map((v) {
                        return ActionChip(
                          label: Text('${v.cz} = ${v.en}'),
                          avatar: const Icon(Icons.add, size: 16),
                          tooltip: 'Add to review deck',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _addVocabToDeck(context, ref, v),
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small TTS icon button for message bubbles.
class _TtsIconButton extends ConsumerWidget {
  final String text;

  const _TtsIconButton({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () {
        ref.read(czechTtsProvider).speak(text);
      },
      icon: const Icon(Icons.volume_up, size: 18),
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: AppLocalizations.of(context).listen,
    );
  }
}

/// Correction card — shows a grammar correction inline.
class _CorrectionCard extends StatelessWidget {
  final Correction correction;

  const _CorrectionCard({required this.correction});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Amber is streak and XP in this palette, so a minor slip is violet — the
    // memory colour — rather than a warning. Only a real error is coral.
    final (ink, tint) = switch (correction.severity) {
      Severity.error => (t.redInk, t.redSoft),
      Severity.minor => (t.violetInk, t.violetSoft),
      Severity.stylistic => (t.muted, t.elev),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 14, color: ink),
              const SizedBox(width: 6),
              Text(
                correction.type.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: correction.userSaid,
                  style: TextStyle(
                    color: ink,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: ink,
                  ),
                ),
                TextSpan(text: '  →  ', style: TextStyle(color: t.faint)),
                TextSpan(
                  text: correction.correct,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
              ],
            ),
            style: TextStyle(fontSize: 15, height: 1.4, color: t.ink),
          ),
          const SizedBox(height: 4),
          Text(
            correction.rule,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// Typing indicator shown while waiting for LLM response.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: 'The tutor is typing',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              boxShadow: t.shadow,
              borderRadius: BorderRadius.circular(
                24,
              ).copyWith(bottomLeft: const Radius.circular(6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(0),
                SizedBox(width: 5),
                _Dot(150),
                SizedBox(width: 5),
                _Dot(300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One bouncing dot of the typing indicator.
///
/// The old version handed a one-shot [TweenAnimationBuilder] a fixed tween and
/// ignored its delay, so the dots faded in once and then sat still — the
/// indicator never actually indicated anything.
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot(this.delay);

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      await Future<void>.delayed(Duration(milliseconds: widget.delay));
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // A short hop in the first 40% of the cycle, then rest.
        final v = _c.value;
        final hop = v < 0.4 ? math.sin(v / 0.4 * math.pi) : 0.0;
        return Transform.translate(
          offset: Offset(0, -4 * hop),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: t.faint.withValues(alpha: 0.25 + 0.75 * hop),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Input bar with text field, voice input, and send button.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final bool isListening;
  final VoidCallback onMic;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isLoading,
    required this.isListening,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.only(left: 18, right: 4),
                decoration: BoxDecoration(
                  color: t.card,
                  border: Border.all(color: t.line, width: 1.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !isLoading,
                        style: TextStyle(fontSize: 16, color: t.ink),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText:
                              isListening
                                  ? 'Listening… speak Czech'
                                  : 'Napiš česky…',
                          hintStyle: TextStyle(color: t.faint, fontSize: 16),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    IconButton(
                      onPressed: isLoading || isListening ? null : onMic,
                      icon: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        size: 20,
                        color: isListening ? t.red : t.muted,
                      ),
                      tooltip: 'Speak your reply',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: isLoading ? null : onSend,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: t.priFill,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: t.priFill.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child:
                    isLoading
                        ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.onFill,
                          ),
                        )
                        : Icon(Icons.send, size: 18, color: t.onFill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
