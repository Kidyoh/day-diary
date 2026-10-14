import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/diary_store.dart';
import 'ui/diary_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // The reference has no status bar — keep only the system navigation bar.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final store = DiaryStore();
  await store.load();
  runApp(DayDiaryApp(store: store));
}

class DayDiaryApp extends StatelessWidget {
  const DayDiaryApp({super.key, required this.store});

  final DiaryStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Day Diary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: DD.font,
        scaffoldBackgroundColor: DD.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: DD.ink, surface: DD.bg, primary: DD.ink, onPrimary: Colors.white),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: DD.ink,
          selectionColor: Color(0x33000000),
          selectionHandleColor: DD.ink,
        ),
      ),
      home: DiaryScreen(store: store),
    );
  }
}
