import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final List<Map<String, dynamic>> sources;
  final DateTime time;

  _ChatMessage({required this.text, required this.isUser, this.isError = false, this.sources = const []})
      : time = DateTime.now();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  final _quickQuestions = [
    'Which of my accounts are most at risk?',
    'What should I fix first?',
    'What happens if my email gets hacked?',
    'How do I enable 2FA everywhere?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: 'Ask about your accounts, breaches or fixes. Answers come from your own records and the Have I Been Pwned breach catalog, with sources.',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final history = _messages
        .skip(1)
        .where((m) => !m.isError && m.text.isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
      _isTyping = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final data = await _api.post('/ai/chat', body: {
        'message': text.trim(),
        'history': history.length > 10 ? history.sublist(history.length - 10) : history,
      });

      final answer = data['response'] as String?;
      setState(() {
        _messages.add(_ChatMessage(
          text: answer ?? data['error'] as String? ?? '',
          isUser: false,
          isError: answer == null,
          sources: List<Map<String, dynamic>>.from(data['sources'] as List? ?? const []),
        ));
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        final text = e is ApiException ? e.message : "Couldn't reach PrivacyBot. Please try again.";
        _messages.add(_ChatMessage(text: text, isUser: false, isError: true));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) return _buildTypingIndicator();
              return _buildMessageBubble(_messages[i]);
            },
          ),
        ),
        if (_messages.length <= 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickQuestions.length,
              separatorBuilder: (_, i) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => _sendMessage(_quickQuestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _quickQuestions[i],
                      style: const TextStyle(color: AppColors.blue, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask PrivacyBot...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.blue),
                  onPressed: () => _sendMessage(_msgCtrl.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: msg.isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text.replaceAll('**', ''),
                    style: TextStyle(
                      color: msg.isUser ? AppColors.surface : (msg.isError ? AppColors.red : AppColors.textPrimary),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (msg.sources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('RETRIEVED RECORDS', style: AppText.eyebrow()),
                    const SizedBox(height: 6),
                    for (final s in msg.sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 20, child: Text('${s['n']}', style: AppText.mono(size: 11, color: AppColors.textMuted))),
                            Expanded(
                              child: Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: '${s['title']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: s['cited'] == true || msg.isError ? AppColors.textPrimary : AppColors.textMuted,
                                  ),
                                ),
                                TextSpan(text: '  ${s['label']}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                              ])),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text('SEARCHING YOUR RECORDS…', style: AppText.eyebrow()),
    );
  }
}
