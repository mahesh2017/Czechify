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
                backgroundColor: t.card,
                title: Text(chat.scenarioTitle),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(chatProvider.notifier).resetConversation();
                    },
                    tooltip: 'End conversation',
                  ),
                ],
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
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 14,
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
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  // Suggested replies — tap to prefill, learner reviews
                  // before sending.
                  if (chat.suggestedReplies.isNotEmpty && !chat.isLoading)
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: chat.suggestedReplies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final suggestion = chat.suggestedReplies[i];
                          return ActionChip(
                            avatar: const Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                            ),
                            label: Text(suggestion),
                            onPressed: () {
                              _inputController.text = suggestion;
                            },
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
              child: const Text('Cancel'),
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
        const DisplayText('AI Tutor', size: 26),
        const SizedBox(height: 6),
        Text(
          'Practice real-life Czech conversations. The tutor adapts to your level.',
          style: TextStyle(fontSize: 15.5, color: t.muted, height: 1.5),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Continue where you left off',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.muted,
            ),
          ),
          const SizedBox(height: 8),
          ...recent.map((summary) {
            final s = _scenarioStyle(context, summary.scenario);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
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
                      size: 34,
                      radius: 11,
                      iconSize: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        summary.scenario,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                    ),
                    Text(
                      _describeDay(summary.createdAt),
                      style: TextStyle(fontSize: 13, color: t.faint),
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
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.98,
          children:
              ChatScenario.all.map((scenario) {
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
                        size: 38,
                        radius: 13,
                        iconSize: 16,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        scenario.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: Text(
                          scenario.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: t.muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isUser ? t.userBubble : t.card,
            boxShadow: isUser ? null : t.shadow,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft:
                  isUser ? const Radius.circular(20) : const Radius.circular(6),
              bottomRight:
                  isUser ? const Radius.circular(6) : const Radius.circular(20),
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
                        fontSize: 15,
                        height: 1.5,
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
                      fontSize: 14,
                      color: t.muted,
                      fontStyle: FontStyle.italic,
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
    final severityColor = switch (correction.severity) {
      Severity.error => t.red,
      Severity.minor => t.amber,
      Severity.stylistic => t.violet,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: severityColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: severityColor),
              const SizedBox(width: 4),
              Text(
                correction.type.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: correction.userSaid,
                  style: TextStyle(
                    color: severityColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const TextSpan(text: ' → '),
                TextSpan(
                  text: correction.correct,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            correction.rule,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(0),
              SizedBox(width: 4),
              _Dot(200),
              SizedBox(width: 4),
              _Dot(400),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot(this.delay);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: context.tokens.muted.withValues(alpha: opacity * 0.6),
            shape: BoxShape.circle,
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
                height: 50,
                padding: const EdgeInsets.only(left: 18, right: 6),
                decoration: BoxDecoration(
                  color: t.card,
                  boxShadow: t.shadow,
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
                      visualDensity: VisualDensity.compact,
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: t.priFill,
                  shape: BoxShape.circle,
                ),
                child:
                    isLoading
                        ? Padding(
                          padding: const EdgeInsets.all(15),
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
