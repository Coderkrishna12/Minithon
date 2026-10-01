import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final DateTime time;

  _ChatMessage({required this.text, required this.isUser})
    : time = DateTime.now();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;
  static const _voiceChannel = MethodChannel('privacyshield/voice');

  final _quickQuestions = [
    'Which of my accounts are most at risk?',
    'What should I fix first?',
    'What happens if my email gets hacked?',
    'How do I enable 2FA everywhere?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            "Hi! I'm PrivacyBot, your AI security assistant. Ask me anything about your digital security.",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
      _isTyping = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m != _messages.first)
          .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
          )
          .toList();

      final data = await _api.post(
        '/ai/chat',
        body: {
          'message': text.trim(),
          'history': history.length > 10
              ? history.sublist(history.length - 10)
              : history,
        },
      );

      setState(() {
        _messages.add(
          _ChatMessage(
            text: data['response'] ?? 'I could not process that.',
            isUser: false,
          ),
        );
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        final text = e is ApiException
            ? e.message
            : "Couldn't reach PrivacyBot. Please try again.";
        _messages.add(_ChatMessage(text: text, isUser: false));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _listen() async {
    setState(() => _isListening = true);
    try {
      final phrase = await _voiceChannel.invokeMethod<String>('listen');
      if (!mounted || phrase == null || phrase.trim().isEmpty) return;
      final prefix = _msgCtrl.text.trim();
      _msgCtrl.text = prefix.isEmpty
          ? phrase.trim()
          : '$prefix ${phrase.trim()}';
      _msgCtrl.selection = TextSelection.collapsed(
        offset: _msgCtrl.text.length,
      );
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Voice input is unavailable.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
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
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 12,
                      ),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  tooltip: _isListening ? 'Listening…' : 'Ask with voice',
                  icon: _isListening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic_none, color: AppColors.blue),
                  onPressed:
                      _isListening ||
                          !{
                            TargetPlatform.android,
                            TargetPlatform.iOS,
                          }.contains(defaultTargetPlatform)
                      ? null
                      : _listen,
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
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.blue, AppColors.purple],
                ),
              ),
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.blue : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: msg.isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
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
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
              ),
            ),
            child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                  child: const _TypingDot(),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot();

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textMuted.withAlpha(
            (100 + 155 * _ctrl.value).toInt(),
          ),
        ),
      ),
    );
  }
}
