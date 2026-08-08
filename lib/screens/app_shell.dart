import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import 'home_screen.dart';
import 'recent_screen.dart';
import 'favourites_screen.dart';
import 'my_contacts_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final api = ApiClient();
  final store = SessionStore();
  UserSession _session = const UserSession();
  bool _hideFooter = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    store.addListener(_refresh);
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => store.read().then((s) => setState(() => _session = s));

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        api: api,
        store: store,
        session: _session,
        onSearchModeChanged: (searching) => setState(() => _hideFooter = searching),
      ),
      RecentScreen(api: api, store: store, session: _session),
      FavouritesScreen(api: api, store: store, session: _session),
      MyContactsScreen(api: api, session: _session),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: _hideFooter && _index == 0
          ? null
          : Theme(
              data: Theme.of(context).copyWith(
                canvasColor: const Color(0xFF242424),
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                backgroundColor: const Color(0xFF242424),
                selectedItemColor: const Color(0xFFF6D207),
                unselectedItemColor: const Color(0xFF808080),
                type: BottomNavigationBarType.fixed,
                items: [
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Image.asset('assets/images/search.png', width: 20, height: 20, color: _index == 0 ? const Color(0xFFF6D207) : const Color(0xFF808080)),
                    ),
                    label: 'Search',
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/images/recent.png', width: 24, height: 24, color: _index == 1 ? const Color(0xFFF6D207) : const Color(0xFF808080)),
                    label: 'Recent',
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/images/star.png', width: 24, height: 24, color: _index == 2 ? const Color(0xFFF6D207) : const Color(0xFF808080)),
                    label: 'Favourites',
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset('assets/images/group.png', width: 24, height: 24, color: _index == 3 ? const Color(0xFFF6D207) : const Color(0xFF808080)),
                    label: 'My Contacts',
                  ),
                ],
              ),
            ),
    );
  }
}
