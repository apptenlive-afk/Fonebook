import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/contact.dart';
import '../models/user_session.dart';
import '../widgets/app_header.dart';
import 'add_profile_screen.dart';
import 'keyword_screen.dart';
import 'verification_screen.dart';
import 'promote_screen.dart';
import 'reports_screen.dart';
import 'visibility_screen.dart';
import 'phone_entry_screen.dart';

class ProfileListScreen extends StatefulWidget {
  final ApiClient api;
  final UserSession session;
  final String mode; // 'profile', 'keywords', 'verification', 'promote', 'traffic', 'settings'
  final String? trafficType; // 'organic', 'paid'

  const ProfileListScreen({
    super.key,
    required this.api,
    required this.session,
    required this.mode,
    this.trafficType,
  });

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  List<DirectoryContact> _profiles = [];
  bool _loading = true;
  late UserSession _currentSession;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.get('check_search_type1', {'email': _currentSession.email});
      if (res is List) {
        // Filter out "ghost" profiles that don't have a valid name or phone
        final profiles = res
            .map((e) => DirectoryContact.fromJson(e))
            .where((p) => p.name.isNotEmpty && p.phone.isNotEmpty)
            .toList();
        
        final isPremium = profiles.any((p) => p.verified == 1);
        
        if (isPremium != _currentSession.premium) {
          _currentSession = UserSession(
            phone: _currentSession.phone,
            email: _currentSession.email,
            place: _currentSession.place,
            place1: _currentSession.place1,
            country: _currentSession.country,
            image: _currentSession.image,
            premium: isPremium,
          );
          await SessionStore().save(_currentSession);
        }

        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String get _title {
    switch (widget.mode) {
      case 'profile': return 'Profiles';
      case 'keywords': return 'Keywords';
      case 'verification': return 'Verification';
      case 'promote': return 'Promote';
      case 'traffic': 
        return widget.trafficType == 'organic' ? 'Organic Traffic Reports' : 'Paid Traffic Reports';
      case 'settings': return 'Settings';
      default: return 'Fone Book';
    }
  }

  void _addContact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhoneEntryScreen(email: widget.session.email!)),
    ).then((_) => _load());
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
              session: widget.session,
              store: SessionStore(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  if (widget.mode == 'profile')
                    InkWell(
                      onTap: _addContact,
                      child: const Text('+Add ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black, decoration: TextDecoration.underline)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD7B41A)))
                  : _profiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No Business profile added yet',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first Business profile to manage ${_title.toLowerCase()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: 200,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _addContact,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Business Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD7B41A),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _profiles.length,
                          itemBuilder: (c, i) {
                            final p = _profiles[i];
                            return _buildItem(p);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(DirectoryContact p) {
    return InkWell(
      onTap: () => _onItemClick(p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/images/user.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: p.imageUrl.isNotEmpty
                  ? ClipOval(
                      child: FadeInImage.assetNetwork(
                        placeholder: 'assets/images/user.png',
                        image: p.imageUrl,
                        fit: BoxFit.cover,
                        imageErrorBuilder: (context, error, stackTrace) => Image.asset('assets/images/user.png', fit: BoxFit.cover),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF232323)),
                  ),
                  Text(
                    p.service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF5F6368)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          p.location1 ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF5F6368)),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.mode == 'profile')
                  Text(
                    p.publish == 'yes' ? 'Published' : 'Verify to publish',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: p.publish == 'yes' ? const Color(0xFF0F8F51) : Colors.red,
                    ),
                  )
                else if (widget.mode == 'verification')
                  Text(
                    p.verified == 1 ? 'Verified' : 'Not Verified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: p.verified == 1 ? const Color(0xFF0F8F51) : Colors.red,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.mode == 'traffic' ? Icons.visibility : Icons.edit,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.mode == 'traffic' ? 'View' : 'Edit',
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onItemClick(DirectoryContact p) {
    Widget target;
    switch (widget.mode) {
      case 'profile':
        target = AddProfileScreen(email: widget.session.email!, phone: p.phone);
        break;
      case 'keywords':
        target = KeywordScreen(
          api: widget.api,
          phone: p.phone,
          name: p.name,
          service: p.service,
          category: p.category ?? 'Individual',
          initial: "${p.keyword ?? ''}, ${p.tags ?? ''}",
          verified: p.verified,
        );
        break;
      case 'verification':
        target = VerificationScreen(contact: p);
        break;
      case 'promote':
        target = PromoteScreen(session: widget.session, contact: p);
        break;
      case 'traffic':
        target = ReportsScreen(
          api: widget.api, 
          phone: p.phone, 
          tags: p.keyword ?? '',
          type: widget.trafficType ?? 'paid',
        );
        break;
      case 'settings':
        target = VisibilityScreen(api: widget.api, phone: p.phone, initial: p.showContact, contact: p);
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => target)).then((_) => _load());
  }
}


