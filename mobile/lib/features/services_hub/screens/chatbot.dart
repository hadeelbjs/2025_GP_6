import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import 'package:waseed/services/api_services.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ChatbotIntroScreen();
  }
}

class ChatbotIntroScreen extends StatelessWidget {
  const ChatbotIntroScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: const Text(
            'مساعدك الذكي',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Spacer(),

                // أيقونة
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 76,
                    color: AppColors.primary.withOpacity(0.60),
                  ),
                ),

                const SizedBox(height: 26),

                Text(
                  'نساعدك تحمي نفسك\nبخطوات بسيطة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 34),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatbotChatScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ابدأ المحادثة الآن',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatbotChatScreen extends StatefulWidget {
  const ChatbotChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotChatScreen> createState() => _ChatbotChatScreenState();
}

class _ChatbotChatScreenState extends State<ChatbotChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final ApiService _api = ApiService();
  bool _isSending = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'هلا! اسأليني أي سؤال أمني، مثل: كيف أتأكد من رابط مشبوه؟',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _messages.add(_ChatMessage(text: 'جاري الرد...', isUser: false));
    });

    _scrollToBottom();

    try {
      final data = await _api.askChatbot(text);

      setState(() {
        // نحذف placeholder
        if (_messages.isNotEmpty && _messages.last.text == 'جاري الرد...') {
          _messages.removeLast();
        }

        final reply = (data['reply'] ?? '').toString().trim();
        final reason = (data['reason'] ?? '').toString().trim();
        final success = data['success'] == true;

        final finalText = reply.isNotEmpty
            ? reply
            : (reason.isNotEmpty
                  ? 'لم يتم الرد. السبب: $reason'
                  : 'ما وصلتني إجابة واضحة. جربي مرة ثانية.');

        _messages.add(_ChatMessage(text: finalText, isUser: false));
      });
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.text == 'جاري الرد...') {
          _messages.removeLast();
        }
        _messages.add(
          _ChatMessage(
            text: 'صار خطأ في الاتصال بالسيرفر. حاولي مرة ثانية.',
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: const Text(
            'مساعدك الذكي',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _bubble(_messages[index]),
              ),
            ),

            // Quick Questions
            _quickQuestionsPanel(),
            // Input
            _assistantTextOnlyBar(),
            /*
            // Quick Questions
            _quickQuestionsPanel(),
          */
          ],
        ),
      ),
    );
  }

  Widget _assistantTextOnlyBar() {
    final canSend = _controller.text.trim().isNotEmpty && !_isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // صندوق الإدخال (نفس ستايل التشات)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isSending,
                        maxLines: null,
                        textDirection: TextDirection.rtl,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        decoration: InputDecoration(
                          hintText: 'اكتب سؤالك هنا...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 17,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: canSend ? (_) => _send() : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    // (اختياري) زر إخفاء الكيبورد مثل التشات
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 4,
                            bottom: 10,
                          ),
                          child: Icon(
                            Icons.keyboard_hide,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // زر الإرسال (نفس التشات)
            GestureDetector(
              onTap: canSend ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: canSend
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: !canSend ? Colors.grey.shade300 : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: canSend
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: canSend ? Colors.white : Colors.grey.shade500,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _quickQuestions = const [
    'كيف أتأكد إن الرابط آمن قبل ما أفتحه؟',
    'وش علامات الرسائل الاحتيالية (Phishing)؟',
    'كيف أسوي كلمة مرور قوية وآمنة؟',
    'كيف أفعل التحقق بخطوتين (2FA)؟',
    'إذا انسرق حسابي وش أول خطوة أسويها؟',
    'كيف أعرف إذا جهازي مخترق أو فيه تطبيق تجسس؟',
  ];

  Widget _quickQuestionsPanel() {
    //  اخفيها إذا المستخدم بدأ يكتب
    if (_controller.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _quickQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final q = _quickQuestions[index];

          return GestureDetector(
            onTap: () {
              _controller.text = q;
              setState(() {});
              _send();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  q,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontFamily: 'IBMPlexSansArabic',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withOpacity(0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUser
                ? AppColors.primary.withOpacity(0.18)
                : Colors.grey.shade200,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 13,
            height: 1.35,
            color: Colors.black.withOpacity(0.78),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}
