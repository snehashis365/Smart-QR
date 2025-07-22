import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:smart_qr/history_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

enum QRCodeType { url, wifi, contact, email, phone, sms, text, geo, calendar }

class ResultPage extends StatefulWidget {
  final String scannedCode;
  final String? historyId; // This parameter is now correctly defined

  const ResultPage({super.key, required this.scannedCode, this.historyId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  HistoryItem? _historyItem;
  bool _isFavorite = false;

  QRCodeType? _type;
  IconData? _icon;
  String? _title;
  Widget? _content;
  List<Widget>? _actions;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadOrSaveHistoryItem();
  }

  Future<void> _loadOrSaveHistoryItem() async {
    HistoryItem item;
    if (widget.historyId == null) {
      // This is a new scan, so we add it to the history
      item = await HistoryService.addToHistory(widget.scannedCode);
    } else {
      // This is an existing item from the history/favorites page
      final history = await HistoryService.getHistory();
      item = history.firstWhere((h) => h.id == widget.historyId, orElse: () => history.first);
    }

    if (mounted) {
      setState(() {
        _historyItem = item;
        _isFavorite = item.isFavorite;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && _historyItem != null) {
      _parseScannedCode();
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      if (_historyItem != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isInitialized) {
            setState(() {
              _parseScannedCode();
              _isInitialized = true;
            });
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              onPressed: () async {
                if (_historyItem != null) {
                  await HistoryService.deleteItem(_historyItem!.id);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline)
          ),
          IconButton(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: widget.scannedCode),
              ),
              icon: const Icon(Icons.share_outlined)
          ),
          IconButton(
              onPressed: () async {
                if (_historyItem != null) {
                  await HistoryService.toggleFavorite(_historyItem!.id);
                  final isFav = await HistoryService.isFavorite(_historyItem!.id);
                  if (mounted) setState(() { _isFavorite = isFav; });
                }
              },
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

  // --- All your helper methods remain the same ---
  void _parseScannedCode() {
    String code = widget.scannedCode;
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

  void _buildVCardUI(String code) {
    final contact = Contact.fromVCard(code);

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
          // --- FIX: Add the confirmation dialog logic ---
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

          if (shouldSave != true) return; // End if user cancels

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
                const SnackBar(content: Text('Permission to access contacts was denied.')),
              );
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

  void _buildEmailUI(String code) {
    _type = QRCodeType.email;
    _icon = Icons.email_outlined;
    _title = 'Email';
    _content = SelectableText(code.replaceFirst('mailto:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send Email'))];
  }

  void _buildPhoneUI(String code) {
    _type = QRCodeType.phone;
    _icon = Icons.phone_outlined;
    _title = 'Phone';
    _content = SelectableText(code.replaceFirst('tel:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Call'))];
  }

  void _buildSmsUI(String code) {
    _type = QRCodeType.sms;
    _icon = Icons.sms_outlined;
    _title = 'SMS';
    _content = SelectableText(code.replaceFirst('smsto:', ''));
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send SMS'))];
  }

  void _buildGeoUI(String code) {
    _type = QRCodeType.geo;
    _icon = Icons.location_on_outlined;
    _title = 'Location';
    final coords = code.replaceFirst('geo:', '');
    _content = SelectableText('Coordinates: $coords');
    _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl('https://maps.google.com/?q=$coords'), child: const Text('Show on Map'))];
  }

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

  String _getSubstring(String source, String start, String end) {
    final startIndex = source.indexOf(start);
    if (startIndex == -1) return '';
    final endIndex = source.indexOf(end, startIndex + start.length);
    if (endIndex == -1) return source.substring(startIndex + start.length).trim();
    return source.substring(startIndex + start.length, endIndex).trim();
  }
}