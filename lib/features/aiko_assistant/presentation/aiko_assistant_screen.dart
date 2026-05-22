import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/aiko_assistant_service.dart';
import '../domain/aiko_response.dart';

class AikoAssistantScreen extends StatefulWidget {
  const AikoAssistantScreen({super.key});

  @override
  State<AikoAssistantScreen> createState() => _AikoAssistantScreenState();
}

class _AikoAssistantScreenState extends State<AikoAssistantScreen> {
  static const _service = AikoAssistantService();
  final _controller = TextEditingController();
  late AikoResponse _response;

  @override
  void initState() {
    super.initState();
    _response = _service.safeToSpend(
      aiConsentEnabled: true,
      safeToSpendAmount: Money.parse('245', 'USD'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask() {
    setState(() {
      _response = _service.answerQuestion(
        question: _controller.text,
        aiConsentEnabled: true,
        safeToSpendAmount: Money.parse('245', 'USD'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Ask Aiko',
            icon: Icons.auto_awesome,
            accentColor: AikoColors.premiumPurple,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_response.answer),
                if (_response.explanation != null) ...[
                  const SizedBox(height: 8),
                  Text(_response.explanation!),
                ],
                if (_response.hasDisclaimer) ...[
                  const SizedBox(height: 8),
                  Text(
                    _response.disclaimer!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Ask about your money',
              suffixIcon: IconButton(
                tooltip: 'Send question',
                onPressed: _ask,
                icon: const Icon(Icons.send),
              ),
            ),
            onSubmitted: (_) => _ask(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/calculators'),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Open calculators'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go('/learning-hub'),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Open Learning Hub'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go('/aiko-optimize'),
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Open Aiko Optimize'),
          ),
        ],
      ),
    );
  }
}
