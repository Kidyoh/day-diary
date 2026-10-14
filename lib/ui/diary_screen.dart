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
double _smooth(double t) => t * t * (3 - 2 * t);

const _greenScan = ColorFilter.matrix([
  0.04, 0.18, 0.02, 0, 0, //
  0.28, 1.08, 0.10, 0, 22, //
  0.10, 0.44, 0.05, 0, 4, //
  0, 0, 0, 1, 0,
]);

/// Layout measured from the reference, scaled by screen width.
class _Geo {
  _Geo(this.size, EdgeInsets pad) : s = size.width / DD.designWidth, top = pad.top, bottom = pad.bottom {
    spacing = 116 * s;
    d = 87 * s;
    big = 128 * s;
    focusY = top > 30 ? top + 38 * s : 90 * s;
    barBottom = math.max(bottom - 12, 12 * s);
    barTop = size.height - barBottom - 58 * s;
  }

  final Size size;
  final double s, top, bottom;
  late final double spacing, d, big, focusY, barBottom, barTop;

  double get w => size.width;
  double get h => size.height;

  /// Gentle zig-zag of the photo column.
  double columnX(int i) => w * 0.462 + math.sin(i * 1.1) * 10 * s;
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.store});
  final DiaryStore store;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final _expand = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
  late final _detail = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 6400));
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  DiaryStore get store => widget.store;
  late List<DiaryEntry> _entries = store.dayEntries;
  late DateTime _shownDay = store.selectedDay;
  int _focus = 0;
  _Geo? _geo;

  DiaryEntry? _open;
  Rect _from = Rect.zero;
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
    _detail.addStatusListener((s) {
      if (s == AnimationStatus.completed && _open != null) _scan.repeat();
    });
    _intro.forward();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _scroll.dispose();
    for (final c in [_intro, _expand, _detail, _scan, _blink]) {
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
      _focus = _focus.clamp(0, math.max(0, list.length - 1));
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
      _focus = 0;
      _intro.forward(from: 0);
    }
  }

  void _onScroll() {
    final g = _geo;
    if (g == null || _entries.isEmpty) return;
    final i = (_scroll.offset / g.spacing).round().clamp(0, _entries.length - 1);
    if (i != _focus) setState(() => _focus = i);
  }

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  double _introDy(int i, _Geo g) {
    final k = math.min(i, 8);
    final p = _iv(_intro.value, 0.04 + k * 0.045, 0.6 + k * 0.045);
    return (1 - Curves.easeOutCubic.transform(p)) * (g.h * 0.9 + k * 26 * g.s);
  }

  ({Rect rect, double radius, double focus}) _itemBox(int i, _Geo g) {
    final cy = g.focusY + i * g.spacing - _offset + _introDy(i, g);
    final f = _smooth((1 - (cy - g.focusY).abs() / g.spacing).clamp(0.0, 1.0));
    final size = lerpDouble(g.d, g.big, f)!;
    final cx = g.columnX(i) - f * 3 * g.s;
    return (
      rect: Rect.fromCenter(center: Offset(cx, cy), width: size, height: size),
      radius: lerpDouble(size / 2, size * 0.22, f)!,
      focus: f,
    );
  }

  Iterable<int> _visible(_Geo g) sync* {
    if (_entries.isEmpty) return;
    final first = ((_offset - g.focusY - g.big) / g.spacing).floor().clamp(0, _entries.length - 1);
    final last = ((_offset + g.h - g.focusY + g.big) / g.spacing).ceil().clamp(0, _entries.length - 1);
    for (var i = first; i <= last; i++) {
      yield i;
    }
  }

  void _scrollTo(int i) {
    final g = _geo;
    if (g == null || !_scroll.hasClients) return;
    _scroll.animateTo(
      (i * g.spacing).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTap(Offset p) {
    final g = _geo;
    if (g == null) return;
    for (final i in _visible(g)) {
      if (_itemBox(i, g).rect.inflate(6).contains(p)) {
        if (i == _focus && (_offset - i * g.spacing).abs() < g.spacing * 0.2) {
          _openEntry(i);
        } else {
          _scrollTo(i);
        }
        return;
      }
    }
  }

  void _onLongPress(Offset p) {
    final g = _geo;
    if (g == null) return;
    for (final i in _visible(g)) {
      if (_itemBox(i, g).rect.contains(p)) {
        _entryActions(_entries[i]);
        return;
      }
    }
  }

  // --------------------------------------------------------------- detail

  void _openEntry(int i) {
    final g = _geo;
    if (g == null || _open != null || i >= _entries.length) return;
    final e = _entries[i];
    final box = _itemBox(i, g);
    setState(() {
      _open = e;
      _from = box.rect;
      _luma = Luma.cached(e) ?? (top: 0.8, bottom: 0.4);
      _drag = 0;
    });
    Luma.of(e).then((l) {
      if (mounted && _open?.id == e.id) setState(() => _luma = l);
    });
    _detail.value = 0;
    _scan
      ..stop()
      ..value = 0;
    _expand.forward(from: 0);
  }

  Future<void> _close() async {
    if (_open == null || _closing) return;
    _closing = true;
    _scan.stop();
    await _detail.animateBack(0, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    await _expand.reverse();
    if (mounted) setState(_resetDetail);
  }

  void _resetDetail() {
    _open = null;
    _closing = false;
    _drag = 0;
    _expand.value = 0;
    _detail.value = 0;
    _scan
      ..stop()
      ..value = 0;
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
            final g = _Geo(box.biggest, MediaQuery.paddingOf(context));
            _geo = g;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (_, _) => DotGrid(scale: g.s, offset: _offset),
                  ),
                ),
                Positioned.fill(child: _items(g)),
                Positioned.fill(child: _scrollSurface(g)),
                if (_open != null) Positioned.fill(child: _expanded(g)),
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

  Widget _items(_Geo g) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scroll, _intro]),
        builder: (context, _) {
          if (_entries.isEmpty) return _emptySlot(g);
          final items = <({double focus, Widget child})>[];
          for (final i in _visible(g)) {
            if (_open != null && _entries[i].id == _open!.id) continue;
            final b = _itemBox(i, g);
            if (b.rect.top > g.h || b.rect.bottom < 0) continue;
            items.add((
              focus: b.focus,
              child: Positioned.fromRect(
                key: ValueKey(_entries[i].id),
                rect: b.rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(b.radius),
                  child: EntryImage(entry: _entries[i]),
                ),
              ),
            ));
          }
          // Paint the focused item last so it overlaps its neighbours.
          items.sort((a, b) => a.focus.compareTo(b.focus));
          final children = [for (final it in items) it.child];
          return Stack(clipBehavior: Clip.none, children: children);
        },
      ),
    );
  }

  Widget _emptySlot(_Geo g) {
    final p = Curves.easeOutBack.transform(_iv(_intro.value, 0.1, 0.5));
    return Stack(
      children: [
        Positioned(
          left: g.columnX(0) - g.big / 2,
          top: g.focusY - g.big / 2,
          child: Transform.scale(
            scale: p,
            child: GestureDetector(
              onTap: () => _compose(),
              child: CustomPaint(
                size: Size.square(g.big),
                painter: _DashedSquirclePainter(g.s),
                child: SizedBox.square(
                  dimension: g.big,
                  child: Center(
                    child: Text('+', style: DD.mono(30 * g.s, weight: FontWeight.w400)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scrollSurface(_Geo g) {
    return IgnorePointer(
      ignoring: _open != null || _entries.isEmpty,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => _onTap(d.localPosition),
        onLongPressStart: (d) => _onLongPress(d.localPosition),
        child: ScrollConfiguration(
          behavior: const _AnyPointerScroll(),
          child: ListView.builder(
            controller: _scroll,
            physics: _SnapPhysics(extent: g.spacing),
            itemExtent: g.spacing,
            padding: EdgeInsets.only(top: g.focusY - g.spacing / 2, bottom: g.h - g.focusY - g.spacing / 2),
            itemCount: math.max(_entries.length, 1),
            itemBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _expanded(_Geo g) {
    final e = _open!;
    return AnimatedBuilder(
      animation: Listenable.merge([_expand, _scan]),
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
        final radius = lerpDouble(_from.width * 0.22, 0, t)! + dragK * 120 * g.s;
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
                      EntryImage(entry: e),
                      _scanLayer(e),
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

  Widget _scanLayer(DiaryEntry e) {
    final v = _scan.value;
    final sweep = Curves.easeInOutSine.transform(_iv(v, 0, 0.45));
    final fade = 1 - _iv(v, 0.66, 0.82);
    if (sweep <= 0 || fade <= 0) return const SizedBox.shrink();
    final edge = sweep * 1.25;
    return IgnorePointer(
      child: Opacity(
        opacity: fade * 0.78,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: const [0.32, 0.55, 0.88, 1],
          ).createShader(r),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, (edge - 0.25).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
            ).createShader(r),
            child: ColorFiltered(
              colorFilter: _greenScan,
              child: EntryImage(entry: e),
            ),
          ),
        ),
      ),
    );
  }

  Widget _labels(_Geo g) {
    final s = g.s;
    final focused = _entries.isEmpty ? null : _entries[_focus.clamp(0, _entries.length - 1)];
    final day = focused?.createdAt ?? store.selectedDay;
    final time = focused == null ? '--:--' : clock(focused.createdAt);
    final title = focused == null ? 'LOG YOUR FIRST MOMENT' : focused.title.toUpperCase();
    final labelStyle = DD.mono(9.6 * s, height: 1.32, spacing: 0.1);

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
              left: 29 * s,
              top: g.focusY + 12 * s,
              child: Opacity(
                opacity: dateO,
                child: SwapScrambleText(stackedDate(day), style: labelStyle),
              ),
            ),
            Positioned(
              left: 50 * s,
              top: g.focusY + 160 * s - 16 * s,
              child: Opacity(
                opacity: globeO,
                child: PixelGlobe(size: 33 * s),
              ),
            ),
            Positioned(
              left: 46 * s,
              top: g.focusY + 275 * s - 10 * s,
              child: Opacity(
                opacity: timeO,
                child: DotMatrixText(time, pitch: 3 * s, maxWidth: 88 * s, dotFraction: 0.8),
              ),
            ),
            Positioned(
              left: 70 * s,
              top: g.focusY + 372 * s,
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
    final shadow = [Shadow(color: Colors.black.withValues(alpha: darkBottom ? 0 : 0.35), blurRadius: 6)];

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
                outline: darkBottom ? null : Colors.black.withValues(alpha: 0.18),
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
      top: g.focusY + 283 * g.s,
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
              _openEntry(_focus);
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
      right: 10 * g.s,
      top: g.top > 30 ? 12 : 16 * g.s,
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) => UserPill(
          scale: g.s,
          intro: _iv(_intro.value, 0.18, 0.75),
          name: store.userName,
          onAvatar: _profile,
          onBolt: () => _compose(pickFirst: ImageSource.camera),
        ),
      ),
    );
  }

  Widget _bottomBar(_Geo g) {
    return Positioned(
      left: 10 * g.s,
      right: 10 * g.s,
      bottom: g.barBottom,
      child: AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) {
          final max = _scroll.hasClients && _scroll.position.hasContentDimensions
              ? _scroll.position.maxScrollExtent
              : 0.0;
          return BottomBar(
            scale: g.s,
            value: max <= 0 ? 0 : (_offset / max).clamp(0.0, 1.0),
            count: _entries.length,
            onMenu: _profile,
            onExplore: _archive,
            onScrub: (v) {
              if (_open != null || !_scroll.hasClients) return;
              _scroll.jumpTo(v * _scroll.position.maxScrollExtent);
            },
            onScrubEnd: () {
              if (_open != null || _entries.isEmpty) return;
              _scrollTo((_offset / g.spacing).round());
            },
          );
        },
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

/// Lands every fling exactly on an entry so one is always in focus.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  ScrollPhysics buildParent(ScrollPhysics? ancestor) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.outOfRange) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);
    final projected = velocity.abs() < tolerance.velocity
        ? position.pixels
        : FrictionSimulation(0.135, position.pixels, velocity).finalX;
    final target = ((projected / extent).roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      const SpringDescription(mass: 1, stiffness: 140, damping: 22),
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _DashedSquirclePainter extends CustomPainter {
  _DashedSquirclePainter(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
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
  bool shouldRepaint(_DashedSquirclePainter old) => old.s != s;
}
