import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/lco_service.dart';
import '../../core/app_theme.dart';

class LcoCustomersPage extends StatefulWidget {
  final Map<String, dynamic> lco;

  final String? initialStatus;
  final String? initialPeriod;

  const LcoCustomersPage({
    super.key,
    required this.lco,
    this.initialStatus,
    this.initialPeriod,
  });

  @override
  State<LcoCustomersPage> createState() => _LcoCustomersPageState();
}

class _LcoCustomersPageState extends State<LcoCustomersPage> {
  List customers = [];
  bool loading = true;

  String? selectedNetwork;
  String? status;
  String search = '';

  Timer? _debounce;

  String? _period;

  @override
  void initState() {
    super.initState();

    status = widget.initialStatus;
    _period = widget.initialPeriod; // 🔥 ADD THIS

    loadCustomers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> loadCustomers() async {
    setState(() => loading = true);

    final res = await LcoService.getAllCustomers(
      widget.lco['_id'] ?? widget.lco['masterLcoId'] ?? '', // Fallback safely
      networkCode: selectedNetwork,
      status: status,
      search: search,
      period: _period, // 🔥 ADD THIS
    );

    if (res['statusCode'] == 200 && res['data'] != null) {
      customers = res['data']['data'] ?? [];
    } else {
      customers = [];
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Customers'),
        elevation: 0,
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: customers.length,
              itemBuilder: (_, i) => _buildCustomerCard(customers[i]),
            ),
          )
        ],
      ),
    );
  }

  // ---------------- UI COMPONENTS ----------------

  Widget _buildTopBar() {
    final networks = widget.lco['networks'] ?? [];

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          // Search Field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or box...',
              hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppTheme.muted),
              filled: true,
              fillColor: AppTheme.scaffoldBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              search = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), loadCustomers);
            },
          ),
          const SizedBox(height: 12),

          // Filters Row
          Row(
            children: [
              // Status Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      isExpanded: true,
                      hint: const Text('All Status', style: TextStyle(color: AppTheme.text, fontSize: 13)),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Status', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'paid', child: Text('Paid', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'unpaid', child: Text('Unpaid', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'new', child: Text('New', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'referred', child: Text('Referred', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) {
                        setState(() => status = v);
                        loadCustomers();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Network Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedNetwork,
                      isExpanded: true,
                      hint: const Text('All Networks', style: TextStyle(color: AppTheme.text, fontSize: 13)),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.muted),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Networks', style: TextStyle(fontSize: 13))),
                        ...(networks as List).map((n) {
                          return DropdownMenuItem<String>(
                            value: n['lcoId']?.toString(),
                            child: Text(
                              n['networkName']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        })
                      ],
                      onChanged: (v) {
                        setState(() => selectedNetwork = v);
                        loadCustomers();
                      },
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Map c) {
    final customer = c['customer'] ?? {};
    final payment = c['payment'];
    final bool isPaid = c['isPaid'] == true;

    final String name = customer['name']?.toString() ?? 'Unknown';
    final String phone = customer['phone']?.toString() ?? 'N/A';
    final String box = c['setupBoxNumber']?.toString() ?? '-';
    final String network = c['networkCode']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letter Avatar
          CircleAvatar(
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            foregroundColor: AppTheme.primary,
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),

          // Customer & Box Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text("📞 $phone", style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  "Box: $box  •  $network",
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Payment Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusTag(isPaid),
              const SizedBox(height: 8),
              if (isPaid && payment != null) ...[
                Text(
                  "₹${((payment['amount'] ?? 0) / 100).toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(payment['paidAt']),
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ] else ...[
                const Text(
                  "₹ -",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusTag(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Not Paid',
        style: TextStyle(
          color: isPaid ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.people_outline, size: 64, color: AppTheme.muted),
          SizedBox(height: 16),
          Text(
            "No customers found",
            style: TextStyle(color: AppTheme.muted, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ---------------- UTILS ----------------

  String _formatDate(String? date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date);
      return "${d.day.toString().padLeft(2, '0')} ${_getMonth(d.month)} ${d.year}";
    } catch (_) {
      return '-';
    }
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}