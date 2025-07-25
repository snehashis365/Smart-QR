import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// The data model now includes a unique ID and a favorite flag
class HistoryItem {
  final String id; // Use timestamp as a unique ID
  final String code;
  final DateTime timestamp;
  bool isFavorite;

  HistoryItem({
    required this.id,
    required this.code,
    required this.timestamp,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
  };

  // --- THIS IS THE CRITICAL FIX FOR YOUR OLD HISTORY ---
  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    // If 'id' is missing (old data), create one from the timestamp.
    id: json['id'] ?? json['timestamp'],
    code: json['code'],
    timestamp: DateTime.parse(json['timestamp']),
    // If 'isFavorite' is missing (old data), default to false.
    isFavorite: json['isFavorite'] ?? false,
  );
}

// The service now manages both history and favorites
class HistoryService {
  static const _historyKey = 'scan_history';

  // GETTERS
  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson = prefs.getStringList(_historyKey) ?? [];
    List<HistoryItem> items = [];
    for (var itemString in historyJson) {
      try {
        items.add(HistoryItem.fromJson(jsonDecode(itemString)));
      } catch (e) {
        // Ignore items that fail to parse (old format without timestamp, etc.)
        print("Could not parse history item: $itemString");
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Ensure latest is first
    return items;
  }

  static Future<List<HistoryItem>> getFavorites() async {
    final allItems = await getHistory();
    return allItems.where((item) => item.isFavorite).toList();
  }

  // ACTIONS
  static Future<HistoryItem> addToHistory(String code) async {
    final allItems = await getHistory();
    // If an item with the same code exists, update its timestamp and bring to top
    allItems.removeWhere((item) => item.code == code);

    final newItem = HistoryItem(
      id: DateTime.now().toIso8601String(),
      code: code,
      timestamp: DateTime.now(),
    );
    allItems.insert(0, newItem); // Add to the top of the list
    await _saveItems(allItems);
    return newItem;
  }

  static Future<void> deleteItem(String id) async {
    final allItems = await getHistory();
    allItems.removeWhere((item) => item.id == id);
    await _saveItems(allItems);
  }

  static Future<void> toggleFavorite(String id) async {
    final allItems = await getHistory();
    final itemIndex = allItems.indexWhere((item) => item.id == id);
    if (itemIndex != -1) {
      allItems[itemIndex].isFavorite = !allItems[itemIndex].isFavorite;
      await _saveItems(allItems);
    }
  }

  static Future<bool> isFavorite(String id) async {
    final allItems = await getHistory();
    return allItems.any((item) => item.id == id && item.isFavorite);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // PRIVATE SAVER
  static Future<void> _saveItems(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson =
    items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_historyKey, historyJson);
  }
}