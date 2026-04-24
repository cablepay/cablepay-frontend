import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/lco_service.dart';

class LcoBankDetailsPage extends StatefulWidget {
  final Map<String, dynamic> lco;

  const LcoBankDetailsPage({super.key, required this.lco});

  @override
  State<LcoBankDetailsPage> createState() => _LcoBankDetailsPageState();
}

class _LcoBankDetailsPageState extends State<LcoBankDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isEdit = false;
  String? _maskedAccount;

  // Timer logic for Resend OTP
  int _resendSeconds = 0;
  Timer? _timer;

  // CRITICAL: Persistent reference to the dialog's state setter
  StateSetter? _otpDialogState;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _confirmCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  // --- LOGIC SECTION ---

  /// Starts the cooldown and refreshes both the page and the dialog (if open)
  void _startCooldown(int ms) {
    _timer?.cancel();

    setState(() {
      _resendSeconds = (ms / 1000).ceil();
    });

    // Refresh the dialog immediately if it's already open
    _otpDialogState?.call(() {});

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          timer.cancel();
        }
      });

      // CRITICAL: This ensures the dialog updates its "Resend in Xs" text every second
      _otpDialogState?.call(() {});
    });
  }

  Future<void> _loadBank() async {
    setState(() => _loading = true);
    try {
      final res = await LcoService.getBank(widget.lco['_id']);
      if (res['statusCode'] == 200 && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _holderCtrl.text = data['accountHolderName'] ?? '';
          _ifscCtrl.text = data['ifscCode'] ?? '';
          _bankCtrl.text = data['bankName'] ?? '';
          _branchCtrl.text = data['branch'] ?? '';
          _maskedAccount = data['accountNumber'];
        });
      }
    } catch (e) {
      _showSnackBar('Unable to load bank details', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // 1. Initial OTP Request
    final otpRes = await LcoService.requestBankOtp();

    setState(() => _saving = false);

    if (otpRes['statusCode'] != 200) {
      _showSnackBar(otpRes['data']?['error'] ?? 'Failed to send OTP', isError: true);
      return;
    }

    _showSnackBar('OTP sent to registered mobile');

    // START TIMER BEFORE OPENING DIALOG
    _startCooldown(120000);

    // 2. Open OTP Dialog Flow
    final bool success = await _handleOtpFlow();

    if (success) {
      _showSnackBar('Bank details updated successfully');
      setState(() {
        _isEdit = false;
        _accountCtrl.clear();
        _confirmCtrl.clear();
      });
      _loadBank();
    }
  }

  Future<bool> _handleOtpFlow() async {
    String? currentError;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final otpController = TextEditingController();
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Store the dialog's state setter so the timer can reach it
            _otpDialogState = setDialogState;

            return PopScope(
              onPopInvoked: (_) => _otpDialogState = null, // Clear on close
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Security Verification', textAlign: TextAlign.center),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter the 6-digit OTP to authorize changes.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        errorText: currentError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendSeconds > 0 ? null : () async {
                        final res = await LcoService.requestBankOtp();
                        if (res['statusCode'] == 200) {
                          _showSnackBar('OTP Resent');
                          _startCooldown(120000); // Timer will auto-refresh this dialog
                        } else if (res['statusCode'] == 429) {
                          final remain = res['data']?['remainingMs'] ?? 30000;
                          _startCooldown(remain);
                        }
                      },
                      child: Text(_resendSeconds > 0 ? 'Resend in ${_resendSeconds}s' : 'Resend OTP'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isVerifying ? null : () {
                      _otpDialogState = null;
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (otpController.text.length < 6) {
                        setDialogState(() => currentError = "Enter 6 digits");
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        currentError = null;
                      });

                      final res = await LcoService.saveBank(
                        widget.lco['_id'],
                        {
                          'accountHolderName': _holderCtrl.text.trim(),
                          'accountNumber': _accountCtrl.text.trim(),
                          'ifscCode': _ifscCtrl.text.toUpperCase().trim(),
                          'bankName': _bankCtrl.text.trim(),
                          'branch': _branchCtrl.text.trim(),
                          'otp': otpController.text.trim()
                        },
                      );

                      if (res['statusCode'] == 200) {
                        _otpDialogState = null;
                        Navigator.pop(context, true);
                      } else {
                        setDialogState(() {
                          isVerifying = false;
                          final code = res['data']?['code'];
                          if (code == 'OTP_INVALID') {
                            currentError = "Invalid OTP. Try again.";
                          } else if (code == 'OTP_EXPIRED') {
                            currentError = "OTP Expired. Resend needed.";
                          } else {
                            currentError = res['data']?['error'] ?? "Verification failed";
                          }
                        });
                      }
                    },
                    child: isVerifying
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify & Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _otpDialogState = null; // Safety cleanup
    return result ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('Bank Details'),
        centerTitle: true,
        actions: [
          if (!_isEdit)
            IconButton(
              icon: const Icon(Icons.edit_square),
              onPressed: () => setState(() => _isEdit = true),
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildVisualCard(),
              const SizedBox(height: 25),
              _buildMainForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualCard() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4683), Color(0xFF2D5796)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.account_balance, color: Colors.white70, size: 30),
              Text(_bankCtrl.text.isEmpty ? "BANK" : _bankCtrl.text.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          Text(
            _maskedAccount ?? "**** **** **** ****",
            style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ACCOUNT HOLDER', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(
                    _holderCtrl.text.isEmpty ? "NOT SET" : _holderCtrl.text.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              const Icon(Icons.contactless, color: Colors.white24, size: 35),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel("Account Holder Name"),
          _buildTextField(_holderCtrl, Icons.person_outline, enabled: _isEdit),

          if (!_isEdit) ...[
            _fieldLabel("Bank Account Number"),
            _buildTextField(TextEditingController(text: _maskedAccount), Icons.lock_outline, enabled: false),
          ],

          if (_isEdit) ...[
            _fieldLabel("New Account Number"),
            _buildTextField(_accountCtrl, Icons.numbers, isNumeric: true,
                validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
            _fieldLabel("Confirm Account Number"),
            _buildTextField(_confirmCtrl, Icons.verified_user_outlined, isNumeric: true,
                validator: (v) => v != _accountCtrl.text ? "Account numbers do not match" : null),
          ],

          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _fieldLabel("IFSC Code"),
                  _buildTextField(_ifscCtrl, Icons.qr_code_scanner,
                      enabled: _isEdit,
                      isCaps: true,
                      validator: (v) => (v == null || v.length < 4) ? "Invalid" : null),
                ]),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _fieldLabel("Branch"),
                  _buildTextField(_branchCtrl, Icons.location_on_outlined, enabled: _isEdit),
                ]),
              ),
            ],
          ),

          _fieldLabel("Bank Name"),
          _buildTextField(_bankCtrl, Icons.account_balance_outlined, enabled: _isEdit),

          if (_isEdit) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: AppTheme.primary,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('VERIFY & SAVE DETAILS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                  onPressed: () => setState(() => _isEdit = false),
                  child: const Text('Cancel Edit', style: TextStyle(color: Colors.redAccent))
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, IconData icon, {
    bool enabled = true,
    bool isNumeric = false,
    bool isCaps = false,
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      validator: validator,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      textCapitalization: isCaps ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: isCaps ? [UpperCaseTextFormatter()] : [],
      style: TextStyle(fontSize: 15, color: enabled ? Colors.black : Colors.black54),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: enabled ? AppTheme.primary : Colors.grey),
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}