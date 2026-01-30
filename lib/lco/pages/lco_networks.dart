import 'package:flutter/material.dart';
import '../../services/lco_service.dart';
import '../../core/local_storage.dart';
import '../widgets/lco_bottom_navigation.dart';
import 'lco_home.dart';
import '../../core/app_theme.dart';

class LcoNetworksPage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const LcoNetworksPage({Key? key, required this.lco}) : super(key: key);

  @override
  _LcoNetworksPageState createState() => _LcoNetworksPageState();
}

class _LcoNetworksPageState extends State<LcoNetworksPage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  late List<_NetworkRow> _rows;

  @override
  void initState() {
    super.initState();
    final existing = widget.lco['networks'] as List<dynamic>? ?? [];
    _rows = existing.map((n) {
      final m = (n is Map) ? Map<String, dynamic>.from(n) : <String, dynamic>{};

      // Helper to handle encrypted fields from backend
      String getDisplayValue(dynamic value) {
        if (value == null) return '';
        if (value is Map && value.containsKey('cipherText')) {
          // If backend sends encrypted object, we show a placeholder
          // or leave it for the user to update if needed.
          return '********';
        }
        return value.toString();
      }

      return _NetworkRow(
        isExisting: true,
        networkNameCtrl: TextEditingController(text: m['networkName'] ?? ''),
        lcoIdCtrl: TextEditingController(text: m['lcoId'] ?? ''),
        // userNameCtrl: TextEditingController(), // start empty
        // passwordCtrl: TextEditingController(), // start empty
        // userNameCtrl: TextEditingController(
        //   text: m['userName'] != null ? _NetworkRow.maskedValue : '',
        // ),
        // passwordCtrl: TextEditingController(
        //   text: m['password'] != null ? _NetworkRow.maskedValue : '',
        // ),
        userNameCtrl: TextEditingController(
          text: _NetworkRow.maskedValue,
        ),
        passwordCtrl: TextEditingController(
          text: _NetworkRow.maskedValue,
        ),
        websiteCtrl: TextEditingController(text: m['website'] ?? ''),
        fixedPriceCtrl: TextEditingController(
          text: m['fixedPrice']?.toString() ?? '',
        ),
      );

    }).toList();

    if (_rows.isEmpty) _rows.add(_NetworkRow.empty());
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _addRow() {
    if (_rows.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 networks allowed')),
      );
      return;
    }
    setState(() => _rows.add(_NetworkRow.empty()));
  }

  void _removeRow(int index) {
    // Only allow removing rows that are NOT already saved in the database
    if (_rows[index].isExisting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved networks cannot be deleted here.')),
      );
      return;
    }
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  // bool _hasDuplicateLcoIds(List<Map<String, dynamic>> networks) {
  //   final seen = <String>{};
  //   for (final n in networks) {
  //     final id = (n['lcoId'] ?? '').toString().trim();
  //     if (id.isEmpty) continue;
  //     if (seen.contains(id)) return true;
  //     seen.add(id);
  //   }
  //   return false;
  // }

  String? _findDuplicateLcoId(List<Map<String, dynamic>> networks) {
    final seen = <String>{};
    for (final n in networks) {
      final id = (n['lcoId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (seen.contains(id)) return id;
      seen.add(id);
    }
    return null;
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final networks = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final name = r.networkNameCtrl.text.trim();
      final lcoId = r.lcoIdCtrl.text.trim();
      final userName = r.userNameCtrl.text.trim();
      final website = r.websiteCtrl.text.trim();
      final password = r.passwordCtrl.text;
      final fixedPriceText = r.fixedPriceCtrl.text.trim();

      if (name.isEmpty && lcoId.isEmpty) continue;

      double? fixedPrice;
      if (fixedPriceText.isNotEmpty) {
        fixedPrice = double.tryParse(fixedPriceText);
      }

      networks.add({
        'networkName': name,
        'lcoId': lcoId,
        'website': website.isNotEmpty ? website : null,
        'fixedPrice': fixedPrice,

        // 🔐 IMPORTANT RULE (MATCHES BACKEND)
        // empty  -> null  -> backend keeps old
        // typed  -> value -> backend encrypts & rotates
        'userName': userName.isEmpty ? null : userName,
        'password': password.isEmpty ? null : password,
      });
    }

    if (networks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one network')));
      return;
    }

    final duplicateId = _findDuplicateLcoId(networks);
    if (duplicateId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network ID "$duplicateId" is already used. Each network must have a unique Network ID.',
          ),
        ),
      );
      return;
    }


    setState(() => _submitting = true);

    final lcoId = widget.lco['_id'] ?? widget.lco['id'] ?? 'new';
    final body = {
      'name': widget.lco['name'] ?? '',
      'businessName': widget.lco['businessName'],
      'phones': widget.lco['phones'] ?? [],
      'district': widget.lco['district'],
      'pincode': widget.lco['pincode'],
      'networks': networks,
    };

    try {
      final res = await LcoService.upsertLco(lcoId.toString(), body: body);
      if (!mounted) return;
      setState(() => _submitting = false);

      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        final updated = Map<String, dynamic>.from(res['data'] as Map);
        await LocalStorage.saveLco(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Networks saved successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LcoBottomNavigation(
              lco: updated,
              initialIndex: 0,
            ),
          ),
        );
      } else {
        final msg = res['data'] is Map && res['data']['error'] != null
            ? res['data']['error']
            : 'Save failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _input(
    String label, {
    String? hint,
    IconData? icon,
    bool isReadOnly = false,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: AppTheme.muted)
          : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: isReadOnly
          ? AppTheme.divider.withOpacity(0.1)
          : AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 720;
    final maxContentWidth = isWide ? 900.0 : double.infinity;
    final lcoName = (widget.lco['businessName'] ?? widget.lco['name'] ?? '')
        .toString()
        .trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Networks'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: AppTheme.onPrimary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page header card ... (Keep existing UI)
                    _buildHeader(lcoName),

                    _buildInfoBanner(),

                    ...List.generate(_rows.length, (i) {
                      final r = _rows[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.divider.withOpacity(0.9),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _buildBadge('Network ${i + 1}'),
                                  const Spacer(),
                                  // REMOVED delete option for existing networks
                                  if (!r.isExisting && _rows.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.primary,
                                      ),
                                      onPressed: () => _removeRow(i),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              LayoutBuilder(
                                builder: (ctx, bc) {
                                  final twoCol = bc.maxWidth >= 520;
                                  return _buildResponsiveRow(twoCol, [
                                    TextFormField(
                                      controller: r.networkNameCtrl,
                                      decoration: _input(
                                        'Network Name *',
                                        icon: Icons.tv,
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                    TextFormField(
                                      controller: r.lcoIdCtrl,
                                      // FIXED: ReadOnly for existing networks
                                      readOnly: r.isExisting,
                                      decoration: _input(
                                        'Network LCO ID *',
                                        icon: Icons.badge,
                                        isReadOnly: r.isExisting,
                                        hint: 'This ID cannot be changed',
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ]);
                                },
                              ),

                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: r.websiteCtrl,
                                      decoration: _input(
                                        'Website *',
                                        icon: Icons.language,
                                      ),
                                      keyboardType: TextInputType.url,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    child: TextFormField(
                                      controller: r.fixedPriceCtrl,
                                      decoration: _input(
                                        'Fixed Price (₹)',
                                        icon: Icons.currency_rupee,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // --- USER NAME FIELD ---
                              TextFormField(
                                controller: r.userNameCtrl,
                                readOnly: r.isExisting && !r.isUserNameVisible,
                                obscureText: false, // IMPORTANT
                                decoration: _input(
                                  'User Name *',
                                  icon: Icons.person,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      r.isUserNameVisible ? Icons.visibility : Icons.visibility_off,
                                      size: 20,
                                      color: AppTheme.muted,
                                    ),
                                    onPressed: () async {
                                      if (!r.isExisting) {
                                        setState(() => r.isUserNameVisible = !r.isUserNameVisible);
                                        return;
                                      }

                                      // hide again
                                      if (r.isUserNameVisible) {
                                        setState(() {
                                          r.isUserNameVisible = false;
                                          r.userNameCtrl.text = _NetworkRow.maskedValue;
                                        });
                                        return;
                                      }

                                      // fetch from backend
                                      final lcoId = widget.lco['_id']?.toString();
                                      if (lcoId == null) return;

                                      final res = await LcoService.getNetworkCredentials(
                                        lcoId,
                                        r.lcoIdCtrl.text.trim(),
                                      );

                                      if (!mounted) return;

                                      if (res['statusCode'] == 200) {
                                        setState(() {
                                          r.userNameCtrl.text = res['data']['userName'] ?? '';
                                          r.isUserNameVisible = true;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // --- PASSWORD FIELD ---
                              TextFormField(
                                controller: r.passwordCtrl,
                                readOnly: r.isExisting && !r.isPasswordVisible,
                                obscureText: false, // IMPORTANT
                                decoration: _input(
                                  'Password *',
                                  icon: Icons.lock,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      r.isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      size: 20,
                                      color: AppTheme.muted,
                                    ),
                                    onPressed: () async {
                                      if (!r.isExisting) {
                                        setState(() => r.isPasswordVisible = !r.isPasswordVisible);
                                        return;
                                      }

                                      if (r.isPasswordVisible) {
                                        setState(() {
                                          r.isPasswordVisible = false;
                                          r.passwordCtrl.text = _NetworkRow.maskedValue;
                                        });
                                        return;
                                      }

                                      final lcoId = widget.lco['_id']?.toString();
                                      if (lcoId == null) return;

                                      final res = await LcoService.getNetworkCredentials(
                                        lcoId,
                                        r.lcoIdCtrl.text.trim(),
                                      );

                                      if (!mounted) return;

                                      if (res['statusCode'] == 200) {
                                        setState(() {
                                          r.passwordCtrl.text = res['data']['password'] ?? '';
                                          r.isPasswordVisible = true;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    _buildFooterActions(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // UI Components to maintain design
  Widget _buildHeader(String name) =>
      Container(/* ... existing header code ... */);
  Widget _buildInfoBanner() =>
      Container(/* ... existing info banner code ... */);
  Widget _buildBadge(String label) =>
      Container(/* ... existing badge code ... */);

  Widget _buildResponsiveRow(bool twoCol, List<Widget> children) {
    if (twoCol)
      return Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: children[1]),
        ],
      );
    return Column(
      children: [children[0], const SizedBox(height: 8), children[1]],
    );
  }

  Widget _buildFooterActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _rows.length < 5 ? _addRow : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add network'),
        ),
        const SizedBox(width: 12),
        Text(
          '${_rows.length}/5',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_submitting ? 'Saving...' : 'Save networks'),
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}

// Update your _NetworkRow class to include visibility state
class _NetworkRow {
  final bool isExisting;
  final TextEditingController networkNameCtrl;
  final TextEditingController lcoIdCtrl;
  final TextEditingController userNameCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController fixedPriceCtrl;
  static const String maskedValue = '********';

  // NEW: Visibility states for toggling eye icon
  bool isUserNameVisible = false;
  bool isPasswordVisible = false;

  _NetworkRow({
    required this.isExisting,
    required this.networkNameCtrl,
    required this.lcoIdCtrl,
    required this.userNameCtrl,
    required this.websiteCtrl,
    required this.passwordCtrl,
    required this.fixedPriceCtrl,
  });

  factory _NetworkRow.empty() => _NetworkRow(
    isExisting: false,
    networkNameCtrl: TextEditingController(),
    lcoIdCtrl: TextEditingController(),
    userNameCtrl: TextEditingController(),
    websiteCtrl: TextEditingController(),
    passwordCtrl: TextEditingController(),
    fixedPriceCtrl: TextEditingController(),
  );

  void dispose() {
    networkNameCtrl.dispose();
    lcoIdCtrl.dispose();
    userNameCtrl.dispose();
    websiteCtrl.dispose();
    passwordCtrl.dispose();
    fixedPriceCtrl.dispose();
  }
}
