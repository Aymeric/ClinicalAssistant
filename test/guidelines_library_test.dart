import 'package:clinical_assistant/guidelines/guideline_source.dart';
import 'package:clinical_assistant/guidelines/guidelines_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuidelineCatalog', () {
    test('filters sources by topic and jurisdiction', () {
      final immunization = GuidelineCatalog.filter(
        topic: GuidelineTopic.immunization,
      );
      expect(immunization.map((source) => source.id), [
        'australian-immunisation',
      ]);

      final ukSources = GuidelineCatalog.filter(
        jurisdiction: GuidelineJurisdiction.unitedKingdom,
      );
      expect(ukSources.map((source) => source.id), ['nice-guidance']);
    });

    test('searches source metadata without changing the bundled catalog', () {
      final results = GuidelineCatalog.filter(
        query: '  uspstf  ',
        topic: GuidelineTopic.prevention,
      );

      expect(results.map((source) => source.id), ['uspstf-recommendations']);
      expect(GuidelineCatalog.sources, hasLength(7));
    });

    test('clearly identifies archives and discovery indexes', () {
      final archive = GuidelineCatalog.sources.singleWhere(
        (source) => source.status == GuidelineSourceStatus.archive,
      );
      final discoveryIndexes = GuidelineCatalog.sources
          .where(
            (source) => source.status == GuidelineSourceStatus.discoveryIndex,
          )
          .toList();

      expect(
        archive.statusNote,
        contains('not establish that a recommendation'),
      );
      expect(discoveryIndexes, hasLength(2));
      expect(
        discoveryIndexes.every(
          (source) => source.statusNote.contains('publisher'),
        ),
        isTrue,
      );
    });
  });

  testWidgets('shows provenance and filters guideline sources', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GuidelinesLibraryPage()));
    await tester.pumpAndSettle();
    final guidelineListScrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;

    expect(
      find.textContaining(
        'This is a curated directory, not a complete or live guideline feed.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('guideline-search')));
    await tester.enterText(
      find.byKey(const ValueKey('guideline-search')),
      'NICE',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('NICE guidance'),
      120,
      scrollable: guidelineListScrollable,
    );
    expect(find.text('NICE guidance'), findsOneWidget);
    expect(find.text('WHO guidelines'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('guideline-search')));
    await tester.tap(find.byKey(const ValueKey('guideline-search-clear')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Immunization'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Immunization'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Australian Immunisation Handbook'),
      120,
      scrollable: guidelineListScrollable,
    );
    expect(find.text('Australian Immunisation Handbook'), findsOneWidget);
    expect(find.text('International Guidelines Library'), findsNothing);
  });
}
