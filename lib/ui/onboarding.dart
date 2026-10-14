import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/diary_store.dart';
import 'sheets.dart' show PillButton;
import 'theme.dart';
import 'widgets/chrome.dart';
import 'widgets/dot_matrix.dart';
import 'widgets/scramble_text.dart';

double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Flash screen: the dot-matrix wordmark decodes in over the dot grid with
/// today's date and a live clock.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / DD.designWidth;
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: DD.bg,
      body: Stack(
        children: [
          Positioned.fill(child: DotGrid(scale: s)),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MorphRow(scale: s, t: t),
                    SizedBox(height: 34 * s),
                    DotMatrixText('DAY', pitch: 9 * s, reveal: _iv(t, 0.1, 0.55)),
                    SizedBox(height: 10 * s),
                    DotMatrixText('DIARY', pitch: 9 * s, reveal: _iv(t, 0.2, 0.7)),
                    SizedBox(height: 28 * s),
                    ScrambleText(
                      '${longDate(now)} · ${hms(now)}',
                      progress: _iv(t, 0.45, 0.95),
                      style: DD.mono(9.5 * s, weight: FontWeight.w400, spacing: 0.4),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Three circles; the middle one swells into a rounded square — the app's
/// signature move in miniature.
class _MorphRow extends StatelessWidget {
  const _MorphRow({required this.scale, required this.t});
  final double scale, t;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final m = Curves.easeInOutCubic.transform(_iv(t, 0.35, 0.8));
    Widget dot(double k, double appear) {
      final size = lerpDouble(26 * s, 40 * s, k)!;
      return Opacity(
        opacity: appear,
        child: Container(
          width: size,
          height: size,
          margin: EdgeInsets.symmetric(horizontal: 5 * s),
          decoration: BoxDecoration(
            color: DD.ink,
            borderRadius: BorderRadius.circular(lerpDouble(size / 2, size * 0.24, k)!),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44 * s,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [dot(0, _iv(t, 0, 0.2)), dot(m, _iv(t, 0.05, 0.25)), dot(0, _iv(t, 0.1, 0.3))],
      ),
    );
  }
}

/// What the user chose to do at the end of onboarding.
enum FirstStep { camera, gallery, later }

/// Three steps: welcome → name and photo → log the first moment.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store, required this.onDone});

  final DiaryStore store;
  final ValueChanged<FirstStep> onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  int _step = 0;
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  Uint8List? _avatar;
  bool _saving = false;

  // Drives each step's headline decode.
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _enter.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _enter.forward(from: 0);
    if (step == 1) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _step == 1) _nameFocus.requestFocus();
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _avatar = bytes);
    } catch (e) {
      debugPrint('Avatar pick failed: $e');
    }
  }

  Future<void> _finish(FirstStep first) async {
    setState(() => _saving = true);
    await widget.store.completeOnboarding(name: _name.text, avatarBytes: _avatar);
    widget.onDone(first);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = mq.size.width / DD.designWidth;
    final pad = EdgeInsets.fromLTRB(
      28 * s,
      math.max(mq.padding.top, 20) + 24 * s,
      28 * s,
      math.max(mq.padding.bottom, 16) + 16 * s,
    );

    return Scaffold(
      backgroundColor: DD.bg,
      body: Stack(
        children: [
          Positioned.fill(child: DotGrid(scale: s)),
          Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Progress(step: _step, scale: s, onBack: _step > 0 ? () => _go(_step - 1) : null),
                SizedBox(height: 30 * s),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(key: ValueKey(_step), child: _body(s)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headline(String text, double s) => AnimatedBuilder(
    animation: _enter,
    builder: (context, _) => ScrambleText(
      text,
      progress: Curves.easeOut.transform(_enter.value),
      style: DD.mono(27 * s, height: 1.05, spacing: -0.5 * s),
    ),
  );

  Widget _caption(String text, double s) => Text(
    text,
    style: DD.mono(10.5 * s, weight: FontWeight.w400, color: DD.mute, height: 1.55, spacing: 0.3),
  );

  Widget _body(double s) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headline('ONE PHOTO.\nONE MOMENT.\nEVERY TIME\nSTAMPED.', s),
            SizedBox(height: 16 * s),
            _caption('DAY DIARY KEEPS YOUR DAY AS A COLUMN OF PHOTOS, EACH WITH THE EXACT TIME IT HAPPENED.', s),
            Expanded(
              child: Center(child: _TimelineDemo(scale: s)),
            ),
            PillButton('BEGIN', onTap: () => _go(1)),
          ],
        );
      case 1:
        final ready = _name.text.trim().isNotEmpty;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headline('WHAT SHOULD\nWE CALL YOU?', s),
              SizedBox(height: 34 * s),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6 * s),
                        decoration: const BoxDecoration(color: DD.ink, shape: BoxShape.circle),
                        child: Avatar(size: 104 * s, image: _avatar == null ? null : MemoryImage(_avatar!), dot: false),
                      ),
                      SizedBox(height: 10 * s),
                      Text(
                        _avatar == null ? '+ ADD PHOTO (OPTIONAL)' : 'CHANGE PHOTO',
                        style: DD.mono(9.5 * s, weight: FontWeight.w400, color: DD.mute),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30 * s),
              Text(
                'YOUR NAME',
                style: DD.mono(9 * s, weight: FontWeight.w400, color: DD.mute, spacing: 0.6),
              ),
              TextField(
                controller: _name,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_name.text.trim().isNotEmpty) _go(2);
                },
                style: DD.mono(24 * s),
                cursorColor: DD.ink,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'TYPE HERE',
                  hintStyle: DD.mono(24 * s, color: DD.mute.withValues(alpha: 0.45)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10 * s),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.line)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.ink, width: 1.4)),
                ),
              ),
              SizedBox(height: 10 * s),
              if (ready) _caption('YOU\'LL SEE "${pillGreeting(_name.text)}" AT THE TOP OF YOUR DIARY.', s),
              SizedBox(height: 28 * s),
              PillButton('CONTINUE', onTap: ready ? () => _go(2) : null),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headline('LOG YOUR\nFIRST\nMOMENT.', s),
            SizedBox(height: 16 * s),
            _caption('SNAP WHAT\'S IN FRONT OF YOU OR PICK A PHOTO. THE TIME IS STAMPED AUTOMATICALLY.', s),
            SizedBox(height: 22 * s),
            _HowToAdd(scale: s),
            const Spacer(),
            PillButton('TAKE A PHOTO', busy: _saving, onTap: () => _finish(FirstStep.camera)),
            SizedBox(height: 8 * s),
            PillButton('CHOOSE FROM GALLERY', dark: false, onTap: _saving ? null : () => _finish(FirstStep.gallery)),
            SizedBox(height: 4 * s),
            TextButton(
              onPressed: _saving ? null : () => _finish(FirstStep.later),
              child: Text(
                'LATER',
                style: DD.mono(10.5 * s, weight: FontWeight.w400, color: DD.mute),
              ),
            ),
          ],
        );
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.scale, this.onBack});
  final int step;
  final double scale;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      height: 28 * s,
      child: Row(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: onBack == null ? 0 : 1,
            child: GestureDetector(
              onTap: onBack,
              child: Text('← BACK', style: DD.mono(10 * s, weight: FontWeight.w400)),
            ),
          ),
          const Spacer(),
          for (var i = 0; i < 3; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(left: 6 * s),
              width: (i == step ? 22 : 8) * s,
              height: 8 * s,
              decoration: BoxDecoration(
                color: i <= step ? DD.ink : DD.line,
                borderRadius: BorderRadius.circular(i == step ? 2.5 * s : 4 * s),
              ),
            ),
          SizedBox(width: 10 * s),
          Text('${two(step + 1)} / 03', style: DD.mono(10 * s, weight: FontWeight.w400)),
        ],
      ),
    );
  }
}

/// A looping miniature of the timeline: a column of circles where the focus
/// walks down, each one swelling into a rounded square in turn.
class _TimelineDemo extends StatefulWidget {
  const _TimelineDemo({required this.scale});
  final double scale;

  @override
  State<_TimelineDemo> createState() => _TimelineDemoState();
}

class _TimelineDemoState extends State<_TimelineDemo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))..repeat();

  static const _tones = [Color(0xFF2A2A2D), Color(0xFF8F8D93), Color(0xFF4B4A4F), Color(0xFFBDBBC1)];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    const n = 4;
    final d = 52 * s, big = 76 * s, gap = 62 * s;
    return SizedBox(
      width: 200 * s,
      height: gap * (n - 1) + big,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Focus glides 0 → 3 and back, like scrolling down and up.
          final f = (1 - math.cos(_c.value * math.pi * 2)) / 2 * (n - 1);
          final children = <({double m, Widget w})>[];
          for (var i = 0; i < n; i++) {
            final near = (1 - (i - f).abs() * 1.4).clamp(0.0, 1.0);
            final m = near * near * (3 - 2 * near);
            final size = lerpDouble(d, big, m)!;
            final cx = 100 * s + math.sin(i * 1.3 + 0.4) * 8 * s;
            final cy = big / 2 + i * gap;
            children.add((
              m: m,
              w: Positioned(
                left: cx - size / 2,
                top: cy - size / 2,
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: _tones[i],
                    borderRadius: BorderRadius.circular(lerpDouble(size / 2, size * 0.24, m)!),
                  ),
                ),
              ),
            ));
          }
          children.sort((a, b) => a.m.compareTo(b.m));
          // Clock label for the focused one.
          final hour = 8 + (f.round() * 3);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final c in children) c.w,
              Positioned(
                left: 0,
                top: big / 2 + f * gap - 8 * s,
                child: DotMatrixText(clock(DateTime(2026, 1, 1, hour)), pitch: 2.4 * s),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows where the + lives so adding later is obvious.
class _HowToAdd extends StatelessWidget {
  const _HowToAdd({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18 * s)),
      child: Row(
        children: [
          Container(
            width: 40 * s,
            height: 40 * s,
            decoration: const BoxDecoration(color: DD.ink, shape: BoxShape.circle),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 22 * s),
          ),
          SizedBox(width: 14 * s),
          Expanded(
            child: Text(
              'TAP + (TOP RIGHT) ANYTIME TO ADD A NEW MOMENT. TAP A PHOTO TO OPEN IT, HOLD IT TO EDIT.',
              style: DD.mono(9 * s, weight: FontWeight.w400, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
