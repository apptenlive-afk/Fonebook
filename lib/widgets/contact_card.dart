import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/contact.dart';
import '../services/api_client.dart';

class ContactCard extends StatelessWidget {
  final DirectoryContact contact;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final bool isFavourite;
  final bool showTime;
  final bool isFirstThree;
  final bool isMyContact;
  const ContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    this.onCall,
    this.isFavourite = false,
    this.showTime = false,
    this.isFirstThree = false,
    this.isMyContact = false,
  });

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return "";
    try {
      final sdf = DateFormat('yyyy-MM-dd HH:mm:ss');
      final date = sdf.parse(timestamp);
      final diff = DateTime.now().difference(date);

      if (diff.inSeconds < 60) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} ${diff.inMinutes == 1 ? 'min ago' : 'mins ago'}";
      if (diff.inHours < 24) return "${diff.inHours} ${diff.inHours == 1 ? 'hr ago' : 'hrs ago'}";
      if (diff.inDays == 1) return "1 day ago";
      if (diff.inDays < 30) return "${diff.inDays} days ago";
      if (diff.inDays < 60) return "1 mon ago";
      if (diff.inDays < 365) return "${diff.inDays ~/ 30} mons ago";
      return "${diff.inDays ~/ 365} yrs ago";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Condition: priority == '0' and balance >= 0.30, and only for first 3 positions
    final isAd = isFirstThree && 
                 contact.priority == '0' && 
                 (double.tryParse(contact.priorityBalance) ?? 0) >= 0.30;
    
    final timeAgo = showTime ? _getTimeAgo(contact.timestamp) : "";
    final subtitle = showTime && timeAgo.isNotEmpty ? "${contact.service} . $timeAgo" : contact.service;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 100, // Balanced height
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // Increased vertical margin for better separation
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isMyContact ? const Color(0xFFFFFDF0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyContact 
              ? const Color(0xFFF6D207).withOpacity(0.4)
              : Colors.grey.withOpacity(0.2), 
            width: 1
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Profile Image (imageView2)
            // Centered vertically as in the native ConstraintLayout (parent top/bottom constraints)
            Positioned(
              left: 21,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: contact.imageUrl.isNotEmpty
                        ? FadeInImage.assetNetwork(
                            placeholder: 'assets/images/user.png',
                            image: contact.imageUrl,
                            fit: BoxFit.cover,
                            imageErrorBuilder: (c, e, s) => Image.asset('assets/images/user.png', fit: BoxFit.cover),
                          )
                        : Image.asset('assets/images/user.png', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

            // Sponsored Label (textView85) - Overlays image
            if (isAd)
              const Positioned(
                top: 3,
                left: 21,
                child: Text(
                  'Sponsored',
                  style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w400),
                ),
              ),

            // Text Content (Right of Image)
            // Starts at top: 25 as per native layout_marginTop="25dp"
            Positioned(
              left: 83,
              top: isMyContact ? 0 : 15, // Center vertically if it is a My Contact
              right: 75,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                children: [
                  // Name (phoneNumberTextView)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          "${contact.name}${isFavourite ? ' ★' : ''}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF232323), fontWeight: FontWeight.w400),
                        ),
                      ),
                      if (contact.verified == 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Image.asset('assets/images/verified.png', width: 16, height: 16),
                        ),
                    ],
                  ),

                  // Content logic for local vs server contacts
                  if (isMyContact) ...[
                    // Row 2: Title (if present)
                    if (contact.service.isNotEmpty)
                      Text(
                        contact.service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF232323)),
                      ),
                    // Row 2/3: Badge (Always shown for local)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6D207).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 8, color: Colors.black.withOpacity(0.6)),
                                const SizedBox(width: 3),
                                Text(
                                  'My Contact',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.black.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Standard Server Contact Layout
                    Row(
                      children: [
                        if (subtitle.isNotEmpty)
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF232323)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Image.asset('assets/images/pin.png', width: 13, height: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            contact.location1 ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF232323), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Call Button (imageView)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: InkWell(
                  onTap: () async {
                    if (!isMyContact) {
                      unawaited(ApiClient().post('savecallcount', {
                        'phone_no': contact.phone,
                        'location': contact.location1 ?? '',
                        'tag': '',
                        'country': contact.location ?? ''
                      }));
                    }
                    onCall?.call();
                    launchUrl(Uri.parse('tel:${contact.phone}'));
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    padding: const EdgeInsets.all(10),
                    child: Image.asset('assets/images/phone.png'),
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
