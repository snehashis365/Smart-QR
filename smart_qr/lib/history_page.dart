import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_qr/history_service.dart';
import 'package:smart_qr/result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _confirmAndClearHistory() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will permanently delete all scanned items.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Clear'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await HistoryService.clearHistory();
      _loadHistory();
    }
  }

  IconData _getIconForCode(String code) {
    if (code.startsWith('http')) return Icons.link;
    if (code.startsWith('WIFI:')) return Icons.wifi;
    if (code.startsWith('BEGIN:VCARD') || code.startsWith('MECARD:')) return Icons.person_outline;
    if (code.startsWith('mailto:')) return Icons.email_outlined;
    if (code.startsWith('tel:')) return Icons.phone_outlined;
    if (code.startsWith('smsto:')) return Icons.sms_outlined;
    return Icons.text_fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _history.isEmpty ? null : _confirmAndClearHistory,
          ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('No history yet.'))
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_getIconForCode(item.code)),
              ),
              title: Text(
                item.code,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                DateFormat.yMd().add_Hms().format(item.timestamp),
              ),
              trailing: IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: item.isFavorite ? Colors.redAccent : null,
                ),
                onPressed: () {
                  // FIX: Update the in-memory list for instant UI feedback
                  HistoryService.toggleFavorite(item.id);
                  setState(() {
                    item.isFavorite = !item.isFavorite;
                  });
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(scannedCode: item.code, historyId: item.id),
                  ),
                ).then((_) => _loadHistory()); // Refresh when returning from details
              },
            ),
          );
        },
      ),
    );
  }
}