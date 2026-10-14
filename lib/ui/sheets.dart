import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/diary_store.dart';
import '../data/entry.dart';
import 'theme.dart';
import 'widgets/entry_image.dart';

Future<T?> showDiarySheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => _SheetFrame(child: child),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + mq.viewInsets.bottom + mq.padding.bottom * 0.4),
      child: Material(
        color: DD.bg,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: DD.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: DD.mono(9, weight: FontWeight.w400, color: DD.mute, spacing: 0.6),
    ),
  );
}

class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onTap, this.dark = true, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool dark, busy;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : DD.ink;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? DD.ink : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: dark ? null : Border.all(color: DD.line),
          ),
          child: busy
              ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
              : Text(label, style: DD.mono(11, color: fg, spacing: 0.8)),
        ),
      ),
    );
  }
}

InputDecoration _field(String hint) => InputDecoration(
  isDense: true,
  hintText: hint,
  hintStyle: DD.mono(14, weight: FontWeight.w400, color: DD.mute.withValues(alpha: 0.6)),
  contentPadding: const EdgeInsets.symmetric(vertical: 10),
  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.line)),
  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DD.ink, width: 1.2)),
);

/// Create a new entry, or edit [entry]. Pops with the saved entry.
class ComposeSheet extends StatefulWidget {
  const ComposeSheet({super.key, required this.store, this.entry, this.pickFirst});

  final DiaryStore store;
  final DiaryEntry? entry;

  /// Opens this picker straight away (the lightning button uses the camera).
  final ImageSource? pickFirst;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  late final _title = TextEditingController(text: widget.entry?.title ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late DateTime _at = widget.entry?.createdAt ?? DateTime.now();
  Uint8List? _bytes;
  bool _timeTouched = false;
  bool _saving = false;
  Timer? _tick;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (!_editing) {
      // Live timestamp until the user sets one by hand.
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_timeTouched && mounted) setState(() => _at = DateTime.now());
      });
    }
    if (widget.pickFirst != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.pickFirst!));
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (source == ImageSource.camera) await _pick(ImageSource.gallery);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t == null) return;
    setState(() {
      _timeTouched = true;
      _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute);
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      _timeTouched = true;
      _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute, _at.second);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _title.text.trim().isEmpty ? 'Untitled moment' : _title.text;
    final nav = Navigator.of(context);
    if (_editing) {
      await widget.store.update(widget.entry!, at: _at, title: title, note: _note.text, newImageBytes: _bytes);
      nav.pop(widget.entry);
    } else {
      final e = await widget.store.add(at: _at, title: title, note: _note.text, imageBytes: _bytes);
      nav.pop(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget photo;
    if (_bytes != null) {
      photo = Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (widget.entry?.image != null) {
      photo = EntryImage(entry: widget.entry!);
    } else {
      photo = Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Text(
          '+ ADD_PHOTO',
          style: DD.mono(11, weight: FontWeight.w400, color: DD.mute),
        ),
      );
    }
    final hasPhoto = _bytes != null || widget.entry?.image != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(_editing ? 'EDIT_ENTRY' : 'NEW_ENTRY', style: DD.mono(20))),
              Text(hms(_at), style: DD.mono(12, weight: FontWeight.w400)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _pick(ImageSource.gallery),
            child: AspectRatio(
              aspectRatio: 1.7,
              child: ClipRRect(borderRadius: BorderRadius.circular(22), child: photo),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  hasPhoto ? 'REPLACE' : 'GALLERY',
                  dark: false,
                  onTap: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: PillButton('CAMERA', dark: false, onTap: () => _pick(ImageSource.camera))),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('TITLE'),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.characters,
            style: DD.mono(15),
            cursorColor: DD.ink,
            decoration: _field('PROJECT_ASSIGNMENT'),
          ),
          const SizedBox(height: 16),
          const _Label('NOTE'),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            style: DD.mono(12, weight: FontWeight.w400, height: 1.45),
            cursorColor: DD.ink,
            decoration: _field('WHAT HAPPENED...'),
          ),
          const SizedBox(height: 16),
          const _Label('TIMESTAMP'),
          Row(
            children: [
              _Chip(clock(_at), onTap: _pickTime),
              const SizedBox(width: 8),
              _Chip(longDate(_at), onTap: _pickDate),
              const Spacer(),
              if (!_editing && !_timeTouched)
                Text(
                  'LIVE',
                  style: DD.mono(9, weight: FontWeight.w400, color: DD.mute),
                ),
            ],
          ),
          const SizedBox(height: 22),
          PillButton(_editing ? 'SAVE_CHANGES' : 'LOG_ENTRY', onTap: _save, busy: _saving),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DD.line),
      ),
      child: Text(text, style: DD.mono(11)),
    ),
  );
}

/// Every day with entries; picks the day shown on the timeline.
class ArchiveSheet extends StatelessWidget {
  const ArchiveSheet({super.key, required this.store});
  final DiaryStore store;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(DateTime.now());
    final days = store.days;
    final rows = [if (!days.any((d) => d.day == today)) (day: today, count: 0), ...days];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('ARCHIVE', style: DD.mono(20))),
            Text(
              '${two(days.length)} DAYS',
              style: DD.mono(10, weight: FontWeight.w400, color: DD.mute),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final r = rows[i];
              final selected = r.day == store.selectedDay;
              final fg = selected ? Colors.white : DD.ink;
              return GestureDetector(
                onTap: () {
                  store.selectDay(r.day);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? DD.ink : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.day == today ? 'TODAY · ${longDate(r.day)}' : longDate(r.day),
                          style: DD.mono(12, color: fg),
                        ),
                      ),
                      Text(
                        '${two(r.count)} X',
                        style: DD.mono(11, weight: FontWeight.w400, color: fg),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Name, stats and sample cleanup.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.store});
  final DiaryStore store;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final _name = TextEditingController(text: widget.store.userName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('HI ${store.userName}', style: DD.mono(20)),
          const SizedBox(height: 4),
          Text(
            '${two(store.totalCount)} ENTRIES · ${two(store.days.length)} DAYS',
            style: DD.mono(10, weight: FontWeight.w400, color: DD.mute),
          ),
          const SizedBox(height: 20),
          const _Label('YOUR NAME'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.characters,
            style: DD.mono(15),
            cursorColor: DD.ink,
            decoration: _field('JACK'),
          ),
          const SizedBox(height: 22),
          if (store.hasSamples) ...[
            PillButton(
              'REMOVE_SAMPLE_ENTRIES',
              dark: false,
              onTap: () async {
                await store.removeSamples();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
          PillButton(
            'SAVE',
            onTap: () async {
              await store.setName(_name.text);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

enum EntryAction { edit, delete }

/// Edit / delete for one entry. Delete needs a second tap.
class EntryActionsSheet extends StatefulWidget {
  const EntryActionsSheet({super.key, required this.entry});
  final DiaryEntry entry;

  @override
  State<EntryActionsSheet> createState() => _EntryActionsSheetState();
}

class _EntryActionsSheetState extends State<EntryActionsSheet> {
  bool _confirm = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(e.title.toUpperCase(), style: DD.mono(18), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          'LOGGED ${hms(e.createdAt)} · ${longDate(e.createdAt)}',
          style: DD.mono(10, weight: FontWeight.w400, color: DD.mute),
        ),
        const SizedBox(height: 20),
        PillButton('EDIT', onTap: () => Navigator.of(context).pop(EntryAction.edit)),
        const SizedBox(height: 8),
        PillButton(
          _confirm ? 'TAP_AGAIN_TO_DELETE' : 'DELETE',
          dark: false,
          onTap: () {
            if (_confirm) {
              Navigator.of(context).pop(EntryAction.delete);
            } else {
              setState(() => _confirm = true);
            }
          },
        ),
      ],
    );
  }
}
