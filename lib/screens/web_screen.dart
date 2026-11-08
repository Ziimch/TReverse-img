import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app browser. System back walks WebView history first, then closes.
class WebScreen extends StatefulWidget {
  final String url;
  final String title;
  const WebScreen({super.key, required this.url, required this.title});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _wv;
  int _progress = 0;
  String? _pageTitle;

  @override
  void initState() {
    super.initState();
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) async {
          final t = await _wv.getTitle();
          if (mounted && t != null && t.isNotEmpty) setState(() => _pageTitle = t);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _wv.canGoBack()) {
          await _wv.goBack();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle ?? widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _wv.reload,
            ),
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_browser_rounded),
              onPressed: () => launchUrl(Uri.parse(widget.url),
                  mode: LaunchMode.externalApplication),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        body: WebViewWidget(controller: _wv),
      ),
    );
  }
}
