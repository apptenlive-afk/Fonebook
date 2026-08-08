import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../models/user_session.dart';
import '../models/contact.dart';
import '../widgets/contact_card.dart';
import '../widgets/app_header.dart';
import '../widgets/header_menu.dart';
import 'details_screen.dart';
import 'my_contacts_screen.dart';

import '../services/countries.dart';
import '../widgets/country_picker_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.store, required this.session, required this.onSearchModeChanged});
  final ApiClient api;
  final SessionStore store;
  final UserSession session;
  final Function(bool) onSearchModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  bool _isSearching = false;
  bool _loading = false;
  bool _hasSearched = false;
  List<DirectoryContact> _results = [];
  int _localMatchCount = 0;
  List<MyContactItem> _localContacts = [];
  List<DirectoryContact> _favs = [];
  String _scopeLabel = 'International';
  String? _selectedLocation; // For filtering

  @override
  void initState() {
    super.initState();
    _loadData();
    _search.addListener(() => setState(() {}));
    _focus.addListener(() {
      if (_focus.hasFocus && !_isSearching) {
        setState(() {
          _isSearching = true;
          widget.onSearchModeChanged(true);
        });
      }
    });
  }

  void _loadData() async {
    final favs = await widget.store.getFavourites();
    setState(() => _favs = favs);
    _loadLocalContacts();
  }

  void _loadLocalContacts() async {
    try {
      final email = (widget.session.email != null && widget.session.email!.isNotEmpty)
          ? widget.session.email!
          : (widget.session.phone ?? 'guest@fonebook.com');
      final res = await widget.api.post('get_my_contacts', {'email': email, 'owner_email': email});
      if (res is List) {
        setState(() {
          _localContacts = res.map((e) => MyContactItem.fromJson(Map<String, dynamic>.from(e))).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading local contacts: $e");
    }
  }

  void _loadFavs() async {
    final favs = await widget.store.getFavourites();
    setState(() => _favs = favs);
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _isSearching = true;
      _hasSearched = true;
      widget.onSearchModeChanged(true);
    });
    try {
      // Save search history
      unawaited(widget.api.post('savesearch', {
        'tag': q.trim(),
        'country': widget.session.country ?? '',
        'location': widget.session.place1 ?? '',
      }));

      // Always fetch latest local contacts during search to ensure sync
      final email = (widget.session.email != null && widget.session.email!.isNotEmpty)
          ? widget.session.email!
          : (widget.session.phone ?? 'guest@fonebook.com');
      final localRes = await widget.api.post('get_my_contacts', {'email': email, 'owner_email': email});
      if (localRes is List) {
        _localContacts = localRes.map((e) => MyContactItem.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      final data = await widget.api.get('check-contact', {
        'type': 'search',
        'query': q.trim(),
        'location': _selectedLocation,
      });
      final List list = data;

      // Filter local contacts
      final query = q.trim().toLowerCase();
      final localMatches = _localContacts.where((c) {
        return c.name.toLowerCase().contains(query) ||
               c.title.toLowerCase().contains(query) ||
               c.phone.toLowerCase().contains(query);
      }).map((c) => DirectoryContact(
        name: c.name,
        service: c.title,
        phone: c.phone,
        priority: '1',
        priorityBalance: '0',
        category: 'my_contact', // Marker for local contact in history
        showContact: 'mwelsf', // Default show all for local contacts
      )).toList();

      setState(() {
        final apiResults = list
            .where((e) => e != null && e is Map && e['name'] != null && e['name'].toString().trim().isNotEmpty)
            .map((e) => DirectoryContact.fromJson(e))
            .where((e) => !localMatches.any((l) => l.phone == e.phone)) // Avoid duplicates
            .toList();
            
        _results = [...localMatches, ...apiResults];
        _localMatchCount = localMatches.length;
      });
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        String cityArea = "Current Location";
        
        if (!kIsWeb) {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark p = placemarks[0];
            cityArea = p.subLocality != null ? "${p.subLocality}, ${p.locality}" : (p.locality ?? '');
          }
        }

        setState(() {
          _scopeLabel = cityArea;
          _selectedLocation = cityArea;
        });
        if (_search.text.isNotEmpty) _doSearch(_search.text);
      }
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showScopeMenu() {
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
      position: position.shift(const Offset(24, 160)), // Positioned near the "Change" text
      items: [
        const PopupMenuItem(value: 'International', child: Text('International')),
        const PopupMenuItem(value: 'Country', child: Text('Country')),
        const PopupMenuItem(value: 'Location', child: Text('Current Location')),
      ],
    ).then((value) async {
      if (value == 'International') {
        setState(() {
          _scopeLabel = 'International';
          _selectedLocation = null;
        });
        if (_search.text.isNotEmpty) _doSearch(_search.text);
      } else if (value == 'Country') {
        final res = await showDialog<String>(
          context: context,
          builder: (c) => const CountryPickerDialog(title: 'Select Country', items: countriesList),
        );
        if (res != null) {
          // Remove emoji
          final name = res.substring(res.indexOf(' ') + 1).trim();
          setState(() {
            _scopeLabel = name;
            _selectedLocation = name;
          });
          if (_search.text.isNotEmpty) _doSearch(_search.text);
        }
      } else if (value == 'Location') {
        _fetchCurrentLocation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Home Content - Logo & Title (Grouped with search positioning)
            if (!_isSearching)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/phone1.png', width: 140, height: 60, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                    const Text(
                      'Fone Book',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF202124), fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 30), // Small gap before search box
                    // Placeholder for search box space to keep layout stable
                    const SizedBox(height: 52),
                    const SizedBox(height: 12),
                    Text(
                      "Ex: Plumber, Doctor, Developer, Electrician, Hotel...",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),

            if (!_isSearching)
              Positioned(
                top: 15,
                right: 15,
                child: HeaderMenu(api: widget.api, store: widget.store, session: widget.session, onUpdate: _loadFavs),
              ),

            // Search Results
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          const Text('Result for ', style: TextStyle(color: Color(0xFF5F6368), fontSize: 14)),
                          Text(_scopeLabel, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF202124), fontSize: 14)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showScopeMenu,
                            child: const Text('Change', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 14, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _hasSearched && _results.isEmpty && _search.text.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 50),
                                  child: Column(
                                    children: [
                                      const Text('No Phone numbers found', 
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                                  itemCount: _results.length,
                                  itemBuilder: (c, i) {
                                    final contact = _results[i];
                                    final isFav = _favs.any((e) => e.phone == contact.phone);
                                    final isMyContact = i < _localMatchCount;

                                    return ContactCard(
                                      contact: contact,
                                      isFavourite: isFav,
                                      isMyContact: isMyContact,
                                      isFirstThree: i < 3,
                                      onCall: isMyContact ? null : () => widget.store.addToHistory(contact),
                                      onTap: isMyContact ? () {} : () {
                                        widget.onSearchModeChanged(false);
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(contact: contact))).then((_) {
                                          _loadFavs();
                                          if (_isSearching) widget.onSearchModeChanged(true);
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),

            // Animated Search Card
            AnimatedAlign(
              alignment: _isSearching ? Alignment.topCenter : Alignment.center,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: _isSearching ? 20 : 80, // Positioned below Logo/Name when centered
                ),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        if (_isSearching)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF5F6368)),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _search.clear();
                                _results.clear();
                                _hasSearched = false;
                                _focus.unfocus();
                                widget.onSearchModeChanged(false);
                              });
                            },
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.search, color: Color(0xFF5F6368)),
                          ),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            focusNode: _focus,
                            onSubmitted: _doSearch,
                            onChanged: (v) {
                              if (v.isEmpty) {
                                setState(() {
                                  _isSearching = false;
                                  _results.clear();
                                  _hasSearched = false;
                                  _focus.unfocus();
                                  widget.onSearchModeChanged(false);
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search name or Keyword...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintStyle: TextStyle(color: Color(0xFF5F6368)),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        if (_search.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF5F6368)),
                            onPressed: () {
                              setState(() {
                                _search.clear();
                                _isSearching = false;
                                _results.clear();
                                _hasSearched = false;
                                _focus.unfocus();
                                widget.onSearchModeChanged(false);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
