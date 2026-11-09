import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _serp;
  TextEditingController? _imgbb;
  bool _show = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context).settings;
    _serp ??= TextEditingController(text: s.serpKey);
    _imgbb ??= TextEditingController(text: s.imgbbKey);
  }

  @override
  void dispose() {
    _serp?.dispose();
    _imgbb?.dispose();
    super.dispose();
  }

  Future<void> _save(SettingsController s) async {
    FocusScope.of(context).unfocus();
    await s.saveKeys(_serp!.text, _imgbb!.text);
    if (mounted) snack(context, 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.settings;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings'), centerTitle: false),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('API keys (optional)', style: tt.titleMedium),
            const SizedBox(height: 4),
            Text('Not required. Without keys the app opens Google Lens, Yandex, TinEye and Bing with your image. '
                'A SerpApi key adds result lists inside the app. Keys are stored only on this device.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            _keyField(_serp!, 'SerpApi key (optional)'),
            const SizedBox(height: 12),
            _keyField(_imgbb!, 'ImgBB key (optional)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                      onPressed: () => _save(s), child: const Text('Save keys')),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _show ? 'Hide keys' : 'Show keys',
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                    onPressed: () => openExternal(context, 'https://serpapi.com/manage-api-key'),
                    child: const Text('Get SerpApi key')),
                TextButton(
                    onPressed: () => openExternal(context, 'https://api.imgbb.com/'),
                    child: const Text('Get ImgBB key')),
              ],
            ),
            const Divider(height: 32),
            Text('Appearance', style: tt.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
            const Divider(height: 32),
            Text('Privacy', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text(
              'To search, your image is uploaded as a temporary public link — to Litterbox '
              '(deleted after 1 hour) or, if you added a key, ImgBB (deleted after 10 minutes) — '
              'and opened in the search engine you choose. History is kept only on this device.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Lens Finder'),
              subtitle: const Text('Reverse image search • Google Lens via SerpApi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyField(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: !_show,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
