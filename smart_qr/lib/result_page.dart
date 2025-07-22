import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_qr/history_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:async';
import 'dart:math';

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

      final List<String> foundNames = [];
      final List<String> foundPhones = [];

      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          final String entityText = annotation.text;
          final EntityType entityType = entity.type;

          final String actionKey = '${entityType}_$entityText';
          if (addedActions.contains(actionKey)) continue;

          Widget? newAction;

          switch (entityType) {
            case EntityType.address:
              newAction = SmartAnimatedButton(
                icon: Icons.map_outlined,
                label: entityText,
                onPressed: () => _safeLaunchUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(entityText)}'),
              );
              break;

            case EntityType.phone:
              final String? launchableNumber = _getLaunchablePhoneNumber(entity, entityText);
              if (launchableNumber != null) {
                foundPhones.add(launchableNumber.replaceFirst('tel:', ''));

                _smartActions.add(SmartAnimatedButton(
                  icon: Icons.call_outlined,
                  label: "Call $entityText",
                  onPressed: () => _safeLaunchUrl(launchableNumber),
                ));
                _smartActions.add(SmartAnimatedButton(
                  icon: Icons.sms_outlined,
                  label: "Text $entityText",
                  onPressed: () => _safeLaunchUrl(launchableNumber.replaceFirst('tel:', 'sms:')),
                ));

                addedActions.add('${EntityType.phone}_$entityText');
                addedActions.add('sms_$entityText');
              }
              break;

            case EntityType.email:
              final String? launchableEmail = _getLaunchableEmail(entity, entityText);
              if (launchableEmail != null) {
                newAction = SmartAnimatedButton(
                  icon: Icons.email_outlined,
                  label: "Email $entityText",
                  onPressed: () => _safeLaunchUrl(launchableEmail),
                );
              }
              break;

            case EntityType.url:
              final String? urlToSearch = _getLaunchableUrl(entity, entityText);
              if (urlToSearch != null) {
                newAction = SmartAnimatedButton(
                  icon: Icons.search,
                  label: "Verify '$entityText'",
                  onPressed: () => _safeLaunchUrl('https://www.google.com/search?q=${Uri.encodeComponent(entityText)}'),
                );
              }
              break;
            default:
              if (entityType.toString() == 'EntityType.PERSON') {
                foundNames.add(entityText);
              }
              break;
          }

          if (newAction != null) {
            _smartActions.add(newAction);
            addedActions.add(actionKey);
          }
        }
      }

      if (foundNames.isNotEmpty && foundPhones.isNotEmpty) {
        _smartActions.add(SmartAnimatedButton(
          icon: Icons.person_add_alt_1,
          label: "Add as Contact",
          onPressed: () => _createContactFromAI(names: foundNames, phones: foundPhones),
        ));
      }

    } catch (e) {
      debugPrint("ML Kit Error: $e");
    } finally {
      if (mounted) setState(() => _isMlKitRunning = false);
    }
  }

  Future<void> _createContactFromAI({required List<String> names, required List<String> phones}) async {
    final contact = Contact();
    contact.name.first = names.first;
    contact.phones = phones.map((p) => Phone(p)).toList();

    if (await FlutterContacts.requestPermission()) {
      await contact.insert();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact saved!')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied.')));
    }
  }

  String? _getLaunchablePhoneNumber(Entity entity, String text) {
    if (entity.rawValue != null && entity.rawValue!.startsWith('tel:')) return entity.rawValue;
    final cleanedText = text.replaceAll(RegExp(r'[\s()-]'), '');
    if (cleanedText.length >= 7 && int.tryParse(cleanedText) != null) return 'tel:$cleanedText';
    return null;
  }

  String? _getLaunchableEmail(Entity entity, String text) {
    if (entity.rawValue != null && entity.rawValue!.startsWith('mailto:')) return entity.rawValue;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (emailRegex.hasMatch(text)) return 'mailto:$text';
    return null;
  }

  String? _getLaunchableUrl(Entity entity, String text) {
    String? potentialUrl = entity.rawValue ?? text;
    if (!potentialUrl.startsWith('http://') && !potentialUrl.startsWith('https://')) {
      potentialUrl = 'https://$potentialUrl';
    }
    if (Uri.tryParse(potentialUrl)?.hasAuthority ?? false) return potentialUrl;
    return null;
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

    String smsData = code.replaceFirst('smsto:', '');
    String number;
    String? message;

    if (smsData.contains(':')) {
      var parts = smsData.split(':');
      number = parts.first;
      message = parts.sublist(1).join(':');
    } else {
      number = smsData;
    }

    _content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(number, style: Theme.of(context).textTheme.titleLarge),
        if (message != null && message.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text("Message:", style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(message),
        ]
      ],
    );

    String url;
    if (message != null && message.isNotEmpty) {
      url = 'sms:$number?body=${Uri.encodeComponent(message)}';
    } else {
      url = 'sms:$number';
    }

    _initialActions.add(FilledButton.tonal(onPressed: () => _safeLaunchUrl(url), child: const Text('Send SMS')));
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

class SmartAnimatedButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const SmartAnimatedButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<SmartAnimatedButton> createState() => _SmartAnimatedButtonState();
}

class _SmartAnimatedButtonState extends State<SmartAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return CustomPaint(
          painter: _SmartBorderPainter(progress: _anim.value),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
                foregroundColor:
                theme.colorScheme.onSurfaceVariant,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: Icon(widget.icon),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label),
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome, size: 16),
                ],
              ),
              onPressed: widget.onPressed,
            ),
          ),
        );
      },
    );
  }
}

class _SmartBorderPainter extends CustomPainter {
  final double progress;

  _SmartBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const borderWidth = 3.0;
    final rect = Offset.zero & size;
    final path = RRect.fromRectAndRadius(rect, Radius.circular(100))
        .deflate(borderWidth / 2);

    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFFA63D),
          Color(0xFFFF3D77),
          Color(0xFF338AFF),
          Color(0xFF3CF0C5),
          Color(0xFFFFA63D),
        ],
        stops: const [0.0, 0.33, 0.66, 0.9, 1.0],
        transform: GradientRotation(2 * pi * progress),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmartBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}