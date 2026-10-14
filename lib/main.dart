import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/diary_store.dart';

import 'package:image_picker/image_picker.dart';

import 'ui/diary_screen.dart';
import 'ui/onboarding.dart';
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
      home: _Root(store: store),
    );
  }
}

/// Flash screen, then onboarding on first launch, then the diary.
class _Root extends StatefulWidget {
  const _Root({required this.store});
  final DiaryStore store;

  @override
  State<_Root> createState() => _RootState();
}

enum _Phase { splash, onboarding, diary }

class _RootState extends State<_Root> {
  _Phase _phase = _Phase.splash;
  ImageSource? _startWith;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _phase = widget.store.onboarded ? _Phase.diary : _Phase.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_phase) {
      _Phase.splash => const SplashScreen(),
      _Phase.onboarding => OnboardingScreen(
        store: widget.store,
        onDone: (first) => setState(() {
          _startWith = switch (first) {
            FirstStep.camera => ImageSource.camera,
            FirstStep.gallery => ImageSource.gallery,
            FirstStep.later => null,
          };
          _phase = _Phase.diary;
        }),
      ),
      _Phase.diary => DiaryScreen(store: widget.store, startWith: _startWith),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(_phase), child: child),
    );
  }
}
