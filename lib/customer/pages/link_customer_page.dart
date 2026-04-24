import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_config.dart';
import '../../services/customer_service.dart';

class LinkCustomerPage extends StatefulWidget {
  final Map customer;
  const LinkCustomerPage({super.key, required this.customer});

  @override
  State<LinkCustomerPage> createState() => _LinkCustomerPageState();
}

class _LinkCustomerPageState extends State<LinkCustomerPage> {
  final nameCtrl = TextEditingController();
  final boxCtrl = TextEditingController();
  final vcCtrl = TextEditingController();

  List lcos = [];
  Map? selectedLco;
  Map? selectedNetwork;
  bool loadingLco = true;

  bool loading = false;
  String? error;

  XFile? selectedImage;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLcos();
  }

  Future<void> _loadLcos() async {
    final res = await ApiConfig.get('/api/lcos/all');

    if (res['statusCode'] == 200) {
      setState(() {
        lcos = res['body'];
        loadingLco = false;
      });
    }
    else {
      setState(() {
        loadingLco = false;
        error = "Failed to load operators";
      });
    }
  }

  Future<void> _create() async {
    if (loading) return;
    final name = nameCtrl.text.trim();
    final box = boxCtrl.text.trim();
    final vc = vcCtrl.text.trim();

    if (name.isEmpty ||
        box.isEmpty ||
        selectedLco == null ||
        selectedNetwork == null) {
      setState(() => error = "Fill all required fields");
      return;
    }

    if (name.length < 3) {
      setState(() => error = "Enter valid name");
      return;
    }

    if (box.length < 5 || box.contains(' ')) {
      setState(() => error = "Invalid Box Number");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // STEP 1: create linked customer
      final customerRes = await ApiConfig.post('/api/customers/secondary', {
        "name": name,
      });

      if (customerRes['statusCode'] != 200) {
        throw Exception("Customer creation failed");
      }

      final linkedCustomerId = customerRes['body']['_id'];
      final parentId = widget.customer['_id'];

      final lcoId = selectedNetwork!['lcoId'];
      final lcoRef = selectedLco!['_id'];
      final network = selectedNetwork!['networkName'];

      // STEP 2: create box
      final boxRes = await CustomerService.createBox(
        parentId,
        setupBoxNumber: box,
        vcNumber: vc,
        network: network,
        lcoId: lcoId,
        lcoRef: lcoRef,
        linkedCustomerId: linkedCustomerId,   // 🔥 IMPORTANT
        connectionLabel: name,                // 🔥 IMPORTANT
        imageFile: selectedImage,             // 🔥 IMAGE FIX
      );

      if (boxRes['statusCode'] == 200 || boxRes['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer linked successfully')),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(boxRes['body']?['error'] ?? "Failed");
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }


  @override
  void dispose() {
    nameCtrl.dispose();
    boxCtrl.dispose();
    vcCtrl.dispose();
    super.dispose();
  }

  void _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Take Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() => selectedImage = picked);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => selectedImage = picked);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imagePreview() {
    if (selectedImage == null) return SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected Image",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),

          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(selectedImage!.path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              // REMOVE BUTTON
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() => selectedImage = null);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }



  Widget _dropdown() {
    final networks = selectedLco?['networks'] ?? [];

    if (loadingLco) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        DropdownButtonFormField<Map>(
          value: selectedLco,
          hint: const Text("Select Operator"),
          items: lcos.map<DropdownMenuItem<Map>>((lco) {
            return DropdownMenuItem<Map>(
              value: lco as Map,
              child: Text(lco['businessName'] ?? lco['name']),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedLco = val;
              selectedNetwork = null;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Map>(
          value: selectedNetwork,
          hint: const Text("Select Network"),
          items: networks.isEmpty
              ? []
              : networks.map<DropdownMenuItem<Map>>((n) {
            return DropdownMenuItem<Map>(
              value: n as Map,
              child: Text(n['networkName']),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedNetwork = val;
            });
          },
        ),
        if (selectedLco != null && networks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "No networks available",
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Connection')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _field(nameCtrl, 'Customer Name'),
                    _field(boxCtrl, 'Setup Box Number'),
                    _field(vcCtrl, 'VC Number (optional)'),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.upload),
                      label: Text(
                        selectedImage == null
                            ? "Upload Barcode"
                            : "Change Image",
                      ),
                    ),
                    _imagePreview(),
                    _dropdown(),
                  ],
                ),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : _create,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Add Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
