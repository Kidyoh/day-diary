import 'package:day_diary/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hardWrap matches the reference timeline label', () {
    expect(hardWrap('PROJECT ASSIGNMENT', 7), 'PROJECT\nASSIGNM\nENT');
  });

  test('breakAll matches the reference headline rhythm', () {
    expect(breakAll('CALCULATED_AZIMUTH: 345°'), 'CALCULATE\nD_AZIMU\nTH: 345°');
  });

  test('clock drops minutes on the hour', () {
    expect(clock(DateTime(2026, 5, 1, 21)), '9:PM');
    expect(clock(DateTime(2026, 5, 1, 9, 41)), '9:41AM');
    expect(clock(DateTime(2026, 5, 1, 0, 5)), '12:05AM');
  });

  test('stackedDate', () {
    expect(stackedDate(DateTime(2026, 5, 4)), 'MONDAY\n04\nMAY');
  });
}
