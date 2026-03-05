// lib/customer/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/customer_service.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> customer;
  const ProfilePage({Key? key, required this.customer}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController; // read-only
  late TextEditingController _emailController;
  late TextEditingController _districtController;
  late TextEditingController _pincodeController;

  Future<void> _loadCustomer() async {
    final customerId = widget.customer['_id'] ?? widget.customer['id'];
    if (customerId == null) return;

    final res = await CustomerService.getCustomer(customerId.toString());

    if (res['statusCode'] == 200 && res['data'] != null) {
      final fresh = Map<String, dynamic>.from(res['data']);

      setState(() {
        widget.customer.addAll(fresh);
        _nameController.text = fresh['name'] ?? '';
        _districtController.text = fresh['district'] ?? '';
        _pincodeController.text = fresh['pincode'] ?? '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: (c['name'] ?? '').toString());
    _phoneController = TextEditingController(text: (c['phone'] ?? c['mobile'] ?? '').toString());
    _emailController = TextEditingController(text: (c['email'] ?? '').toString());
    _districtController = TextEditingController(text: (c['district'] ?? '').toString());
    _pincodeController = TextEditingController(text: (c['pincode'] ?? '').toString());

    _loadCustomer();   // 🔥 THIS WAS MISSING
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final customerId = widget.customer['_id'] ?? widget.customer['id'];
      if (customerId == null) throw Exception('Missing customer id');

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'district': _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
        'pincode': _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
      };

      final res = await CustomerService.updateCustomer(customerId.toString(), payload);
      if (res['statusCode'] == 200 && res['data'] != null) {
        final updated = Map<String, dynamic>.from(res['data']);
        widget.customer.addAll(updated);

        // reflect server-normalized values
        _nameController.text = updated['name'] ?? _nameController.text;
        _emailController.text = updated['email'] ?? _emailController.text;
        _districtController.text = updated['district'] ?? _districtController.text;
        _pincodeController.text = updated['pincode'] ?? _pincodeController.text;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        setState(() => _editing = false);
      } else {
        final err = (res['data'] != null && res['data']['error'] != null) ? res['data']['error'].toString() : 'Update failed';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.primary) : null,
      filled: true,
      fillColor: AppTheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primary, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader(String name, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 6.0),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, color: AppTheme.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(phone, style: const TextStyle(color: Colors.black87, fontSize: 14)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }


  String? validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(t)) {
      return 'Only letters and spaces allowed';
    }
    return null;
  }

  String? validatePincode(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (!RegExp(r'^\d{4,6}$').hasMatch(t)) return 'Invalid pincode';
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim().isEmpty ? '-' : _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? '-' : _phoneController.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
        elevation: 1,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: _saving ? null : () => setState(() => _editing = false),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          children: [
            _buildHeader(name, phone),

            // thin divider
            Divider(color: AppTheme.divider, thickness: 1, height: 6),
            const SizedBox(height: 12),

            // Account details label
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Account details', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
            ),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Full name
                  TextFormField(
                    controller: _nameController,
                    enabled: _editing && !_saving,
                    decoration: _inputDecoration(label: 'Full name', icon: Icons.person),
                    style: const TextStyle(color: AppTheme.text),
                    // validator: (v) {
                    //   if (v == null || v.trim().isEmpty) return 'Please enter name';
                    //   return null;
                    // },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                    ],
                    validator: validateName,
                  ),
                  const SizedBox(height: 12),

                  // Phone - read only
                  TextFormField(
                    controller: _phoneController,
                    enabled: false,
                    decoration: _inputDecoration(label: 'Phone', icon: Icons.phone),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // Email
                  // TextFormField(
                  //   controller: _emailController,
                  //   enabled: _editing && !_saving,
                  //   keyboardType: TextInputType.emailAddress,
                  //   decoration: _inputDecoration(label: 'Email (optional)', icon: Icons.email),
                  //   style: const TextStyle(color: AppTheme.text),
                  //   validator: (v) {
                  //     final text = v?.trim() ?? '';
                  //     if (text.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(text)) return 'Enter a valid email';
                  //     return null;
                  //   },
                  // ),
                  // const SizedBox(height: 12),

                  // District & Pincode row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _districtController,
                          enabled: _editing && !_saving,
                          decoration: _inputDecoration(label: 'District', icon: Icons.location_city),
                          style: const TextStyle(color: AppTheme.text),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                          ],
                          validator: validateName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _pincodeController,
                          enabled: _editing && !_saving,
                          decoration: _inputDecoration(label: 'Pincode', icon: Icons.pin_drop),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppTheme.text),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: validatePincode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bottom action: prominent when not editing
                  if (!_editing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _editing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        child: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),

                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text('Make changes and press Save', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
