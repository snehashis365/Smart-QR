import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_qr/history_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:async';

enum QRCodeType { url, wifi, contact, email, phone, sms, text, geo, calendar }

class ResultPage extends StatefulWidget {
  final String scannedCode;
  final String? historyId;

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

  final List<Widget> _initialActions = [];
  final List<Widget> _smartActions = [];
  bool _isMlKitRunning = false;

  late final EntityExtractor _entityExtractor;

  @override
  void initState() {
    super.initState();
    _entityExtractor = EntityExtractor(language: EntityExtractorLanguage.english);
    _loadOrSaveHistoryItem();
  }

  @override
  void dispose() {
    _entityExtractor.close();
    super.dispose();
  }

  Future<void> _loadOrSaveHistoryItem() async {
    HistoryItem item;
    if (widget.historyId == null) {
      item = await HistoryService.addToHistory(widget.scannedCode);
    } else {
      final history = await HistoryService.getHistory();
      item = history.firstWhere((h) => h.id == widget.historyId, orElse: () => history.first);
    }

    if (mounted) {
      setState(() {
        _historyItem = item;
        _isFavorite = item.isFavorite;
        _runParsing();
      });
    }
  }

  void _runParsing() {
    _parseScannedCodeQuickly();
    _runMLKitAnalysis();
  }

  void _parseScannedCodeQuickly() {
    String code = widget.scannedCode;
    _initialActions.clear();

    if (code.startsWith('BEGIN:VCARD')) _buildVCardUI(code);
    else if (code.startsWith('BEGIN:VCALENDAR')) _buildCalendarUI(code);
    else if (code.startsWith('WIFI:')) _buildWifiUI(code);
    else if (code.startsWith('http://') || code.startsWith('https://')) _buildUrlUI(code);
    else if (code.startsWith('mailto:')) _buildEmailUI(code);
    else if (code.startsWith('tel:')) _buildPhoneUI(code);
    else if (code.startsWith('smsto:')) _buildSmsUI(code);
    else if (code.startsWith('geo:')) _buildGeoUI(code);
    else _buildTextUI(code);

    if (mounted) setState(() {});
  }

  Future<void> _runMLKitAnalysis() async {
    if (_isMlKitRunning) return;
    if (mounted) setState(() => _isMlKitRunning = true);

    _smartActions.clear();

    try {
      final annotations = await _entityExtractor.annotateText(widget.scannedCode);
      final Set<String> addedActions = {};

      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          final String entityText = annotation.text;
          final String? entityRawValue = entity.rawValue;
          final EntityType entityType = entity.type;

          final String actionKey = '${entityType}_$entityText';
          if (addedActions.contains(actionKey)) continue;

          Widget? newAction;

          switch (entityType) {
            case EntityType.address:
              newAction = PulsingSmartButton( // Changed to animated button
                icon: Icons.map_outlined,
                label: entityText,
                onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(entityText)}'),
              );
              break;

            case EntityType.phone:
              String? potentialNumber;
              if (entityRawValue != null && entityRawValue.startsWith('tel:')) {
                potentialNumber = entityRawValue;
              } else {
                final cleanedText = entityText.replaceAll(RegExp(r'[\s()-]'), '');
                if (cleanedText.length >= 7 && int.tryParse(cleanedText) != null) {
                  potentialNumber = 'tel:$cleanedText';
                }
              }
              if (potentialNumber != null) {
                newAction = PulsingSmartButton( // Changed to animated button
                  icon: Icons.call_outlined,
                  label: "Call $entityText",
                  onPressed: () => _safeLaunchUrl(potentialNumber!),
                );
              }
              break;

            case EntityType.email:
              String? potentialEmail;
              if (entityRawValue != null && entityRawValue.startsWith('mailto:')) {
                potentialEmail = entityRawValue;
              } else {
                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (emailRegex.hasMatch(entityText)) {
                  potentialEmail = 'mailto:$entityText';
                }
              }
              if (potentialEmail != null) {
                newAction = PulsingSmartButton( // Changed to animated button
                  icon: Icons.email_outlined,
                  label: "Email $entityText",
                  onPressed: () => _safeLaunchUrl(potentialEmail!),
                );
              }
              break;

            case EntityType.url:
            // *** FEATURE IMPLEMENTATION: GOOGLE SEARCH FOR URLS ***
              String? potentialUrl = entityRawValue ?? entityText;
              if (!potentialUrl.startsWith('http://') && !potentialUrl.startsWith('https://')) {
                potentialUrl = 'https://$potentialUrl';
              }

              if (Uri.tryParse(potentialUrl)?.hasAuthority ?? false) {
                newAction = PulsingSmartButton( // Changed to animated button
                  icon: Icons.search, // New icon
                  label: "Verify '$entityText'", // New label
                  onPressed: () => _safeLaunchUrl('https://www.google.com/search?q=${Uri.encodeComponent(entityText)}'),
                );
              }
              break;
            default:
              break;
          }

          if (newAction != null) {
            _smartActions.add(newAction);
            addedActions.add(actionKey);
          }
        }
      }
    } catch (e) {
      debugPrint("ML Kit Error: $e");
    } finally {
      if (mounted) setState(() => _isMlKitRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_title == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final allActions = [..._initialActions, ..._smartActions];
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
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            onPressed: () => SharePlus.instance.share(ShareParams(text: widget.scannedCode)),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: () async {
              if (_historyItem != null) {
                await HistoryService.toggleFavorite(_historyItem!.id);
                final isFav = await HistoryService.isFavorite(_historyItem!.id);
                if (mounted) setState(() => _isFavorite = isFav);
              }
            },
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.redAccent : null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_icon != null) CircleAvatar(child: Icon(_icon)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_title != null) Text(_title!, style: Theme.of(context).textTheme.headlineSmall),
                        Text('QR Code', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (_content != null) DefaultTextStyle(style: Theme.of(context).textTheme.bodyLarge!, child: _content!),
              const SizedBox(height: 24),
              if (allActions.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: allActions,
                ),
              if (_isMlKitRunning)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text("Finding smart actions...", style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
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
    _initialActions.add(FilledButton.tonal(
      onPressed: () async {
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
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
              TextButton(child: const Text('Save'), onPressed: () => Navigator.of(context).pop(true)),
            ],
          ),
        );
        if (shouldSave != true) return;
        if (await FlutterContacts.requestPermission()) {
          await contact.insert();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact saved!')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied.')));
        }
      },
      child: const Text('Add Contact'),
    ));
    if (phone.isNotEmpty) _initialActions.add(OutlinedButton(onPressed: () => _safeLaunchUrl('tel:$phone'), child: const Text('Call')));
    if (email.isNotEmpty) _initialActions.add(OutlinedButton(onPressed: () => _safeLaunchUrl('mailto:$email'), child: const Text('Email')));
    if (address.isNotEmpty) _initialActions.add(OutlinedButton(onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'), child: const Text('Map')));
  }

  void _buildCalendarUI(String code) {
    _type = QRCodeType.calendar;
    _icon = Icons.calendar_today;
    _title = 'Calendar Event';
    _content = SelectableText(code);
    _initialActions.add(FilledButton.tonal(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adding calendar events not supported yet.'))),
      child: const Text('Add to Calendar'),
    ));
  }

  void _buildUrlUI(String code) {
    _type = QRCodeType.url;
    _icon = Icons.link;
    _title = 'URL';
    _content = SelectableText(code);
    _initialActions.add(FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Open Link')));
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
        Text('Network Name:', style: Theme.of(context).textTheme.titleSmall), SelectableText(ssid),
        const SizedBox(height: 8),
        Text('Password:', style: Theme.of(context).textTheme.titleSmall), SelectableText(pass),
        const SizedBox(height: 8),
        Text('Network Type:', style: Theme.of(context).textTheme.titleSmall), SelectableText(type),
      ],
    );
    _initialActions.add(FilledButton.tonal(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: pass));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password copied to clipboard')));
      },
      child: const Text('Copy Password'),
    ));
  }

  void _buildEmailUI(String code) {
    _type = QRCodeType.email;
    _icon = Icons.email_outlined;
    _title = 'Email';
    _content = SelectableText(code.replaceFirst('mailto:', ''));
    _initialActions.add(FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send Email')));
  }

  void _buildPhoneUI(String code) {
    _type = QRCodeType.phone;
    _icon = Icons.phone_outlined;
    _title = 'Phone';
    _content = SelectableText(code.replaceFirst('tel:', ''));
    _initialActions.add(FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Call')));
  }

  void _buildSmsUI(String code) {
    _type = QRCodeType.sms;
    _icon = Icons.sms_outlined;
    _title = 'SMS';
    _content = SelectableText(code.replaceFirst('smsto:', ''));
    _initialActions.add(FilledButton.tonal(onPressed: () => _safeLaunchUrl(code), child: const Text('Send SMS')));
  }

  void _buildGeoUI(String code) {
    _type = QRCodeType.geo;
    _icon = Icons.location_on_outlined;
    _title = 'Location';
    final coords = code.replaceFirst('geo:', '');
    _content = SelectableText('Coordinates: $coords');
    _initialActions.add(FilledButton.tonal(
      onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=$coords'),
      child: const Text('Show on Map'),
    ));
  }

  void _buildTextUI(String code) {
    _type = QRCodeType.text;
    _icon = Icons.text_fields;
    _title = 'Text';
    _content = SelectableText(code);
    _initialActions.add(FilledButton.tonal(
      onPressed: () => _safeLaunchUrl('https://www.google.com/search?q=${Uri.encodeComponent(code)}'),
      child: const Text('Web Search'),
    ));
  }

  String _getSubstring(String source, String start, String end) {
    final startIndex = source.indexOf(start);
    if (startIndex == -1) return '';
    final endIndex = source.indexOf(end, startIndex + start.length);
    if (endIndex == -1) return source.substring(startIndex + start.length).trim();
    return source.substring(startIndex + start.length, endIndex).trim();
  }

  Future<void> _safeLaunchUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not create a valid URL')));
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}

// *** FEATURE IMPLEMENTATION: ANIMATED SMART BUTTON ***
class PulsingSmartButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const PulsingSmartButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<PulsingSmartButton> createState() => _PulsingSmartButtonState();
}

class _PulsingSmartButtonState extends State<PulsingSmartButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: FilledButton.icon(
        icon: Icon(widget.icon),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome, size: 16),
          ],
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}