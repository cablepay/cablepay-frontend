// lib/common/pages/notification_page.dart
import 'package:flutter/material.dart';
import '../../core/api_config.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool loading = true;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiConfig.get('/api/notifications/my');
      final list = (res['body'] as List?) ?? [];

      setState(() {
        items = list;
        loading = false;
      });

      // 🔥 Mark all unread as read after loading
      for (final n in list) {
        if (n is Map && n['read'] == false) {
          ApiConfig.post('/api/notifications/${n['_id']}/read', {});
        }
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text('No notifications'))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final n = items[i] as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(n['title'] ?? ''),
              subtitle: Text(n['body'] ?? ''),
            );
          },
        ),
      ),
    );
  }
}
