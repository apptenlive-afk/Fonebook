import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../widgets/app_header.dart';

class ReportsScreen extends StatefulWidget {
  final ApiClient api;
  final String phone;
  final String tags;
  final String type; // 'organic' or 'paid'
  const ReportsScreen({super.key, required this.api, required this.phone, required this.tags, this.type = 'paid'});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = 'All';
  List _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final endpoint = widget.type == 'paid' ? 'check-search3' : 'check-search2';
      final callType = widget.type == 'paid' ? 'paid' : 'normal';

      final data = await widget.api.get(endpoint, {
        'tags': widget.tags,
        'type': _range,
        'phone': widget.phone,
        'call_type': callType,
      });
      
      List list = data as List;
      
      // Secondary check like native app's getNoSearch
      try {
        final noSearchData = await widget.api.get('check-call-count1', {
          'type': _range,
          'phone': widget.phone,
          'call_type': callType,
        });
        if (noSearchData is List) {
          for (var item in noSearchData) {
            if (!list.any((e) => e['tags'] == item['tag'] || (e['tags'] == '' && item['tag'] == ''))) {
               list.add({
                 'tags': item['tag'] ?? '',
                 'call_count': item['call_count'] ?? '0',
                 'search_count': '0',
               });
            }
          }
        }
      } catch(_) {}

      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.type == 'paid';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Fone Book',
              onBack: () => Navigator.pop(context),
              showMenu: true,
              api: widget.api,
              store: SessionStore(),
              session: UserSession(phone: widget.phone),
            ),
            
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 5, top: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isPaid ? 'Paid Traffic Reports' : 'Organic Traffic Reports',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins'),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: DropdownButton<String>(
                      value: _range,
                      isExpanded: true,
                      underline: Container(height: 1, color: Colors.grey),
                      items: ['All', 'Today', 'Yesterday', 'Last 7 days', 'Last Week', 'Last Month']
                          .map((e) => DropdownMenuItem(value: e, child: Center(child: Text(e, style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'))))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _range = v!;
                          _load();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text('Search Keywords', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF232323), fontFamily: 'Poppins')),
                  ),
                  SizedBox(
                    width: 60,
                    child: _buildHeaderIcon('assets/images/research.png', label: 'Research'),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 60,
                    child: _buildHeaderIcon('assets/images/phone.png', label: 'Inbound'),
                  ),
                  if (isPaid) ...[
                    const SizedBox(width: 5),
                    const SizedBox(
                      width: 80,
                      child: Text('Amount', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD7B41A)))
                  : _rows.isEmpty
                      ? const Center(child: Text('No Traffic Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')))
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (c, i) {
                            final r = _rows[i];
                            final callCountStr = r['call_count']?.toString() ?? '0';
                            final callCount = int.tryParse(callCountStr) ?? 0;
                            final amount = (callCount * 0.30).toStringAsFixed(2);
                            return _buildReportItem(
                              r['tags'] ?? '',
                              r['search_count']?.toString() ?? '0',
                              callCountStr,
                              isPaid ? amount : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(String asset, {String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: 20, height: 20),
        Text(label ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
      ],
    );
  }

  Widget _buildReportItem(String tag, String searchCount, String callCount, String? amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              tag, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Poppins')
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(searchCount, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Poppins')),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 60,
            child: Text(callCount, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Poppins')),
          ),
          if (amount != null) ...[
            const SizedBox(width: 5),
            SizedBox(
              width: 80,
              child: Text('\$$amount', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Poppins')),
            ),
          ],
        ],
      ),
    );
  }
}
