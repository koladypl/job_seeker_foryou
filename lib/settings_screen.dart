import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final ThemeMode initialTheme;
  final int initialRadiusKm;
  final bool initialRemoteOnly;
  final void Function(ThemeMode theme, int radiusKm, bool remoteOnly)? onApply;
  final void Function(ThemeMode theme)? onThemeChanged;

  const SettingsPanel({
    super.key,
    this.initialTheme = ThemeMode.system,
    this.initialRadiusKm = 25,
    this.initialRemoteOnly = false,
    this.onApply,
    this.onThemeChanged, required void Function(ThemeMode mode) onTheme,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late ThemeMode _themeMode;
  late int _radiusKm;
  late bool _remoteOnly;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialTheme;
    _radiusKm = widget.initialRadiusKm;
    _remoteOnly = widget.initialRemoteOnly;
  }

  void _reset() {
    setState(() {
      _themeMode = ThemeMode.system;
      _radiusKm = 25;
      _remoteOnly = false;
    });
    widget.onThemeChanged?.call(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.settings, size: 20),
            const SizedBox(width: 8),
            Text('Ustawienia wyszukiwania', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: _reset, child: const Text('Resetuj')),
          ]),
          const SizedBox(height: 12),
          Text('Motyw aplikacji', style: t.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(children: [
            ChoiceChip(label: const Text('System'), selected: _themeMode == ThemeMode.system, onSelected: (_) => setState(() { _themeMode = ThemeMode.system; widget.onThemeChanged?.call(_themeMode); })),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Jasny'), selected: _themeMode == ThemeMode.light, onSelected: (_) => setState(() { _themeMode = ThemeMode.light; widget.onThemeChanged?.call(_themeMode); })),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Ciemny'), selected: _themeMode == ThemeMode.dark, onSelected: (_) => setState(() { _themeMode = ThemeMode.dark; widget.onThemeChanged?.call(_themeMode); })),
          ]),
          const SizedBox(height: 16),
          Text('Promień wyszukiwania: ${_radiusKm} km', style: t.textTheme.bodyMedium),
          Slider(value: _radiusKm.toDouble(), min: 5, max: 200, divisions: 39, label: '$_radiusKm km', onChanged: (v) => setState(() => _radiusKm = v.round())),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: Text('Tylko oferty zdalne', style: t.textTheme.bodyMedium)), Switch(value: _remoteOnly, onChanged: (v) => setState(() => _remoteOnly = v))]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close), label: const Text('Anuluj'), onPressed: () => Navigator.maybePop(context))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.check), label: const Text('Zastosuj'), onPressed: () { widget.onApply?.call(_themeMode, _radiusKm, _remoteOnly); Navigator.maybePop(context); })),
          ]),
        ]),
      ),
    );
  }
}
