import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// A simple class to represent a history item
class HistoryItem {
  final String code;
  final DateTime timestamp;

  HistoryItem({required this.code, required this.timestamp});

  // Methods to convert our object to and from a format that can be stored
  Map<String, dynamic> toJson() => {
        'code': code,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        code: json['code'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

// A service class to handle all logic for history persistence
class HistoryService {
  static const _historyKey = 'scan_history';

  // Load the list of history items from device storage
  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson = prefs.getStringList(_historyKey) ?? [];
    return historyJson
        .map((item) => HistoryItem.fromJson(jsonDecode(item)))
        .toList();
  }

  // Add a new item to the history
  static Future<void> addToHistory(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final List<HistoryItem> history = await getHistory();

    // Avoid adding duplicate codes
    history.removeWhere((item) => item.code == code);

    final newItem = HistoryItem(code: code, timestamp: DateTime.now());
    history.insert(0, newItem); // Add to the top of the list

    final List<String> historyJson =
        history.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_historyKey, historyJson);
  }

  // Clear the entire history
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}