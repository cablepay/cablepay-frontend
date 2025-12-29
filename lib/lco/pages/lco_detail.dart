// lib/lco/pages/lco_detail.dart
import 'package:flutter/material.dart';
import '../../services/lco_service.dart';
import '../../core/local_storage.dart';
import 'lco_home.dart';
import '../../widgets/loading_button.dart';
import 'lco_networks.dart';
import '../../core/app_theme.dart';

class LcoDetailPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  const LcoDetailPage({Key? key, this.data}) : super(key: key);

  @override
  _LcoDetailPageState createState() => _LcoDetailPageState();
}

class _LcoDetailPageState extends State<LcoDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final TextEditingController _businessCtrl = TextEditingController();
  final TextEditingController _phone1Ctrl = TextEditingController();
  final TextEditingController _phone2Ctrl = TextEditingController();
  final TextEditingController _districtCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? lco;

  @override
  void initState() {
    super.initState();
    lco = widget.data;
    _nameCtrl = TextEditingController(text: lco != null ? (lco!['name'] ?? '') : '');
    if (lco != null && lco!['phones'] != null && (lco!['phones'] as List).isNotEmpty) {
      final phones = (lco!['phones'] as List).map((p) => p?.toString() ?? '').toList();
      _phone1Ctrl.text = phones.isNotEmpty ? phones[0] : '';
      if (phones.length > 1) _phone2Ctrl.text = phones[1];
    }
    _businessCtrl.text = lco != null ? (lco!['businessName'] ?? '') : '';
    _districtCtrl.text = lco != null ? (lco!['district'] ?? '') : '';
    _pincodeCtrl.text = lco != null ? (lco!['pincode'] ?? '') : '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    _districtCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (lco == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing LCO context')));
      return;
    }

    setState(() => _submitting = true);
    final lcoId = lco!['_id'] ?? lco!['id'] ?? 'new';

    // phone1 is read-only but still required; ensure normalized storage
    final phones = [
      _phone1Ctrl.text.trim(),
      if (_phone2Ctrl.text.trim().isNotEmpty) _phone2Ctrl.text.trim()
    ];

    final body = {
      'name': _nameCtrl.text.trim(),
      'businessName': _businessCtrl.text.trim(),
      'phones': phones,
      'district': _districtCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
    };

    try {
      final res = await LcoService.upsertLco(lcoId.toString(), body: body);
      if (!mounted) return;
      setState(() => _submitting = false);

      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        final updated = Map<String, dynamic>.from(res['data'] as Map);
        await LocalStorage.saveLco(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LCO profile saved')));

        final networks = (updated['networks'] as List<dynamic>?) ?? [];
        if (networks.isEmpty) {
          // if no networks configured, guide user to networks screen
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LcoNetworksPage(lco: updated)));
          return;
        }

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LcoHomePage(lco: updated)));
        return;
      } else {
        final msg = res['data'] is Map && res['data']['error'] != null ? res['data']['error'] : 'Save failed';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _input(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete LCO Profile'),
        foregroundColor: AppTheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        // keep background transparent so gradient shows
        backgroundColor: AppTheme.primary,
        // ensure icons (back button) use onPrimary color for contrast
        iconTheme: const IconThemeData(color: AppTheme.onPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        // Use primary color & onPrimary icon for better contrast with gradient appbar
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.business, color: AppTheme.onPrimary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Finish your profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('Add business details so customers can find you and pricing can be set.'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Personal block (name + phone) -- read-only by default (already set)
                    _sectionHeader('Owner', Icons.person_outline),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _input('Name'),
                      readOnly: true,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone1Ctrl,
                      decoration: _input('Phone (primary)'),
                      keyboardType: TextInputType.phone,
                      readOnly: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone is required';
                        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 10) return 'Invalid phone';
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Business details
                    _sectionHeader('Business', Icons.storefront_outlined),
                    TextFormField(
                      controller: _businessCtrl,
                      decoration: _input('Business name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Secondary phone + address row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phone2Ctrl,
                            decoration: _input('Phone (secondary) - optional'),
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length < 10) return 'Invalid phone';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _pincodeCtrl,
                            decoration: _input('Pincode'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Pincode is required';
                              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length < 6) return 'Invalid pincode';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _districtCtrl,
                      decoration: _input('District'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'District is required' : null,
                    ),

                    const SizedBox(height: 20),

                    // Save button (gradient) - keeps same external behavior
                    Row(
                      children: [
                        Expanded(
                          child: _GradientLoadingButton(
                            isLoading: _submitting,
                            label: 'Save & Continue',
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Small hint
                    Center(
                      child: Text(
                        'You can add networks and pricing after saving your profile.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Local gradient loading button used in this page so design aligns with AppTheme.loginButtonGradient.
/// It intentionally mirrors the external behavior of LoadingButton: accepts isLoading, label, onPressed.
class _GradientLoadingButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;

  const _GradientLoadingButton({
    Key? key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  bool get _enabled => !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Opacity(
        opacity: _enabled ? 1.0 : 0.75,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.primary, // <-- Clear, correct background color
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Material(
            type: MaterialType.transparency, // <-- Keep Material transparent so outer color shows
            child: InkWell(
              onTap: _enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                  ),
                )
                    : Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

