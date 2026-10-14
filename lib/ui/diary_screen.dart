import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:image_picker/image_picker.dart';

import '../data/diary_store.dart';
import '../data/entry.dart';
import 'sheets.dart';
import 'theme.dart';
import 'widgets/chrome.dart';
import 'widgets/dot_matrix.dart';
import 'widgets/entry_image.dart';
import 'widgets/pixel_globe.dart';
import 'widgets/scramble_text.dart';

double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Layout measured from the reference, scaled by screen width.
class _Geo {
  // Measured from the reference frame flattened to 393 × 852: circles 112pt
  // in one centred column, 144.5pt apart, first centre at y 102.7; pressed
  // square 165pt; bottom bar 64pt tall, 20pt from the bottom edge.
  _Geo(this.size, EdgeInsets pad, int count) : s = size.width / DD.designWidth, top = pad.top, bottom = pad.bottom {
    d = 112 * s;
    big = 165 * s;
    spacing = 144.75 * s;
    y0 = 102.7 * s;
    barBottom = math.max(20 * s, bottom + 6);
    barTop = size.height - barBottom - 64 * s;

    // Scroll only once the column no longer fits above the bar, in whole rows.
    final n = math.max(count, 1);
    final fits = ((barTop - 20 * s - y0) / spacing).floor() + 1;
    travel = math.max(0, n - fits) * spacing;
    padTop = y0 - spacing / 2;
    padBottom = travel + size.height - padTop - n * spacing;
  }

  final Size size;
  final double s, top, bottom;
  late final double d, big, spacing, y0, barBottom, barTop, travel, padTop, padBottom;

  double get w => size.width;
  double get h => size.height;

  double columnX(int i) => w / 2;
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.store, this.startWith});
  final DiaryStore store;

  /// Opens the new-entry sheet with this picker right after launch
  /// (the last onboarding step).
  final ImageSource? startWith;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final _expand = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  late final _detail = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  DiaryStore get store => widget.store;
  late List<DiaryEntry> _entries = store.dayEntries;
  late DateTime _shownDay = store.selectedDay;
  _Geo? _geo;

  /// Entry shown by the left-hand labels (updated once scrolling settles on it).
  int _labelIndex = 0;
  int _labelTarget = 0;
  Timer? _labelTimer;

  String? _pressedId;

  /// Scrubber position while the user drags it.
  double? _scrub;

  DiaryEntry? _open;
  Rect _from = Rect.zero;
  double _fromRadius = 0;
  ({double top, double bottom}) _luma = (top: 0.8, bottom: 0.4);
  bool _closing = false;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _scroll.addListener(_onScroll);
    _expand.addStatusListener((s) {
      if (s == AnimationStatus.completed && _open != null) _detail.forward(from: 0);
    });
    _intro.forward();
    final first = widget.startWith;
    if (first != null) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _compose(pickFirst: first);
      });
    }
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _labelTimer?.cancel();
    _scroll.dispose();
    for (final c in [_intro, _press, _expand, _detail, _blink]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- state

  void _onStore() {
    final list = store.dayEntries;
    final dayChanged = store.selectedDay != _shownDay;
    setState(() {
      _entries = list;
      _shownDay = store.selectedDay;
      _labelIndex = _labelIndex.clamp(0, math.max(0, list.length - 1));
      _labelTarget = _labelIndex;
      if (_open != null) {
        final i = list.indexWhere((e) => e.id == _open!.id);
        if (i < 0 || dayChanged) {
          _resetDetail();
        } else {
          _open = list[i];
        }
      }
    });
    if (dayChanged) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _labelIndex = _labelTarget = 0;
      _intro.forward(from: 0);
    }
  }

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  /// Fractional index of the entry in focus. The focus point travels from the
  /// first entry to the last as you scroll from top to bottom, so it walks
  /// down the screen like the reference.
  /// Index of the entry at the top of the column (fractional mid-scroll).
  double get _focus {
    final g = _geo;
    if (g == null || _entries.isEmpty) return 0;
    return (_offset / g.spacing).clamp(0.0, _entries.length - 1.0);
  }

  double _offsetFor(int i) {
    final g = _geo;
    if (g == null) return 0;
    return (i * g.spacing).clamp(0.0, g.travel);
  }

  void _onScroll() {
    if (_entries.isEmpty) return;
    _labelTarget = _focus.round();
  }

  /// Labels decode only once scrolling has fully stopped, never mid-drag.
  void _onScrollIdle() {
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted || !_scroll.hasClients || _scroll.position.isScrollingNotifier.value) return;
      if (_labelIndex != _labelTarget && _open == null) setState(() => _labelIndex = _labelTarget);
    });
  }

  double _introDy(int i, _Geo g) {
    if (_intro.isCompleted) return 0;
    final k = math.min(i, 7);
    final p = _iv(_intro.value, 0.02 + k * 0.05, 0.5 + k * 0.05);
    return (1 - Curves.easeOutQuart.transform(p)) * (g.h * 0.85 + k * 30 * g.s);
  }

  ({Rect rect, double radius, double morph}) _itemBox(int i, _Geo g, double focus) {
    final cy = g.y0 + i * g.spacing - _offset + _introDy(i, g);
    // Every entry is a circle; only the one under your finger swells into a
    // rounded square (the reference's press state).
    var m = 0.0;
    if (_pressedId != null && _entries[i].id == _pressedId) {
      m = math.max(m, Curves.easeOutCubic.transform(_press.value));
    }
    final size = lerpDouble(g.d, g.big, m)!;
    final cx = g.columnX(i);
    return (
      rect: Rect.fromCenter(center: Offset(cx, cy), width: size, height: size),
      radius: lerpDouble(size / 2, size * 0.23, m)!,
      morph: m,
    );
  }

  Iterable<int> _visible(_Geo g) sync* {
    if (_entries.isEmpty) return;
    final first = ((_offset - g.y0 - g.big) / g.spacing).floor().clamp(0, _entries.length - 1);
    final last = ((_offset + g.h - g.y0 + g.big) / g.spacing).ceil().clamp(0, _entries.length - 1);
    for (var i = first; i <= last; i++) {
      yield i;
    }
  }

  int? _hit(Offset p) {
    final g = _geo;
    if (g == null) return null;
    final f = _focus;
    int? best;
    var bestM = -1.0;
    for (final i in _visible(g)) {
      final b = _itemBox(i, g, f);
      if (b.rect.inflate(4).contains(p) && b.morph > bestM) {
        best = i;
        bestM = b.morph;
      }
    }
    return best;
  }

  void _scrollTo(int i) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_offsetFor(i), duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  /// Dashed "+" circles that continue the column after the last entry, so
  /// the day never looks empty and there is always a place to add a moment.
  List<Rect> _ghosts(_Geo g) {
    final n = _entries.length;
    final out = <Rect>[];
    for (var k = 0; k < 6; k++) {
      final i = n + k;
      final cy = g.y0 + i * g.spacing - _offset + _introDy(i, g);
      if (k > 0 && cy - g.d / 2 > g.barTop - 10 * g.s) break;
      out.add(Rect.fromCenter(center: Offset(g.columnX(i), cy), width: g.d, height: g.d));
    }
    return out;
  }

  // ------------------------------------------------------------- touches

  void _onTapDown(TapDownDetails d) {
    final i = _hit(d.localPosition);
    if (i == null) return;
    final provider = EntryImage.providerFor(_entries[i]);
    if (provider != null) precacheImage(provider, context);
    _labelTimer?.cancel();
    setState(() {
      _pressedId = _entries[i].id;
      _labelIndex = _labelTarget = i;
    });
    _press.forward();
  }

  void _onTapUp(TapUpDetails d) {
    final i = _hit(d.localPosition);
    if (i == null) {
      final g = _geo;
      if (g != null && _ghosts(g).any((r) => r.contains(d.localPosition))) _compose();
    }
    if (i == null || _entries[i].id != _pressedId) {
      _release();
      return;
    }
    _openEntry(i);
  }

  void _release() {
    _press.reverse().whenComplete(() {
      if (mounted && _press.isDismissed && _open == null) setState(() => _pressedId = null);
    });
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      if (_pressedId != null) _release();
    }
    if (n is ScrollEndNotification) _onScrollIdle();
    return false;
  }

  // --------------------------------------------------------------- detail

  void _openEntry(int i) {
    final g = _geo;
    if (g == null || _open != null || i >= _entries.length) return;
    final e = _entries[i];
    final box = _itemBox(i, g, _focus);
    _labelTimer?.cancel();
    setState(() {
      _open = e;
      _pressedId = e.id;
      _from = box.rect;
      _fromRadius = box.radius;
      _labelIndex = _labelTarget = i;
      _luma = Luma.cached(e) ?? (top: 0.8, bottom: 0.4);
      _drag = 0;
    });
    Luma.of(e).then((l) {
      if (mounted && _open?.id == e.id) setState(() => _luma = l);
    });
    _press.value = 1;
    _detail.value = 0;
    _expand.forward(from: 0);
  }

  Future<void> _close() async {
    if (_open == null || _closing) return;
    _closing = true;
    await _detail.animateBack(0, duration: const Duration(milliseconds: 280), curve: Curves.easeIn);
    await _expand.reverse();
    if (!mounted) return;
    setState(_resetDetail);
    _release();
  }

  void _resetDetail() {
    _open = null;
    _closing = false;
    _drag = 0;
    _expand.value = 0;
    _detail.value = 0;
  }

  // ---------------------------------------------------------------- sheets

  Future<void> _compose({ImageSource? pickFirst, DiaryEntry? edit}) async {
    final saved = await showDiarySheet<DiaryEntry>(
      context,
      ComposeSheet(store: store, entry: edit, pickFirst: pickFirst),
    );
    if (saved == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = _entries.indexWhere((e) => e.id == saved.id);
      if (i >= 0 && _open == null) _scrollTo(i);
    });
  }

  Future<void> _entryActions(DiaryEntry e) async {
    if (_pressedId != null && _open == null) _release();
    final action = await showDiarySheet<EntryAction>(context, EntryActionsSheet(entry: e));
    if (!mounted) return;
    switch (action) {
      case EntryAction.edit:
        await _compose(edit: e);
      case EntryAction.delete:
        if (_open?.id == e.id) await _close();
        await store.delete(e);
      case null:
        break;
    }
  }

  void _archive() => showDiarySheet<void>(context, ArchiveSheet(store: store));
  void _profile() => showDiarySheet<void>(context, ProfileSheet(store: store));

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: DD.bg,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, box) {
            final g = _Geo(box.biggest, MediaQuery.paddingOf(context), _entries.length);
            _geo = g;
            final thumb = (g.big * MediaQuery.devicePixelRatioOf(context)).round();
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (_, _) => DotGrid(scale: g.s, offset: _offset),
                  ),
                ),
                Positioned.fill(child: _items(g, thumb)),
                Positioned.fill(child: _scrollSurface(g)),
                if (_open != null) Positioned.fill(child: _expanded(g, thumb)),
                Positioned.fill(child: IgnorePointer(child: _labels(g))),
                if (_open != null) Positioned.fill(child: IgnorePointer(child: _detailTexts(g))),
                _sideTab(g),
                _pill(g),
                _bottomBar(g),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _items(_Geo g, int thumb) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scroll, _intro, _press]),
        builder: (context, _) {
          final f = _focus;
          final items = <({double morph, Widget child})>[];
          final ghosts = _ghosts(g);
          for (var k = 0; k < ghosts.length; k++) {
            items.add((
              morph: -1,
              child: Positioned.fromRect(
                key: ValueKey('ghost$k'),
                rect: ghosts[k],
                child: Opacity(
                  opacity: const [1.0, 0.5, 0.32, 0.22, 0.16, 0.12][k],
                  child: CustomPaint(
                    painter: _DashedCirclePainter(g.s),
                    child: k == 0
                        ? Center(
                            child: Text('+', style: DD.mono(30 * g.s, weight: FontWeight.w400)),
                          )
                        : null,
                  ),
                ),
              ),
            ));
          }
          for (final i in _visible(g)) {
            if (_open != null && _entries[i].id == _open!.id) continue;
            final b = _itemBox(i, g, f);
            if (b.rect.top > g.h || b.rect.bottom < 0) continue;
            items.add((
              morph: b.morph,
              child: Positioned.fromRect(
                key: ValueKey(_entries[i].id),
                rect: b.rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(b.radius),
                  child: EntryImage(entry: _entries[i], thumbWidth: thumb),
                ),
              ),
            ));
          }
          // Paint the rounded square last so it overlaps its neighbours.
          items.sort((a, b) => a.morph.compareTo(b.morph));
          return Stack(clipBehavior: Clip.none, children: [for (final it in items) it.child]);
        },
      ),
    );
  }

  Widget _scrollSurface(_Geo g) {
    final n = math.max(_entries.length, 1);
    return IgnorePointer(
      ignoring: _open != null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () {
          if (_open == null && _pressedId != null) _release();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ScrollConfiguration(
            behavior: const _AnyPointerScroll(),
            child: ListView.builder(
              controller: _scroll,
              physics: _SnapPhysics(extent: g.spacing),
              itemExtent: g.spacing,
              padding: EdgeInsets.only(top: g.padTop, bottom: g.padBottom),
              itemCount: n,
              itemBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _expanded(_Geo g, int thumb) {
    final e = _open!;
    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        final v = _expand.value;
        final t = Curves.easeInOutCubic.transform(v);
        // Grow as a square first, then stretch to full height (reference).
        final wt = Curves.easeInOutCubic.transform(_iv(v, 0, 0.7));
        final ht = Curves.easeInOutCubic.transform(_iv(v, 0.12, 1));
        final full = Offset.zero & g.size;
        final width = lerpDouble(_from.width, full.width, wt)!;
        final height = lerpDouble(_from.height, full.height, ht)!;
        final center = Offset(
          lerpDouble(_from.center.dx, full.center.dx, wt)!,
          lerpDouble(_from.center.dy, full.center.dy, ht)!,
        );
        var rect = Rect.fromCenter(center: center, width: width, height: height);
        final dragK = (_drag / g.h).clamp(0.0, 0.4);
        if (dragK > 0) {
          rect = Rect.fromCenter(
            center: rect.center.translate(0, _drag * 0.5),
            width: rect.width * (1 - dragK * 0.5),
            height: rect.height * (1 - dragK * 0.5),
          );
        }
        // Circle → rounded square happens in the first part of the growth.
        final squared = lerpDouble(_fromRadius, _from.width * 0.24, _iv(v, 0, 0.25))!;
        final radius = lerpDouble(squared, 0, t)! + dragK * 120 * g.s;
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                onLongPress: () => _entryActions(e),
                onVerticalDragUpdate: (d) {
                  if (_expand.value < 1) return;
                  setState(() => _drag = math.max(0, _drag + d.delta.dy));
                },
                onVerticalDragEnd: (d) {
                  if (_drag > 90 * g.s || d.velocity.pixelsPerSecond.dy > 900) {
                    _close();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail shows instantly; the full photo fades over it.
                      EntryImage(entry: e, thumbWidth: thumb),
                      EntryImage(entry: e, fadeIn: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _labels(_Geo g) {
    final s = g.s;
    final focused = _entries.isEmpty ? null : _entries[_labelIndex.clamp(0, _entries.length - 1)];
    final day = focused?.createdAt ?? store.selectedDay;
    final time = clock(focused?.createdAt ?? DateTime.now());
    final title = focused == null ? 'LOG YOUR FIRST MOMENT' : focused.title.toUpperCase();
    final labelStyle = DD.mono(11.9 * s, height: 1.37);

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _expand, _detail]),
      builder: (context, _) {
        final appear = _iv(_intro.value, 0, 0.12);
        final dateO = appear * (1 - _iv(_detail.value, 0.02, 0.14));
        final timeO = appear * (1 - _iv(_detail.value, 0.04, 0.16));
        final globeO = appear * (1 - _iv(_expand.value, 0, 0.4));
        final titleO = appear * (1 - _iv(_expand.value, 0.3, 0.9));
        return Stack(
          children: [
            Positioned(
              left: 45.8 * s,
              top: 87.9 * s,
              child: Opacity(
                opacity: dateO,
                child: SwapScrambleText(stackedDate(day), style: labelStyle),
              ),
            ),
            Positioned(
              left: 53.8 * s,
              top: 260.7 * s,
              child: Opacity(
                opacity: globeO,
                child: PixelGlobe(size: 41 * s),
              ),
            ),
            Positioned(
              left: 33.5 * s,
              top: 412.3 * s,
              child: Opacity(
                opacity: timeO,
                child: DotMatrixText(time, pitch: 3.3 * s, maxWidth: 76 * s, dotFraction: 0.8, round: true),
              ),
            ),
            Positioned(
              left: 45.3 * s,
              top: 548.5 * s,
              child: Opacity(
                opacity: titleO,
                child: SwapScrambleText(hardWrap(title, 7), style: labelStyle),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailTexts(_Geo g) {
    final e = _open!;
    final s = g.s;
    final darkTop = _luma.top > 0.5;
    final darkBottom = _luma.bottom > 0.62;
    final topInk = darkTop ? DD.ink : Colors.white;
    final bottomInk = darkBottom ? DD.ink : Colors.white;
    // Soft halo in the opposite colour keeps text readable on mixed photos.
    final halo = darkBottom ? Colors.white : Colors.black;
    final shadow = [Shadow(color: halo.withValues(alpha: 0.55), blurRadius: 8)];

    final delta = store.minutesSincePrevious(e);
    final deltaText = delta == null
        ? '+00'
        : delta < 1000
        ? '+$delta'
        : '+${(delta / 60).round()}H';
    final headline = '${e.title.toUpperCase().replaceAll(' ', '_')}: ${clock(e.createdAt)}';
    final index = _entries.length - _entries.indexWhere((x) => x.id == e.id);
    final meta =
        'ENTRY_ID: ${index.toString().padLeft(4, '0')}\n'
        'LOGGED: ${hms(e.createdAt)}\n'
        '${longDate(e.createdAt).replaceAll(' ', '_')}';
    final note = (e.note.isEmpty ? 'NO_NOTE...' : e.note).toUpperCase();

    return AnimatedBuilder(
      animation: Listenable.merge([_detail, _blink]),
      builder: (context, _) {
        final d = _detail.value;
        return Stack(
          children: [
            Positioned(
              left: 40 * s,
              top: math.max(46 * s, g.top + 2),
              child: ScrambleText(
                breakAll(headline),
                progress: _iv(d, 0.14, 0.56),
                style: DD.mono(29 * s, color: topInk, height: 0.97, spacing: -0.6 * s),
              ),
            ),
            Positioned(
              right: 44 * s,
              top: g.h * 0.33,
              child: Opacity(
                opacity: _iv(d, 0.5, 0.58),
                child: TypeText(
                  meta,
                  progress: _iv(d, 0.5, 0.82),
                  blink: _blink.value,
                  cursor: false,
                  style: DD
                      .mono(6.6 * s, weight: FontWeight.w400, color: Colors.white, height: 1.35, spacing: 0.3)
                      .copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)]),
                ),
              ),
            ),
            Positioned(
              left: 24 * s,
              top: g.barTop - 168 * s,
              child: DotMatrixText(
                deltaText,
                pitch: 7.2 * s,
                color: bottomInk,
                outline: halo.withValues(alpha: 0.4),
                reveal: _iv(d, 0.42, 0.74),
              ),
            ),
            Positioned(
              left: 24 * s,
              top: g.barTop - 92 * s,
              width: 200 * s,
              child: TypeText(
                note,
                progress: _iv(d, 0.06, 0.42),
                blink: _blink.value,
                style: DD
                    .mono(9 * s, weight: FontWeight.w400, color: bottomInk, height: 1.4, spacing: 1.2 * s)
                    .copyWith(shadows: shadow),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sideTab(_Geo g) {
    return Positioned(
      right: 0,
      top: 486 * g.s,
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, child) {
          final p = Curves.easeOutCubic.transform(_iv(_intro.value, 0.5, 0.8));
          return Transform.translate(offset: Offset((1 - p) * 40 * g.s, 0), child: child);
        },
        child: SideTab(
          scale: g.s,
          expanded: _open != null,
          onExpand: () {
            if (_open != null) {
              _close();
            } else if (_entries.isNotEmpty) {
              _openEntry(_focus.round());
            }
          },
          onArchive: _archive,
          onAdd: () => _compose(pickFirst: ImageSource.gallery),
        ),
      ),
    );
  }

  Widget _pill(_Geo g) {
    return Positioned(
      right: 12 * g.s,
      top: 24 * g.s,
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) => UserPill(
          scale: g.s,
          intro: _iv(_intro.value, 0.18, 0.75),
          name: store.userName,
          avatar: store.avatar,
          onAvatar: _profile,
          onAdd: () => _compose(),
        ),
      ),
    );
  }

  /// Time of day (0..1) of the entry the labels show — where the scrubber
  /// thumb sits.
  double get _dayFraction {
    final e = _entries.isEmpty ? null : _entries[_labelIndex.clamp(0, _entries.length - 1)];
    final t = e?.createdAt ?? DateTime.now();
    return (t.hour * 60 + t.minute) / 1440;
  }

  void _scrubTo(double v) {
    if (_open != null || _entries.isEmpty) return;
    // Pick the entry closest to the scrubbed time of day.
    final minutes = v * 1440;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _entries.length; i++) {
      final t = _entries[i].createdAt;
      final d = (t.hour * 60 + t.minute - minutes).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    _labelTimer?.cancel();
    setState(() {
      _scrub = v;
      _labelIndex = _labelTarget = best;
    });
    if (_scroll.hasClients && (_offset - _offsetFor(best)).abs() > 1) _scrollTo(best);
  }

  Widget _bottomBar(_Geo g) {
    return Positioned(
      left: 8 * g.s,
      right: 7 * g.s,
      bottom: g.barBottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _scrub ?? _dayFraction),
        duration: Duration(milliseconds: _scrub == null ? 520 : 0),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => BottomBar(
          scale: g.s,
          value: v,
          count: _entries.length,
          onMenu: _profile,
          onExplore: _archive,
          onScrub: _scrubTo,
          onScrubEnd: () => setState(() => _scrub = null),
        ),
      ),
    );
  }
}

/// Lets mouse and trackpad drag the timeline too (web / desktop previews).
class _AnyPointerScroll extends ScrollBehavior {
  const _AnyPointerScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Natural iOS-style scrolling that comes to rest on whole rows, with a
/// critically damped spring (no overshoot, no wobble).
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  ScrollPhysics buildParent(ScrollPhysics? ancestor) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  static final _spring = SpringDescription.withDampingRatio(mass: 0.5, stiffness: 100, ratio: 1);

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (extent <= 0 || position.outOfRange) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);
    final projected = velocity.abs() < tolerance.velocity
        ? position.pixels
        : FrictionSimulation(0.135, position.pixels, velocity).finalX;
    final target = ((projected / extent).roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance && velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(_spring, position.pixels, target, velocity, tolerance: tolerance);
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width / 2));
    final paint = Paint()
      ..color = DD.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s;
    final path = Path()..addRRect(rrect.deflate(0.6 * s));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9 * s) {
        canvas.drawPath(m.extractPath(d, d + 4.5 * s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.s != s;
}
