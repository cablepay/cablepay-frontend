// // lib/customer/pages/customer_login.dart
// import 'dart:async';
// import 'package:cable_pay/customer/widgets/bottom_navigation.dart';
// import 'package:cable_pay/routes.dart';
// import 'package:flutter/material.dart';
// import '../../widgets/simple_input.dart';
// import '../../widgets/label.dart';
// import '../../widgets/loading_button.dart';
// import '../../services/customer_service.dart';
// import 'customer_detail.dart';
// import 'customer_home.dart';
// import '../../core/local_storage.dart';
// import '../../core/api_config.dart';
// import '../../core/app_theme.dart';
//
// class CustomerLoginPage extends StatefulWidget {
//   const CustomerLoginPage({Key? key}) : super(key: key);
//
//   @override
//   _CustomerLoginPageState createState() => _CustomerLoginPageState();
// }
//
// class _CustomerLoginPageState extends State<CustomerLoginPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameCtrl = TextEditingController();
//   final _phoneCtrl = TextEditingController();
//   final _referralCtrl = TextEditingController();
//   final _otpCtrl = TextEditingController();
//
//   bool _sendingOtp = false;
//   bool _verifyingOtp = false;
//   bool _otpSent = false;
//
//   static const String _fixedOtp = '0000';
//
//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     _phoneCtrl.dispose();
//     _referralCtrl.dispose();
//     _otpCtrl.dispose();
//     super.dispose();
//   }
//
//   // ---------------------------
//   // LOGIC SECTION (unchanged)
//   // ---------------------------
//   Future<void> _sendOtp() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() => _sendingOtp = true);
//
//     // simulate send OTP; autofill fixed OTP for dev
//     await Future.delayed(const Duration(milliseconds: 700));
//     Timer(const Duration(milliseconds: 400), () {
//       if (mounted) setState(() => _otpCtrl.text = _fixedOtp);
//     });
//
//     if (mounted) {
//       setState(() {
//         _sendingOtp = false;
//         _otpSent = true;
//       });
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('OTP sent (dev stub): 0000')));
//     }
//   }
//
//   Future<void> _verifyOtpAndLogin() async {
//     final otp = _otpCtrl.text.trim();
//     if (otp.isEmpty) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Please enter OTP')));
//       return;
//     }
//     if (otp != _fixedOtp) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Invalid OTP')));
//       return;
//     }
//
//     setState(() => _verifyingOtp = true);
//
//     try {
//       final name = _nameCtrl.text.trim();
//       final phone = _phoneCtrl.text.trim();
//       final ref = _referralCtrl.text.trim();
//
//       final loginRes = await CustomerService.login(
//         name: name,
//         phone: phone,
//         referralCode: ref.isEmpty ? null : ref,
//       );
//
//       // response checks
//       if (!(loginRes['statusCode'] == 200 || loginRes['statusCode'] == 201)) {
//         final msg = (loginRes['data'] is Map && loginRes['data']['error'] != null)
//             ? loginRes['data']['error']
//             : 'Login failed';
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//           setState(() => _verifyingOtp = false);
//         }
//         return;
//       }
//
//       final payload = (loginRes['data'] is Map)
//           ? Map<String, dynamic>.from(loginRes['data'])
//           : <String, dynamic>{};
//
//       final session = payload['session'] is Map<String, dynamic>
//           ? Map<String, dynamic>.from(payload['session'])
//           : null;
//
//       Map<String, dynamic>? customerRaw;
//       if (payload['customer'] is Map<String, dynamic>) {
//         customerRaw = Map<String, dynamic>.from(payload['customer']);
//       } else if (payload.isNotEmpty) {
//         customerRaw = Map<String, dynamic>.from(payload);
//       } else {
//         customerRaw = null;
//       }
//
//       if (session != null) {
//         await LocalStorage.saveSession(session);
//         ApiConfig.setSessionKey(session['sessionKey']?.toString());
//       }
//
//       if (customerRaw == null) {
//         if (mounted) {
//           setState(() => _verifyingOtp = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Invalid customer returned from server')),
//           );
//         }
//         return;
//       }
//
//       final Map<String, dynamic> customer = Map<String, dynamic>.from(customerRaw);
//       await LocalStorage.saveCustomer(customer);
//
//       final customerId = customer['_id'] ?? customer['id'] ?? customer['uid'];
//       if (customerId == null) {
//         if (mounted) {
//           setState(() => _verifyingOtp = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Invalid customer id returned from server')),
//           );
//         }
//         return;
//       }
//
//       final boxesRes = await CustomerService.listBoxes(customerId.toString());
//       if (mounted) setState(() => _verifyingOtp = false);
//
//       if (boxesRes['statusCode'] == 200) {
//         final boxes = boxesRes['data'] as List<dynamic>;
//         if (boxes.isNotEmpty && mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (_) => AppBottomNavigation(customer: customer),
//             ),
//           );
//           return;
//         }
//       }
//
//       if (mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) => CustomerDetailPage(data: customer),
//           ),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _verifyingOtp = false);
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Login error: $e')));
//       }
//     }
//   }
//
//   // ---------------------------
//   // UI COMPONENTS
//   // ---------------------------
//
//   /// Header with logo, app name and tagline
//   Widget _buildHeader() {
//     return Column(
//       children: [
//         // App logo circle
//         Container(
//           height: 96,
//           width: 96,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: Colors.white,
//             boxShadow: [
//               BoxShadow(
//                 color: AppTheme.primary.withOpacity(0.18),
//                 blurRadius: 20,
//                 offset: const Offset(0, 10),
//               ),
//             ],
//           ),
//           padding: const EdgeInsets.all(18),
//           child: Image.asset(
//             'assets/app_logo.png',
//             fit: BoxFit.contain,
//           ),
//         ),
//         const SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.tv_rounded, color: AppTheme.primary, size: 22),
//             const SizedBox(width: 8),
//             Text(
//               'Cable Pay',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: AppTheme.text,
//                 letterSpacing: 0.3,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Fast, simple cable bill payments',
//           textAlign: TextAlign.center,
//           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//             color: AppTheme.muted,
//             fontSize: 13,
//           ),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: AppTheme.primary.withOpacity(0.08),
//             borderRadius: BorderRadius.circular(999),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.lock_rounded, size: 16, color: AppTheme.primary),
//               SizedBox(width: 6),
//               Text(
//                 'Secure OTP login',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w500,
//                   color: AppTheme.primary,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   /// Helper to wrap inputs consistently
//   Widget _buildInputField({required String label, required Widget field, IconData? icon}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             if (icon != null) ...[
//               Icon(icon, size: 16, color: AppTheme.muted),
//               const SizedBox(width: 6),
//             ],
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 6),
//         field,
//         const SizedBox(height: 16),
//       ],
//     );
//   }
//
//   Widget _buildEntryForm() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           _buildHeader(),
//           const SizedBox(height: 36),
//
//           // Name Input
//           _buildInputField(
//             label: 'Full Name',
//             icon: Icons.person_outline_rounded,
//             field: SimpleInput(
//               controller: _nameCtrl,
//               hint: 'e.g. John Doe',
//               validator: (v) =>
//               v == null || v.trim().isEmpty ? 'Please enter your name' : null,
//             ),
//           ),
//
//           // Phone Input
//           _buildInputField(
//             label: 'Mobile Number',
//             icon: Icons.phone_iphone_rounded,
//             field: SimpleInput(
//               controller: _phoneCtrl,
//               hint: 'e.g. 9876543210',
//               keyboardType: TextInputType.phone,
//               validator: (v) {
//                 if (v == null || v.trim().isEmpty) {
//                   return 'Please enter mobile number';
//                 }
//                 final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
//                 if (digits.length < 10) {
//                   return 'Invalid number (min 10 digits)';
//                 }
//                 return null;
//               },
//             ),
//           ),
//
//           // Referral Input
//           _buildInputField(
//             label: 'Referral Code (Optional)',
//             icon: Icons.card_giftcard_rounded,
//             field: SimpleInput(
//               controller: _referralCtrl,
//               hint: 'Have a code? Enter here',
//             ),
//           ),
//
//           const SizedBox(height: 10),
//           Text(
//             'We’ll send a one-time code to your mobile number to verify it.',
//             style: Theme.of(context).textTheme.bodySmall?.copyWith(
//               color: AppTheme.muted,
//               height: 1.4,
//             ),
//           ),
//
//           const SizedBox(height: 24),
//           SizedBox(
//             height: 52,
//             child: LoadingButton(
//               isLoading: _sendingOtp,
//               label: 'Get OTP',
//               onPressed: _sendOtp,
//             ),
//           ),
//
//           const SizedBox(height: 28),
//           _buildFooterDivider(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOtpForm() {
//     final phoneDisplay = _phoneCtrl.text.trim();
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(18),
//           decoration: BoxDecoration(
//             color: AppTheme.primary.withOpacity(0.08),
//             shape: BoxShape.circle,
//           ),
//           child: const Icon(
//             Icons.sms_rounded,
//             size: 32,
//             color: AppTheme.primary,
//           ),
//         ),
//         const SizedBox(height: 20),
//         Text(
//           'Enter OTP',
//           style: Theme.of(context).textTheme.titleLarge?.copyWith(
//             fontWeight: FontWeight.w700,
//             color: AppTheme.text,
//           ),
//         ),
//         const SizedBox(height: 8),
//         RichText(
//           textAlign: TextAlign.center,
//           text: TextSpan(
//             style: const TextStyle(color: AppTheme.muted, fontSize: 13),
//             children: [
//               const TextSpan(text: 'We’ve sent a 4-digit code to\n'),
//               TextSpan(
//                 text: phoneDisplay.isEmpty ? 'your mobile number' : phoneDisplay,
//                 style: const TextStyle(
//                   color: AppTheme.text,
//                   fontWeight: FontWeight.w600,
//                   height: 1.6,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 28),
//
//         // OTP field
//         SizedBox(
//           width: 220,
//           child: TextFormField(
//             controller: _otpCtrl,
//             keyboardType: TextInputType.number,
//             maxLength: 4,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 10,
//             ),
//             decoration: InputDecoration(
//               counterText: '',
//               hintText: '• • • •',
//               hintStyle: TextStyle(
//                 color: Colors.grey.shade300,
//                 letterSpacing: 10,
//                 fontSize: 22,
//               ),
//               contentPadding: const EdgeInsets.symmetric(vertical: 16),
//               enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(14),
//                 borderSide: BorderSide(color: Colors.grey.shade300),
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(14),
//                 borderSide: const BorderSide(color: AppTheme.primary, width: 2),
//               ),
//             ),
//           ),
//         ),
//
//         const SizedBox(height: 28),
//         SizedBox(
//           width: double.infinity,
//           height: 52,
//           child: LoadingButton(
//             isLoading: _verifyingOtp,
//             label: 'Verify & Login',
//             onPressed: _verifyOtpAndLogin,
//           ),
//         ),
//
//         const SizedBox(height: 20),
//         TextButton.icon(
//           onPressed: _sendingOtp
//               ? null
//               : () {
//             setState(() {
//               _otpSent = false;
//               _otpCtrl.clear();
//             });
//           },
//           icon: const Icon(Icons.arrow_back_rounded, size: 18),
//           label: const Text(
//             'Change phone number',
//             style: TextStyle(fontSize: 13),
//           ),
//           style: TextButton.styleFrom(
//             foregroundColor: AppTheme.muted,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFooterDivider() {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(child: Divider(color: Colors.grey.shade300)),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: Text(
//                 'OR',
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: Colors.grey.shade500,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//             ),
//             Expanded(child: Divider(color: Colors.grey.shade300)),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.business_rounded, size: 18, color: Colors.grey.shade600),
//             const SizedBox(width: 6),
//             Text(
//               'Are you an LCO?',
//               style: TextStyle(
//                 color: Colors.grey.shade700,
//                 fontSize: 13,
//               ),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pushNamed(context, AppRoutes.lcoLogin),
//               style: TextButton.styleFrom(
//                 padding: const EdgeInsets.symmetric(horizontal: 6),
//                 minimumSize: const Size(0, 0),
//                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//               ),
//               child: const Text(
//                 'LCO Login',
//                 style: TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 13,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final double maxWidth = screenWidth < 500 ? screenWidth : 480.0;
//
//     return Scaffold(
//       backgroundColor: AppTheme.scaffoldBackground,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//             child: ConstrainedBox(
//               constraints: BoxConstraints(maxWidth: maxWidth),
//               child: AnimatedSwitcher(
//                 duration: const Duration(milliseconds: 260),
//                 switchInCurve: Curves.easeOut,
//                 switchOutCurve: Curves.easeIn,
//                 transitionBuilder: (child, animation) {
//                   return FadeTransition(
//                     opacity: animation,
//                     child: SlideTransition(
//                       position: Tween<Offset>(
//                         begin: const Offset(0.04, 0),
//                         end: Offset.zero,
//                       ).animate(animation),
//                       child: child,
//                     ),
//                   );
//                 },
//                 child: _otpSent ? _buildOtpForm() : _buildEntryForm(),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }





// lib/customer/pages/customer_login.dart
import 'dart:async';
import 'package:flutter/material.dart';

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

  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _otpSent = false;

  static const String _fixedOtp = '0000';

  @override
  void dispose() {
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

    final res = await CustomerService.requestOtp(phone);

    if (!mounted) return;

    setState(() => _sendingOtp = false);

    if (res['statusCode'] != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP')),
      );
      return;
    }

    // DEV ONLY: autofill OTP
    Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _otpCtrl.text = _fixedOtp);
    });

    setState(() => _otpSent = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent')),
    );
  }


  Future<void> _verifyOtpAndLogin() async {
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
      final referral = _referralCtrl.text.trim();

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
            validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
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
          'Enter the 4-digit OTP sent to',
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
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: 'OTP',
            hintText: '4-digit code',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            filled: true,
            fillColor: AppTheme.surface,
            counterText: '',
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              borderSide:
              BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

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
              setState(() {
                _otpSent = false;
                _otpCtrl.clear();
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

