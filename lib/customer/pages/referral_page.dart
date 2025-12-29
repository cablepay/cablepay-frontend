// lib/customer/pages/referral_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/local_storage.dart';
import '../../services/customer_service.dart';
import '../../services/referral_service.dart';

class ReferralPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  const ReferralPage({Key? key, required this.customer}) : super(key: key);

  @override
  _ReferralPageState createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  late Map<String, dynamic> _customer;
  bool _loading = false;
  bool _listLoading = false;
  String? _error;
  List<Map<String, dynamic>> _referrals = [];

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
    _fetchReferrals();
  }

  Future<void> _refreshCustomer() async {
    final id = _customer['_id'] ?? _customer['id'];
    if (id == null) return;
    try {
      setState(() => _loading = true);
      final res = await CustomerService.getCustomer(id.toString());
      if (res['statusCode'] == 200 && res['data'] != null) {
        final updated = Map<String, dynamic>.from(res['data'] as Map);
        setState(() {
          _customer = updated;
        });
        await LocalStorage.saveCustomer(updated);
        // refresh referral list too in case backend updated referral records
        await _fetchReferrals();
      } else {
        setState(() => _error = 'Failed to refresh profile');
      }
    } catch (e) {
      setState(() => _error = 'Network error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchReferrals() async {
    // try to fetch referrals where current user is the referrer
    final id = _customer['_id'] ?? _customer['id'];
    if (id == null) return;
    setState(() {
      _listLoading = true;
      _error = null;
      _referrals = [];
    });

    try {
      final res = await ReferralService.getReferralsForReferrer(id.toString());
      if (res['statusCode'] == 200 && res['data'] != null) {
        final body = res['data'];
        final arr = (body is Map && body['referrals'] is List)
            ? body['referrals'] as List
            : (body is List ? body : []);
        setState(() {
          _referrals = arr.map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).toList();
        });
      } else {
        // endpoint may not exist — keep empty and rely on customer fields
        setState(() {
          _referrals = [];
        });
      }
    } catch (e) {
      // network/parse error -> keep empty
      setState(() {
        _referrals = [];
      });
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  // compute counts from referrals list; fallback to customer flags if list empty
  int get _pendingCount {
    if (_referrals.isNotEmpty) {
      return _referrals.where((r) => (r['status'] ?? 'pending').toString() == 'pending').length;
    }
    // fallback
    return _customer['referralPending'] == true ? 1 : 0;
  }

  int get _completedCount {
    if (_referrals.isNotEmpty) {
      return _referrals.where((r) => (r['status'] ?? '').toString() == 'completed').length;
    }
    // fallback: if referralRewardIssued true, we cannot infer how many — return 1 if true
    return _customer['referralRewardIssued'] == true ? 1 : 0;
  }

  Widget _infoTile({required String title, required String subtitle, IconData? leading}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceVariant),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 20, color: AppTheme.primary),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final myCode = _customer['referralCode'] ?? '-';

    // inside _buildReferralCard()
    final points = _customer['rewardPoints'] ?? 0;

// compute pending either from customer flag or from _referrals list
    bool referralPendingFlag = _customer['referralPending'] == true;
    bool hasPendingInList = _referrals.any((r) => (r['status'] ?? 'pending') == 'pending');
    final referralPending = referralPendingFlag || hasPendingInList;

// similarly for rewardIssued compute from either customer or referrals:
    bool rewardIssuedFlag = _customer['referralRewardIssued'] == true;
    bool hasCompletedInList = _referrals.any((r) => (r['status'] ?? '') == 'completed');
    final rewardIssued = rewardIssuedFlag || hasCompletedInList;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share your code', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text('Your referral code', style: const TextStyle(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  SelectableText(myCode.toString(), style: const TextStyle(letterSpacing: 0.7, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                Text('Invite friends — when they complete their first payment, you earn reward points.', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share code'),
                      onPressed: () {
                        final code = myCode.toString();
                        if (code == '-' || code.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No referral code available')));
                          return;
                        }
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied to clipboard')));
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _loading ? null : _refreshCustomer,
                    child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14)),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _infoTile(title: 'Reward points', subtitle: points.toString(), leading: Icons.stars)),
          const SizedBox(width: 12),
          Expanded(child: _infoTile(title: 'Pending referrals', subtitle: _pendingCount.toString(), leading: Icons.hourglass_top)),
        ]),
        const SizedBox(height: 12),
        _infoTile(title: 'Completed referrals', subtitle: _completedCount.toString(), leading: Icons.check_circle_outline),
        if (rewardIssued)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('You have received rewards for referrals.', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildReferredBySection() {
    final referredBy = _customer['referredBy'];
    if (referredBy == null) return const SizedBox.shrink();

    String referrerId = referredBy is Map && referredBy['_id'] != null ? (referredBy['_id'].toString()) : referredBy.toString();
    final referralPendingFlag = _customer['referralPending'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('You were referred by', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_outline, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(referrerId, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              Text(
                // rely on referrals list if present, otherwise on customer flag
                (_referrals.isNotEmpty
                    ? 'Your referrer will receive the reward when you make your first successful payment.'
                    : (referralPendingFlag
                    ? 'Your referrer will receive the reward after you make your first successful payment.'
                    : 'Referral recorded.')),
                style: TextStyle(color: AppTheme.muted),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralsList() {
    if (_listLoading) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator()));
    }

    if (_referrals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text('People you referred', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('No referrals yet', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('When someone signs up using your code, they appear here as pending until they make their first payment.', style: TextStyle(color: AppTheme.muted)),
              ]),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('People you referred', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._referrals.map((r) {
          final status = (r['status'] ?? 'pending').toString();
          final referredInfo = r['referredCustomer'] is Map ? Map<String, dynamic>.from(r['referredCustomer']) : null;
          final displayName = referredInfo != null && (referredInfo['name'] ?? '').toString().isNotEmpty
              ? referredInfo['name'].toString()
              : (r['referredName'] ?? r['referred'] ?? 'Unknown').toString();
          final phone = referredInfo != null ? (referredInfo['phone'] ?? '-') : (r['referredPhone'] ?? '-');
          final createdAt = r['createdAt'] != null ? DateTime.tryParse(r['createdAt'].toString()) : null;
          final completedAt = r['completedAt'] != null ? DateTime.tryParse(r['completedAt'].toString()) : null;
          final points = r['rewardPoints'] ?? r['points'] ?? '-';

          Color badgeColor = AppTheme.primary;
          IconData badgeIcon = Icons.hourglass_top;
          String badgeText = 'Pending';
          if (status == 'completed') {
            badgeColor = Colors.green;
            badgeIcon = Icons.check_circle_outline;
            badgeText = 'Completed';
          } else if (status == 'cancelled') {
            badgeColor = Colors.grey;
            badgeIcon = Icons.cancel_outlined;
            badgeText = 'Cancelled';
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Phone: ${phone ?? '-'}', style: TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: badgeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(badgeIcon, size: 14, color: badgeColor),
                            const SizedBox(width: 6),
                            Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                      if (completedAt != null) Text('Completed: ${_formatDate(completedAt)}', style: const TextStyle(color: AppTheme.muted)),
                      if (createdAt != null) Text('Since: ${_formatDate(createdAt)}', style: const TextStyle(color: AppTheme.muted)),
                      Text('Pts: $points', style: const TextStyle(color: AppTheme.muted)),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshCustomer,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildReferralCard(),
              const SizedBox(height: 12),
              _buildReferredBySection(),
              const SizedBox(height: 12),
              _buildReferralsList(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}
