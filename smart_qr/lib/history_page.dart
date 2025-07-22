import 'package:flutter/material.dart';
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

  Future<void> _deleteItem(String id) async {
    await HistoryService.deleteItem(id);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: _history.isEmpty
          ? const Center(
        child: Text(
          'No scan history yet.',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return ListTile(
            leading: Icon(item.isFavorite ? Icons.favorite : Icons.history, color: item.isFavorite ? Colors.redAccent : null),
            title: Text(
              item.code, // <-- CORRECTED PROPERTY
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(item.timestamp.toString().substring(0, 16)),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResultPage(
                    scannedCode: item.code, // <-- CORRECTED PROPERTY
                    historyId: item.id,
                  ),
                ),
              );
              _loadHistory();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteItem(item.id),
            ),
          );
        },
      ),
    );
  }
}