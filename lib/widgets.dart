// Shared widgets + link helpers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'screens/web_screen.dart';

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) snack(context, 'Could not open link');
}

void openInApp(BuildContext context, String url, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => WebScreen(url: url, title: title)),
  );
}

/// Long-press menu for a result.
void showMatchActions(BuildContext context, VisualMatch m) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.web_rounded),
            title: const Text('Open in app'),
            onTap: () {
              Navigator.pop(sheet);
              openInApp(context, m.link, m.source.isEmpty ? m.title : m.source);
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_browser_rounded),
            title: const Text('Open in browser'),
            onTap: () {
              Navigator.pop(sheet);
              openExternal(context, m.link);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy link'),
            onTap: () async {
              Navigator.pop(sheet);
              await Clipboard.setData(ClipboardData(text: m.link));
              if (context.mounted) snack(context, 'Link copied');
            },
          ),
        ],
      ),
    ),
  );
}

class MatchTile extends StatelessWidget {
  final VisualMatch match;
  const MatchTile({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openInApp(
            context, match.link, match.source.isEmpty ? match.title : match.source),
        onLongPress: () => showMatchActions(context, match),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: match.thumbnail == null
                      ? ColoredBox(
                          color: cs.surfaceContainerHigh,
                          child: const Icon(Icons.image_not_supported_outlined))
                      : Image.network(
                          match.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: cs.surfaceContainerHigh,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (match.source.isNotEmpty) match.source,
                        if (match.price != null) match.price!,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => showMatchActions(context, match),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while uploading / searching.
class StatusBlock extends StatelessWidget {
  final String label;
  const StatusBlock({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const LinearProgressIndicator(
              borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// Human-friendly relative time without extra packages.
String timeAgo(int millis) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  final t = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${t.day}/${t.month}/${t.year}';
}
