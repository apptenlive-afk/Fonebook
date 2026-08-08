import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../models/contact.dart';
import '../widgets/app_header.dart';

class VisibilityScreen extends StatefulWidget {
  final ApiClient api;
  final String phone;
  final String initial;
  final DirectoryContact contact;
  const VisibilityScreen({super.key, required this.api, required this.phone, required this.initial, required this.contact});
  @override
  State<VisibilityScreen> createState() => _VisibilityScreenState();
}

class _VisibilityScreenState extends State<VisibilityScreen> {
  late bool m, w, e, l, s, f, pub;
  String _whoContact = 'all';

  @override
  void initState() {
    super.initState();
    m = widget.initial.contains('m');
    w = widget.initial.contains('w');
    e = widget.initial.contains('e');
    l = widget.initial.contains('l');
    s = widget.initial.contains('s');
    f = widget.initial.contains('f');
    pub = widget.contact.publish == 'yes';
    _whoContact = widget.contact.whoContact ?? 'all';
  }

  void _saveShow() async {
    await widget.api.post('save_show', {
      'phone': widget.phone,
      'show': '${m ? 'm' : ''}${w ? 'w' : ''}${e ? 'e' : ''}${l ? 'l' : ''}${s ? 's' : ''}${f ? 'f' : ''}'
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  void _saveWho(String val) async {
    setState(() => _whoContact = val);
    await widget.api.post('save_access', {
      'phone': widget.phone,
      'who_contact': val,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  void _savePub(bool v) async {
    if (v && widget.contact.verified != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only verified contacts can publish profile in directory.')),
      );
      setState(() => pub = false);
      return;
    }
    await widget.api.post('save_publish', {'phone': widget.phone, 'publish': v ? 'yes' : 'no'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              session: UserSession(phone: widget.phone),
              store: SessionStore(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(25, 20, 25, 10),
                      child: Text(
                        'Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'Poppins'),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFD7D7D7)),
                    
                    const Padding(
                      padding: EdgeInsets.fromLTRB(30, 15, 25, 5),
                      child: Text(
                        'Show Contacts',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black, fontFamily: 'Poppins'),
                      ),
                    ),
                    
                    _buildNativeSwitchTile('Mobile no', m, (v) { setState(() => m = v); _saveShow(); }),
                    _buildNativeSwitchTile('Whatsapp', w, (v) { setState(() => w = v); _saveShow(); }),
                    _buildNativeSwitchTile('Email', e, (v) { setState(() => e = v); _saveShow(); }),
                    _buildNativeSwitchTile('Landline', l, (v) { setState(() => l = v); _saveShow(); }),
                    _buildNativeSwitchTile('Skype', s, (v) { setState(() => s = v); _saveShow(); }),
                    _buildNativeSwitchTile('Full Address', f, (v) { setState(() => f = v); _saveShow(); }),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(height: 2, thickness: 1.5, color: Color(0xFFD7D0B4)),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.fromLTRB(30, 0, 25, 5),
                      child: Text(
                        'Access',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black, fontFamily: 'Poppins'),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(80, 15, 25, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Who can contact you',
                              style: TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Poppins'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _whoContact.toLowerCase(),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Users', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'verified', child: Text('Only Verified', style: TextStyle(fontSize: 14))),
                              ],
                              onChanged: (v) => _saveWho(v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    /*
                    const Divider(height: 2, thickness: 1.5, color: Color(0xFFD7D0B4)),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(80, 20, 25, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Publish profile',
                              style: TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Poppins'),
                            ),
                          ),
                          Switch(
                            value: pub,
                            onChanged: (v) {
                              setState(() => pub = v);
                              _savePub(v);
                            },
                            activeColor: const Color(0xFFD7B41A),
                          ),
                        ],
                      ),
                    ),
                    */
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    bool canToggle = true;
    if (title == 'Whatsapp' && (widget.contact.whatsapp == null || widget.contact.whatsapp!.isEmpty)) canToggle = false;
    if (title == 'Email' && (widget.contact.email == null || widget.contact.email!.isEmpty)) canToggle = false;
    if (title == 'Landline' && (widget.contact.landline == null || widget.contact.landline!.isEmpty)) canToggle = false;
    if (title == 'Skype' && (widget.contact.skype == null || widget.contact.skype!.isEmpty)) canToggle = false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 0, 25, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16, 
                color: canToggle ? Colors.black : Colors.grey, 
                fontFamily: 'Poppins'
              ),
            ),
          ),
          Switch(
            value: value && canToggle,
            onChanged: (v) {
              if (!canToggle && v) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You didn't enter the ${title.toLowerCase()}.")));
                return;
              }
              onChanged(v);
            },
            activeColor: const Color(0xFFD7B41A),
          ),
        ],
      ),
    );
  }
}
