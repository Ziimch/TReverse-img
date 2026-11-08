// Lens Finder — reverse image search.
//
//   lib/main.dart                  app bootstrap, theme, bottom-nav shell
//   lib/models.dart                data classes + JSON
//   lib/services.dart              ImgBB / SerpApi clients, history storage
//   lib/state.dart                 settings / history / search controllers
//   lib/widgets.dart               shared widgets + link helpers
//   lib/screens/*                  search, history, settings, in-app browser
//
// Flow: pick/take photo -> (optional crop) -> upload to ImgBB (temporary URL)
//       -> SerpApi Google Lens -> Similar / Exact / Products -> saved to history.

import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsController();
  final history = HistoryController();
  await Future.wait([settings.load(), history.load()]);

  runApp(AppScope(
    settings: settings,
    history: history,
    lens: LensController(settings, history),
    child: const LensFinderApp(),
  ));
}

class LensFinderApp extends StatelessWidget {
  const LensFinderApp({super.key});

  static ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6BED),
          brightness: b,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      );

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Lens Finder',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: settings.themeMode,
        home: const HomeShell(),
      ),
    );
  }
}

/// Bottom navigation: Search · History · Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0, // back from another tab returns to Search first
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            SearchScreen(onOpenSettings: () => _go(2)),
            HistoryScreen(onOpened: () => _go(0)),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.image_search_outlined),
              selectedIcon: Icon(Icons.image_search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
