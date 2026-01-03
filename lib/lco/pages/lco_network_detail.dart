// lib/lco/pages/lco_network_detail.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/lco_service.dart';

class NetworkDetailPage extends StatefulWidget {
  final String lcoId;
  final Map<String, dynamic> network;
  final String? period;

  const NetworkDetailPage({
    Key? key,
    required this.lcoId,
    required this.network,
    this.period,
  }) : super(key: key);

  @override
  State<NetworkDetailPage> createState() => _NetworkDetailPageState();
}

class _NetworkDetailPageState extends State<NetworkDetailPage> {
  bool loading = true;
  bool financeLoading = true;

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filtered = [];
  String query = '';

  Map<String, dynamic>? financials;

  // Currency formatter
  final currencyFormat = NumberFormat('#,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      financeLoading = true;
    });

    await Future.wait([_loadCustomers(), _loadFinancials()]);

    if (!mounted) return;
    setState(() {
      loading = false;
      financeLoading = false;
    });
  }

  String _networkIdFrom(Map<String, dynamic> n) {
    return (n['lcoId'] ?? n['networkId'] ?? n['_id'] ?? n['id'] ?? '')
        .toString();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      loading = true;
    });

    try {
      final networkId = _networkIdFrom(widget.network);
      if (networkId.isEmpty) {
        setState(() {
          customers = [];
          filtered = [];
        });
        return;
      }

      final res = await LcoService.getNetworkCustomers(widget.lcoId, networkId,period: widget.period);
      if (res['statusCode'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final rawList = (data['customers'] as List? ?? []);

        final list = rawList.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();

        final normalized = list.map((c) {
          final boxesRaw = c['boxes'] as List? ?? [];
          final boxes = boxesRaw.map<Map<String, dynamic>>((b) {
            final boxMap = (b is Map<String, dynamic>)
                ? Map<String, dynamic>.from(b)
                : Map<String, dynamic>.from(b as Map);

            // pricePaise -> priceRupees
            if (boxMap.containsKey('pricePaise') &&
                boxMap['pricePaise'] != null) {
              final p = boxMap['pricePaise'];
              if (p is num) {
                boxMap['priceRupees'] = p.toDouble() / 100.0;
              } else {
                final parsed = double.tryParse(p.toString());
                if (parsed != null) boxMap['priceRupees'] = parsed / 100.0;
              }
            } else if (boxMap.containsKey('priceRupees') &&
                boxMap['priceRupees'] != null) {
              final pr = boxMap['priceRupees'];
              if (pr is num) {
                boxMap['priceRupees'] = pr.toDouble();
              } else {
                final parsed = double.tryParse(pr.toString());
                if (parsed != null) boxMap['priceRupees'] = parsed;
              }
            } else {
              boxMap['priceRupees'] = null;
            }

            // parent amountDue for fallback
            boxMap['parentAmountDue'] = c.containsKey('amountDue')
                ? c['amountDue']
                : null;
            return boxMap;
          }).toList();

          final isPaid = c['isPaid'] == true;
          final amountDue = c.containsKey('amountDue') ? c['amountDue'] : null;

          return {
            'customerId': c['customerId'] ?? c['_id'] ?? null,
            'name': c['name'] ?? '-',
            'phone': c['phone'] ?? '-',
            'boxes': boxes,
            'isPaid': isPaid,
            'amountDue': amountDue,
          };
        }).toList();

        setState(() {
          customers = normalized;
          filtered = normalized;
        });
      } else {
        setState(() {
          customers = [];
          filtered = [];
        });
      }
    } catch (_) {
      setState(() {
        customers = [];
        filtered = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadFinancials() async {
    setState(() => financeLoading = true);
    try {
      final res = await LcoService.getLcoFinancials(widget.lcoId);
      if (!mounted) return;

      if (res['statusCode'] == 200 && res['data'] != null) {
        setState(() {
          financials = Map<String, dynamic>.from(
            res['data'] as Map<String, dynamic>,
          );
        });
      } else {
        setState(() => financials = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => financials = null);
    } finally {
      if (!mounted) return;
      setState(() => financeLoading = false);
    }
  }

  void _onSearchChanged(String q) {
    setState(() {
      query = q;
      final lower = q.toLowerCase();

      filtered = customers.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        final boxesList = (c['boxes'] as List? ?? []);
        final setupNumbers = boxesList
            .map((b) => (b['setupBoxNumber'] ?? '').toString().toLowerCase())
            .join(' ');
        return name.contains(lower) ||
            phone.contains(lower) ||
            setupNumbers.contains(lower);
      }).toList();
    });
  }

  double _boxCanonicalRupees(
    Map<String, dynamic> box,
    dynamic customerAmountDueRupees,
  ) {
    if (box.containsKey('pricePaise') && box['pricePaise'] != null) {
      final p = box['pricePaise'];
      if (p is num) return p.toDouble() / 100.0;
      final parsed = double.tryParse(p.toString());
      if (parsed != null) return parsed / 100.0;
    }

    if (box.containsKey('priceRupees') && box['priceRupees'] != null) {
      final pr = box['priceRupees'];
      if (pr is num) return pr.toDouble();
      final parsed = double.tryParse(pr.toString());
      if (parsed != null) return parsed;
    }

    if (customerAmountDueRupees != null) {
      if (customerAmountDueRupees is num) {
        return customerAmountDueRupees.toDouble();
      }
      final parsed = double.tryParse(customerAmountDueRupees.toString());
      return parsed ?? 0.0;
    }

    return 0.0;
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final isPaid = c['isPaid'] == true;
    final amountDue = c['amountDue']; // rupees
    final name = c['name'] ?? '-';
    final phone = c['phone'] ?? '-';
    final boxes = (c['boxes'] as List? ?? []).cast<Map<String, dynamic>>();

    final tagBg = isPaid
        ? Colors.green.withOpacity(0.10)
        : Colors.red.withOpacity(0.08);
    final tagColor = isPaid ? Colors.green : Colors.redAccent;
    final tagText = isPaid ? 'PAID' : 'PENDING';

    final dueRupees = () {
      if (amountDue == null) return 0.0;
      if (amountDue is num) return amountDue.toDouble();
      return double.tryParse(amountDue.toString()) ?? 0.0;
    }();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green : Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.call_outlined,
                          size: 14,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      size: 14,
                      color: tagColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tagText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(color: AppTheme.divider.withOpacity(0.9), height: 1),
          const SizedBox(height: 8),

          // Boxes info
          Column(
            children: boxes.map((b) {
              final status = (b['status'] ?? '').toString();
              DateTime? lastCutoff;
              if (b['lastCutoffDate'] != null) {
                try {
                  lastCutoff =
                      DateTime.tryParse(b['lastCutoffDate'].toString()) ??
                      (b['lastCutoffDate'] is DateTime
                          ? b['lastCutoffDate']
                          : null);
                } catch (_) {
                  lastCutoff = null;
                }
              }

              // Force IST (Indian Standard Time) = UTC + 5:30
              DateTime toIST(DateTime d) =>
                  d.toUtc().add(const Duration(hours: 5, minutes: 30));

              final cutoffText = lastCutoff != null
                  ? DateFormat.yMMMd().add_jm().format(toIST(lastCutoff))
                  : 'No cutoff yet';

              final displayAmountRupees = _boxCanonicalRupees(b, amountDue);

              final statusColor = status == 'active'
                  ? Colors.green
                  : Colors.grey;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tv_rounded,
                      size: 18,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Box: ${b['setupBoxNumber'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'VC: ${b['vcNumber'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status.isEmpty
                                    ? 'Unknown'
                                    : status[0].toUpperCase() +
                                          status.substring(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.schedule,
                                size: 12,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cutoffText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${currencyFormat.format(displayAmountRupees)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isPaid ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _showEditAmountDialog(b, amountDue),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.primaryLight.withOpacity(0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: AppTheme.primaryLight,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total due',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              Text(
                dueRupees <= 0 ? '-' : '₹${currencyFormat.format(dueRupees)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditAmountDialog(
    Map<String, dynamic> box,
    dynamic parentAmountDue,
  ) async {
    final boxId = box['_id']?.toString();
    if (boxId == null) return;

    final initialRupees = _boxCanonicalRupees(box, parentAmountDue);

    final controller = TextEditingController(
      text: initialRupees > 0 ? initialRupees.toStringAsFixed(2) : '',
    );
    final noteController = TextEditingController();

    final result = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.currency_rupee_rounded,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Edit box price',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Box: ${box['setupBoxNumber'] ?? boxId}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'e.g. 250.00',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Reason / remark for this price',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.muted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This will update the canonical price for this box. '
                      'Billing & settlements use this amount.',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Remove price',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // Cancel
    if (result == false) return;

    final messenger = ScaffoldMessenger.of(context);

    // Remove price
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Removing price...')),
      );
      try {
        final resp = await LcoService.removeBoxPrice(widget.lcoId, boxId);
        if (resp['statusCode'] == 200) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Price removed')),
          );
          await _loadCustomers();
        } else {
          final msg = (resp['data'] != null && resp['data']['error'] != null)
              ? resp['data']['error'].toString()
              : 'Failed to remove price';
          messenger.showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to remove price')),
        );
      }
      return;
    }

    // Save new price
    final text = controller.text.trim();
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter amount in rupees')),
      );
      return;
    }

    final rupees = double.tryParse(text.replaceAll(',', ''));
    if (rupees == null || rupees <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    final note = noteController.text.trim().isEmpty
        ? null
        : noteController.text.trim();

    messenger.showSnackBar(const SnackBar(content: Text('Saving price...')));

    try {
      final resp = await LcoService.setBoxPrice(
        widget.lcoId,
        boxId,
        amountRupees: rupees,
        note: note,
      );

      if (resp['statusCode'] == 200) {
        messenger.showSnackBar(const SnackBar(content: Text('Price saved')));
        await _loadCustomers();
      } else {
        final msg = (resp['data'] != null && resp['data']['error'] != null)
            ? resp['data']['error'].toString()
            : 'Failed to save price';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save price')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkName =
        widget.network['networkName'] ?? _networkIdFrom(widget.network) ?? '-';
    final fixedPrice = widget.network['fixedPrice'];

    final fixedPriceRupees = () {
      if (fixedPrice == null) return null;
      if (fixedPrice is num) return fixedPrice.toDouble();
      return double.tryParse(fixedPrice.toString()) ?? 0.0;
    }();

    // Map financials -> per-network totals
    Map<String, dynamic> netTotals = {};
    if (financials != null) {
      final nets = financials!['networks'];
      final needle = _networkIdFrom(widget.network);

      if (nets is List) {
        for (final e in nets) {
          if (e is Map) {
            final key =
                (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                    .toString();
            if (key == needle) {
              netTotals = Map<String, dynamic>.from(e);
              break;
            }
          }
        }
      }

      if (netTotals.isEmpty) {
        final unknown = financials!['unknown'];
        if (unknown is List) {
          for (final e in unknown) {
            if (e is Map) {
              final key =
                  (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                      .toString();
              if (key == needle) {
                netTotals = Map<String, dynamic>.from(e);
                break;
              }
            }
          }
        }
      }
    }

    final totalCust = (netTotals['totalCustomers'] ?? 0) as int;
    final paidCust = (netTotals['paidCustomers'] ?? 0) as int;
    final unpaidCust = totalCust - paidCust;

    final totalAmt = (netTotals['totalAmountRupees'] ?? 0) as num;
    final paidAmt = (netTotals['paidAmountRupees'] ?? 0) as num;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          networkName.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              _buildHeaderCard(
                networkName: networkName.toString(),
                fixedPriceRupees: fixedPriceRupees,
                totalCust: totalCust,
                paidCust: paidCust,
                unpaidCust: unpaidCust < 0 ? 0 : unpaidCust,
                totalAmt: totalAmt,
                paidAmt: paidAmt,
              ),
              const SizedBox(height: 12),
              _buildSearchBar(),
              const SizedBox(height: 10),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No customers found for this network.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final raw = filtered[i];
                          final c = raw is Map<String, dynamic>
                              ? raw
                              : Map<String, dynamic>.from(raw as Map);
                          return _buildCustomerCard(c);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String networkName,
    required double? fixedPriceRupees,
    required int totalCust,
    required int paidCust,
    required int unpaidCust,
    required num totalAmt,
    required num paidAmt,
  }) {
    final displayTotalAmt = (totalAmt is num)
        ? totalAmt.toDouble()
        : double.tryParse(totalAmt.toString()) ?? 0.0;
    final displayPaidAmt = (paidAmt is num)
        ? paidAmt.toDouble()
        : double.tryParse(paidAmt.toString()) ?? 0.0;

    final collectionRate = totalCust > 0 ? (paidCust * 100 / totalCust) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Network title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.router_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  networkName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadAll,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Colors.white70,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (fixedPriceRupees != null)
            Text(
              'Plan price: ₹${currencyFormat.format(fixedPriceRupees)} / month',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              _statChip(
                label: 'Total customers',
                value: totalCust.toString(),
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(width: 8),
              _statChip(
                label: 'Paid',
                value: paidCust.toString(),
                icon: Icons.verified_rounded,
              ),
              const SizedBox(width: 8),
              _statChip(
                label: 'Pending',
                value: unpaidCust.toString(),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _amountTile(
                  title: 'Total billed',
                  amountRupees: displayTotalAmt,
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _amountTile(
                  title: 'Collected',
                  amountRupees: displayPaidAmt,
                  textColor: Colors.greenAccent.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Collection rate: ${collectionRate.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountTile({
    required String title,
    required double amountRupees,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.9)),
        ),
        const SizedBox(height: 2),
        Text(
          '₹${currencyFormat.format(amountRupees)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search by name, phone, or box number',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}
