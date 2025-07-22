import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_qr/theme_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Theme', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (value) => themeProvider.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (value) => themeProvider.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (value) => themeProvider.setThemeMode(value!),
          ),
          const Divider(),
          DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final isDynamicColorSupported = lightDynamic != null && darkDynamic != null;

              return SwitchListTile(
                title: const Text('Use Material You colors'),
                subtitle: Text(isDynamicColorSupported ? 'Syncs with your device\'s wallpaper' : 'Not supported on this device'),
                value: isDynamicColorSupported && themeProvider.useDynamicColor,
                onChanged: isDynamicColorSupported ? (value) => themeProvider.setUseDynamicColor(value) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}