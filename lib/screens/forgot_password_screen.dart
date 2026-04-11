import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // 3 خطوات: 0=رقم الهاتف, 1=رمز OTP, 2=كلمة المرور الجديدة
  int _step = 0;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Timer? _timer;
  int _secondsLeft = 0;

  static const _sendUrl = 'https://sendotp-cuoayufz5a-uc.a.run.app';
  static const _verifyUrl = 'https://verifyotp-cuoayufz5a-uc.a.run.app';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300); // 5 دقائق
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
      }
    });
  }

  String _fmtTimer() {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── خطوة 1: إرسال OTP ──────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // التحقق من وجود الرقم في قاعدة البيانات
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(phone)
          .get();
      if (!doc.exists) {
        setState(() {
          _error = 'رقم الهاتف غير مسجل في التطبيق';
          _isLoading = false;
        });
        return;
      }

      final res = await http.post(
        Uri.parse(_sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _startTimer();
        setState(() {
          _step = 1;
          _isLoading = false;
        });
      } else if (res.statusCode == 429) {
        setState(() {
          _error = 'انتظر قليلاً قبل طلب رمز جديد';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'فشل إرسال رمز التحقق';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  // ── إعادة إرسال OTP (من step 1 بدون تحقق Firestore) ──────
  Future<void> _resendOtp() async {
    final phone = _phoneController.text.trim();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse(_sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _startTimer();
        setState(() => _isLoading = false);
      } else if (res.statusCode == 429) {
        setState(() {
          _error = 'انتظر دقيقة واحدة قبل طلب رمز جديد';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error'] ?? 'فشل إرسال الرمز';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  // ── خطوة 2: التحقق من OTP ──────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'رمز التحقق يجب أن يكون 4 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_verifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phoneController.text.trim(), 'otp': otp}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['verified'] == true) {
        _timer?.cancel();
        setState(() {
          _step = 2;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['reason'] == 'expired'
              ? 'انتهت صلاحية الرمز، اطلب رمزاً جديداً'
              : 'رمز التحقق غير صحيح';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  // ── خطوة 3: تحديث كلمة المرور ─────────────────────────
  Future<void> _updatePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hashed = BCrypt.hashpw(newPass, BCrypt.gensalt());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_phoneController.text.trim())
          .update({'password': hashed});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء تحديث كلمة المرور';
        _isLoading = false;
      });
    }
  }

  // ── بناء الواجهة ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'استرداد كلمة المرور',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E1229),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // مؤشر الخطوات
            _buildStepIndicator(),
            const SizedBox(height: 32),

            // محتوى الخطوة الحالية
            if (_step == 0) _buildStepPhone(),
            if (_step == 1) _buildStepOtp(),
            if (_step == 2) _buildStepNewPassword(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['رقم الهاتف', 'رمز التحقق', 'كلمة المرور'];
    return Row(
      children: List.generate(3, (i) {
        final done = i < _step;
        final active = i == _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? Colors.green
                            : active
                            ? const Color(0xFF6E1229)
                            : Colors.grey[300],
                      ),
                      child: Center(
                        child: done
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? const Color(0xFF6E1229)
                            : Colors.grey[500],
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: done ? Colors.green : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── خطوة 1 ─────────────────────────────────────────────
  Widget _buildStepPhone() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_android, color: Color(0xFF6E1229), size: 40),
          const SizedBox(height: 12),
          const Text(
            'أدخل رقم هاتفك',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'سنرسل رمز التحقق عبر WhatsApp أو SMS',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              hintText: '07XXXXXXXXX',
              prefixIcon: const Icon(Icons.phone, color: Color(0xFF6E1229)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6E1229),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_error != null) _buildError(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1229),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _isLoading ? 'جاري الإرسال...' : 'إرسال رمز التحقق',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── خطوة 2 ─────────────────────────────────────────────
  Widget _buildStepOtp() {
    final progress = _secondsLeft / 300.0;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس مع رقم الهاتف
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6E1229).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: Color(0xFF6E1229),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رمز التحقق',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      _phoneController.text.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6E1229),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // حقل إدخال الرمز
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              color: Color(0xFF6E1229),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '----',
              hintStyle: TextStyle(
                letterSpacing: 10,
                color: Colors.grey[300],
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
              filled: true,
              fillColor: const Color(0xFF6E1229).withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF6E1229),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // شريط التقدم للعداد
          if (_secondsLeft > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _secondsLeft < 60 ? Colors.red : const Color(0xFF6E1229),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صلاحية الرمز',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  _fmtTimer(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _secondsLeft < 60
                        ? Colors.red
                        : const Color(0xFF6E1229),
                  ),
                ),
              ],
            ),
          ] else
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _resendOtp,
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Color(0xFF6E1229),
                ),
                label: const Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(color: Color(0xFF6E1229)),
                ),
              ),
            ),
          if (_error != null) _buildError(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1229),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.verified, size: 20),
              label: Text(
                _isLoading ? 'جاري التحقق...' : 'تحقق من الرمز',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── خطوة 3 ─────────────────────────────────────────────
  Widget _buildStepNewPassword() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_reset, color: Color(0xFF6E1229), size: 40),
          const SizedBox(height: 12),
          const Text(
            'كلمة المرور الجديدة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اختر كلمة مرور جديدة لحسابك',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              hintText: '6 أحرف على الأقل',
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF6E1229)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6E1229),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFF6E1229),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6E1229),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_error != null) _buildError(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                _isLoading ? 'جاري الحفظ...' : 'حفظ كلمة المرور الجديدة',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
