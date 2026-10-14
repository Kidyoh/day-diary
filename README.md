# Day Diary

A motion-first photo diary built in Flutter, based on the
[reference motion piece](https://www.pinterest.com/pin/211174979741990/)
(by @svet_lanchig). Every entry is a photo, a title, a note and an exact timestamp.

## What it does

**Timeline**
- Entries for the selected day sit in a zig-zag column of big circles. Newest is on top.
- Everything is a circle. Press a photo and it swells into a rounded square; release to open it. Dashed + circles continue the column so there is always a place to add a moment.
- Tap any photo to open it full screen.
- The left side shows the focused entry. The date (`MONDAY 01 MAY`) and title (`PROJECT ASSIGNM ENT`) decode in. The time (`9:PM`) dissolves dot by dot. A pixel globe spins.
- Bottom bar: the scrubber moves through the day, and `07 X` is the number of entries that day.

**Detail**
- Tap the focused entry. It grows as a square, then fills the screen.
- The headline decodes in, using the reference's 9 / 7 / 9 line rhythm (`CALCULATE / D_AZIMU / TH: 345°`).
- The dot-matrix counter shows minutes since the previous entry (`+80`).
- The note types out, with entry metadata (ID, `LOGGED: 21:00:00`, date).
- Overlay text switches between black and white based on how bright the photo is.
- To close: swipe down, use the side-tab button, or press back.

**Controls**
- + in the pill, or any dashed circle: new entry.
- Side tab:
  - Expand / collapse
  - Archive of days
  - New entry from the gallery
- Avatar or ☰: your name, and remove the sample entries.
- Open an entry and long-press the photo: edit or delete it.

**Storage**
- Everything is stored on-device.
- Entries are kept as JSON in `shared_preferences`.
- Photos go in the app documents folder (web keeps them inline).
- First launch shows a splash screen and onboarding (name, optional photo, first moment). The demo edition also seeds a sample day.

## Run

```sh
flutter pub get
flutter run            # iOS / Android device or simulator
flutter run -d chrome  # quick browser preview
flutter test
```

Two editions:

```sh
flutter build apk --release                                      # "Day Diary Demo" (sample day)
flutter build apk --release --dart-define=EMPTY=true -Pempty=true # "Day Diary" (starts empty)
```

The empty edition uses its own app ID (`com.kidyoh.day_diary.empty`), so both can be installed at once.

## Structure

```
lib/
  main.dart                 app entry, immersive mode, theme
  data/                     entry model, store, image persistence (io / web)
  ui/diary_screen.dart      timeline, focus morph, expand transition, detail view
  ui/sheets.dart            compose / archive / profile / entry actions
  ui/widgets/               dot-matrix text, pixel globe, scramble text, pill, side tab, bottom bar
```

Fonts: Space Mono (SIL OFL, `assets/fonts/OFL.txt`).
Sample photos: Unsplash via picsum.photos (Unsplash license).
