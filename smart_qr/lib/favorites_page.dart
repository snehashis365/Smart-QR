import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_qr/history_service.dart';
import 'package:smart_qr/result_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<HistoryItem> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await HistoryService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favorites;
      });
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
        title: const Text('Favorites'),
      ),
      body: _favorites.isEmpty
          ? const Center(child: Text('No favorites yet.'))
          : ListView.builder(
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index];
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
                icon: const Icon(Icons.favorite, color: Colors.redAccent),
                onPressed: () {
                  // FIX: Update the in-memory list for instant UI feedback
                  HistoryService.toggleFavorite(item.id);
                  setState(() {
                    _favorites.removeAt(index);
                  });
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(scannedCode: item.code, historyId: item.id),
                  ),
                ).then((_) => _loadFavorites()); // Refresh when returning from details
              },
            ),
          );
        },
      ),
    );
  }
}