// lib/lco/pages/lco_profile_page.dart
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/lco_service.dart'; // 🔹 ADD THIS

class LcoProfilePage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const LcoProfilePage({Key? key, required this.lco}) : super(key: key);

  @override
  State<LcoProfilePage> createState() => _LcoProfilePageState();
}

class _LcoProfilePageState extends State<LcoProfilePage> {
  late Map<String, dynamic> _lco;

  @override
  void initState() {
    super.initState();
    _lco = Map<String, dynamic>.from(widget.lco);
  }

  // Navigate to edit screen inside same file, get updated result
  Future<void> _goToEdit() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LcoEditPage(lco: _lco),
      ),
    );

    if (updated != null && updated is Map<String, dynamic>) {
      setState(() => _lco = updated);
    }
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
    final name = _lco["name"]?.toString().trim() ?? "";
    final business = _lco["businessName"]?.toString().trim() ?? "";
    final phones = (_lco["phones"] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final district = _lco["district"]?.toString().trim() ?? "";
    final pincode = _lco["pincode"]?.toString().trim() ?? "";
    final email = _lco["email"]?.toString().trim() ?? "";
    final displayName = business.isNotEmpty ? business : name;

    final avatarInitial =
    (displayName.isNotEmpty ? displayName[0] : "L").toUpperCase();

    // Optional extra info if backend already provides it
    final lcoId =
        _lco["_id"]?.toString() ?? _lco["id"]?.toString() ?? _lco["uid"]?.toString() ?? "";
    final status = _lco["status"]?.toString(); // 'active', 'pending', 'suspended', etc.
    final networksCount =
    (_lco["networks"] is List) ? (_lco["networks"] as List).length : 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 22),
            onPressed: _goToEdit,
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileHeader(
                displayName: displayName,
                ownerName: name,
                avatar: avatarInitial,
                businessName: business,
                // status: status,
                networksCount: networksCount,
              ),
              const SizedBox(height: 18),

              // ───────── Business section ─────────
              _sectionLabel("Business"),
              _infoTile(
                Icons.storefront_outlined,
                "Business name",
                business.isNotEmpty ? business : "-",
              ),
              if (name.isNotEmpty)
                _infoTile(
                  Icons.person_outline,
                  "Owner name",
                  name,
                ),
              // if (lcoId.isNotEmpty)
              //   _infoTile(
              //     Icons.badge_outlined,
              //     "LCO ID",
              //     lcoId,
              //   ),
              if (networksCount > 0)
                _infoTile(
                  Icons.wifi_tethering,
                  "Networks linked",
                  networksCount.toString(),
                ),

              const SizedBox(height: 18),

              // ───────── Contact section ─────────
              _sectionLabel("Contact details"),
              _infoTile(
                Icons.email_outlined,
                "Email",
                email.isNotEmpty ? email : "-",
              ),
              _infoTile(
                Icons.call,
                "Phone 1",
                phones.isNotEmpty ? phones[0] : "-",
              ),
              if (phones.length > 1)
                _infoTile(
                  Icons.phone_android,
                  "Phone 2",
                  phones[1],
                ),

              const SizedBox(height: 18),

              // ───────── Location section ─────────
              _sectionLabel("Location"),
              _infoTile(
                Icons.location_on_outlined,
                "District",
                district.isNotEmpty ? district : "-",
              ),
              _infoTile(
                Icons.local_post_office_outlined,
                "Pincode",
                pincode.isNotEmpty ? pincode : "-",
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader({
    required String displayName,
    required String ownerName,
    required String avatar,
    required String businessName,
    // required String? status,
    required int networksCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppTheme.primaryLight.withOpacity(.18),
            child: Text(
              avatar,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main name (Business or Owner)
                Text(
                  displayName.isNotEmpty ? displayName : "LCO",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                // Owner line
                if (ownerName.isNotEmpty)
                  Text(
                    "Owner: $ownerName",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.muted,
                    ),
                  ),
                // If both business + owner exist, show subtle tag
                if (businessName.isNotEmpty && ownerName.isNotEmpty)
                  const SizedBox(height: 4),
                if (businessName.isNotEmpty && ownerName.isNotEmpty)
                  const Text(
                    "Business profile",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (networksCount > 0) ...[
                      const Icon(
                        Icons.wifi_tethering,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$networksCount networks',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.muted,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────── */
/*                      EDIT PAGE (Same File)                      */
/* ──────────────────────────────────────────────────────────────── */

class _LcoEditPage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const _LcoEditPage({Key? key, required this.lco}) : super(key: key);

  @override
  State<_LcoEditPage> createState() => _LcoEditPageState();
}

class _LcoEditPageState extends State<_LcoEditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _businessCtrl;
  late TextEditingController _phone1Ctrl;
  late TextEditingController _phone2Ctrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _pincodeCtrl;
  // late TextEditingController _emailCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.lco;

    final phones = (l['phones'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    _nameCtrl = TextEditingController(text: l["name"] ?? "");
    _businessCtrl = TextEditingController(text: l["businessName"] ?? "");
    _phone1Ctrl =
        TextEditingController(text: phones.isNotEmpty ? phones[0] : "");
    _phone2Ctrl =
        TextEditingController(text: phones.length > 1 ? phones[1] : "");
    _districtCtrl = TextEditingController(text: l["district"] ?? "");
    _pincodeCtrl = TextEditingController(text: l["pincode"] ?? "");
    //_emailCtrl = TextEditingController(text: l["email"] ?? "");

  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    _districtCtrl.dispose();
    _pincodeCtrl.dispose();
    //_emailCtrl.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // Build local updated map
    final updated = Map<String, dynamic>.from(widget.lco);
    final phones = <String>[];

    if (_phone1Ctrl.text.trim().isNotEmpty) {
      phones.add(_phone1Ctrl.text.trim());
    }
    if (_phone2Ctrl.text.trim().isNotEmpty) {
      phones.add(_phone2Ctrl.text.trim());
    }

    updated["name"] = _nameCtrl.text.trim();
    updated["businessName"] = _businessCtrl.text.trim();
    updated["phones"] = phones;
    updated["district"] = _districtCtrl.text.trim();
    updated["pincode"] = _pincodeCtrl.text.trim();
    //updated["email"] = _emailCtrl.text.trim();   // <-- ADD THIS

    // 🔹 Determine LCO id for API
    final lcoId = (widget.lco["_id"] ??
        widget.lco["id"] ??
        widget.lco["uid"])
        ?.toString() ??
        '';

    if (lcoId.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot update: LCO id missing')),
      );
      return;
    }

    try {
      final body = <String, dynamic>{
        'name': updated['name'],
        'businessName': updated['businessName'],
        'phones': updated['phones'],
        'district': updated['district'],
        'pincode': updated['pincode'],
        'email': updated['email'],   // <-- NEW
      };

      final res = await LcoService.upsertLco(lcoId, body: body);
      final status = res['statusCode'] as int? ?? 500;

      if (!mounted) return;

      if (status < 200 || status >= 300) {
        setState(() => _saving = false);
        final data = res['data'];
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : (res['error']?.toString() ?? 'Failed to update profile');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
        return;
      }

      // Backend returns updated LCO document
      final serverData = res['data'];
      final updatedFromServer = (serverData is Map<String, dynamic>)
          ? Map<String, dynamic>.from(serverData)
          : updated;

      Navigator.pop(context, updatedFromServer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        elevation: 1,
        title: const Text("Edit Profile"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _inputField(
                      controller: _nameCtrl,
                      label: "Owner name",
                      icon: Icons.person_outline,
                      validator: (v) =>
                      v!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 14),
                    _inputField(
                      controller: _businessCtrl,
                      label: "Business name",
                      icon: Icons.business_outlined,
                      validator: (v) =>
                      v!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),

                    _section("Contact details"),
                    // _inputField(
                    //   controller: _emailCtrl,
                    //   label: "Email",
                    //   icon: Icons.email_outlined,
                    //   keyboardType: TextInputType.emailAddress,
                    //   validator: (v) {
                    //     final val = v?.trim() ?? '';
                    //     if (val.isEmpty) return null; // optional
                    //     // very basic email check
                    //     if (!val.contains('@') || !val.contains('.')) return "Invalid email";
                    //     return null;
                    //   },
                    // ),
                    const SizedBox(height: 12),
                    _inputField(
                      controller: _phone1Ctrl,
                      label: "Phone 1",
                      icon: Icons.phone_android,
                      validator: (v) {
                        if (v!.trim().isEmpty) return "Required";
                        final d = v.replaceAll(RegExp(r'[^0-9]'), '');
                        if (d.length < 6) return "Invalid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _phone2Ctrl,
                      label: "Phone 2 (optional)",
                      icon: Icons.phone_outlined,
                    ),

                    const SizedBox(height: 24),

                    _section("Location"),
                    const SizedBox(height: 12),
                    _inputField(
                      controller: _districtCtrl,
                      label: "District",
                      icon: Icons.map_outlined,
                      validator: (v) =>
                      v!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _pincodeCtrl,
                      label: "Pincode",
                      icon: Icons.local_post_office_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                      v!.trim().isEmpty ? "Required" : null,
                    ),

                    const SizedBox(height: 28),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.muted,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,

        // 🔥 Proper spacing fix
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),

        prefixIcon: icon != null
            ? Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            icon,
            color: AppTheme.muted,
            size: 20,
          ),
        )
            : null,
        prefixIconConstraints:
        const BoxConstraints(minWidth: 40, minHeight: 40),

        filled: true,
        fillColor: AppTheme.surface,

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text("Save changes"),
      ),
    );
  }
}
