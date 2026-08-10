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
  String _scopeLabel = 'Location(Current Location)';
  String? _selectedLocation; // For filtering
  bool _userHasCustomScope = false;

  String _mapCountryCodeToName(String code) {
    final upper = code.toUpperCase();
    const map = {
      'IN': 'India',
      'US': 'United States',
      'GB': 'United Kingdom',
      'CA': 'Canada',
      'AU': 'Australia',
      'NG': 'Nigeria',
      'AE': 'United Arab Emirates',
      'SG': 'Singapore',
      'MY': 'Malaysia',
      'PK': 'Pakistan',
      'BD': 'Bangladesh',
      'LK': 'Sri Lanka',
      'ZA': 'South Africa',
      'DE': 'Germany',
      'FR': 'France',
      'IT': 'Italy',
      'ES': 'Spain',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'NZ': 'New Zealand',
    };
    return map[upper] ?? 'India';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _loadLocalContacts();
        if (!_isSearching) {
          setState(() {
            _isSearching = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _loadData() async {
    final favs = await widget.store.getFavourites();
    final currentSession = await widget.store.read();

    if (mounted) setState(() => _favs = favs);

    if (!_userHasCustomScope) {
      String defaultCity = (currentSession.place1 != null && currentSession.place1!.isNotEmpty)
          ? currentSession.place1!
          : ((widget.session.place1 != null && widget.session.place1!.isNotEmpty)
              ? widget.session.place1!
              : "Current Location");

      if (mounted) {
        setState(() {
          _scopeLabel = "Location($defaultCity)";
          _selectedLocation = defaultCity == "Current Location" ? null : defaultCity;
        });
      }

      _autoFetchLocation();
    }

    _loadLocalContacts();
  }

  Future<void> _autoFetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );

        if (!kIsWeb) {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark p = placemarks.first;
            final subLocality = p.subLocality?.trim();
            final locality = p.locality?.trim();

            String cityArea = "Current Location";
            if (subLocality != null && subLocality.isNotEmpty && locality != null && locality.isNotEmpty) {
              cityArea = "$subLocality, $locality";
            } else if (locality != null && locality.isNotEmpty) {
              cityArea = locality;
            }

            if (mounted && !_userHasCustomScope) {
              setState(() {
                _scopeLabel = "Location($cityArea)";
                _selectedLocation = cityArea;
              });
              if (_search.text.isNotEmpty) _doSearch(_search.text);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Auto location detection error: $e");
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.email != widget.session.email || oldWidget.session.phone != widget.session.phone) {
      _loadLocalContacts();
    }
  }

  Future<void> _loadLocalContacts() async {
    final List<MyContactItem> list = [];
    try {
      final currentSession = await widget.store.read();
      final email = (currentSession.email != null && currentSession.email!.isNotEmpty)
          ? currentSession.email!
          : ((currentSession.phone != null && currentSession.phone!.isNotEmpty)
              ? currentSession.phone!
              : ((widget.session.email != null && widget.session.email!.isNotEmpty)
                  ? widget.session.email!
                  : (widget.session.phone ?? 'guest@fonebook.com')));

      final res = await widget.api.post('get_my_contacts', {'email': email, 'owner_email': email});
      if (res is List) {
        list.addAll(res.map((e) => MyContactItem.fromJson(Map<String, dynamic>.from(e))));
      }

      if (mounted) {
        setState(() {
          _localContacts = list;
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
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      unawaited(widget.api.post('savesearch', {
        'tag': q.trim(),
        'country': widget.session.country ?? '',
        'location': widget.session.place1 ?? '',
      }));

      await _loadLocalContacts();

      final cleanQ = query.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');

      final localMatches = _localContacts.where((c) {
        final cleanP = c.phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
        final nameMatch = c.name.toLowerCase().contains(query);
        final titleMatch = c.title.toLowerCase().contains(query);
        final phoneMatch = cleanQ.isNotEmpty && cleanP.contains(cleanQ);
        return nameMatch || titleMatch || phoneMatch;
      }).map((c) => DirectoryContact(
        name: c.name,
        service: c.title,
        phone: c.phone,
        priority: '1',
        priorityBalance: '0',
        category: 'my_contact',
        showContact: 'mwelsf',
      )).toList();

      final isContactNameSearch = _localContacts.any(
        (c) => c.name.toLowerCase().contains(query),
      );

      List<DirectoryContact> apiResults = [];

      if (!isContactNameSearch) {
        String apiLocation = '';
        if (_scopeLabel.startsWith('Location(') || _scopeLabel.startsWith('Country(')) {
          apiLocation = _selectedLocation ?? '';
        }

        final data = await widget.api.get('check-contact', {
          'type': 'search',
          'query': q.trim(),
          'location': apiLocation,
        });

        if (data is List) {
          apiResults = data
              .where((e) => e != null && e is Map && e['name'] != null && e['name'].toString().trim().isNotEmpty)
              .map((e) => DirectoryContact.fromJson(e))
              .where((e) {
                final cleanPhone = e.phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                final nameMatch = e.name.toLowerCase().contains(query);
                final serviceMatch = e.service.toLowerCase().contains(query);
                final keywordMatch = (e.keyword ?? '').toLowerCase().contains(query);
                final tagsMatch = (e.tags ?? '').toLowerCase().contains(query);
                final aboutMatch = (e.about ?? '').toLowerCase().contains(query);
                final phoneMatch = cleanQ.isNotEmpty && cleanPhone.contains(cleanQ);

                final textMatch = nameMatch || serviceMatch || keywordMatch || tagsMatch || aboutMatch || phoneMatch;
                if (!textMatch) return false;

                final who = (e.whoContact ?? 'international').toLowerCase();
                if (who == 'international' || who == 'all' || who.isEmpty) {
                  return true;
                }

                final isLocationSearch = _scopeLabel.startsWith('Location(');
                final isCountrySearch = _scopeLabel.startsWith('Country(');
                final isInternationalSearch = _scopeLabel == 'International';

                if (who == 'country') {
                  return isCountrySearch || isInternationalSearch;
                }

                if (who == 'location') {
                  return isLocationSearch;
                }

                return true;
              })
              .where((e) => !localMatches.any((l) => l.phone == e.phone))
              .toList();
        }
      }

      setState(() {
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
          _scopeLabel = "Location($cityArea)";
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

  void _showScopeMenuAt(BuildContext btnContext) {
    final RenderBox button = btnContext.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(btnContext).overlay!.context.findRenderObject() as RenderBox;

    final Offset topBelow = button.localToGlobal(Offset(0, button.size.height + 8), ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(button.size.bottomRight(Offset(0, 8)), ancestor: overlay);

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(topBelow, bottomRight),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: btnContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
      color: const Color(0xFFFFF9E6),
      items: const [
        PopupMenuItem(value: 'International', child: Text('International', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600))),
        PopupMenuItem(value: 'Country', child: Text('Country', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600))),
        PopupMenuItem(value: 'Location', child: Text('Current Location', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    ).then((value) async {
      if (value == 'International') {
        setState(() {
          _userHasCustomScope = true;
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
          final name = res.substring(res.indexOf(' ') + 1).trim();
          setState(() {
            _userHasCustomScope = true;
            _scopeLabel = 'Country($name)';
            _selectedLocation = name;
          });
          if (_search.text.isNotEmpty) _doSearch(_search.text);
        }
      } else if (value == 'Location') {
        _userHasCustomScope = true;
        _fetchCurrentLocation();
      }
    });
  }

  Widget _buildScopePill() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public, size: 16, color: Color(0xFF5F6368)),
          const SizedBox(width: 6),
          const Text(
            'Result for ',
            style: TextStyle(color: Color(0xFF5F6368), fontSize: 13, fontFamily: 'Poppins'),
          ),
          Flexible(
            child: Text(
              _scopeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF202124), fontSize: 13, fontFamily: 'Poppins'),
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (btnContext) {
              return InkWell(
                onTap: () => _showScopeMenuAt(btnContext),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFECB3), width: 0.8),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Poppins'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
                    Image.asset('assets/images/phonebooklogo.png', width: 140, height: 60, fit: BoxFit.contain),
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
                    const SizedBox(height: 16),
                    _buildScopePill(),
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
                    _buildScopePill(),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD7B41A)))
                          : _hasSearched && _results.isEmpty && _search.text.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 60),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off, size: 52, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No contacts found', 
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF202124), fontFamily: 'Poppins')),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Try searching for another name, title, or phone number',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontFamily: 'Poppins')),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 6, bottom: 20),
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
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
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
                              hintStyle: TextStyle(color: Color(0xFF5F6368), fontFamily: 'Poppins'),
                            ),
                            style: const TextStyle(fontSize: 16, fontFamily: 'Poppins', color: Color(0xFF202124)),
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
