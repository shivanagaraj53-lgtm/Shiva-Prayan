import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';
import 'package:prayan_trading_journal/features/trade/screenshot_strip.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// Chart screenshots: stored, decoded, and rendered.
///
/// The one part a test cannot reach is the operating system's photo picker, so
/// everything downstream of it is covered here — the upload, the data URI it
/// produces, the decode, and what the strip shows when the bytes are missing.
/// What remains unverified is a tap on a real device opening a real gallery,
/// and that is stated rather than implied.
///
/// A 1x1 PNG: small enough to inline, real enough to decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
  'IQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(LocalStore, LocalAttachmentRepository)> store() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = LocalStore(await SharedPreferences.getInstance());
    return (s, LocalAttachmentRepository(s));
  }

  Widget host(LocalStore s, List<String> ids) => ProviderScope(
        overrides: [
          attachmentRepositoryProvider
              .overrideWithValue(LocalAttachmentRepository(s)),
          currentUserIdProvider.overrideWithValue('user'),
        ],
        child: MaterialApp(
          theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
          home: Scaffold(
            body: ScreenshotStrip(
              attachmentIds: ids,
              onAdded: (_) {},
              onRemoved: (_) {},
            ),
          ),
        ),
      );

  test('an upload round-trips through a data URI', () async {
    final (_, repo) = await store();
    final id = await repo.upload('user', _png,
        filename: 'chart.png', contentType: 'image/png');

    final uri = await repo.resolveUrl(id);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'data');
    expect(UriData.fromUri(uri).contentAsBytes(), _png,
        reason: 'the bytes that came back are not the bytes that went in');
  });

  test('deleting an attachment leaves nothing behind', () async {
    final (_, repo) = await store();
    final id = await repo.upload('user', _png,
        filename: 'chart.png', contentType: 'image/png');
    await repo.delete(id);
    expect(await repo.resolveUrl(id), isNull);
  });

  testWidgets('a stored screenshot renders as a thumbnail', (tester) async {
    final (s, repo) = await store();
    final id = await repo.upload('user', _png,
        filename: 'chart.png', contentType: 'image/png');

    await tester.pumpWidget(host(s, [id]));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing attachment shows a broken image, not a crash',
      (tester) async {
    // An id whose bytes are gone is entirely possible — a delete that raced a
    // save, a store trimmed by the platform. The trade must still open.
    final (s, _) = await store();
    await tester.pumpWidget(host(s, ['att_does_not_exist']));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the add button disappears once the cap is reached',
      (tester) async {
    final (s, _) = await store();
    final ids = List.generate(ScreenshotStrip.maxPerTrade, (i) => 'att_$i');
    await tester.pumpWidget(host(s, ids));
    await tester.pumpAndSettle();

    expect(find.text('Add chart'), findsNothing);
    expect(find.textContaining('enough for one trade'), findsOneWidget);
  });

  testWidgets('with none attached the only thing shown is how to add one',
      (tester) async {
    final (s, _) = await store();
    await tester.pumpWidget(host(s, const []));
    await tester.pumpAndSettle();
    expect(find.text('Add chart'), findsOneWidget);
  });

  test('images are downscaled before they are stored', () {
    // Not a preference: attachments live in the same preferences file as every
    // other document, and a raw phone screenshot is two or three megabytes
    // before base64 adds a third. A few of those would stall every read.
    expect(ScreenshotStrip.maxDimension, lessThanOrEqualTo(1600));
    expect(ScreenshotStrip.quality, lessThan(85));
    expect(ScreenshotStrip.maxPerTrade, lessThanOrEqualTo(8));
  });
}
