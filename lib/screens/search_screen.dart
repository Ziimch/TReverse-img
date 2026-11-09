import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'crop_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const SearchScreen({super.key, required this.onOpenSettings});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  LensController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c == null) {
      _c = AppScope.of(context).lens..addListener(_syncQuery);
      _q.text = _c!.query;
    }
  }

  // Keeps the text box in sync when a history entry is opened or reset.
  void _syncQuery() {
    final c = _c!;
    if (!_focus.hasFocus && _q.text != c.query) _q.text = c.query;
  }

  Future<void> _crop(BuildContext context, LensController c) async {
    final file = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => CropScreen(image: c.image!)),
    );
    if (file != null) await c.useCropped(file);
  }

  @override
  void dispose() {
    _c?.removeListener(_syncQuery);
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.lens;
    return ListenableBuilder(
      listenable: Listenable.merge([c, scope.settings]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Lens Finder'),
          centerTitle: false,
          actions: [
            if (c.image != null)
              IconButton(
                tooltip: 'New search',
                icon: const Icon(Icons.close_rounded),
                onPressed: c.busy ? null : c.reset,
              ),
          ],
        ),
        body: SafeArea(
          child: c.image == null
              ? _empty(context, c, scope.settings)
              : _results(context, c),
        ),
        bottomNavigationBar: c.image == null ? null : _actionBar(c),
      ),
    );
  }

  // ── Empty state / onboarding ──
  Widget _empty(BuildContext context, LensController c, SettingsController s) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration:
                  BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.image_search_rounded,
                  size: 56, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text('Search with an image', style: tt.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Find where a photo comes from, similar products, or what it shows.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            if (!s.hasSerp) ...[
              Card(
                color: cs.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('No API key needed',
                          style: tt.titleSmall
                              ?.copyWith(color: cs.onTertiaryContainer)),
                      const SizedBox(height: 4),
                      Text(
                          'Pick a photo, then open it in Google Lens, Yandex, TinEye or Bing. '
                          'Optionally add a SerpApi key for in-app result lists.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onTertiaryContainer)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: widget.onOpenSettings,
                        child: const Text('Add optional keys'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => c.pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => c.pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take a photo'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview + refine + results ──
  Widget _results(BuildContext context, LensController c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final res = c.current;
    final hasSerp = AppScope.of(context).settings.hasSerp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: SizedBox.expand(child: Image.file(c.image!, fit: BoxFit.cover)),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                onPressed: c.busy ? null : () => _crop(context, c),
                icon: const Icon(Icons.crop_rounded, size: 18),
                label: const Text('Crop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _freePanel(context, c),
        if (hasSerp) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: c.busy ? null : c.refine,
          decoration: InputDecoration(
            hintText: 'Refine with words (optional)',
            prefixIcon: const Icon(Icons.edit_outlined),
            suffixIcon: IconButton(
              tooltip: 'Search again',
              icon: const Icon(Icons.search_rounded),
              onPressed: c.busy ? null : () => c.refine(_q.text),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<SearchType>(
          showSelectedIcon: false,
          segments: [
            for (final t in SearchType.values)
              ButtonSegment(value: t, label: Text(t.label)),
          ],
          selected: {c.type},
          onSelectionChanged: c.busy ? null : (s) => c.setType(s.first),
        ),
        if (c.type == SearchType.exact && c.query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Text refinement is ignored for exact matches.',
                style: tt.bodySmall),
          ),
        ],
        const SizedBox(height: 16),
        if (c.busy)
          StatusBlock(
              label: c.phase == Phase.uploading
                  ? 'Uploading image…'
                  : 'Searching the web…'),
        if (c.phase == Phase.error) _errorCard(c, cs),
        if (hasSerp && c.phase == Phase.idle && c.current == null)
          FilledButton.icon(
            onPressed: c.search,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search with SerpApi'),
          ),
        if (c.phase == Phase.done && res != null) ...[
          if (res.bestGuess != null) _bestGuess(context, res, cs),
          Row(
            children: [
              Expanded(
                child: Text(
                    '${res.matches.length} ${c.type.label.toLowerCase()} results',
                    style: tt.titleMedium),
              ),
              if (c.imageUrl != null)
                TextButton.icon(
                  onPressed: () => openExternal(context,
                      'https://lens.google.com/uploadbyurl?url=${Uri.encodeComponent(c.imageUrl!)}'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Google Lens'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (res.matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nothing found. Try cropping tighter on the object, adding a word, '
                'or switching tabs.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final m in res.matches) MatchTile(match: m),
        ],
      ],
    );
  }

  Widget _freePanel(BuildContext context, LensController c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search on the web', style: tt.titleSmall),
            const SizedBox(height: 2),
            Text('Free, no API key. Opens the engine with your image.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in webEngines)
                  FilledButton.tonalIcon(
                    onPressed: c.busy
                        ? null
                        : () async {
                            final url = await c.ensurePublicUrl();
                            if (url != null && context.mounted) {
                              openInApp(context, e.urlFor(url), e.name);
                            }
                          },
                    icon: Icon(e.icon, size: 18),
                    label: Text(e.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bestGuess(BuildContext context, LensResult res, ColorScheme cs) {
    return Card(
      color: cs.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(res.bestGuess!,
            style: TextStyle(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
        subtitle: Text(
          ['Best guess', if (res.bestGuessSub != null) res.bestGuessSub!].join(' • '),
          style: TextStyle(color: cs.onPrimaryContainer),
        ),
        trailing: res.bestGuessLink == null
            ? null
            : Icon(Icons.chevron_right_rounded, color: cs.onPrimaryContainer),
        onTap: res.bestGuessLink == null
            ? null
            : () => openInApp(context, res.bestGuessLink!, res.bestGuess!),
      ),
    );
  }

  Widget _errorCard(LensController c, ColorScheme cs) {
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.error ?? 'Something went wrong',
                  style: TextStyle(color: cs.onErrorContainer)),
            ),
            TextButton(
              onPressed: c.retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(LensController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: c.busy ? null : () => c.pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: c.busy ? null : () => c.pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
          ),
        ],
      ),
    );
  }
}
