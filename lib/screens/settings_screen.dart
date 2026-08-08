import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../widgets/app_header.dart';
import 'login_screen.dart';
import 'profile_list_screen.dart';
import 'my_contacts_screen.dart';

class SettingsScreen extends StatelessWidget {
  final ApiClient api;
  final UserSession session;
  const SettingsScreen({super.key, required this.api, required this.session});

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
              showMenu: false,
              api: api,
              session: session,
              store: SessionStore(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    const SizedBox(height: 25),
                    const Text(
                      'Settings',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFD7D7D7)),
                    const SizedBox(height: 10),
                    
                    _buildMenuItem(context, 'Profile', 'profile'),
                    _buildMenuItem(context, 'Keywords', 'keywords'),
                    _buildMenuItem(context, 'Verification', 'verification'),
                    _buildMenuItem(context, 'Promote', 'promote'),
                    _buildMenuItem(context, 'Traffic reports', 'traffic'),
                    _buildMenuItem(context, 'Profile Settings', 'settings'),
                    _buildMenuItem(context, 'My Contacts', 'my_contacts'),
                    
                    const SizedBox(height: 50),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: InkWell(
                        onTap: () {
                          SessionStore().clear().then((_) => Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false));
                        },
                        child: Container(
                          width: double.infinity,
                          height: 59,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFD7D7D7)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Log out',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF232323), fontFamily: 'Poppins'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, String mode) {
    return InkWell(
      onTap: () {
        if (mode == 'traffic') {
          _showTrafficMenu(context);
        } else if (mode == 'my_contacts') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MyContactsScreen(api: api, session: session)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileListScreen(api: api, session: session, mode: mode)));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(40, 18, 10, 18),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black, fontFamily: 'Poppins'),
        ),
      ),
    );
  }

  void _showTrafficMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 400, 20, 0),
      items: [
        const PopupMenuItem(value: 'organic', child: Text('Organic Traffic')),
        const PopupMenuItem(value: 'paid', child: Text('Paid Traffic')),
      ],
    ).then((value) {
      if (value != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileListScreen(api: api, session: session, mode: 'traffic', trafficType: value)));
      }
    });
  }
}
