import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/support_service.dart';

class LcoChatPage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const LcoChatPage({super.key, required this.lco});

  @override
  State<LcoChatPage> createState() => _LcoChatPageState();
}

class _LcoChatPageState extends State<LcoChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _tickets = [];
  List<dynamic> _messages = [];
  Map<String, dynamic>? _activeTicket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    final t = await SupportService.lcoTickets();
    if (!mounted) return;
    setState(() {
      _tickets = t;
      _loading = false;
    });
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    setState(() {
      _activeTicket = ticket;
      _loading = true;
    });

    // final res = await SupportService.ticketMessages(ticket['_id']);
    final res = await SupportService.lcoTicketWithMessages(ticket['_id']);

    if (!mounted) return;

    setState(() {
      _activeTicket = res['ticket'];     // ✅ UPDATED
      _messages = res['messages'];       // ✅ UPDATED
      _loading = false;
    });

    _scrollToBottom();
  }


  Future<void> _sendReply({bool resolve = false}) async {
    if (_controller.text.trim().isEmpty || _activeTicket == null) return;

    final message = _controller.text.trim();
    _controller.clear();

    await SupportService.lcoRespond(
      ticketId: _activeTicket!['_id'],
      message: message,
      status: resolve ? 'resolved' : 'in_progress',
    );

    if (resolve) {
      setState(() => _activeTicket = null);
      _loadTickets();
    } else {
      final res = await SupportService.lcoTicketWithMessages(_activeTicket!['_id']);
      setState(() {
        _activeTicket = res['ticket'];
        _messages = res['messages'];
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we show the list or the chat based on _activeTicket
    return PopScope(
      canPop: _activeTicket == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _activeTicket = null);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        appBar: AppBar(
          leading: _activeTicket != null
              ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _activeTicket = null)
          )
              : null,
          // title: Text(_activeTicket == null
          //     ? 'Support Tickets'
          //     : 'Chat: ${_activeTicket!['networkCode']}'),
          // title: Text(_activeTicket == null
          //     ? 'Support Tickets'
          //     : 'Chat: ${_activeTicket!['customer']?['name'] ?? 'Customer'} (${_activeTicket!['customer']?['phone'] ?? '-'})'),

          title: Text(
            _activeTicket == null
                ? 'Support Tickets'
                : _activeTicket!['customer']?['name'] ?? 'Customer',
          ),

          actions: [
            if (_activeTicket == null)
              IconButton(onPressed: _loadTickets, icon: const Icon(Icons.refresh))
          ],
        ),
        body: _activeTicket == null ? _buildTicketList() : _buildChatArea(),
      ),
    );
  }

  /// ───── Ticket List View ─────
  Widget _buildTicketList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tickets.isEmpty) {
      return const Center(
        child: Text('No active support tickets', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tickets.length,
      itemBuilder: (_, i) {
        final t = _tickets[i];
        final status = t['status'].toString().toLowerCase();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              t['questionSnapshot']['title'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Network: ${t['networkCode']}'),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'open' ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status == 'open' ? Colors.blue : Colors.orange,
                ),
              ),
            ),
            onTap: () => _openTicket(t),
          ),
        );
      },
    );
  }

  /// ───── Chat Interface View ─────
  Widget _buildChatArea() {
    return Column(
      children: [
        // Ticket Info Header
        // Container(
        //   width: double.infinity,
        //   padding: const EdgeInsets.all(12),
        //   color: Colors.white,
        //   child: Text(
        //     "Subject: ${_activeTicket!['questionSnapshot']['title']}",
        //     style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        //   ),
        // ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "Subject: ${_activeTicket!['questionSnapshot']['title']}",
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 8),

              Text(
                "Customer: ${_activeTicket!['customer']?['name'] ?? '-'}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              Text(
                "Phone: ${_activeTicket!['customer']?['phone'] ?? '-'}",
              ),

              Text(
                "Address: ${_activeTicket!['customer']?['address'] ?? '-'}",
              ),

              Text(
                "District: ${_activeTicket!['customer']?['district'] ?? '-'}",
              ),

              Text(
                "Pincode: ${_activeTicket!['customer']?['pincode'] ?? '-'}",
              ),

              if (_activeTicket!['box'] != null)
                Text(
                  "STB: ${_activeTicket!['box']?['setupBoxNumber'] ?? '-'}",
                ),

            ],
          ),
        ),

        // Message Thread
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              final isLco = m['senderType'] == 'lco';
              return _ChatBubble(message: m, isLco: isLco);
            },
          ),
        ),

        // Input Field
        if (_activeTicket!['status'] != 'resolved') _buildInputSection(),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: 12, right: 12, top: 8
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type reply...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send Button
          // GestureDetector(
          //   onTap: () => _sendReply(),
          //   child: CircleAvatar(
          //     backgroundColor: AppTheme.primary,
          //     radius: 22,
          //     child: const Icon(Icons.send, color: Colors.white, size: 20),
          //   ),
          // ),

          Column(
            children: [
              GestureDetector(
                onTap: () => _sendReply(),
                child: CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 22,
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(height:4),
              const Text("Reply",style:TextStyle(fontSize:10))
            ],
          ),

          const SizedBox(width: 8),
          // Resolve Button
          // GestureDetector(
          //   onTap: () => _sendReply(resolve: true),
          //   child: const CircleAvatar(
          //     backgroundColor: Colors.green,
          //     radius: 22,
          //     child: Icon(Icons.check, color: Colors.white, size: 20),
          //   ),
          // ),

          Column(
            children: [
              GestureDetector(
                // onTap: () => _sendReply(resolve: true),

                onTap: () async {
                  final confirm = await showDialog(
                    context: context,
                    builder: (c)=>AlertDialog(
                      title: const Text("Resolve Ticket"),
                      content: const Text("Mark this issue as resolved?"),
                      actions:[
                        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text("Cancel")),
                        TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text("Resolve")),
                      ],
                    ),
                  );

                  if(confirm==true){
                    _sendReply(resolve:true);
                  }
                },

                child: const CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 22,
                  child: Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(height:4),
              const Text("Resolve",style:TextStyle(fontSize:10))
            ],
          ),

        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final dynamic message;
  final bool isLco;

  const _ChatBubble({required this.message, required this.isLco});

  @override
  Widget build(BuildContext context) {
    // final time = DateFormat('hh:mm a').format(DateTime.parse(message['createdAt']));
    final time = DateFormat('hh:mm a').format(
      DateTime.parse(message['createdAt']).toLocal(),
    );


    return Align(
      alignment: isLco ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isLco ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isLco ? 15 : 0),
            bottomRight: Radius.circular(isLco ? 0 : 15),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['message'],
              style: TextStyle(color: isLco ? Colors.white : Colors.black87, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(color: isLco ? Colors.white70 : Colors.black45, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}