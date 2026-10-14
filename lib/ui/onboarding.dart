import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Three steps on one shared layout — progress bar, headline, caption,
/// visual, then the same button slots — so nothing jumps between steps.
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

  String get _cleanName => _name.text.trim();

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
    if (_saving) return;
    setState(() => _saving = true);
    await widget.store.completeOnboarding(name: _cleanName, avatarBytes: _avatar);
    widget.onDone(first);
  }

  // ------------------------------------------------------------- content

  ({
    String headline,
    String caption,
    Widget visual,
    String primary,
    VoidCallback? onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
    String? link,
    VoidCallback? onLink,
  })
  _content(double s) {
    switch (_step) {
      case 0:
        return (
          headline: 'ONE PHOTO.\nONE MOMENT.\nEVERY TIME\nSTAMPED.',
          caption: 'YOUR DAY AS A COLUMN OF PHOTOS. EACH ONE KEEPS THE EXACT TIME IT HAPPENED.',
          visual: _TimelineDemo(scale: s),
          primary: 'BEGIN',
          onPrimary: () => _go(1),
          secondary: null,
          onSecondary: null,
          link: null,
          onLink: null,
        );
      case 1:
        return (
          headline: 'WHAT SHOULD\nWE CALL YOU?',
          caption: 'SHOWN AT THE TOP OF YOUR DIARY. ADD A PHOTO IF YOU LIKE.',
          visual: _nameForm(s),
          primary: 'CONTINUE',
          onPrimary: _cleanName.isEmpty ? null : () => _go(2),
          secondary: null,
          onSecondary: null,
          link: null,
          onLink: null,
        );
      default:
        return (
          headline: 'LOG YOUR\nFIRST\nMOMENT.',
          caption: 'SNAP WHAT\'S IN FRONT OF YOU OR PICK A PHOTO. THE TIME IS STAMPED AUTOMATICALLY.',
          visual: _AddHint(scale: s, name: _cleanName, avatar: _avatar == null ? null : MemoryImage(_avatar!)),
          primary: 'TAKE A PHOTO',
          onPrimary: () => _finish(FirstStep.camera),
          secondary: 'CHOOSE FROM GALLERY',
          onSecondary: () => _finish(FirstStep.gallery),
          link: 'LATER',
          onLink: () => _finish(FirstStep.later),
        );
    }
  }

  Widget _nameForm(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(5 * s),
                decoration: const BoxDecoration(color: DD.ink, shape: BoxShape.circle),
                child: Avatar(size: 96 * s, image: _avatar == null ? null : MemoryImage(_avatar!), dot: false),
              ),
              SizedBox(height: 10 * s),
              Text(_avatar == null ? '+ ADD PHOTO' : 'CHANGE PHOTO', style: DD.mono(9.5 * s, weight: FontWeight.w400)),
            ],
          ),
        ),
        SizedBox(height: 26 * s),
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCase()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_cleanName.isNotEmpty) _go(2);
          },
          style: DD.mono(22 * s),
          cursorColor: DD.ink,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'YOUR NAME',
            hintStyle: DD.mono(22 * s, color: DD.mute.withValues(alpha: 0.4)),
            contentPadding: EdgeInsets.symmetric(vertical: 10 * s),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.line)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.ink, width: 1.4)),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = mq.size.width / DD.designWidth;
    final c = _content(s);
    final buttonGap = 8 * s;

    return Scaffold(
      backgroundColor: DD.bg,
      body: Stack(
        children: [
          Positioned.fill(child: DotGrid(scale: s)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              28 * s,
              math.max(mq.padding.top, 20) + 18 * s,
              28 * s,
              math.max(mq.padding.bottom, 12) + 12 * s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Progress(step: _step, scale: s, onBack: _step > 0 ? () => _go(_step - 1) : null),
                SizedBox(height: 34 * s),
                // Headline + caption: same place on every step.
                AnimatedBuilder(
                  animation: _enter,
                  builder: (context, _) => ScrambleText(
                    c.headline,
                    progress: Curves.easeOut.transform(_enter.value),
                    style: DD.mono(27 * s, height: 1.05, spacing: -0.5 * s),
                  ),
                ),
                SizedBox(height: 14 * s),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    c.caption,
                    key: ValueKey(_step),
                    style: DD.mono(10 * s, weight: FontWeight.w400, color: DD.mute, height: 1.55, spacing: 0.3),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: Center(child: SingleChildScrollView(child: c.visual)),
                    ),
                  ),
                ),
                // Button slots: identical positions on every step.
                PillButton(c.primary, onTap: _saving ? null : c.onPrimary, busy: _saving && _step == 2),
                SizedBox(height: buttonGap),
                SizedBox(
                  height: 48,
                  child: c.secondary == null
                      ? null
                      : PillButton(c.secondary!, dark: false, onTap: _saving ? null : c.onSecondary),
                ),
                SizedBox(
                  height: 40 * s,
                  child: c.link == null
                      ? null
                      : Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _saving ? null : c.onLink,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 10 * s),
                              child: Text(c.link!, style: DD.mono(10 * s, weight: FontWeight.w400, spacing: 0.6)),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
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
          IgnorePointer(
            ignoring: onBack == null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: onBack == null ? 0 : 1,
              child: GestureDetector(
                onTap: onBack,
                child: Text('← BACK', style: DD.mono(10 * s, weight: FontWeight.w400)),
              ),
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
                borderRadius: BorderRadius.circular(4 * s),
              ),
            ),
          SizedBox(width: 10 * s),
          Text('${two(step + 1)} / 03', style: DD.mono(10 * s, weight: FontWeight.w400)),
        ],
      ),
    );
  }
}

/// A miniature of the real timeline with the sample photos: a column of
/// circles where a "finger" presses each in turn and it swells into the
/// rounded square, with the date and dot-matrix time on the left — exactly
/// what the app does.
class _TimelineDemo extends StatefulWidget {
  const _TimelineDemo({required this.scale});
  final double scale;

  @override
  State<_TimelineDemo> createState() => _TimelineDemoState();
}

class _TimelineDemoState extends State<_TimelineDemo> with SingleTickerProviderStateMixin {
  static const _photos = ['coffee', 'gear', 'summit', 'golden'];
  static const _times = [(7, 40), (9, 10), (14, 20), (19, 40)];
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final n = _photos.length;
    final d = 62 * s, big = 90 * s, gap = 74 * s;
    final width = 250 * s;
    return SizedBox(
      width: width,
      height: gap * (n - 1) + big,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Each photo gets an equal slot: swell in, hold, relax.
          final slot = _c.value * n;
          final active = slot.floor() % n;
          final local = slot - slot.floor();
          final press = local < 0.3
              ? Curves.easeOutCubic.transform(local / 0.3)
              : local < 0.7
              ? 1.0
              : 1 - Curves.easeInCubic.transform((local - 0.7) / 0.3);
          final items = <({double m, Widget w})>[];
          for (var i = 0; i < n; i++) {
            final m = i == active ? press : 0.0;
            final size = lerpDouble(d, big, m)!;
            final cx = width * 0.62 + math.sin(i * 1.3 + 0.4) * 7 * s - m * 4 * s;
            final cy = big / 2 + i * gap;
            items.add((
              m: m,
              w: Positioned(
                left: cx - size / 2,
                top: cy - size / 2,
                width: size,
                height: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(lerpDouble(size / 2, size * 0.24, m)!),
                  child: Image.asset(
                    'assets/samples/${_photos[i]}.jpg',
                    fit: BoxFit.cover,
                    cacheWidth: (big * MediaQuery.devicePixelRatioOf(context)).round(),
                  ),
                ),
              ),
            ));
          }
          items.sort((a, b) => a.m.compareTo(b.m));
          final (h, m) = _times[active];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final it in items) it.w,
              Positioned(
                left: 0,
                top: big / 2 + active * gap - 10 * s,
                child: Opacity(
                  opacity: press,
                  child: DotMatrixText(clock(DateTime(2026, 1, 1, h, m)), pitch: 2.6 * s, maxWidth: 74 * s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The real top-right pill and a dashed add-circle, so the user knows
/// exactly where adding lives.
class _AddHint extends StatefulWidget {
  const _AddHint({required this.scale, required this.name, this.avatar});
  final double scale;
  final String name;
  final ImageProvider? avatar;

  @override
  State<_AddHint> createState() => _AddHintState();
}

class _AddHintState extends State<_AddHint> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final label = DD.mono(9 * s, weight: FontWeight.w400, height: 1.45);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 76 * s,
              height: 76 * s,
              child: CustomPaint(
                painter: _DashedCircle(s),
                child: Center(
                  child: Text('+', style: DD.mono(24 * s, weight: FontWeight.w400)),
                ),
              ),
            ),
            SizedBox(height: 12 * s),
            Text('TAP A DASHED\nCIRCLE', textAlign: TextAlign.center, style: label),
          ],
        ),
        SizedBox(width: 26 * s),
        Text('OR', style: label.copyWith(color: DD.mute)),
        SizedBox(width: 26 * s),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = _pulse.value;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    child!,
                    // Ring pulsing around the + button.
                    Positioned(
                      bottom: 8 * s - 10 * s * t,
                      child: IgnorePointer(
                        child: Container(
                          width: 44 * s + 20 * s * t,
                          height: 44 * s + 20 * s * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DD.ink.withValues(alpha: (1 - t) * 0.6),
                              width: 1.5 * s,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: UserPill(
                scale: s,
                intro: 1,
                name: widget.name,
                avatar: widget.avatar,
                onAvatar: () {},
                onAdd: () {},
              ),
            ),
            SizedBox(height: 12 * s),
            Text('TAP + AT THE\nTOP RIGHT', textAlign: TextAlign.center, style: label),
          ],
        ),
      ],
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DD.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s;
    final path = Path()..addOval((Offset.zero & size).deflate(0.6 * s));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9 * s) {
        canvas.drawPath(m.extractPath(d, d + 4.5 * s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.s != s;
}
