import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../application/aiko_assistant_service.dart';
import '../domain/aiko_response.dart';
import '../../accounts/domain/account.dart';

class AikoAssistantScreen extends ConsumerStatefulWidget {
  const AikoAssistantScreen({super.key});

  @override
  ConsumerState<AikoAssistantScreen> createState() =>
      _AikoAssistantScreenState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
    this.explanation,
    this.disclaimer,
    this.recommendation,
    this.expression = 'assets/images/aiko/aiko_happy.png',
  });

  final String text;
  final bool isMe;
  final DateTime time;
  final String? explanation;
  final String? disclaimer;
  final String? recommendation;
  final String expression;
}

class _AikoAssistantScreenState extends ConsumerState<AikoAssistantScreen> {
  static const _service = AikoAssistantService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  String _currentExpression = 'assets/images/aiko/aiko_welcome.png';
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            "Hi there! I'm Aiko, your blue-haired personal finance assistant. 💙 Let me know how I can guide you today!",
        isMe: false,
        time: DateTime.now(),
        expression: 'assets/images/aiko/aiko_welcome.png',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isMe: true, time: DateTime.now()));
      _isTyping = true;
      _currentExpression = 'assets/images/aiko/aiko_thinking.png';
    });
    _scrollToBottom();
    _controller.clear();

    // Mock network/processing delay for interactive feel
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Load active states from Riverpod
    final profile = await ref.read(profileProvider.future);
    final transactions = await ref.read(transactionsProvider.future);
    final accounts = await ref.read(accountsProvider.future);
    final budgets = await ref.read(budgetsProvider.future);
    final goals = await ref.read(goalsProvider.future);
    final insights = await ref.read(aikoInsightsProvider.future);

    final aiConsent = profile.aiConsentEnabled;

    // We can fetch safeToSpend estimation cushion if available from dashboard or simple math
    final double safeToSpendValue =
        accounts.fold<double>(0, (sum, acc) {
          if (acc.type == AccountType.cash || acc.type == AccountType.bank) {
            return sum + acc.currentBalance.amount.toDouble();
          }
          return sum;
        }) *
        0.15; // 15% cash safe-to-spend mock cushion if none available
    final safeToSpendAmount = Money.parse(
      safeToSpendValue.toStringAsFixed(2),
      'USD',
    );

    final response = _service.answerQuestion(
      question: text,
      aiConsentEnabled: aiConsent,
      safeToSpendAmount: safeToSpendAmount,
      insights: insights,
      accounts: accounts,
      budgets: budgets,
      goals: goals,
      transactions: transactions,
    );

    // Map response type to character expression
    String responseExpression = 'assets/images/aiko/aiko_happy.png';
    final normalized = text.toLowerCase();

    if (response.type == AikoResponseType.missingData) {
      responseExpression = 'assets/images/aiko/aiko_warning.png';
    } else if (normalized.contains('net worth') ||
        normalized.contains('goal') ||
        normalized.contains('celebrate')) {
      responseExpression = 'assets/images/aiko/aiko_celebrating.png';
    } else if (normalized.contains('safe') ||
        normalized.contains('spend') ||
        normalized.contains('optimize')) {
      responseExpression = 'assets/images/aiko/aiko_encouraging.png';
    } else if (normalized.contains('help') ||
        response.type == AikoResponseType.disclaimer) {
      responseExpression = 'assets/images/aiko/aiko_thinking.png';
    }

    setState(() {
      _isTyping = false;
      _currentExpression = responseExpression;
      _messages.add(
        _ChatMessage(
          text: response.answer,
          isMe: false,
          time: DateTime.now(),
          explanation: response.explanation,
          disclaimer: response.disclaimer,
          recommendation: response.recommendation,
          expression: responseExpression,
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AikoColors.softBlue,
              child: Icon(Icons.face_3, color: AikoColors.primaryBlue),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aiko Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Online companion',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Aiko Face Display Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AikoColors.white,
              border: Border(
                bottom: BorderSide(color: AikoColors.border.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  _currentExpression,
                  width: 60,
                  height: 60,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.face_3,
                    size: 60,
                    color: AikoColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aiko Guidance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AikoColors.darkNavy,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Aiko analyzes your budgets, savings goals, and cash flow in real-time.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Quick reply chips
          _buildQuickReplyChips(),

          // Input text bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AikoColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AikoColors.border.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/aiko/aiko_thinking.png',
              width: 24,
              height: 24,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            const Text(
              'Aiko is thinking...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AikoColors.primaryBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: AikoColors.white, fontSize: 14),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              msg.expression,
              width: 36,
              height: 36,
              errorBuilder: (_, _, _) => const CircleAvatar(
                radius: 18,
                backgroundColor: AikoColors.softBlue,
                child: Icon(
                  Icons.face_3,
                  size: 20,
                  color: AikoColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AikoColors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AikoColors.border.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AikoColors.border.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AikoColors.darkNavy,
                        height: 1.3,
                      ),
                    ),
                    if (msg.explanation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        msg.explanation!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (msg.recommendation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AikoColors.softBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: AikoColors.primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                msg.recommendation!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AikoColors.deepBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (msg.disclaimer != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        msg.disclaimer!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplyChips() {
    final suggestions = [
      'Estimate Safe-to-Spend',
      'What\'s my Net Worth?',
      'Check Savings Goals',
      'Summarize Budgets',
      'How to Optimize?',
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final title = suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: AikoColors.white,
              side: BorderSide(color: AikoColors.border.withOpacity(0.5)),
              label: Text(
                title,
                style: const TextStyle(
                  color: AikoColors.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => _sendMessage(title),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AikoColors.white,
        border: Border(
          top: BorderSide(color: AikoColors.border.withOpacity(0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask about your money...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AikoColors.primaryBlue),
              onPressed: () => _sendMessage(_controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}
