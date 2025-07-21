import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_qr/history_service.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Enum to represent the different types of QR code content
enum QRCodeType { url, wifi, contact, email, phone, sms, text, geo }

class ResultPage extends StatefulWidget {
  final String scannedCode;

  const ResultPage({super.key, required this.scannedCode});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  QRCodeType _type = QRCodeType.text;
  IconData _icon = Icons.text_fields;
  String _title = 'Text';
  Widget _content = const SizedBox.shrink();
  List<Widget> _actions = [];

  @override
  void initState() {
    super.initState();
    _parseScannedCode();
    // Save the scanned code to history
    HistoryService.addToHistory(widget.scannedCode);
  }

  // This is the core "intent handling" logic
  void _parseScannedCode() {
    String code = widget.scannedCode;

    // Highest priority: structured data formats
    if (code.startsWith('BEGIN:VCARD')) {
      _buildContactUI(code, isVCard: true);
    } else if (code.startsWith('MECARD:')) {
      _buildContactUI(code, isVCard: false);
    } else if (code.startsWith('WIFI:')) {
      _buildWifiUI(code);
    }
    // URI schemes
    else if (code.startsWith('http://') || code.startsWith('https://')) {
      _buildUrlUI(code);
    } else if (code.startsWith('mailto:')) {
      _buildEmailUI(code);
    } else if (code.startsWith('tel:')) {
      _buildPhoneUI(code);
    } else if (code.startsWith('smsto:')) {
      _buildSmsUI(code);
    } else if (code.startsWith('geo:')) {
      _buildGeoUI(code);
    }
    // Default to plain text
    else {
      _buildTextUI(code);
    }
  }

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

  // UI Builder for URL
  void _buildUrlUI(String code) {
    setState(() {
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
    });
  }

  // UI Builder for Wifi
  void _buildWifiUI(String code) {
    setState(() {
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
    });
  }

  // UI Builder for Contact Cards (VCard and MeCard)
  void _buildContactUI(String code, {required bool isVCard}) {
     // Basic parsers - can be expanded for more fields
    final name = isVCard ? _getSubstring(code, '\nFN:', '\n') : _getSubstring(code, 'N:', ';');
    final phone = isVCard ? _getSubstring(code, '\nTEL;[^:]*:', '\n') : _getSubstring(code, 'TEL:', ';');
    final email = isVCard ? _getSubstring(code, '\nEMAIL;[^:]*:', '\n') : _getSubstring(code, 'EMAIL:', ';');
    final address = isVCard ? _getSubstring(code, '\nADR;[^:]*:', '\n').replaceAll(';', ' ') : _getSubstring(code, 'ADR:', ';');

    setState(() {
      _type = QRCodeType.contact;
      _icon = Icons.person;
      _title = 'Contact';
       _content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) ...[SelectableText(name, style: Theme.of(context).textTheme.titleLarge)],
          if (address.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(address)],
          if (phone.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(phone)],
          if (email.isNotEmpty) ...[const SizedBox(height: 8), SelectableText(email)],
        ],
      );
      _actions = [
        if (phone.isNotEmpty) FilledButton.tonal(onPressed: () => _safeLaunchUrl('tel:$phone'), child: const Text('Call')),
        if (email.isNotEmpty) FilledButton.tonal(onPressed: () => _safeLaunchUrl('mailto:$email'), child: const Text('Send Email')),
        if (address.isNotEmpty) FilledButton.tonal(onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'), child: const Text('Show Map')),
      ];
    });
  }

  // UI Builder for Email
  void _buildEmailUI(String code) {
    setState(() {
      _type = QRCodeType.email;
      _icon = Icons.email_outlined;
      _title = 'Email';
      _content = SelectableText(code.replaceFirst('mailto:', ''));
      _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send Email'))];
    });
  }

  // UI Builder for Phone
  void _buildPhoneUI(String code) {
    setState(() {
      _type = QRCodeType.phone;
      _icon = Icons.phone_outlined;
      _title = 'Phone';
      _content = SelectableText(code.replaceFirst('tel:', ''));
      _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Call'))];
    });
  }

  // UI Builder for SMS
  void _buildSmsUI(String code) {
    setState(() {
      _type = QRCodeType.sms;
      _icon = Icons.sms_outlined;
      _title = 'SMS';
      _content = SelectableText(code.replaceFirst('smsto:', ''));
      _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send SMS'))];
    });
  }

  // UI Builder for Geolocation
  void _buildGeoUI(String code) {
    setState(() {
      _type = QRCodeType.geo;
      _icon = Icons.location_on_outlined;
      _title = 'Location';
      final coords = code.replaceFirst('geo:', '');
      _content = SelectableText('Coordinates: $coords');
      _actions = [FilledButton.tonal(onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=$coords'), child: const Text('Show on Map'))];
    });
  }

  // UI Builder for Plain Text
  void _buildTextUI(String code) {
    setState(() {
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
    });
  }

  // Helper function to extract data from formatted strings
  String _getSubstring(String source, String start, String end) {
    final startIndex = source.indexOf(start);
    if (startIndex == -1) return '';
    final endIndex = source.indexOf(end, startIndex + start.length);
    if (endIndex == -1) return source.substring(startIndex + start.length);
    return source.substring(startIndex + start.length, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline)),
          IconButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: widget.scannedCode)),
            icon: const Icon(Icons.copy_all_outlined)
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
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
                    Text(_title, style: Theme.of(context).textTheme.headlineSmall),
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
              child: _content,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _actions,
            ),
          ],
        ),
      ),
    );
  }
}