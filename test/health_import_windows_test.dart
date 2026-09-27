import 'package:clinical_assistant/integrations/health_import_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partitions history into ten-year windows without gaps or overlap', () {
    final since = DateTime(1900, 1, 1, 12);
    final until = DateTime(2026, 9, 26, 12);

    final windows = buildHealthImportWindows(
      since: since,
      until: until,
      batchYears: 10,
    );

    expect(windows, hasLength(13));
    expect(windows.first.start, DateTime(1900, 1, 1));
    expect(windows.first.end, DateTime(1910, 1, 1));
    expect(windows.last.end, until);
    for (var index = 0; index < windows.length; index++) {
      final window = windows[index];
      expect(window.end.isAfter(window.start), isTrue);
      final nextTenYearBoundary = DateTime(
        window.start.year + 10,
        window.start.month,
        window.start.day,
      );
      expect(
        window.end.isBefore(nextTenYearBoundary) ||
            window.end.isAtSameMomentAs(nextTenYearBoundary),
        isTrue,
      );
      expect(
        window.start,
        DateTime(window.start.year, window.start.month, window.start.day),
      );
      if (index > 0) {
        expect(window.start, windows[index - 1].end);
      }
    }
  });

  test('returns no windows when the requested range is empty', () {
    expect(
      buildHealthImportWindows(
        since: DateTime(2026, 9, 26),
        until: DateTime(2026, 9, 26),
        batchYears: 10,
      ),
      isEmpty,
    );
  });

  test('rejects a non-positive batch length', () {
    expect(
      () => buildHealthImportWindows(
        since: DateTime(2026, 9, 1),
        until: DateTime(2026, 9, 2),
        batchYears: 0,
      ),
      throwsArgumentError,
    );
  });
}
