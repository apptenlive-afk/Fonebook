import 'dart:async';
import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import '../services/api_client.dart';
import '../models/user_session.dart';
import '../models/contact.dart';
import '../widgets/app_header.dart';
import '../widgets/form_widgets.dart';
import '../services/location_service.dart';
import '../services/payment_service.dart';
import '../widgets/payment_dialog.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PromoteScreen extends StatefulWidget {
  final UserSession session;
  final DirectoryContact contact;
  const PromoteScreen({super.key, required this.session, required this.contact});
  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  final _api = ApiClient();
  bool _isPromoting = false;
  bool _isInternational = false;
  String _searchType = 'broad';
  String _balance = '0.00';
  
  String _selectedCountry = 'All';
  String _selectedState = 'All';
  String _selectedCity = 'All';
  
  String? _countryCode;
  String? _stateCode;
  
  late StreamSubscription<PurchaseDetails> _purchaseSub;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    
    _purchaseSub = PaymentService().purchaseStream.listen((purchase) {
      if (purchase.status == PurchaseStatus.purchased) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful! Updating balance...')));
        // Refresh balance after a short delay to allow backend to process
        Future.delayed(const Duration(seconds: 3), () => _loadStatus());
      } else if (purchase.status == PurchaseStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${purchase.error?.message ?? 'Unknown error'}')));
      }
    });
  }

  @override
  void dispose() {
    _purchaseSub.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      String balPhone = widget.session.phone ?? widget.contact.phone;
      final balRes = await _api.get('check-priority', {'phone': balPhone});
      
      String foundBal = '0.00';
      if (balRes is List && balRes.isNotEmpty) {
        foundBal = balRes[0]['priority_balance']?.toString() ?? '0.00';
      }

      setState(() {
        _balance = foundBal;
      });

      final statusRes = await _api.get('check-priority', {'phone': widget.contact.phone});
      if (statusRes is List && statusRes.isNotEmpty) {
        final data = statusRes[0];
        setState(() {
          _isPromoting = data['priority'] == '0'; 
          _isInternational = data['promote_international'] == 'yes';
          _searchType = data['search_type'] ?? 'broad';
          _selectedCountry = data['promote_country'] ?? 'All';
          _selectedState = data['promote_state'] ?? 'All';
          _selectedCity = data['promote_city'] ?? 'All';
        });
      }
    } catch (e) {
      debugPrint("Load status error: $e");
    }
  }

  Future<void> _updatePriority(bool value) async {
    if (value && (double.tryParse(_balance) ?? 0) < 0.30) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You don't have enough amount to promote your contact")));
      setState(() => _isPromoting = false);
      return;
    }
    setState(() => _isPromoting = value);
    await _api.post('savepriority', {
      'owner': widget.session.phone ?? '', 
      'phone': widget.contact.phone,
      'priority_amount': _balance,
      'priority': value ? '0' : '1',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  Future<void> _updateSearchType(String type) async {
    setState(() => _searchType = type);
    await _api.post('save_search_type1', {
      'phone': widget.contact.phone,
      'type': type,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  Future<void> _savePromote() async {
    await _api.post('savepromote', {
      'phone': widget.contact.phone,
      'international': _isInternational ? 'yes' : 'no',
      'country': _selectedCountry,
      'state': _selectedState,
      'city': _selectedCity,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
    }
  }

  String _formatBalance(String val) {
    double d = double.tryParse(val) ?? 0.0;
    if (d < 1000) return d.toStringAsFixed(2);
    if (d < 1000000) return "${(d / 1000).toStringAsFixed(2)}K";
    return "${(d / 1000000).toStringAsFixed(2)}M";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Promote',
              onBack: () => Navigator.pop(context),
              showMenu: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.contact.name, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                    Text(widget.contact.phone, 
                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Poppins')),
                    const SizedBox(height: 15),
                    
                    _buildSwitchRow('Promote', _isPromoting, _updatePriority, isMain: true),
                    
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text('Balance Amount for Promotion', style: TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Poppins')),
                        const Spacer(),
                        Text('\$ ${_formatBalance(_balance)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                      ],
                    ),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                           showDialog(
                             context: context, 
                             builder: (c) => const PaymentDialog()
                           );
                        },
                        child: const Text('+Add Amount', 
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'Poppins')),
                      ),
                    ),
                    
                    const Divider(height: 40, thickness: 1.5, color: Color(0xFFD7D0B4)),
                    
                    const Text('Keywords', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                    const SizedBox(height: 5),
                    _buildSwitchRow('Broad (Default)', _searchType == 'broad', (v) {
                      if (v) _updateSearchType('broad');
                    }),
                    _buildSwitchRow('Phrase', _searchType == 'phrase', (v) {
                      if (v) _updateSearchType('phrase');
                    }),
                    _buildSwitchRow('Exact', _searchType == 'exact', (v) {
                      if (v) _updateSearchType('exact');
                    }),
                    
                    /*
                    const Divider(height: 40, thickness: 1.5, color: Color(0xFFD7D0B4)),
                    
                    const Text('Promote Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                    const SizedBox(height: 5),
                    _buildSwitchRow('International', _isInternational, (v) {
                      setState(() => _isInternational = v);
                      _savePromote();
                    }),
                    
                    _buildLocationRow('Country', _selectedCountry, () async {
                      final list = await LocationService.getCountries();
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (c) => SearchDialog(
                          title: 'Select Country',
                          items: ['All', ...list.map((e) => e.name)],
                          onSelected: (val) {
                            setState(() {
                              _selectedCountry = val;
                              _selectedState = 'All';
                              _selectedCity = 'All';
                              _countryCode = val == 'All' ? null : list.firstWhere((e) => e.name == val).isoCode;
                            });
                            _savePromote();
                          },
                        ),
                      );
                    }),
                    _buildLocationRow('State', _selectedState, () async {
                      if (_countryCode == null) return;
                      final list = await LocationService.getStates(_countryCode!);
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (c) => SearchDialog(
                          title: 'Select State',
                          items: ['All', ...list.map((e) => e.name)],
                          onSelected: (val) {
                            setState(() {
                              _selectedState = val;
                              _selectedCity = 'All';
                              _stateCode = val == 'All' ? null : list.firstWhere((e) => e.name == val).isoCode;
                            });
                            _savePromote();
                          },
                        ),
                      );
                    }),
                    _buildLocationRow('City', _selectedCity, () async {
                      if (_stateCode == null || _countryCode == null) return;
                      final list = await LocationService.getCities(_countryCode!, _stateCode!);
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (c) => SearchDialog(
                          title: 'Select City',
                          items: ['All', ...list.map((e) => e.name)],
                          onSelected: (val) {
                            setState(() => _selectedCity = val);
                            _savePromote();
                          },
                        ),
                      );
                    }),
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

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged, {bool isMain = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isMain ? 0 : 20, top: 5, bottom: 5),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: isMain ? 17 : 16, color: Colors.black, fontFamily: 'Poppins')),
          const Spacer(),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFD7B41A),
              activeTrackColor: const Color(0xFFD7B41A).withOpacity(0.3),
              inactiveThumbColor: const Color(0xFF808080),
              inactiveTrackColor: const Color(0xFFE6E6E6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Poppins')),
          const Spacer(),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black26, width: 1)),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Poppins'),
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}
