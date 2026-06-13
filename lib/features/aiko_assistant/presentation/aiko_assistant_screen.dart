import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/aiko_colors.dart';
import '../../aiko_character/presentation/aiko_avatar.dart';
import '../application/aiko_chat_controller.dart';
import '../application/chat_engine.dart';

class AikoAssistantScreen extends ConsumerStatefulWidget {
  const AikoAssistantScreen({super.key});

  @override
  ConsumerState<AikoAssistantScreen> createState() =>
      _AikoAssistantScreenState();
}

class _AikoAssistantScreenState extends ConsumerState<AikoAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = <String>[
    'How much can I safely spend?',
    'Am I on track for my goals?',
    'Where can I cut back?',
    'Give me a quick money check-up.',
  ];

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aikoChatControllerProvider);
    ref.listen(aikoChatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (next.isStreaming && next.messages.isNotEmpty)) {
        _scrollToBottom();
      }
    });

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
                    state.consentOff ? 'Offline mode' : 'Online',
                    style: TextStyle(
                      fontSize: 11,
                      color: state.consentOff
                          ? AikoColors.warningOrange
                          : AikoColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                final isLast = index == state.messages.length - 1;
                return _MessageBubble(
                  message: message,
                  streaming: isLast && state.isStreaming,
                  error: isLast && !state.isStreaming ? state.lastError : null,
                  onRetry: () =>
                      ref.read(aikoChatControllerProvider.notifier).retry(),
                );
              },
            ),
          ),
          if (state.showSuggestions)
            _SuggestionStrip(suggestions: _suggestions, onSelected: _submit),
          _InputBar(
            controller: _textController,
            disabled: state.consentOff || state.isStreaming,
            onSubmit: _submit,
            onChanged: (_) => setState(() {}),
          ),
          if (state.consentOff) const _ConsentOffNotice(),
        ],
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
                  : _ContentBlock(
                      content: message.content,
                      streaming: streaming,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({required this.content, required this.streaming});

  final String content;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty && streaming) {
      return const _ThinkingDots();
    }
    if (streaming && content.isNotEmpty) {
      return RichText(
        text: TextSpan(
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            height: 1.4,
          ),
          children: [
            TextSpan(text: content),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _BlinkingCaret(),
            ),
          ],
        ),
      );
    }
    return Text(
      content,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
        height: 1.4,
      ),
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

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Padding(
        padding: EdgeInsets.only(left: 2),
        child: Text(
          '│',
          style: TextStyle(
            color: AikoColors.primaryBlue,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
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
  const _SuggestionStrip({required this.suggestions, required this.onSelected});

  final List<String> suggestions;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final title = suggestions[index];
          return ActionChip(
            backgroundColor: AikoColors.softBlue.withValues(alpha: 0.35),
            side: BorderSide(
              color: AikoColors.primaryBlue.withValues(alpha: 0.2),
            ),
            label: Text(
              title,
              style: const TextStyle(
                color: AikoColors.deepBlue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () => onSelected(title),
          );
        },
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

class _ConsentOffNotice extends StatelessWidget {
  const _ConsentOffNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AikoColors.paleBlue,
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: AikoColors.deepBlue,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'AI features are off — using offline mode. Enable in Settings → Privacy.',
              style: TextStyle(fontSize: 12, color: AikoColors.deepBlue),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/profile'),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
