import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entry.dart';
import 'image_store.dart';

/// Holds every diary entry, the selected day and the user's name, and
/// persists them on-device.
/// Build with `--dart-define=EMPTY=true` for the blank edition (no sample day).
const seedSamples = !bool.fromEnvironment('EMPTY');

class DiaryStore extends ChangeNotifier {
  static const _kEntries = 'entries_v1';
  static const _kName = 'user_name';
  static const _kSeeded = 'seeded_v1';

  late SharedPreferences _prefs;
  List<DiaryEntry> _all = [];
  String _name = 'JACK';
  DateTime _day = dayOf(DateTime.now());

  String get userName => _name;
  DateTime get selectedDay => _day;
  bool get hasSamples => _all.any((e) => e.sample);
  int get totalCount => _all.length;

  /// Entries of the selected day, newest first (top of the timeline).
  List<DiaryEntry> get dayEntries {
    final list = _all.where((e) => dayOf(e.createdAt) == _day).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Every day that has at least one entry, newest first, with its count.
  List<({DateTime day, int count})> get days {
    final counts = <DateTime, int>{};
    for (final e in _all) {
      final d = dayOf(e.createdAt);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (day: k, count: counts[k]!)];
  }

  /// Minutes between [entry] and the entry logged before it on the same day.
  int? minutesSincePrevious(DiaryEntry entry) {
    DiaryEntry? prev;
    for (final e in _all) {
      if (dayOf(e.createdAt) != dayOf(entry.createdAt)) continue;
      if (!e.createdAt.isBefore(entry.createdAt)) continue;
      if (prev == null || e.createdAt.isAfter(prev.createdAt)) prev = e;
    }
    if (prev == null) return null;
    return entry.createdAt.difference(prev.createdAt).inMinutes;
  }

  Future<void> load() async {
    await ImageStore.init();
    _prefs = await SharedPreferences.getInstance();
    _name = _prefs.getString(_kName) ?? _name;
    final raw = _prefs.getString(_kEntries);
    if (raw != null) {
      try {
        _all = (jsonDecode(raw) as List).map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Could not read diary entries: $e');
      }
    }
    if (seedSamples && !(_prefs.getBool(_kSeeded) ?? false)) {
      _all.addAll(_samples());
      await _prefs.setBool(_kSeeded, true);
      await _save();
    }
    final days = this.days;
    final today = dayOf(DateTime.now());
    _day = days.any((d) => d.day == today) || days.isEmpty ? today : days.first.day;
    notifyListeners();
  }

  void selectDay(DateTime day) {
    _day = dayOf(day);
    notifyListeners();
  }

  Future<void> setName(String name) async {
    final clean = name.trim().toUpperCase();
    _name = clean.isEmpty ? 'THERE' : clean;
    await _prefs.setString(_kName, _name);
    notifyListeners();
  }

  Future<DiaryEntry> add({required DateTime at, required String title, String note = '', List<int>? imageBytes}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final image = imageBytes == null ? null : await ImageStore.save(id, imageBytes);
    final entry = DiaryEntry(id: id, createdAt: at, title: title.trim(), note: note.trim(), image: image);
    _all.add(entry);
    _day = dayOf(at);
    await _save();
    notifyListeners();
    return entry;
  }

  Future<void> update(
    DiaryEntry entry, {
    required DateTime at,
    required String title,
    String note = '',
    List<int>? newImageBytes,
  }) async {
    var image = entry.image;
    if (newImageBytes != null) {
      if (image != null) await ImageStore.delete(image);
      image = await ImageStore.save('${entry.id}_${DateTime.now().millisecondsSinceEpoch}', newImageBytes);
    }
    final i = _all.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    _all[i] = entry.copyWith(createdAt: at, title: title.trim(), note: note.trim(), image: image);
    _day = dayOf(at);
    await _save();
    notifyListeners();
  }

  Future<void> delete(DiaryEntry entry) async {
    _all.removeWhere((e) => e.id == entry.id);
    if (entry.image != null) await ImageStore.delete(entry.image!);
    await _save();
    notifyListeners();
  }

  Future<void> removeSamples() async {
    _all.removeWhere((e) => e.sample);
    await _save();
    final days = this.days;
    if (!days.any((d) => d.day == _day)) {
      _day = days.isEmpty ? dayOf(DateTime.now()) : days.first.day;
    }
    notifyListeners();
  }

  Future<void> _save() => _prefs.setString(_kEntries, jsonEncode([for (final e in _all) e.toJson()]));

  /// A starter day so the app opens looking alive. It lands on today once the
  /// last sample (9 PM) is in the past, otherwise on yesterday.
  static List<DiaryEntry> _samples() {
    final now = DateTime.now();
    var day = dayOf(now);
    if (now.hour < 21) day = day.subtract(const Duration(days: 1));
    DiaryEntry s(int h, int m, String title, String note, String img) => DiaryEntry(
      id: 'sample_$img',
      createdAt: day.add(Duration(hours: h, minutes: m)),
      title: title,
      note: note,
      image: 'asset:assets/samples/$img.jpg',
      sample: true,
    );
    return [
      s(7, 40, 'Morning coffee', 'First cup by the window. Slow start, clear head.', 'coffee'),
      s(9, 10, 'Packed the gear', 'Camera, headphones, notebook. Ready to move.', 'gear'),
      s(11, 30, 'Vinyl hunt', 'Found an old pressing at the market stall.', 'vinyl'),
      s(14, 20, 'Summit trail', 'Analyzing surface biome... rock, wind, no signal.', 'summit'),
      s(17, 5, 'Lighthouse walk', 'Grey sky over the point. Waves louder than thoughts.', 'lighthouse'),
      s(19, 40, 'Golden hour', 'The hills went orange for ten minutes, then gone.', 'golden'),
      s(21, 0, 'Project assignment', 'Final boards sent to the studio for review.', 'desk'),
    ];
  }
}
