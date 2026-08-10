import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../models/contact.dart';
import '../widgets/contact_card.dart';
import '../widgets/app_header.dart';
import 'details_screen.dart';

class RecentScreen extends StatefulWidget {
  final ApiClient api;
  final SessionStore store;
  final UserSession session;
  const RecentScreen({super.key, required this.api, required this.store, required this.session});
  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  List<DirectoryContact> _list = [];
  List<DirectoryContact> _filtered = [];
  List<DirectoryContact> _favs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final favs = await widget.store.getFavourites();
    List<DirectoryContact> history = [];

    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        final Iterable<CallLogEntry> entries = await CallLog.get();
        final DateFormat sdf = DateFormat('yyyy-MM-dd HH:mm:ss');
        for (final entry in entries) {
          final String rawName = entry.name?.trim() ?? '';
          final String phone = entry.formattedNumber ?? entry.number ?? '';
          final String name = rawName.isNotEmpty ? rawName : (phone.isNotEmpty ? phone : 'Unknown');

          String service = 'Call';
          switch (entry.callType) {
            case CallType.incoming:
              service = 'Incoming Call';
              break;
            case CallType.outgoing:
              service = 'Outgoing Call';
              break;
            case CallType.missed:
              service = 'Missed Call';
              break;
            case CallType.rejected:
              service = 'Rejected Call';
              break;
            case CallType.blocked:
              service = 'Blocked Call';
              break;
            default:
              service = 'Call';
          }

          final String timestamp = entry.timestamp != null
              ? sdf.format(DateTime.fromMillisecondsSinceEpoch(entry.timestamp!))
              : '';

          history.add(DirectoryContact(
            name: name,
            service: service,
            phone: phone,
            timestamp: timestamp,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error reading call log: $e');
    }

    if (history.isEmpty) {
      history = await widget.store.getHistory();
    }

    setState(() {
      _list = history;
      _filtered = _list;
      _favs = favs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Recent',
              showSearch: true,
              searchHint: 'Search Recent',
              onSearch: (q) {
                setState(() {
                  _filtered = _list.where((e) => e.name.toLowerCase().contains(q.toLowerCase()) || e.service.toLowerCase().contains(q.toLowerCase())).toList();
                });
              },
              api: widget.api,
              store: widget.store,
              session: widget.session,
              onUpdate: _load,
            ),
            if (_list.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No Recent Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (c, i) {
                    final contact = _filtered[i];
                    final isFav = _favs.any((e) => e.phone == contact.phone);
                    final isMyContact = contact.category == 'my_contact';
                    
                    return ContactCard(
                      contact: contact,
                      isFavourite: isFav,
                      isMyContact: isMyContact,
                      showTime: true,
                      onCall: () => widget.store.addToHistory(contact).then((_) => _load()),
                      onTap: isMyContact ? () {} : () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(contact: contact))).then((_) => _load()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
