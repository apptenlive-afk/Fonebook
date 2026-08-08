import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../models/contact.dart';
import '../screens/login_screen.dart';
import '../screens/add_profile_screen.dart';
import '../screens/keyword_screen.dart';
import '../screens/visibility_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/worldwide_screen.dart';
import '../screens/promote_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/profile_list_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/my_contacts_screen.dart';

class HeaderMenu extends StatelessWidget {
  final ApiClient? api;
  final SessionStore? store;
  final UserSession? session;
  final VoidCallback? onUpdate;
  const HeaderMenu({super.key, this.api, this.store, this.session, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Image.asset('assets/images/three_dots.png', width: 25, height: 30),
      onSelected: (v) async {
        if (v == 'Logout') {
          SessionStore().clear().then((_) => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false));
          return;
        }

        final effectiveApi = api ?? ApiClient();
        final effectiveSession = (session != null && session!.email != null) ? session! : await SessionStore().read();
        
        if (effectiveSession.email == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to access management features.')));
          return;
        }

        if (v == 'Traffic') {
          // NOTE: Currently open for Free users for testing. Revoke after testing.
          _showTrafficMenu(context, effectiveApi, effectiveSession);
          return;
        }

        String mode = '';
        if (v == 'Profile') mode = 'profile';
        else if (v == 'Keywords') mode = 'keywords';
        else if (v == 'Verification') mode = 'verification';
        else if (v == 'Promote') mode = 'promote';
        else if (v == 'Settings') mode = 'settings';

        if (mode.isNotEmpty) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileListScreen(api: effectiveApi, session: effectiveSession, mode: mode)));
        }
      },
      itemBuilder: (c) => [
        const PopupMenuItem(value: 'Profile', child: Text('Profile')),
        const PopupMenuItem(value: 'Keywords', child: Text('Keywords')),
        const PopupMenuItem(value: 'Verification', child: Text('Verification')),
        const PopupMenuItem(value: 'Promote', child: Text('Promote')),
        const PopupMenuItem(value: 'Traffic', child: Text('Traffic')),
        const PopupMenuItem(value: 'Settings', child: Text('Settings')),
        const PopupMenuItem(value: 'Logout', child: Text('Logout')),
      ],
    );
  }

  void _showTrafficMenu(BuildContext context, ApiClient effectiveApi, UserSession effectiveSession) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(value: 'organic', child: Text('Organic Traffic')),
        const PopupMenuItem(value: 'paid', child: Text('Paid Traffic')),
      ],
    ).then((value) {
      if (value != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileListScreen(api: effectiveApi, session: effectiveSession, mode: 'traffic', trafficType: value)));
      }
    });
  }
}
