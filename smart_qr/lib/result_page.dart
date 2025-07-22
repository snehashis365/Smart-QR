import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:smart_qr/history_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';

// ... (enum and StatefulWidget declaration remain the same)
enum QRCodeType { url, wifi, contact, email, phone, sms, text, geo, calendar }

class ResultPage extends StatefulWidget {
  final String scannedCode;
  final String? historyId; // Pass the ID to manage favorites/deletions

  const ResultPage({super.key, required this.scannedCode, this.historyId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}


class _ResultPageState extends State<ResultPage> {
  // ... (state variables remain the same)
  QRCodeType? _type;
  IconData? _icon;
  String? _title;
  Widget? _content;
  List<Widget>? _actions;
  bool _isInitialized = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  // New method to check if the item is a favorite
  Future<void> _checkFavoriteStatus() async {
    if (widget.historyId != null) {
      final isFav = await HistoryService.isFavorite(widget.historyId!);
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _parseScannedCode();
      _isInitialized = true;
    }
  }

  void _parseScannedCode() {
    // ... (the main parsing logic remains the same)
    String code = widget.scannedCode;

    // Determine the type and build the corresponding UI
    if (code.startsWith('BEGIN:VCARD')) {
      _buildVCardUI(code);
    } else if (code.startsWith('BEGIN:VCALENDAR')) {
      _buildCalendarUI(code);
    } else if (code.startsWith('WIFI:')) {
      _buildWifiUI(code);
    } else if (code.startsWith('http://') || code.startsWith('https://')) {
      _buildUrlUI(code);
    } else if (code.startsWith('mailto:')) {
      _buildEmailUI(code);
    } else if (code.startsWith('tel:')) {
      _buildPhoneUI(code);
    } else if (code.startsWith('smsto:')) {
      _buildSmsUI(code);
    } else if (code.startsWith('geo:')) {
      _buildGeoUI(code);
    } else {
      _buildTextUI(code);
    }
  }

  // --- UPDATED VCard Parser using flutter_contacts ---
  void _buildVCardUI(String code) {
    // The package can parse the VCard string directly
    final contact = Contact.fromVCard(code);

    // Extract the first available details for display
    final name = contact.displayName;
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
    final address = contact.addresses.isNotEmpty ? contact.addresses.first.address : '';

    _type = QRCodeType.contact;
    _icon = Icons.person;
    _title = 'Contact';
    _content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty) SelectableText(name, style: Theme.of(context).textTheme.titleLarge),
        if (address.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(address)],
        if (phone.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(phone)],
        if (email.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(email)],
      ],
    );
    _actions = [
      FilledButton.tonal(
          onPressed: () async {
            // --- THIS IS THE NEW LOGIC ---
            // Show a confirmation dialog before saving
            final bool? shouldSave = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Save Contact?'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      if (name.isNotEmpty) Text(name, style: Theme.of(context).textTheme.titleMedium),
                      if (phone.isNotEmpty) Text(phone),
                      if (email.isNotEmpty) Text(email),
                      if (address.isNotEmpty) Text(address),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('Save'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            );

            // If the user tapped "Save"
            if (shouldSave == true) {
              if (await FlutterContacts.requestPermission()) {
                await contact.insert();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact saved!')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission denied.')),
                  );
                }
              }
            }
          },
        child: const Text('Add Contact'),
      ),
      if (phone.isNotEmpty) OutlinedButton(onPressed: () => _safeLaunchUrl('tel:$phone'), child: const Text('Call')),
      if (email.isNotEmpty) OutlinedButton(onPressed: () => _safeLaunchUrl('mailto:$email'), child: const Text('Send Email')),
      if (address.isNotEmpty) OutlinedButton(onPressed: () => _safeLaunchUrl('https://maps.google.com/?q=${Uri.encodeComponent(address)}'), child: const Text('Show Map')),
    ];
  }

  // (The rest of your code remains the same)
  // ... Paste all your other _build...UI, _safeLaunchUrl, and the main build method here ...

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until parsing is complete
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        // --- MAKE THE ACTION BUTTONS FUNCTIONAL ---
        actions: [
          IconButton(
              onPressed: () async {
                if (widget.historyId != null) {
                  await HistoryService.deleteItem(widget.historyId!);
                  if (mounted) Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline)
          ),
          IconButton(
              onPressed: () => SharePlus.instance.share(ShareParams(text: widget.scannedCode)),
              icon: const Icon(Icons.share_outlined)
          ),
          IconButton(
              onPressed: () async {
                if (widget.historyId != null) {
                  await HistoryService.toggleFavorite(widget.historyId!);
                  _checkFavoriteStatus(); // Update the icon
                }
              },
              // Change icon based on favorite status
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.redAccent : null,)
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(_icon)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title!, style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      'QR Code',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyLarge!,
              child: _content!,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _actions!,
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER AND UI BUILDER METHODS ---

  // Helper to safely launch URLs
  Future<void> _safeLaunchUrl(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  // UI Builder for Calendar
  void _buildCalendarUI(String code) {
    final summary = _getSubstring(code, 'SUMMARY:', '\n');
    final dtstart = _getSubstring(code, 'DTSTART:', '\n');
    final dtend = _getSubstring(code, 'DTEND:', '\n');
    final location = _getSubstring(code, 'LOCATION:', '\n');

    _type = QRCodeType.calendar;
    _icon = Icons.calendar_today;
    _title = 'Calendar Event';
    _content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) SelectableText(summary, style: Theme.of(context).textTheme.titleLarge),
        if (location.isNotEmpty) ...[const SizedBox(height: 8), SelectableText("Location: $location")],
        if (dtstart.isNotEmpty) ...[const SizedBox(height: 8), SelectableText("Starts: $dtstart")],
        if (dtend.isNotEmpty) ...[const SizedBox(height: 8), SelectableText("Ends: $dtend")],
      ],
    );
    _actions = [
      FilledButton.tonal(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding to calendar requires a specialized package.')),
          );
        },
        child: const Text('Add to Calendar'),
      ),
    ];
  }

  // UI Builder for URL
  void _buildUrlUI(String code) {
    _type = QRCodeType.url;
    _icon = Icons.link;
    _title = 'URL';
    _content = SelectableText(code);
    _actions = [
      FilledButton.tonal(
        onPressed: () => _safeLaunchUrl(code),
        child: const Text('Open Link'),
      ),
    ];
  }

  // UI Builder for Wifi
  void _buildWifiUI(String code) {
    _type = QRCodeType.wifi;
    _icon = Icons.wifi;
    _title = 'Wi-Fi';
    final ssid = _getSubstring(code, 'S:', ';');
    final pass = _getSubstring(code, 'P:', ';');
    final type = _getSubstring(code, 'T:', ';');

    _content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Network Name:', style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(ssid),
        const SizedBox(height: 8),
        const Text('Password:', style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(pass),
        const SizedBox(height: 8),
        const Text('Network Type:', style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(type),
      ],
    );
    _actions = [
      FilledButton.tonal(
          onPressed: () { /* Connecting requires a platform-specific package */ },
          child: const Text('Connect')),
      OutlinedButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: pass)),
          child: const Text('Copy Password')),
    ];
  }

  // UI Builder for Email
  void _buildEmailUI(String code) {
    _type = QRCodeType.email;
    _icon = Icons.email_outlined;
    _title = 'Email';
    _content = SelectableText(code.replaceFirst('mailto:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send Email'))];
  }

  // UI Builder for Phone
  void _buildPhoneUI(String code) {
    _type = QRCodeType.phone;
    _icon = Icons.phone_outlined;
    _title = 'Phone';
    _content = SelectableText(code.replaceFirst('tel:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Call'))];
  }

  // UI Builder for SMS
  void _buildSmsUI(String code) {
    _type = QRCodeType.sms;
    _icon = Icons.sms_outlined;
    _title = 'SMS';
    _content = SelectableText(code.replaceFirst('smsto:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send SMS'))];
  }

  // UI Builder for Geolocation
  void _buildGeoUI(String code) {
    _type = QRCodeType.geo;
    _icon = Icons.location_on_outlined;
    _title = 'Location';
    final coords = code.replaceFirst('geo:', '');
    _content = SelectableText('Coordinates: $coords');
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl('https://maps.google.com/?q=$coords'), child: const Text('Show on Map'))];
  }

  // UI Builder for Plain Text
  void _buildTextUI(String code) {
    _type = QRCodeType.text;
    _icon = Icons.text_fields;
    _title = 'Text';
    _content = SelectableText(code);
    _actions = [
      FilledButton.tonal(
        onPressed: () => _safeLaunchUrl('https://www.google.com/search?q=${Uri.encodeComponent(code)}'),
        child: const Text('Web Search'),
      ),
    ];
  }

  // Helper function to extract data from formatted strings
  String _getSubstring(String source, String start, String end) {
    final startIndex = source.indexOf(start);
    if (startIndex == -1) return '';
    final endIndex = source.indexOf(end, startIndex + start.length);
    if (endIndex == -1) return source.substring(startIndex + start.length).trim();
    return source.substring(startIndex + start.length, endIndex).trim();
  }
}