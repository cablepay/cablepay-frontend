// lib/customer/pages/customer_login.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cable_pay/customer/widgets/bottom_navigation.dart';
import 'package:cable_pay/routes.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/loading_button.dart';
import '../../services/customer_service.dart';
import 'customer_detail.dart';
import '../../core/local_storage.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({Key? key}) : super(key: key);

  @override
  _CustomerLoginPageState createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _savedReferralCode = "";


  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;

  Timer? _otpTimer;
  int _remainingSeconds = 300; // 5 minutes
  bool _canResend = false;




  @override
  void dispose() {
    _otpTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _referralCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sendingOtp = true);

    final phone = _phoneCtrl.text.trim();
    // final res = await CustomerService.requestOtp(phone);
    final res = await CustomerService.requestOtp(
      phone,
      name: _nameCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (res['statusCode'] != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['data']?['error'] ?? 'Failed to send OTP')),
      );
      return;
    }

    // ✅ DEV ONLY convenience
    if (!kReleaseMode) {
      final devOtp = res['data']?['devOtp'];
      if (devOtp != null && devOtp.toString().trim().length == 6 && devOtp != '000000') {
        _otpCtrl.text = devOtp.toString().trim();
      }
    }


    // setState(() => _otpSent = true);

    setState(() {
      _otpSent = true;
      _savedReferralCode = _referralCtrl.text.trim();
    });

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
    // Reset timer state BEFORE sending
    _otpTimer?.cancel();
    setState(() {
      _remainingSeconds = 300;
      _canResend = false;
    });

    // Clear OTP boxes before resend
    _otpCtrl.clear();

    // Do NOT revalidate full form on resend
    setState(() => _sendingOtp = true);

    final phone = _phoneCtrl.text.trim();

    final res = await CustomerService.requestOtp(
      phone,
      name: _nameCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (res['statusCode'] != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['data']?['error'] ?? 'Failed to resend OTP')),
      );
      return;
    }

    // DEV OTP autofill
    // if (!kReleaseMode) {
    //   final devOtp = res['data']?['devOtp'];
    //   if (devOtp != null) {
    //     _otpCtrl.text = devOtp.toString();
    //   }
    // }

    _startOtpTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent')),
    );
  }




  Future<void> _verifyOtpAndLogin() async {

    if (_remainingSeconds <= 0 && !_canResend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired. Please resend OTP')),
      );
      return;
    }

    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter OTP')));
      return;
    }

    setState(() => _verifyingOtp = true);

    try {
      final phone = _phoneCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      // final referral = _referralCtrl.text.trim();

      final referral = _savedReferralCode;


      final res = await CustomerService.verifyOtp(
        phone: phone,
        otp: otp,
        name: name,
        referralCode: referral.isEmpty ? null : referral,
      );

      if (!mounted) return;

      if (res['statusCode'] != 200 && res['statusCode'] != 201) {
        setState(() => _verifyingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['data']?['error'] ?? 'Login failed')),
        );
        return;
      }

      final data = Map<String, dynamic>.from(res['data']);
      final session = Map<String, dynamic>.from(data['session']);
      final customer = Map<String, dynamic>.from(data['customer']);

      // ---------------- REFERRAL CLAIM FIX (NEW CODE) ----------------

      if (referral.isNotEmpty) {
        try {
          final claimRes = await CustomerService.claimReferral(
            customerId: customer['_id'].toString(),
            referralCode: referral,
          );

          // Optional logging
          if (claimRes['statusCode'] != 200) {
            debugPrint("Referral claim failed: ${claimRes['data']}");
          }

        } catch (e) {
          debugPrint("Referral claim exception: $e");
        }
      }
// ---------------------------------------------------------------


      await LocalStorage.saveSession(session);
      await LocalStorage.saveCustomer(customer);

      ApiConfig.setSessionKey(session['sessionKey']);

      // 🔕 Push token must NOT block login
      unawaited(() async {
        final token = await PushNotificationService.initAndGetToken();
        if (token != null) {
          await ApiConfig.post('/api/devices/register', {
            'fcmToken': token,
            'platform': 'android',
          });
        }
      }());

      final boxesRes =
      await CustomerService.listBoxes(customer['_id'].toString());

      setState(() => _verifyingOtp = false);

      if (boxesRes['statusCode'] == 200 &&
          (boxesRes['data'] as List).isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AppBottomNavigation(customer: customer),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailPage(data: customer),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    }
  }


  // ---------------------------
  // UI helpers (modern, colorful, no Card)
  // ---------------------------

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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon)
          .copyWith(counterText: ''),
    );
  }

  Widget _buildTopBrand() {
    final double screenW = MediaQuery.of(context).size.width;
    final double badgeDiameter =
    screenW < 360 ? 86 : (screenW < 520 ? 104 : 120);

    return Column(
      children: [
        Container(
          // width: badgeDiameter + 20,
          // height: badgeDiameter + 20,
          // decoration: BoxDecoration(
          //   shape: BoxShape.circle,
          //   gradient: LinearGradient(
          //     colors: [
          //       AppTheme.primary,
          //       AppTheme.primaryLight,
          //     ],
          //     begin: Alignment.topLeft,
          //     end: Alignment.bottomRight,
          //   ),
          //   boxShadow: [
          //     BoxShadow(
          //       color: AppTheme.primary.withOpacity(0.25),
          //       blurRadius: 16,
          //       offset: const Offset(0, 6),
          //     ),
          //   ],
          // ),
          child: Center(
            child: Container(
              width: badgeDiameter,
              height: badgeDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1B4683),
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
          'Cable Smart Pay',
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
              Icon(Icons.person_outline,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                'Customer Login',
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

  Widget _buildEntryForm(double maxWidth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBrand(),
          const SizedBox(height: 26),

          // Name
          _buildTextField(
            label: 'Full Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            controller: _nameCtrl,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';

              final trimmed = v.trim();

              if (!RegExp(r'^[A-Za-z ]+$').hasMatch(trimmed)) {
                return 'Only letters and spaces allowed';
              }

              if (trimmed.length < 2) {
                return 'Name too short';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),

          // Mobile
          _buildTextField(
            label: 'Mobile Number',
            hint: 'Enter mobile number',
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
          const SizedBox(height: 14),

          // Referral (optional)
          _buildTextField(
            label: 'Referral Code (optional)',
            hint: 'Enter referral code (if any)',
            icon: Icons.card_giftcard_rounded,
            controller: _referralCtrl,
            validator: (_) => null,
          ),
          const SizedBox(height: 22),

          // Prominent full-width Send OTP button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: LoadingButton(
              isLoading: _sendingOtp,
              label: 'Send OTP',
              onPressed: _sendOtp,
            ),
          ),

          const SizedBox(height: 18),

          // ────────── OR separator ──────────
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

          // inline prompt + LCO link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Are you LCO?',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.lcoLogin,
                ),
                icon: Icon(
                  Icons.cable_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                label: Text(
                  'LCO Login',
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

        // OTP field (keeps existing behaviour)
        // TextFormField(
        //   controller: _otpCtrl,
        //   keyboardType: TextInputType.number,
        //   maxLength: 6,
        //   autofillHints: const [],        // 🚫 disable OS autofill
        //   enableSuggestions: false,
        //   autocorrect: false,
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
            _resendOtp();   // ✅ correct resend flow
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
            isLoading: _verifyingOtp,
            label: 'Verify & Login',
            onPressed: _verifyOtpAndLogin,
          ),
        ),

        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _sendingOtp
                ? null
                : () {
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

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Customer Login'),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
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
                  const SizedBox(height: 16),
                ],
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




