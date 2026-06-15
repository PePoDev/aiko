import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/aiko_colors.dart';
import '../../aiko_character/presentation/aiko_avatar.dart';
import '../application/aiko_chat_controller.dart';
import '../application/chat_engine.dart';
import '../domain/aiko_prompt_suggestions.dart';
import '../domain/chat_session.dart';
import 'aiko_markdown.dart';

class AikoAssistantScreen extends ConsumerStatefulWidget {
  const AikoAssistantScreen({super.key});

  @override
  ConsumerState<AikoAssistantScreen> createState() =>
      _AikoAssistantScreenState();
}

class _AikoAssistantScreenState extends ConsumerState<AikoAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _suggestionsKey = GlobalKey();

  /// Measured height of the floating suggestion strip, reserved as bottom
  /// padding on the chat list so the last message clears above the chips.
  double _suggestionsHeight = 0;

  /// Suggestions shown on the empty state — randomized once per screen open.
  late final List<String> _initialSuggestions = AikoPromptSuggestions.sample();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _submit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(aikoChatControllerProvider.notifier).send(trimmed);
    _textController.clear();
    _scrollToBottom(animated: false);
  }

  /// Which suggestion chips to show, or null when none apply.
  ///
  /// On the empty state we show the randomized [_initialSuggestions]. Once Aiko
  /// has answered (idle, no error, last message is a finished reply), we show
  /// fresh "next" recommendations seeded on the turn so they stay stable while
  /// that reply is on screen and refresh after the next answer.
  List<String>? _suggestionsFor(ChatState state) {
    if (state.showSuggestions) return _initialSuggestions;
    if (state.isStreaming || state.lastError != null) return null;

    final last = state.messages.last;
    final hasUserTurn = state.messages.any((m) => m.isUser);
    if (last.isUser || last.content.isEmpty || !hasUserTurn) return null;

    final asked = state.messages.where((m) => m.isUser).map((m) => m.content);
    return AikoPromptSuggestions.sample(
      seed: state.messages.length,
      exclude: asked,
    );
  }

  /// Measures the floating suggestion strip after layout and reserves its
  /// height as chat-list bottom padding, so the last message never hides behind
  /// the chips. Guarded so it only calls setState when the value changes.
  void _scheduleSuggestionsMeasure({required bool shown}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = shown
          ? (_suggestionsKey.currentContext?.findRenderObject() as RenderBox?)
                    ?.size
                    .height ??
                _suggestionsHeight
          : 0.0;
      if (target != _suggestionsHeight) {
        setState(() => _suggestionsHeight = target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aikoChatControllerProvider);
    ref.listen(aikoChatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (next.isStreaming && next.messages.isNotEmpty)) {
        _scrollToBottom();
      }
    });

    final suggestions = _suggestionsFor(state);
    _scheduleSuggestionsMeasure(shown: suggestions != null);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            const AikoAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aiko',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    state.offline ? 'On-device mode' : 'Online',
                    style: TextStyle(
                      fontSize: 11,
                      color: state.offline
                          ? AikoColors.warningOrange
                          : AikoColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () {
              _textController.clear();
              ref.read(aikoChatControllerProvider.notifier).newChat();
            },
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Builder(
                  builder: (context) {
                    final history = state.history;
                    final hasHeader = history.isNotEmpty;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12 + _suggestionsHeight,
                      ),
                      itemCount: state.messages.length + (hasHeader ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (hasHeader && index == 0) {
                          final notifier = ref.read(
                            aikoChatControllerProvider.notifier,
                          );
                          return _ChatHistoryList(
                            sessions: history,
                            onOpen: (id) {
                              notifier.loadSession(id);
                              _scrollToBottom(animated: false);
                            },
                            onTogglePin: notifier.togglePin,
                            onDelete: notifier.deleteSession,
                          );
                        }
                        final messageIndex = hasHeader ? index - 1 : index;
                        final message = state.messages[messageIndex];
                        final isLast =
                            messageIndex == state.messages.length - 1;
                        return _MessageBubble(
                          message: message,
                          streaming: isLast && state.isStreaming,
                          error: isLast && !state.isStreaming
                              ? state.lastError
                              : null,
                          onRetry: () => ref
                              .read(aikoChatControllerProvider.notifier)
                              .retry(),
                        );
                      },
                    );
                  },
                ),
                if (suggestions != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SuggestionStrip(
                      key: _suggestionsKey,
                      suggestions: suggestions,
                      onSelected: _submit,
                    ),
                  ),
              ],
            ),
          ),
          _InputBar(
            controller: _textController,
            disabled: state.isStreaming,
            onSubmit: _submit,
            onChanged: (_) => setState(() {}),
          ),
          if (state.offline) const _OfflineNotice(),
        ],
      ),
    );
  }
}

/// The rolling list of saved conversations rendered above Aiko's greeting.
///
/// Each row opens the thread on tap; the trailing star pins it (exempting it
/// from the 3-session rotation) and the trash icon removes it.
class _ChatHistoryList extends StatelessWidget {
  const _ChatHistoryList({
    required this.sessions,
    required this.onOpen,
    required this.onTogglePin,
    required this.onDelete,
  });

  final List<ChatSession> sessions;
  final void Function(String id) onOpen;
  final void Function(String id) onTogglePin;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recent chats',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final session in sessions)
            _ChatHistoryRow(
              key: ValueKey(session.id),
              session: session,
              onOpen: () => onOpen(session.id),
              onTogglePin: () => onTogglePin(session.id),
              onDelete: () => onDelete(session.id),
            ),
        ],
      ),
    );
  }
}

class _ChatHistoryRow extends StatelessWidget {
  const _ChatHistoryRow({
    super.key,
    required this.session,
    required this.onOpen,
    required this.onTogglePin,
    required this.onDelete,
  });

  final ChatSession session;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: session.pinned ? 'Unpin' : 'Pin',
              visualDensity: VisualDensity.compact,
              onPressed: onTogglePin,
              icon: Icon(
                session.pinned ? Icons.star : Icons.star_border,
                size: 20,
                color: session.pinned
                    ? AikoColors.warningOrange
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.streaming,
    required this.error,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool streaming;
  final ChatError? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 10, left: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AikoColors.primaryBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: AikoColors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AikoAvatar(
              size: 32,
              pulse: streaming && message.content.isEmpty,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: error != null
                  ? _ErrorBlock(message: error!.message, onRetry: onRetry)
                  : _ContentBlock(message: message, streaming: streaming),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({required this.message, required this.streaming});

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final content = message.content;
    if (content.isEmpty && streaming) {
      return const _ThinkingDots();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AikoMarkdownText(content: content, streaming: streaming),
        if (!streaming && message.disclaimer != null) ...[
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 6),
          Text(
            message.disclaimer!,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value + i * 0.2) % 1.0;
            final opacity = 0.3 + (1 - (t - 0.5).abs() * 2).clamp(0, 1) * 0.7;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: const Text(
                  '●',
                  style: TextStyle(color: AikoColors.primaryBlue, fontSize: 10),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: 16,
              color: AikoColors.dangerRed,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AikoColors.dangerRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final scaffold = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      // Solid background so messages don't show through behind the chips.
      color: scaffold,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < suggestions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _SuggestionChip(title: suggestions[i], onSelected: onSelected),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.title, required this.onSelected});

  final String title;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AikoColors.softBlue.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AikoColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onSelected(title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            title,
            style: const TextStyle(
              color: AikoColors.deepBlue,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.disabled,
    required this.onSubmit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool disabled;
  final void Function(String) onSubmit;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !disabled,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmit,
                decoration: InputDecoration(
                  hintText: disabled
                      ? 'Aiko is busy...'
                      : 'Ask about your money...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AikoColors.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: (disabled || !hasText)
                  ? AikoColors.softBlue
                  : AikoColors.primaryBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: (disabled || !hasText)
                    ? null
                    : () => onSubmit(controller.text),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    color: AikoColors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AikoColors.paleBlue,
      child: const Row(
        children: [
          Icon(
            Icons.offline_bolt_outlined,
            size: 16,
            color: AikoColors.deepBlue,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'On-device mode — Aiko answers from data on this device. '
              'Connect to Aiko cloud for richer, up-to-date insights.',
              style: TextStyle(fontSize: 12, color: AikoColors.deepBlue),
            ),
          ),
        ],
      ),
    );
  }
}
