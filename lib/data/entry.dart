/// A single diary moment: a photo, a title, a note and the exact time it was
/// logged.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.createdAt,
    required this.title,
    this.note = '',
    this.image,
    this.sample = false,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String note;

  /// Image reference understood by `image_store.dart`
  /// (`asset:...`, `doc:...` or `b64:...`). Null for text-only entries.
  final String? image;

  /// True for the starter entries seeded on first launch.
  final bool sample;

  DiaryEntry copyWith({DateTime? createdAt, String? title, String? note, String? image, bool clearImage = false}) {
    return DiaryEntry(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      note: note ?? this.note,
      image: clearImage ? null : (image ?? this.image),
      sample: sample,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'title': title,
    'note': note,
    if (image != null) 'image': image,
    if (sample) 'sample': true,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    title: json['title'] as String? ?? '',
    note: json['note'] as String? ?? '',
    image: json['image'] as String?,
    sample: json['sample'] as bool? ?? false,
  );
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
