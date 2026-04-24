import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../services/customer_service.dart';
import 'customer_detail.dart';
import 'link_customer_page.dart';

class MyConnectionsPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  const MyConnectionsPage({super.key, required this.customer});

  @override
  State<MyConnectionsPage> createState() => _MyConnectionsPageState();
}

class _MyConnectionsPageState extends State<MyConnectionsPage> {
  List boxes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    final id = widget.customer['_id'];
    final res = await CustomerService.listBoxes(id);

    if (res['statusCode'] == 200) {
      setState(() {
        boxes = (res['data'] as List).where((b) {
          return b['wasLinked'] != true;
        }).toList();
        loading = false;
      });
    }
  }

  int get totalBoxes => boxes.length;

  int get ownBoxes =>
      boxes.where((b) => b['linkedCustomer'] == null).length;

  int get linkedBoxes =>
      boxes.where((b) => b['linkedCustomer'] != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Connections')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : boxes.isEmpty
          ? const Center(child: Text("No connections yet"))
          : Column(
        children: [
          _statsCard(),
          Expanded(child: _boxList()),
          _addButtons(),
        ],
      ),
    );
  }

  Widget _statsCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: ListTile(
          title: Text('Total: $totalBoxes / 3'),
          subtitle: Text('Own: $ownBoxes | Linked: $linkedBoxes / 2'),
        ),
      ),
    );
  }

  Widget _boxList() {
    return ListView.builder(
      itemCount: boxes.length,
      itemBuilder: (_, i) {
        final b = boxes[i];
        final isLinked = b['linkedCustomer'] != null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(
              b['setupBoxNumber'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked
                      ? "Linked: ${b['connectionLabel'] ?? 'Unknown'}"
                      : "Your Connection",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isLinked ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text("${b['network'] ?? '-'} • ${b['lcoId'] ?? '-'}"),
              ],
            ),
            trailing: isLinked
                ? IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: () async {
                final success = await _disconnect(b['_id']);

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connection removed')),
                  );
                }
              },
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _addButtons() {
    final canAddOwn = ownBoxes < 1 && totalBoxes < 3;
    final canAddLinked = linkedBoxes < 2 && totalBoxes < 3;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: canAddOwn ? _openAddBox : null,
            child: const Text('Add Your Box'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!canAddLinked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Max 2 linked connections allowed')),
                );
                return;
              }
              _openLinkCustomer();
            },
            child: const Text('Add Connection (Family / Friend)'),
          ),
        ],
      ),
    );
  }

  Future<bool> _disconnect(String boxId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to remove this connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    final res = await CustomerService.disconnectBox(boxId);

    if (res['statusCode'] == 200) {
      await _loadBoxes();
      return true;
    }

    return false;
  }

  void _openAddBox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailPage(data: widget.customer),
      ),
    );

    _loadBoxes(); // 🔥 refresh
  }

  void _openLinkCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LinkCustomerPage(customer: widget.customer),
      ),
    );

    if (result == true) {
      _loadBoxes();
    }
  }

}