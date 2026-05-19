import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/api_services.dart';
import '../../../services/socket_service.dart';
import '../../../services/messaging_service.dart';
import '../../../services/local_db/database_helper.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waseed/features/massaging/widgets/unified_screenshot_protector.dart';
import '../widgets/duration_picker_sheet.dart';
import 'package:http/http.dart' as http;
import '../../../services/media_service.dart';
import '../../../services/screenshot_protection_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String username;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // مكان كتابة الرسائل
  final _messageController = TextEditingController();
  final _messagingService = MessagingService();
  final _scrollController = ScrollController();
  final _socketService = SocketService();
  bool _myPolicyAllowsScreenshots = false; // أنا أسمح للطرف الآخر؟
  bool _peerAllowsMyScreenshots = false; // الطرف الآخر يسمح لي؟
  bool _isLoadingScreenshotPolicy = true;
  final _mediaService = MediaService.instance;
  final ScreenCaptureEvent _screenListener = ScreenCaptureEvent();
  //  منع تكرار التنبيهات
  bool _hasShownScreenshotChangeMessage = false;
  String? _lastScreenshotPolicyHash;

  int _sessionResetAttempts = 0;
  static const int _maxSessionResetAttempts = 2;

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _conversationId;

  bool _isDecryptingMessages = false;

  int _decryptionFailureCount = 0;

  //delete
  bool _hasShownDecryptionDialog = false; // لتجنب عرض Dialog متعدد

  File? _pendingImageFile;
  PlatformFile? _pendingFile;

  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _deleteSubscription;
  StreamSubscription? _statusSubscription;
  int? currentDuration;
  StreamSubscription? _messageExpiredSubscription;

  StreamSubscription? _userStatusSubscription;
  StreamSubscription? _connectionSubscription;
  bool _isOtherUserOnline = false;
  bool _rekeyRequired = false;
  Timer? _rekeyRetryTimer;

  //  للكشف عن Screenshot في iOS
  // StreamSubscription? _screenshotSubscription;
  StreamSubscription? _uploadProgressSubscription;
  UploadProgress? _currentProgress;

  // Pulse Animation لأيقونة الساعة
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize pulse animation controller and animation
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initScreenshotProtection();

    _socketService.socket?.on('privacy:screenshots:changed', (data) {
      if (data['peerUserId'] == widget.userId) {
        final newPeerPolicy = data['allowScreenshots'] == true;
        //final newPolicy = data['allowScreenshots'] == true;
        final policyHash = '${widget.userId}_$newPeerPolicy';

        //  منع التكرار
        if (_lastScreenshotPolicyHash == policyHash) {
          return;
        }
        _lastScreenshotPolicyHash = policyHash;

        if (mounted) {
          setState(() {
            _peerAllowsMyScreenshots = newPeerPolicy;
          });
          bool wasDialogOpen = false;
          Navigator.of(context, rootNavigator: true).popUntil((route) {
            if (route is DialogRoute) {
              wasDialogOpen = true;
              return false;
            }
            return true;
          });

          if (wasDialogOpen) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _showOptionsDialog();
              }
            });
          }
          // عرض إشعار للمستخدم
          if (!_hasShownScreenshotChangeMessage) {
            _hasShownScreenshotChangeMessage = true;
            _showPolicyChangeNotification(newPeerPolicy);
            Future.delayed(Duration(seconds: 2), () {
              _hasShownScreenshotChangeMessage = false;
            });
          }
        }
      }
    });

    _socketService.socket?.on('screenshot:notification', (data) {
      if (!mounted) return;

      final takenByUserId = data['takenByUserId'];
      final takenByName = data['takenByName'] ?? widget.name;

      // فقط إذا كان من المحادثة الحالية
      if (takenByUserId == widget.userId) {
        _showScreenshotTakenByPeerNotification(takenByName);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadScreenshotPolicyFromServer();
    });

    _setupScreenshotDetection();
    _initializeChat();
    _listenToUserStatus();
    _messagingService.setCurrentOpenChat(widget.userId);
    _listenToExpiredMessages();
    _listenToUploadProgress();
    _restoreRekeyState();
  }

  void _listenToUploadProgress() {
    _uploadProgressSubscription = _messagingService.onUploadProgress.listen((
      progress,
    ) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
        });

        // ✅ إخفاء المؤشر بعد الانتهاء أو الخطأ
        if (progress.isComplete || progress.isError) {
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _currentProgress = null;
              });
            }
          });
        }
      }
    });
  }

  Future<void> _restoreRekeyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final required = prefs.getBool('rekey_required_${widget.userId}') ?? false;
      if (!mounted) return;
      if (required) {
        _setRekeyRequired(true, showMessage: false);
        _attemptRekeyRecovery();
      }
    } catch (_) {}
  }

  void _setRekeyRequired(bool value, {bool showMessage = true}) {
    if (!mounted) return;
    setState(() {
      _rekeyRequired = value;
    });

    if (value) {
      _startRekeyRetryTimer();
      if (showMessage) {
        _showMessage(
          'تم تفعيل وضع الطوارئ للطرف الآخر. سيتم استئناف الإرسال بعد إعادة تهيئة التشفير.',
          false,
        );
      }
    } else {
      _rekeyRetryTimer?.cancel();
      _rekeyRetryTimer = null;
    }
  }

  void _startRekeyRetryTimer() {
    _rekeyRetryTimer?.cancel();
    _rekeyRetryTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _attemptRekeyRecovery();
    });
  }

  Future<void> _attemptRekeyRecovery() async {
    if (!mounted || !_rekeyRequired || _isSending) return;
    final ok = await _messagingService.createNewSession(widget.userId);
    if (!ok || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rekey_required_${widget.userId}');
    _setRekeyRequired(false, showMessage: false);
    _showMessage('تمت إعادة تهيئة التشفير بنجاح. يمكنك المتابعة.', true);
  }

  /// تهيئة خدمة حماية الشاشة
  Future<void> _initScreenshotProtection() async {
    await ScreenshotProtectionService.initialize(
      onScreenshotTaken: () {
        // عند التقاط الشاشة - إرسال إشعار للطرف الآخر
        if (!_peerAllowsMyScreenshots) {
          _socketService.socket?.emit('screenshot:taken', {
            'targetUserId': widget.userId,
          });
          print('📸 Screenshot taken - notification sent to ${widget.userId}');
        }
      },
      onScreenRecordingChanged: (isRecording) {
        if (isRecording && !_peerAllowsMyScreenshots) {
          print('🎥 Screen recording detected');
        }
      },
    );
  }

  // =====================================================
  //  دالة جلب السياسة من السيرفر
  // =====================================================
  Future<void> _loadScreenshotPolicyFromServer() async {
    try {
      setState(() => _isLoadingScreenshotPolicy = true);

      //  جلب السياسة الحالية من الـ API
      final result = await ApiService.instance.getJson(
        '/contacts/${widget.userId}/screenshots',
      );

      if (result['success'] == true) {
        setState(() {
          // سياستي: هل أسمح للطرف الآخر بالتقاط شاشتي
          _myPolicyAllowsScreenshots = result['myPolicy'] ?? false;
          // سياسة الطرف الآخر: هل يسمح لي بالتقاط شاشته
          _peerAllowsMyScreenshots = result['peerPolicy'] ?? false;
        });

        print('📷 Screenshot policies loaded:');
        print('   My policy (I allow peer): $_myPolicyAllowsScreenshots');
        print('   Peer policy (allows me): $_peerAllowsMyScreenshots');
      } else {
        // في حالة الفشل: استخدام القيمة الافتراضية (منع اللقطات)
        setState(() {
          _myPolicyAllowsScreenshots = false;
          _peerAllowsMyScreenshots = false;
        });
      }
    } catch (e) {
      print('❌ Error loading screenshot policy: $e');
      // في حالة الخطأ: منع اللقطات للأمان
      setState(() {
        _myPolicyAllowsScreenshots = false;
        _peerAllowsMyScreenshots = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingScreenshotPolicy = false);
      }
    }
  }

  // =====================================================
  //  الكشف عن Screenshot في iOS
  // =====================================================
  void _setupScreenshotDetection() {
    if (Platform.isIOS) {
      _screenListener.addScreenShotListener((filePath) {
        print(' Screenshot detected on iOS!');

        // إرسال إشعار للطرف الآخر عبر الـ socket
        _socketService.socket?.emit('screenshot:taken', {
          'targetUserId': widget.userId,
          'takenBy': 'me', // السيرفر يستبدلها بالـ userId الحقيقي لو حابّين
        });

        // عرض رسالة تحذيرية عندي في الجهاز
        _showMessage('لا يُسمح بأخذ لقطات شاشة لهذا المحتوى', false);
      });

      _screenListener.watch();
    }
  }

  Future<void> _saveScreenshotPolicyToServer(bool allow) async {
    try {
      final result = await ApiService.instance.putJson(
        '/contacts/${widget.userId}/screenshots',
        {'allowScreenshots': allow},
      );

      if (result['success'] != true) {
        _showMessage('فشل حفظ الإعداد في السيرفر', false);
      } else {
        print('Screenshot policy saved to server');

        //  إرسال إشعار للطرف الآخر عبر Socket
        _socketService.socket?.emit('privacy:screenshots:update', {
          'targetUserId': widget.userId,
          'allowScreenshots': allow,
        });
      }
    } catch (e) {
      print('❌ Error saving screenshot policy: $e');
      _showMessage('حدث خطأ أثناء حفظ الإعداد', false);
    }
  }

  Future<void> _loadDuration() async {
    if (_conversationId == null) return;

    try {
      final duration = await _messagingService.getUserDuration(
        _conversationId!,
      );
      if (mounted) {
        setState(() {
          currentDuration = duration;
        });
        
        // إدارة Pulse Animation بناءً على وجود المدة
        if (duration != null) {
          // إيقاف Animation إذا كانت المدة موجودة
          if (_pulseAnimationController.isAnimating) {
            _pulseAnimationController.stop();
          }
        } else {
          // بدء Animation إذا لم تكن المدة موجودة
          if (!_pulseAnimationController.isAnimating) {
            _pulseAnimationController.repeat(reverse: true);
          }
        }
        
        print('⏱️ Duration loaded: ${duration}s');
      }
    } catch (e) {
      print('❌ Error loading duration: $e');
    }
  }
  //عرض إشعار تغيير السياسة:

  void _showPolicyChangeNotification(bool peerAllows) {
  if (!mounted) return;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -20 * (1 - value)),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: peerAllows ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (peerAllows ? Colors.green : Colors.red).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  peerAllows ? Icons.check_circle : Icons.block,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    peerAllows
                        ? '${widget.name} سمح لك بلقطات الشاشة'
                        : '${widget.name} منع لقطات الشاشة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  Future.delayed(const Duration(seconds: 3), () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}

  void _showScreenshotTakenByPeerNotification(String peerName) {
  if (!mounted) return;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            // التأكد من أن القيمة دائماً بين 0 و 1
            final clampedValue = value.clamp(0.0, 1.0);
            return Opacity(
              opacity: clampedValue,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - clampedValue)),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade800],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تم التقاط الشاشة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$peerName قام بالتقاط شاشة المحادثة',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  Future.delayed(const Duration(seconds: 4), () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}
  void _listenToExpiredMessages() {
    _messageExpiredSubscription = _messagingService.onMessageExpired.listen((
      data,
    ) {
      final messageId = data['messageId'] as String;
      print('⏱️ Message expired: $messageId');

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
          print('🧹 Removed from _messages: $messageId');
        });
      }
    });
  }

  Future<void> _selectDuration() async {
  if (_conversationId == null) return;

  final selected = await DurationPickerSheet.show(
    context,
    currentDuration: currentDuration,
  );

  if (selected != null) {
    try {
      await _messagingService.setUserDuration(_conversationId!, selected);

      if (mounted) {
        setState(() {
          currentDuration = selected;
        });

        // إيقاف Pulse Animation عند اختيار المدة
        if (_pulseAnimationController.isAnimating) {
          _pulseAnimationController.stop();
        }

        // إشعار محسّن في الأعلى
        final overlay = Overlay.of(context);
        late OverlayEntry entry;

        entry = OverlayEntry(
          builder: (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -20 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'تم تحديد المدة: ${_formatDuration(selected)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          fontFamily: 'IBMPlexSansArabic',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        overlay.insert(entry);

        Future.delayed(const Duration(seconds: 2), () {
          if (entry.mounted) {
            entry.remove();
          }
        });
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }
}

  // تنسيق المدة
  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}ث';
    if (seconds < 3600) return '${seconds ~/ 60}د';
    return '${seconds ~/ 3600}س';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _screenListener.dispose();
    _pulseAnimationController.dispose();
    _newMessageSubscription?.cancel();
    _deleteSubscription?.cancel();
    _statusSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _rekeyRetryTimer?.cancel();
    _messageExpiredSubscription?.cancel();
    _uploadProgressSubscription?.cancel();
    _socketService.socket?.off('screenshot:notification');
    _socketService.socket?.off('privacy:screenshots:changed');
    //_screenshotSubscription?.cancel();
    _messagingService.setCurrentOpenChat(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //  مراقبة lifecycle للتطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // print('🔄 App resumed - ensuring socket connection...');
      _ensureSocketConnection();
    }
  }

  Future<void> _ensureSocketConnection() async {
    try {
      if (!_messagingService.isConnected) {
        print('🔌 Socket not connected - initializing...');
        final success = await _messagingService.initialize();
        if (success) {
          print('✅ Socket connected after resume');
        } else {
          print('❌ Failed to connect socket after resume');
          return;
        }
      }

      //  طلب الحالة دائماً عند العودة للتطبيق (حتى لو Socket متصل)
      // لأن السيرفر يحتاج أن يعرف أن المستخدم عاد online
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          // print('🔄 Requesting user status after resume...');
          _messagingService.requestUserStatus(widget.userId);
        }
      });
    } catch (e) {
      print('Error ensuring socket connection: $e');
    }
  }

  Future<void> _printDebugInfo() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
  }

  Future<void> _decryptAllMessages() async {
    try {
      if (_conversationId == null) return;

      print('Starting decryption for conversation: $_conversationId');

      final result = await _messagingService.decryptAllConversationMessages(
        _conversationId!,
      );

      if (result['error'] == 'SessionReset' && mounted) {
        Navigator.pushReplacementNamed(context, '/chats');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت إعادة تعيين الجلسة لتغير مفاتيح التشفير يرجى إعادة الدخول للمحادثة',
            ),
          ),
        );
      }

      if (result['success'] == true) {
        final count = result['count'] ?? 0;

        if (count > 0) {
          print('Decrypted $count messages successfully');
          await _loadMessagesFromDatabase();

          _decryptionFailureCount = 0;
          _hasShownDecryptionDialog = false;
        } else {
          print('ℹNo encrypted messages to decrypt');
        }
      } else {
        // ❌ فشل فك التشفير
        final errorType = result['error'];

        print('❌ Decryption failed: $errorType');

        // ========================================
        //  معالجة خاصة لـ InvalidSessionException
        // ========================================
        if (errorType == 'InvalidSessionException' ||
            errorType == 'NoSessionException' ||
            errorType?.toString().contains('session') == true) {
          print('⚠️ Session error detected - auto-recreating session');

          // إنشاء session جديد تلقائياً بدون سؤال المستخدم
          await _autoRecreateSession();
          return; // الخروج بعد إعادة الإنشاء
        }
      }
    } catch (e) {
      print('❌ Exception during decryption: $e');

      // ✅ التحقق من نوع الاستثناء
      if (e.toString().contains('session') ||
          e.toString().contains('Session')) {
        print('⚠️ Session exception caught - auto-recreating');
        await _autoRecreateSession();
      } else {
        _showMessage('فشل فك تشفير الرسائل', false);
      }
    }
  }

  //review

  // ========================================
  //: إعادة إنشاء Session تلقائياً (بدون Dialog)
  // ========================================
  Future<void> _autoRecreateSession() async {
    try {
      print('Auto-recreating session for ${widget.userId}');

      // التحقق من آخر محاولة
      final lastAttemptKey = 'last_session_reset_${widget.userId}';
      final lastAttemptStr = await FlutterSecureStorage().read(
        key: lastAttemptKey,
      );

      if (lastAttemptStr != null) {
        final lastAttempt = DateTime.parse(lastAttemptStr);
        final timeSince = DateTime.now().difference(lastAttempt);

        if (timeSince.inMinutes < 2) {
          print(
            '⚠️ Session reset blocked - attempted ${timeSince.inSeconds}s ago',
          );
          _showMessage('يرجى الانتظار قبل إعادة المحاولة', false);
          return;
        }
      }

      // حفظ وقت المحاولة
      await FlutterSecureStorage().write(
        key: lastAttemptKey,
        value: DateTime.now().toIso8601String(),
      );

      _showMessage('جاري إصلاح جلسة التشفير...', true);

      // حذف Session القديم
      await _messagingService.deleteSession(widget.userId);
      print('Old session deleted');

      // إنشاء Session جديد
      final success = await _messagingService.createNewSession(widget.userId);

      if (success) {
        print('New session created automatically');

        // إعادة تعيين العدادات
        _decryptionFailureCount = 0;
        _hasShownDecryptionDialog = false;

        // إعادة تحميل الرسائل
        await _loadMessagesFromDatabase();

        // عرض رسالة نجاح
        _showMessage('تم إصلاح جلسة التشفير بنجاح', true);

        // لا نعيد محاولة فك التشفير تلقائياً - ننتظر رسالة جديدة
        // await Future.delayed(Duration(seconds: 1));
        // await _decryptAllMessages();
      } else {
        print('❌ Failed to auto-create session');
        _showMessage('فشل إصلاح جلسة التشفير', false);

        /* // إذا فشل الإنشاء التلقائي، عرض Dialog للمستخدم
        if (mounted && !_hasShownDecryptionDialog) {
          _hasShownDecryptionDialog = true;
          await _showDecryptionFailureDialog();
        }*/
      }
    } catch (e) {
      print('❌ Error in auto-recreate session: $e');
      _showMessage('حدث خطأ أثناء إصلاح الجلسة', false);

      /* // في حالة الخطأ، عرض Dialog للمستخدم
      if (mounted && !_hasShownDecryptionDialog) {
        _hasShownDecryptionDialog = true;
        await _showDecryptionFailureDialog();
      }*/
    }
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    try {
      final initialized = await _messagingService.initialize();

      if (!initialized) {
        _showMessage('فشل الاتصال بالخادم', false);
        return;
      }

      _conversationId = _messagingService.getConversationId(widget.userId);

      await _loadMessagesFromDatabase();
      _subscribeToRealtimeUpdates();
      await _messagingService.markConversationAsRead(_conversationId!);
      await _loadDuration();

      //فك تشفير الرسائل بعد التهيئة مباشرة
      if (_conversationId != null) {
      _showDecryptionDialog();
      
      await _decryptAllMessages();
      
      // إغلاق الـ dialog بعد الانتهاء
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _loadMessagesFromDatabase();
}
    } catch (e) {
      _showMessage('حدث خطأ في تهيئة المحادثة', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessagesFromDatabase() async {
    try {
      await DatabaseHelper.instance.deleteExpiredMessages();
      final messages = await _messagingService.getConversationMessages(
        _conversationId!,
        limit: 50,
      );

      final now = DateTime.now();
      final filteredMessages = messages.where((msg) {
        final expiresAt = msg['expiresAt'];
        if (expiresAt != null) {
          DateTime? expiryDateTime;

          if (expiresAt is int) {
            expiryDateTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
          } else if (expiresAt is String) {
            expiryDateTime = DateTime.tryParse(expiresAt);
          }

          if (expiryDateTime != null && now.isAfter(expiryDateTime)) {
            DatabaseHelper.instance.deleteMessageById(msg['id']);
            return false;
          }
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(filteredMessages);
        });

        await DatabaseHelper.instance.deleteExpiredMessages();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      });
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  void _subscribeToRealtimeUpdates() {
    _newMessageSubscription = _messagingService.onNewMessage.listen((data) async {
    if (data['conversationId'] == _conversationId) {
      // Await decryption pipeline fully before reading the database row
      await _decryptAllMessages();
      await _loadMessagesFromDatabase();
    }
  });

    _deleteSubscription = _messagingService.onMessageDeleted.listen((
      data,
    ) async {
      if (!mounted) return;

      final deletedMessageId = data['messageId'];
      final deletedFor = data['deletedFor'];

      setState(() {
        if (deletedFor == 'everyone') {
          _messages.removeWhere((m) => m['id'] == deletedMessageId);
        } else if (deletedFor == 'recipient') {
          _messages.removeWhere((m) => m['id'] == deletedMessageId);
        }
      });
    });

    _statusSubscription = _messagingService.onMessageStatusUpdate.listen((
      data,
    ) {
      // التعامل مع فشل التحقق عند المستقبل
      if (data['type'] == 'peer_emergency_mode') {
        final peerId = data['userId'];
        if (peerId == widget.userId && mounted) {
          _setRekeyRequired(true);
        }
        return;
      }

      if (data['type'] == 'recipient_failed_verification') {
        final recipientId = data['recipientId'];
        if (recipientId == widget.userId && mounted) {
          // إعادة تحميل الرسائل لتحديث العلامات
          _loadMessagesFromDatabase();
        }
        return;
      }

      // التعامل العادي مع تحديثات الحالة
      final messageId = data['messageId'];
      final newStatus = data['status'];

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            final updatedMessage = Map<String, dynamic>.from(_messages[index]);
            updatedMessage['status'] = newStatus;
            _messages[index] = updatedMessage;
          }
        });
      }
    });
  }

  void _listenToUserStatus() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        _messagingService.requestUserStatus(widget.userId);
      }
    });

    _userStatusSubscription = _messagingService.onUserStatusChange.listen((
      data,
    ) {
      if (data['userId'] == widget.userId) {
        if (mounted) {
          setState(() {
            _isOtherUserOnline = data['isOnline'] ?? false;
          });
          print(
            '📡 ${widget.name} is now: ${_isOtherUserOnline ? "online" : "offline"}',
          );
        }
      }
    });

    _connectionSubscription = _socketService.onConnectionChange.listen((
      isConnected,
    ) {
      if (isConnected && mounted) {
        if (_rekeyRequired) {
          _attemptRekeyRecovery();
        }
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _messagingService.requestUserStatus(widget.userId);
          }
        });
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85, // ضغط مباشر
      );

      if (picked == null) return;

      setState(() {
        _pendingImageFile = File(picked.path);
      });

      print('✅ Image selected: ${picked.path}');
    } catch (e) {
      print('❌ Pick image error: $e');
      _showMessage('تعذر اختيار الصورة', false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final mediaResult = await _mediaService.pickFile();

      if (!mediaResult.success || mediaResult.file == null) {
        if (mediaResult.errorMessage != null) {
          _showMessage(mediaResult.errorMessage!, false);
        }
        return;
      }

      setState(() {
        _pendingFile = PlatformFile(
          name: mediaResult.fileName!,
          size: mediaResult.fileSize!,
          path: mediaResult.file!.path,
          bytes: null,
        );
      });

      print('✅ File selected: ${mediaResult.fileName}');
    } catch (e) {
      print('❌ Pick file error: $e');
      _showMessage('تعذر اختيار الملف', false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              ListTile(
                leading: Icon(Icons.image_outlined, color: AppColors.primary),
                title: Text('صورة من المعرض', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: Text('التقاط صورة', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.primary,
                ),
                title: Text('اختيار ملف', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (currentDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء اختيار مدة اختفاء الرسائل أولاً'),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();

    if (text.isEmpty && _pendingImageFile == null && _pendingFile == null)
      return;
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      File? attachmentFile;
      String? fileName;

      if (_pendingFile != null && _pendingFile!.path != null) {
        attachmentFile = File(_pendingFile!.path!);
        fileName = _pendingFile!.name;
      }

      final result = await _messagingService.sendMessage(
        recipientId: widget.userId,
        recipientName: widget.name,
        messageText: text.isEmpty
            ? (_pendingImageFile != null ? 'صورة' : 'ملف')
            : text,
        imageFile: _pendingImageFile,
        attachmentFile: attachmentFile,
        fileName: fileName,
      );

      if (result['success']) {
        _messageController.clear();
        setState(() {
          _pendingImageFile = null;
          _pendingFile = null;
          _rekeyRequired = false;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rekey_required_${widget.userId}');
        await _loadMessagesFromDatabase();
      } else {
        if (result['code'] == 'REKEY_REQUIRED') {
          _setRekeyRequired(true, showMessage: false);
        }
        _showMessage(result['message'] ?? 'فشل الإرسال', false);
      }
    } catch (e) {
      _showMessage('فشل إرسال الرسالة', false);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showDeleteOptions(Map<String, dynamic> message) {
    final failedVerificationAtRecipient =
        message['failedVerificationAtRecipient'] == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('خيارات الحذف', style: AppTextStyles.h3),
            ),

            SizedBox(height: 20),

            if (failedVerificationAtRecipient) ...[
              _buildDeleteOption(
                icon: Icons.delete_outline,
                iconColor: Colors.grey,
                title: 'حذف لدي فقط',
                subtitle: 'الرسالة محذوفة لدى المستقبل',
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageLocally(message['id']);
                },
              ),
            ] else ...[
              _buildDeleteOption(
                icon: Icons.person_remove_outlined,
                iconColor: Colors.orange,
                title: 'حذف من عند المستقبل',
                subtitle: 'ستبقى الرسالة عندك فقط',
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteForRecipient(message['id']);
                },
              ),

              Divider(height: 1),

              _buildDeleteOption(
                icon: Icons.delete_forever_outlined,
                iconColor: Colors.red,
                title: 'حذف للجميع',
                subtitle: 'سيتم حذف الرسالة نهائياً',
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteForEveryone(message['id']);
                },
              ),
            ],

            SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'إلغاء',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForRecipient(String messageId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('حذف من عند المستقبل؟', style: AppTextStyles.h3),
          content: Text(
            'سيتم حذف هذه الرسالة من عند المستقبل فقط. ستبقى الرسالة عندك.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteForRecipient(messageId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessageLocally(String messageId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);

      setState(() {
        _messages.removeWhere((msg) => msg['id'] == messageId);
      });

      _showMessage('تم الحذف', true);
    } catch (e) {
      _showMessage('فشل الحذف', false);
    }
  }

  void _confirmDeleteForEveryone(String messageId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('حذف للجميع؟', style: AppTextStyles.h3),
          content: Text(
            'سيتم حذف هذه الرسالة من محادثتك ومحادثة المستلم نهائياً. لا يمكن التراجع عن هذا الإجراء.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteForEveryone(messageId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteForRecipient(String messageId) async {
    try {
      final result = await _messagingService.deleteMessage(
        messageId: messageId,
        deleteForEveryone: false,
      );

      if (result['success']) {
        _showMessage('تم الحذف من عند المستقبل', true);
        await _loadMessagesFromDatabase();
      } else {
        _showMessage(result['message'], false);
      }
    } catch (e) {
      _showMessage('فشل الحذف', false);
    }
  }

  Future<void> _deleteForEveryone(String messageId) async {
    try {
      final result = await _messagingService.deleteMessage(
        messageId: messageId,
        deleteForEveryone: true,
      );

      if (result['success']) {
        _showMessage('تم الحذف للجميع', true);
        await _loadMessagesFromDatabase();
      } else {
        _showMessage(result['message'], false);
      }
    } catch (e) {
      _showMessage('فشل الحذف', false);
    }
  }

  void _showMessage(String message, bool isSuccess) {
  if (!mounted) return;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -20 * (1 - value)),
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);

  Future.delayed(const Duration(seconds: 2), () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}

  void _showDecryptionDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 25),
            Text(
              'جاري فك تشفير المحادثة...',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final hasAttachment = _pendingImageFile != null || _pendingFile != null;

    return GestureDetector(
    onTap: () {
      // إخفاء الكيبورد عند النقر في أي مكان
      FocusScope.of(context).unfocus();
    },
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
  backgroundColor: AppColors.primary,
  elevation: 2,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
    onPressed: () => Navigator.pop(context),
  ),
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // اسم المستخدم بخط أكبر
      Text(
        widget.name,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20, // كان 16-17، الآن 20
          fontFamily: 'IBMPlexSansArabic',
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 4),
      // حالة الاتصال بخط أكبر
      Row(
        children: [
          Container(
            width: 10, // كان 8، الآن 10
            height: 10,
            decoration: BoxDecoration(
              color: _isOtherUserOnline
                  ? Colors.greenAccent
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
              boxShadow: _isOtherUserOnline
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isOtherUserOnline ? 'متصل الآن' : 'غير متصل',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 14, // كان 12، الآن 14
              fontWeight: FontWeight.w500,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        ],
      ),
    ],
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
      tooltip: 'المزيد',
      onPressed: _showOptionsDialog,
    ),
  ],
  toolbarHeight: 70, // زيادة ارتفاع AppBar لاستيعاب النص الأكبر
),

        body: _isLoadingScreenshotPolicy
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : UnifiedScreenshotProtector(
                //  الحماية مفعلة إذا الطرف الآخر لم يسمح لي
                enabled: !_peerAllowsMyScreenshots,
                peerName: widget.name,
                onScreenshotAttempt: () {
                  // إرسال إشعار للطرف الآخر أني التقطت
                  _socketService.socket?.emit('screenshot:taken', {
                    'targetUserId': widget.userId,
                  });
                },
                child: _buildBody(hasAttachment),
              ),
      ),
    )
    );
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        //  استخدام StatefulBuilder لتحديث الـ Dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            //  الاستماع لتغيير السياسة داخل الـ Dialog
            // نحفظ listener لنزيله عند إغلاق الـ Dialog
            void onPolicyChanged(dynamic data) {
              if (data['peerUserId'] == widget.userId) {
                final newPeerPolicy = data['allowScreenshots'] == true;
                setDialogState(() {
                  _peerAllowsMyScreenshots = newPeerPolicy;
                });
                // تحديث الـ State الرئيسي أيضاً
                if (mounted) {
                  setState(() {
                    _peerAllowsMyScreenshots = newPeerPolicy;
                  });
                }
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                insetPadding: const EdgeInsets.only(
                  top: 72,
                  right: 12,
                  left: 12,
                ),
                backgroundColor: Colors.transparent,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إعدادات الخصوصية',
                            style: AppTextStyles.h4.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          //  خيار السماح للطرف الآخر
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'السماح بلقطات الشاشة',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'السماح لـ ${widget.name} بالتقاط شاشتك',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _myPolicyAllowsScreenshots,
                                  activeColor: Colors.white,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (v) async {
                                    // تحديث الـ Dialog
                                    setDialogState(() {
                                      _myPolicyAllowsScreenshots = v;
                                    });
                                    // تحديث الـ State الرئيسي
                                    setState(() {
                                      _myPolicyAllowsScreenshots = v;
                                    });

                                    await _saveScreenshotPolicyToServer(v);

                                    Navigator.of(dialogContext).pop();

                                    _showMessage(
                                      v
                                          ? 'سمحت لـ ${widget.name} بلقطات الشاشة'
                                          : 'منعت ${widget.name} من لقطات الشاشة',
                                      true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          //  عرض حالة الطرف الآخر
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _peerAllowsMyScreenshots
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _peerAllowsMyScreenshots
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _peerAllowsMyScreenshots
                                      ? Icons.check_circle_outline
                                      : Icons.block_outlined,
                                  color: _peerAllowsMyScreenshots
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _peerAllowsMyScreenshots
                                        ? '${widget.name} يسمح لك بالتقاط الشاشة'
                                        : '${widget.name} لا يسمح لك بالتقاط الشاشة',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: _peerAllowsMyScreenshots
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(bool hasAttachment) {
    //  حالة فك تشفير الرسائل فقط

    return Column(
      children: [
        if (_currentProgress != null && _currentProgress!.isProcessing)
          _buildProgressIndicator(),
        Expanded(
          child: _isLoading && _messages.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: AppColors.textHint.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'محادثة مشفرة من طرف لطرف',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ محادثة آمنة مع ${widget.name}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
        ),

        if (hasAttachment) _buildAttachmentPreview(),

        _buildInputBar(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _currentProgress!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: progress.isError
            ? Colors.red.shade50
            : AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: progress.isError
                ? Colors.red.shade200
                : AppColors.primary.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (progress.isError)
                Icon(Icons.error_outline, color: Colors.red, size: 20)
              else
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress.progress,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: progress.isError ? Colors.red : AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(progress.progress * 100).toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: progress.isError ? Colors.red : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 4,
              backgroundColor: progress.isError
                  ? Colors.red.shade100
                  : AppColors.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.isError ? Colors.red : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_pendingImageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _pendingImageFile!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else if (_pendingFile != null)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.insert_drive_file, color: AppColors.primary),
            ),

          SizedBox(width: 12),
          Expanded(
            child: Text(
              _pendingImageFile != null
                  ? p.basename(_pendingImageFile!.path)
                  : _pendingFile!.name,
              style: AppTextStyles.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _pendingImageFile = null;
                _pendingFile = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
  final canSend = currentDuration != null &&
      !_rekeyRequired &&
      (_messageController.text.trim().isNotEmpty ||
          _pendingImageFile != null ||
          _pendingFile != null);

  final isEnabled = currentDuration != null && !_rekeyRequired;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط المدة في الأعلى
          if (currentDuration == null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade50,
                    Colors.orange.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'اختر مدة اختفاء الرسائل من أيقونة الساعة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // الصف الرئيسي للإدخال
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // أيقونة المدة
              GestureDetector(
                onTap: _selectDuration,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: currentDuration != null
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: currentDuration != null
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.orange.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (currentDuration == null)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Icon(
                                Icons.timer_outlined,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            );
                          },
                        )
                      else
                        Icon(
                          Icons.timer,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      if (currentDuration != null)
                        Text(
                          _formatDuration(currentDuration!),
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // أيقونة المرفقات
              GestureDetector(
                onTap: isEnabled ? _showAttachmentOptions : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnabled
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.attach_file_rounded,
                    color: isEnabled ? AppColors.primary : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // حقل الإدخال المودرن
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: isEnabled ? Colors.grey.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isEnabled
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.grey.shade300,
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
                      // حقل النص
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: isEnabled && !_isSending,
                          maxLines: null,
                          textDirection: TextDirection.rtl,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.4,
                            color: AppColors.textPrimary,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                          decoration: InputDecoration(
                            hintText: isEnabled
                                ? 'اكتب رسالتك هنا...'
                                : (_rekeyRequired
                                      ? 'جاري إعادة تهيئة التشفير...'
                                      : 'اختر المدة أولاً'),
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
                          onSubmitted: canSend && !_isSending
                              ? (_) => _sendMessage()
                              : null,
                          onChanged: (_) {
                            // تحديث خفيف فقط لزر الإرسال
                            setState(() {});
                          },
                        ),
                      ),

                      // زر إخفاء الكيبورد (يظهر فقط عند الكتابة)
                      if (_messageController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                          },
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

              // زر الإرسال المودرن
              GestureDetector(
                onTap: canSend && !_isSending ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: canSend && !_isSending
                        ? LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !canSend || _isSending
                        ? Colors.grey.shade300
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: canSend && !_isSending
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isSending
                        ? SizedBox(
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
        ],
      ),
    ),
  );
}
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['isMine'] == 1;
    final isLocked = false;
    final isDeleted = message['status'] == 'deleted';
    final isDeletedForRecipient = message['deletedForRecipient'] == 1;
    final failedVerificationAtRecipient =
        message['failedVerificationAtRecipient'] == 1;
    final text = message['plaintext'] ?? '';
    final status = message['status'] ?? 'sent';

    final attachmentData = message['attachmentData'];
    final attachmentType = message['attachmentType'];
    final attachmentName = message['attachmentName'];
    final hasAttachment = attachmentData != null && attachmentType != null;

    final timestamp = message['createdAt'];
    final time = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    return GestureDetector(
      onLongPress: () {
        if (isMine && !isLocked && !isDeleted) {
          _showDeleteOptions(message);
        }
      },

      onTap: () {
        if (hasAttachment && !isLocked) {
          _openAttachment(attachmentData, attachmentType, attachmentName);
        }
      },

      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: isMine ? Radius.circular(4) : Radius.circular(18),
              bottomRight: isMine ? Radius.circular(18) : Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAttachment && !isLocked) ...[
                if (attachmentType == 'image')
                  ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(attachmentData),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 800, // تحسين الأداء
                        gaplessPlayback: true, // منع الوميض
                        errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'فشل عرض الصورة',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (attachmentType == 'file')
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: isMine ? Colors.white : AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            attachmentName ?? 'ملف',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isMine
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
              ],
              if (text.isNotEmpty)
                Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                    fontSize: 18,
                     height: 1.5,
                     fontFamily: 'IBMPlexSansArabic'
                  ),
                ),

              if (failedVerificationAtRecipient && isMine) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.orange.shade300,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'تم حذف هذه الرسالة لدى المستقبل لفشل التحقق',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.orange.shade200,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (isDeletedForRecipient && isMine) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block,
                      size: 11,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'تم الحذف لدى المستقبل',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'IBMPlexSansArabic',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(time),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isMine
                          ? Colors.white.withOpacity(0.7)
                          : AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _getStatusIcon(status),
                      size: 14,
                      color:
                          (status == 'verified' ||
                              status == 'opened' ||
                              status == 'read')
                          ? Colors.lightBlueAccent
                          : Colors.white.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'verified':
      case 'opened':
      case 'read':
        return Icons.done_all;
      default:
        return Icons.access_time;
    }
  }

  void _openAttachment(String data, String type, String? name) async {
    try {
      if (type == 'image') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _Base64ImageViewer(base64Data: data),
          ),
        );
      } else if (type == 'file') {
        _showMessage('جاري تحميل الملف...', true);

        Uint8List bytes;

        bytes = base64Decode(data);
        print('✅ File decoded: ${bytes.length} bytes');

        final tempDir = await getTemporaryDirectory();
        final fileName =
            name ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
        final tempFile = File('${tempDir.path}/$fileName');

        await tempFile.writeAsBytes(bytes);
        print('✅ File saved to: ${tempFile.path}');

        final result = await OpenFilex.open(tempFile.path);

        if (result.type != ResultType.done) {
          _showMessage('تعذر فتح الملف: ${result.message}', false);
        } else {
          _showMessage('تم فتح الملف', true);
        }
      }
    } catch (e, stackTrace) {
      print('❌ Open attachment error: $e');
      print('Stack trace: $stackTrace');
      _showMessage('فشل فتح المرفق: $e', false);
    }
  }
}

class _Base64ImageViewer extends StatelessWidget {
  final String base64Data;

  const _Base64ImageViewer({required this.base64Data});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('صورة', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.memory(
              base64Decode(base64Data),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'فشل عرض الصورة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}