// lib/customer/pages/customer_detail.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../routes.dart';
import '../../services/customer_service.dart';
import '../../services/lco_service.dart';
import '../../core/app_theme.dart';
import '../../core/api_config.dart';
import '../../core/local_storage.dart';
import '../widgets/bottom_navigation.dart';
import 'customer_home.dart';

class CustomerDetailPage extends StatefulWidget {
  final Map<String, dynamic>? data;
  const CustomerDetailPage({Key? key, this.data}) : super(key: key);

  @override
  _CustomerDetailPageState createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _districtCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  final TextEditingController _setupBoxCtrl = TextEditingController();
  final TextEditingController _vcCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  // State
  List<String> _availableNetworks = [];
  bool _loadingNetworks = false;
  List<Map<String, dynamic>> _lcosForNetwork = [];
  String? _selectedNetworkName;
  XFile? _pickedImage; // use XFile to be cross-platform
  bool _submitting = false;
  Map<String, dynamic>? customer;
  bool _checkingBoxes = true;

  // LCO Selection
  Map<String, dynamic>? _selectedLco;
  List<Map<String, dynamic>> _lcoNetworks = [];
  String? _selectedNetworkLcoId;

  final ImagePicker _picker = ImagePicker();

  // Theme tokens (use AppTheme)
  final Color _primaryColor = AppTheme.primary;
  final Color _inputFillColor = AppTheme.surface;
  final Color _borderColor = AppTheme.divider;
  final double _paddingHorizontal = 20.0;
  final double _sectionSpacing = 18.0;
  final double _fieldSpacing = 14.0;
  final double _controlRadius = 12.0;

  @override
  void initState() {
    super.initState();
    customer = widget.data;

    // _nameCtrl = TextEditingController(text: customer != null ? (customer!['name'] ?? '') : '');
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: customer != null ? (customer!['phone'] ?? '') : '');

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndMaybeRedirect());
    _loadAvailableNetworks();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _districtCtrl.dispose();
    _pincodeCtrl.dispose();
    _setupBoxCtrl.dispose();
    _vcCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // LOGIC METHODS
  // --------------------------------------------------------------------------

  Future<void> _checkAndMaybeRedirect() async {
    if (customer == null) {
      if (!mounted) return;
      setState(() => _checkingBoxes = false);
      return;
    }
    final customerId = customer!['_id'] ?? customer!['id'] ?? customer!['uid'];
    if (customerId == null) {
      if (!mounted) return setState(() => _checkingBoxes = false);
      return;
    }
    try {
      final res = await CustomerService.listBoxes(customerId.toString());
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        final boxes = res['data'] as List<dynamic>;
        if (boxes.isNotEmpty) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppBottomNavigation(customer: customer!)));
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checkingBoxes = false);
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: CircleAvatar(backgroundColor: _primaryColor.withOpacity(0.12), child: Icon(Icons.camera_alt, color: _primaryColor)),
            title: const Text('Take a photo'),
            onTap: () async {
              final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1400, imageQuality: 85);
              if (x != null && mounted) setState(() => _pickedImage = x);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: AppTheme.primaryLight.withOpacity(0.12), child: Icon(Icons.photo_library, color: AppTheme.primaryLight)),
            title: const Text('Choose from gallery'),
            onTap: () async {
              final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 85);
              if (x != null && mounted) setState(() => _pickedImage = x);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _loadAvailableNetworks() async {
    if (!mounted) return;
    setState(() {
      _loadingNetworks = true;
      _availableNetworks = [];
    });
    try {
      final res = await LcoService.searchNetworks('', limit: 200);
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['data'] is List) {
        final list = (res['data'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final names = <String>{};
        for (final item in list) {
          final nm = (item['networkName'] ?? item['networkCode'] ?? item['lcoId'])?.toString();
          if (nm != null && nm.trim().isNotEmpty) names.add(nm.trim());
        }
        final sorted = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() => _availableNetworks = sorted);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingNetworks = false);
    }
  }

  Future<void> _fetchLcosForNetwork(String networkName) async {
    if (!mounted) return;
    setState(() {
      _lcosForNetwork = [];
      _selectedNetworkName = networkName;
      _selectedNetworkLcoId = null;
      _selectedLco = null;
    });
    try {
      final res = await LcoService.searchNetworks(networkName, limit: 200);
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['data'] is List) {
        final list = (res['data'] as List).map<Map<String, dynamic>>((e) {
          return (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};
        }).toList();

        final seen = <String>{};
        final out = <Map<String, dynamic>>[];
        for (final item in list) {
          final lid = (item['lcoId'] ?? item['networkCode'])?.toString();
          if (lid == null || seen.contains(lid)) continue;
          seen.add(lid);
          out.add({
            'lcoRef': item['lcoRef'],
            'businessName': item['businessName'],
            'networkName': item['networkName'],
            'lcoId': lid,
            'networkCode': item['networkCode'],
            'fixedPrice': item['fixedPrice'],
          });
        }
        out.sort((a, b) {
          final aKey = (a['lcoId'] ?? a['businessName'] ?? '').toString();
          final bKey = (b['lcoId'] ?? b['businessName'] ?? '').toString();
          return aKey.toLowerCase().compareTo(bKey.toLowerCase());
        });

        setState(() => _lcosForNetwork = out);

        if (out.length == 1) {
          final only = out.first;
          final selectedId = (only['lcoId'] ?? only['networkCode'])?.toString();
          setState(() {
            _selectedNetworkLcoId = selectedId;
            _selectedLco = {'_id': only['lcoRef'], 'businessName': only['businessName']};
            _lcoNetworks = [
              {
                'networkName': networkName,
                'networkCode': only['networkCode'],
                'lcoId': only['lcoId'],
                'fixedPrice': only['fixedPrice']
              }
            ];
          });
        }
      }
    } catch (_) {}
  }

  void _onLcoIdSelected(String? lcoId) {
    if (lcoId == null || lcoId.trim().isEmpty) {
      setState(() {
        _selectedNetworkLcoId = null;
        _selectedLco = null;
        _lcoNetworks = [];
      });
      return;
    }
    final match = _lcosForNetwork.firstWhere((e) => (e['lcoId'] ?? e['networkCode'])?.toString() == lcoId, orElse: () => {});
    setState(() {
      _selectedNetworkLcoId = lcoId;
      _selectedLco = {
        '_id': match.isNotEmpty ? match['lcoRef'] : null,
        'businessName': match.isNotEmpty ? match['businessName'] : null
      };
      _lcoNetworks = [
        {
          'networkName': _selectedNetworkName,
          'networkCode': match.isNotEmpty ? match['networkCode'] : lcoId,
          'lcoId': lcoId,
        }
      ];
    });
  }

  Future<void> _registerNow() async {
    if (!_formKey.currentState!.validate()) return;
    if (customer == null || _selectedLco == null || _selectedNetworkLcoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Network and LCO')));
      return;
    }

    // 🔴 IMAGE MANDATORY CHECK
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Box barcode image is required'))
      );
      return;
    }

    setState(() => _submitting = true);
    final customerId = customer!['_id'] ?? customer!['id'] ?? customer!['uid'];

    try {
      final selectedNetworkId = _selectedNetworkLcoId!;
      final networkEntry = _lcoNetworks.firstWhere((n) {
        final cid = (n['networkCode'] ?? n['lcoId'] ?? n['networkName'])?.toString();
        return cid == selectedNetworkId;
      }, orElse: () => {});

      final networkName = (networkEntry.isNotEmpty && networkEntry['networkName'] != null)
          ? networkEntry['networkName'].toString()
          : selectedNetworkId;

      final lcoRefVal = _selectedLco!['_id'] ?? _selectedLco!['id'] ?? _selectedLco!['uid'];

      String? perNetworkId;
      if (networkEntry.isNotEmpty) {
        perNetworkId = (networkEntry['lcoId'] ?? networkEntry['networkCode'])?.toString();
      }
      final lcoIdToSend = (perNetworkId != null && perNetworkId.trim().isNotEmpty) ? perNetworkId : lcoRefVal?.toString();

      final Map<String, dynamic> payload = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };

      if (_addressCtrl.text.trim().isNotEmpty) {
        payload['address'] = _addressCtrl.text.trim();
      }

      if (_districtCtrl.text.trim().isNotEmpty) {
        payload['district'] = _districtCtrl.text.trim();
      }

      if (_pincodeCtrl.text.trim().isNotEmpty) {
        payload['pincode'] = _pincodeCtrl.text.trim();
      }

      // await CustomerService.updateCustomer(customerId.toString(), payload);
      final updateRes = await CustomerService.updateCustomer(
        customerId.toString(),
        payload,
      );

      if (updateRes['statusCode'] != 200) {
        final msg = updateRes['data']?['error'] ?? 'Update failed';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg.toString())));
        setState(() => _submitting = false);
        return;
      }

      // Pass XFile to createBox (service handles bytes for web & mobile)
      final res = await CustomerService.createBox(
        customerId.toString(),
        setupBoxNumber: _setupBoxCtrl.text.trim(),
        vcNumber: _vcCtrl.text.trim().isEmpty ? null : _vcCtrl.text.trim(),
        network: networkName,
        lcoId: lcoIdToSend,
        lcoRef: lcoRefVal?.toString(),
        imageFile: _pickedImage,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (res['statusCode'] == 201 || res['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Box registered successfully!')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppBottomNavigation(customer: customer!)));
      } else {
        final msg = (res['data'] is Map && res['data']['error'] != null) ? res['data']['error'] : 'Register failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --------------------------------------------------------------------------
  // LOGOUT (from your provided snippet)
  // --------------------------------------------------------------------------
  Future<void> _logout() async {
    try {
      // attempt server-side logout (best-effort)
      try {
        await ApiConfig.post('/api/auth/logout', {});
      } catch (_) {}

      // clear client-side session + profile
      await LocalStorage.clearSession();
      await LocalStorage.clearLco();

      // clear runtime header token
      ApiConfig.setSessionKey(null);

      // navigate to login (use AppRoutes constant)
      Navigator.pushReplacementNamed(context, AppRoutes.customerLogin);
    } catch (e) {
      Navigator.pushReplacementNamed(context, AppRoutes.customerLogin);
    }
  }

  // --------------------------------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------------------------------

  InputDecoration _inputDecoration({required String label, String? hint, bool dense = true}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _inputFillColor,
      isDense: dense,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType type = TextInputType.text,
    bool requiredField = true,
    int? maxLength,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: _fieldSpacing),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        validator: (v) {
          if (!requiredField) return null;
          if (v == null || v.trim().isEmpty) return '$label is required';
          if (type == TextInputType.phone && v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Invalid phone number';
          if (label.toLowerCase().contains('pincode') && v.trim().length < 6) return 'Invalid pincode';
          if (label.toLowerCase().contains('district')) {
            if (!RegExp(r'^[A-Za-z .-]+$').hasMatch(v.trim())) {
              return 'Invalid district name';
            }
          }

          if (label.toLowerCase().contains('pincode')) {
            if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
              return 'Pincode must be 6 digits';
            }
          }
          return null;
        },
        decoration: _inputDecoration(label: label, hint: hint),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
    bool isLoading = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: _fieldSpacing),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        icon: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.keyboard_arrow_down_rounded),
        validator: (v) => v == null ? 'Please select $label' : null,
        decoration: _inputDecoration(label: label),
      ),
    );
  }

  // Image preview with edit + remove actions
  Widget _imagePreviewBox() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _inputFillColor,
        borderRadius: BorderRadius.circular(_controlRadius),
        border: Border.all(
          color: _pickedImage != null ? _primaryColor : _borderColor,
          width: _pickedImage != null ? 2 : 1,
        ),
      ),
      child: _pickedImage != null
          ? FutureBuilder<List<int>>(
        future: _pickedImage!.readAsBytes(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Icon(Icons.broken_image, size: 36));
          }
          final bytes = snap.data!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(_controlRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes as Uint8List, fit: BoxFit.cover),
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(Icons.edit, color: _primaryColor),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _pickedImage = null);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      )
          : InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(_controlRadius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, size: 30, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text("Tap to upload photo", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text("(Optional)", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MAIN BUILD
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Register New Box', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: _primaryColor,
        foregroundColor: AppTheme.onPrimary,
        elevation: 1,
        centerTitle: true,
      ),
      body: _checkingBoxes
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: _paddingHorizontal, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top helper hint
              Text(
                "Fill customer details and register set-top box",
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              SizedBox(height: _sectionSpacing),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal details
                    sectionHeader("Personal Details", Icons.person_outline),
                    _buildInput(controller: _nameCtrl, label: "Full Name", hint: "Enter customer name"),
                    _buildInput(controller: _phoneCtrl, label: "Mobile Number", type: TextInputType.phone, maxLength: 10),

                    Divider(color: _borderColor, height: 1),
                    SizedBox(height: _sectionSpacing),

                    // Location
                    sectionHeader("Location", Icons.location_on_outlined),
                    Row(
                      children: [
                        Expanded(child: _buildInput(controller: _districtCtrl, label: "District", requiredField: false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput(controller: _pincodeCtrl, label: "Pincode", type: TextInputType.number, maxLength: 6, requiredField: false)),
                      ],
                    ),
                    _buildInput(
                      controller: _addressCtrl,
                      label: "House No / Street / Area",
                      requiredField: false,
                    ),

                    Divider(color: _borderColor, height: 1),
                    SizedBox(height: _sectionSpacing),

                    // Network & LCO
                    sectionHeader("Network & LCO", Icons.hub_outlined),
                    _buildDropdown<String>(
                      label: "Select Network",
                      value: _selectedNetworkName,
                      isLoading: _loadingNetworks,
                      items: _availableNetworks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                      onChanged: (v) {
                        if (v != null) _fetchLcosForNetwork(v);
                      },
                    ),
                    if (_selectedNetworkName != null) ...[
                      _lcosForNetwork.isEmpty
                          ? Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text("No LCOs found for this network.", style: TextStyle(color: Colors.orange, fontSize: 13))),
                        ]),
                      )
                          : _buildDropdown<String>(
                        label: "Select LCO ID",
                        value: _selectedNetworkLcoId,
                        items: _lcosForNetwork.map((e) {
                          final idStr = (e['lcoId'] ?? e['networkCode'])?.toString() ?? '';
                          final business = (e['businessName'] ?? '').toString();
                          final display = business.isNotEmpty ? '$idStr • $business' : idStr;
                          return DropdownMenuItem(
                            value: idStr,
                            child: Text(display, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _onLcoIdSelected,
                      ),
                      if (_selectedLco != null && (_selectedLco!['businessName'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _primaryColor.withOpacity(0.10)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.storefront, color: _primaryColor, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedLco!['businessName'],
                                    style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],

                    Divider(color: _borderColor, height: 1),
                    SizedBox(height: _sectionSpacing),

                    // Box details
                    sectionHeader("Set-Top Box Info", Icons.tv_rounded),
                    _buildInput(controller: _setupBoxCtrl, label: "STB Number", hint: "Enter setup box number"),
                    _buildInput(controller: _vcCtrl, label: "VC Number (Optional)", requiredField: false, hint: "Enter VC number"),

                    SizedBox(height: _sectionSpacing),

                    // Barcode upload
                    sectionHeader("Box Barcode", Icons.qr_code_scanner_rounded),
                    _imagePreviewBox(),

                    const SizedBox(height: 26),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _registerNow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: AppTheme.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("Register Box", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // CANCEL now shows logout confirmation and calls _logout on confirm
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await _logout();
                          }
                        },
                        child: Text("Logout", style: TextStyle(color: Colors.grey[700])),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              Center(
                child: Text(
                  'You can add barcode later from box details',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
