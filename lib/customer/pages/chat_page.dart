import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/support_service.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String boxId;

  const ChatPage({super.key, required this.customer, required this.boxId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _questions = [];
  List<dynamic> _messages = [];
  Map<String, dynamic>? _activeTicket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initSupport();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initSupport() async {
    setState(() => _loading = true);

    final tickets = await SupportService.customerTickets();

    // Only treat truly active tickets as active
    final active = tickets.isNotEmpty ? tickets.first : null;

    if (active != null) {
      final msgs = await SupportService.ticketMessages(active['_id']);
      if (!mounted) return;
      setState(() {
        _activeTicket = active;
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
      return;
    }

    // No active ticket → show questions
    final q = await SupportService.listQuestions();
    if (!mounted) return;
    setState(() {
      _questions = q;
      _activeTicket = null;
      _messages = [];
      _loading = false;
    });
  }

  Future<void> _sendInitialQuestion(String questionId) async {
    setState(() => _loading = true);

    final ticket = await SupportService.createTicket(
      boxId: widget.boxId,
      questionId: questionId,
    );

    final msgs = await SupportService.ticketMessages(ticket['_id']);

    if (!mounted) return;
    setState(() {
      _activeTicket = ticket;
      _messages = msgs;
      _questions = [];
      _loading = false;
    });

    _scrollToBottom();
  }

  Future<void> _sendFollowUp() async {
    if (_controller.text.trim().isEmpty || _activeTicket == null) return;

    final message = _controller.text.trim();
    _controller.clear();

    await SupportService.customerReply(
      ticketId: _activeTicket!['_id'],
      message: message,
    );

    final tickets = await SupportService.customerTickets();
    final updated = tickets.firstWhere(
          (t) => t['_id'] == _activeTicket!['_id'],
      orElse: () => null,
    );

    final msgs = await SupportService.ticketMessages(_activeTicket!['_id']);

    if (!mounted) return;
    setState(() {
      _activeTicket = updated;
      _messages = msgs;
    });

    _scrollToBottom();
  }

  void _resetToNewTicketFlow() async {
    setState(() {
      _activeTicket = null;
      _messages = [];
      _questions = [];
      _loading = true;
    });

    final q = await SupportService.listQuestions();
    if (!mounted) return;
    setState(() {
      _questions = q;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initSupport, // reload ticket + messages
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _activeTicket == null
                ? _EmptySupportState(
              questions: _questions,
              onSelect: _sendInitialQuestion,
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _ChatBubble(
                message: _messages[i],
                isCustomer: _messages[i]['senderType'] == 'customer',
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    if (_activeTicket == null) return const SizedBox.shrink();

    final status = _activeTicket!['status'];
    final canReply = _activeTicket!['customerCanReply'] == true;

    if (status == 'resolved' || status == 'closed') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Column(
          children: [
            Text(
              'This ticket is resolved.',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _resetToNewTicketFlow,
              child: const Text('Start New Ticket'),
            ),
          ],
        ),
      );
    }

    if (!canReply) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          "Waiting for operator response...",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
        ),
      );
    }

    return _replyInput();
  }

  Widget _replyInput() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10,
        left: 16,
        right: 16,
        top: 10,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Reply to operator...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendFollowUp),
        ],
      ),
    );
  }
}


class _ChatBubble extends StatelessWidget {
  final dynamic message;
  final bool isCustomer;

  const _ChatBubble({required this.message, required this.isCustomer});

  @override
  Widget build(BuildContext context) {
    // final time = DateFormat('hh:mm a').format(DateTime.parse(message['createdAt']));
    final time = DateFormat(
      'hh:mm a',
    ).format(DateTime.parse(message['createdAt']).toLocal());

    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCustomer ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isCustomer ? 16 : 0),
            bottomRight: Radius.circular(isCustomer ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['message'],
              style: TextStyle(
                color: isCustomer ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isCustomer ? Colors.white70 : Colors.black45,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySupportState extends StatelessWidget {
  final List<dynamic> questions;
  final Function(String) onSelect;
  const _EmptySupportState({required this.questions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.support_agent_rounded,
            size: 80,
            color: AppTheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            'How can we help you?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a common issue to start a ticket',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ...questions.map(
            (q) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                onPressed: () => onSelect(q['_id']),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q['title'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
