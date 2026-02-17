// lib/lco/pages/lco_login.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/push_notification_service.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/simple_input.dart'; // still imported if used elsewhere
import '../../widgets/label.dart';       // still imported if used elsewhere
import '../../services/lco_service.dart';
import '../../core/local_storage.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../routes.dart';

class LcoLoginPage extends StatefulWidget {
  const LcoLoginPage({Key? key}) : super(key: key);

  @override
  _LcoLoginPageState createState() => _LcoLoginPageState();
}

class _LcoLoginPageState extends State<LcoLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _sending = false;
  bool _otpSent = false;
  bool _verifying = false;

  // NEW: while we are checking if an existing LCO session is present
  bool _checkingExisting = true;

  String _normalizePhone(String v) {
    return v.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Timer? _otpTimer;
  int _remainingSeconds = 300;
  bool _canResend = false;


  @override
  void initState() {
    super.initState();
    _redirectIfAlreadyLoggedIn();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // --------------------------
  // CHECK EXISTING LCO SESSION
  // --------------------------
  Future<void> _redirectIfAlreadyLoggedIn() async {
    bool redirected = false;
    try {
      final session = await LocalStorage.getSession();
      if (session == null) {
        return;
      }

      final userType = (session['userType'] ?? '').toString();
      final sessionKey = session['sessionKey'];

      // Only auto-redirect if this is an LCO session with a valid key
      if (userType != 'lco' || sessionKey == null) {
        return;
      }

      // Restore API header
      ApiConfig.setSessionKey(sessionKey.toString());

      // Load stored LCO profile
      final storedLco = await LocalStorage.getLco();
      if (!mounted) return;

      if (storedLco != null) {
        final lco = Map<String, dynamic>.from(storedLco);
        redirected = true;
        // Replace this login route with LCO home
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.lcoHome,
          arguments: lco,
        );
      }
    } catch (_) {
      // swallow – user can still log in manually
    } finally {
      if (!mounted) return;
      if (!redirected) {
        setState(() {
          _checkingExisting = false;
        });
      }
      // If redirected == true, this route will be replaced soon anyway.
    }
  }

  // --------------------------
  // EXISTING LOGIC (UNCHANGED)
  // --------------------------
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    final phone = _normalizePhone(_phoneCtrl.text);

    // final res = await ApiConfig.post(
    //   '/api/lcos/request-otp',
    //   {'phone': phone},
    // );

    final res = await LcoService.requestOtp(
      phone: phone,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
    );



    if (!mounted) return;
    setState(() => _sending = false);

    if (res['statusCode'] != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']?['error'] ?? 'Failed to send OTP'),
        ),
      );
      return;
    }

    setState(() => _otpSent = true);
    _startOtpTimer();


    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent')),
    );
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _remainingSeconds = 300;
    _canResend = false;

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    _otpTimer?.cancel();
    setState(() {
      _remainingSeconds = 300;
      _canResend = false;
    });

    setState(() => _sending = true);

    final phone = _normalizePhone(_phoneCtrl.text);

    final res = await LcoService.requestOtp(
      phone: phone,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (res['statusCode'] != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['data']?['error'] ?? 'Failed to resend OTP')),
      );
      return;
    }

    _startOtpTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent')),
    );
  }



  Future<void> _verifyAndLogin() async {

    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired. Please resend OTP')),
      );
      return;
    }

    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter OTP')),
      );
      return;
    }

    setState(() => _verifying = true);

    try {
      final phone = _normalizePhone(_phoneCtrl.text);

      // final res = await ApiConfig.post(
      //   '/api/lcos/verify-otp',
      //   {
      //     'phone': phone,
      //     'otp': otp,
      //     'name': _nameCtrl.text.trim(),
      //     'email': _emailCtrl.text.trim(),
      //   },
      // );

      final res = await LcoService.verifyOtp(
        phone: phone,
        otp: otp,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
      );


      if (!mounted) return;

      setState(() => _verifying = false);

      if (res['statusCode'] != 200 && res['statusCode'] != 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['data']?['error'] ?? 'OTP verification failed'),
          ),
        );
        return;
      }


      final payload = Map<String, dynamic>.from(res['data']);
      final session = Map<String, dynamic>.from(payload['session']);
      final lco = Map<String, dynamic>.from(payload['lco']);

      await LocalStorage.saveSession(session);
      await LocalStorage.saveLco(lco);
      ApiConfig.setSessionKey(session['sessionKey']);

      unawaited(() async {
        final token = await PushNotificationService.initAndGetToken();
        if (token != null) {
          await ApiConfig.post('/api/devices/register', {
            'fcmToken': token,
            'platform': 'android',
          });
        }
      }());


      final profileComplete = payload['profileComplete'] == true;

      Navigator.pushNamedAndRemoveUntil(
        context,
        profileComplete ? AppRoutes.lcoHome : AppRoutes.lcoDetail,
            (_) => false,
        arguments: lco,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error')),
      );
    }
  }



  // --------------------------
  // MODERN UI HELPERS
  // --------------------------

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primary),
      filled: true,
      fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon)
          .copyWith(counterText: ''),
    );
  }

  // --------------------------
  // Top branding (gradient circle, LCO tag)
  // --------------------------
  Widget _buildTopBrand() {
    final double screenW = MediaQuery.of(context).size.width;
    final double badgeDiameter =
    screenW < 360 ? 86 : (screenW < 520 ? 104 : 120);

    return Column(
      children: [
        Container(
          width: badgeDiameter + 20,
          height: badgeDiameter + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primary,
                AppTheme.primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: badgeDiameter,
              height: badgeDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Cable Pay',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cable_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'LCO Login / Dashboard',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------
  // Entry form (Name + Phone + Send OTP)
  // --------------------------
  Widget _buildEntryForm(double maxWidth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBrand(),
          const SizedBox(height: 26),

          _buildTextField(
            label: 'Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            controller: _nameCtrl,
            validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          // NEW: Email field
          _buildTextField(
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final val = v.trim();
              if (!val.contains('@') || !val.contains('.')) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          _buildTextField(
            label: 'Phone Number',
            hint: 'Enter phone number',
            icon: Icons.phone_android_rounded,
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length < 10) return 'Invalid phone';
              return null;
            },
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: LoadingButton(
              isLoading: _sending,
              label: 'Send OTP',
              onPressed: _sendOtp,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.divider,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.divider,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Are you a customer?',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.customerLogin,
                ),
                icon: Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.primary,
                ),
                label: Text(
                  'Customer Login',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------
  // OTP form
  // --------------------------
  Widget _buildOtpForm(double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBrand(),
        const SizedBox(height: 18),
        Text(
          'Enter the 6-digit OTP sent to',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          _phoneCtrl.text.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 20),

        // TextFormField(
        //   controller: _otpCtrl,
        //   keyboardType: TextInputType.number,
        //   maxLength: 6,
        //   decoration: InputDecoration(
        //     labelText: 'OTP',
        //     hintText: '6-digit code',
        //     prefixIcon: const Icon(Icons.lock_outline_rounded),
        //     filled: true,
        //     fillColor: AppTheme.surface,
        //     counterText: '',
        //     contentPadding:
        //     const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        //     border: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(14),
        //       borderSide: BorderSide(color: AppTheme.divider),
        //     ),
        //     enabledBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(14),
        //       borderSide: BorderSide(color: AppTheme.divider),
        //     ),
        //     focusedBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(14),
        //       borderSide:
        //       BorderSide(color: AppTheme.primary, width: 2),
        //     ),
        //   ),
        // ),
        OtpSixBox(controller: _otpCtrl),
        const SizedBox(height: 16),

        Text(
          _remainingSeconds > 0
              ? 'OTP expires in ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'
              : 'OTP expired',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: _remainingSeconds > 0 ? AppTheme.muted : Colors.red,
          ),
        ),

        const SizedBox(height: 8),

        TextButton(
          onPressed: _canResend
              ? () {
            _otpCtrl.clear();
            _resendOtp();
          }
              : null,
          child: Text(
            _canResend
                ? 'Resend OTP'
                : 'Resend in $_remainingSeconds sec',
          ),
        ),


        SizedBox(
          width: double.infinity,
          height: 52,
          child: LoadingButton(
            isLoading: _verifying,
            label: 'Verify & Login',
            onPressed: _verifyAndLogin,
          ),
        ),

        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () {
              _otpTimer?.cancel();
              setState(() {
                _otpSent = false;
                _otpCtrl.clear();
                _remainingSeconds = 300;
                _canResend = false;
              });
            },

            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit phone number'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double maxWidth =
    (mq.size.width < 520) ? (mq.size.width - 28) : 520.0;

    // While checking existing session, just show a minimal loader with theme BG
    if (_checkingExisting) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('LCO Login / Signup'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _otpSent
                      ? _buildOtpForm(maxWidth)
                      : _buildEntryForm(maxWidth),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class OtpSixBox extends StatefulWidget {
  final TextEditingController controller;

  const OtpSixBox({Key? key, required this.controller}) : super(key: key);

  @override
  State<OtpSixBox> createState() => _OtpSixBoxState();
}

class _OtpSixBoxState extends State<OtpSixBox> {
  late List<TextEditingController> _boxes;
  late List<FocusNode> _focus;

  final List<String> _otpBuffer = List.filled(6, '');

  bool _internalUpdate = false; // 🔴 prevents feedback loop

  @override
  void initState() {
    super.initState();
    _boxes = List.generate(6, (_) => TextEditingController());
    _focus = List.generate(6, (_) => FocusNode());

    widget.controller.addListener(_syncFromParent);
  }

  void _syncFromParent() {
    if (_internalUpdate) return; // 🔥 break feedback loop

    final text = widget.controller.text;

    for (int i = 0; i < 6; i++) {
      final char = (i < text.length) ? text[i] : '';
      _otpBuffer[i] = char;
      _boxes[i].text = char;
    }
  }

  void _syncToParent() {
    _internalUpdate = true;
    widget.controller.text = _otpBuffer.join();
    _internalUpdate = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final c in _boxes) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  void _onChanged(int i, String v) {
    if (v.isEmpty) {
      _otpBuffer[i] = '';
      _boxes[i].text = '';
      if (i > 0) _focus[i - 1].requestFocus();
    } else {
      final digit = v[v.length - 1];
      _otpBuffer[i] = digit;
      _boxes[i].text = digit;
      if (i < 5) _focus[i + 1].requestFocus();
    }

    _syncToParent();
  }

  Widget _buildBox(int i) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _boxes[i],
        focusNode: _focus[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: const InputDecoration(counterText: ''),
        onChanged: (v) => _onChanged(i, v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, _buildBox),
    );
  }
}

