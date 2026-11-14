// TEMPORARY: verifies the issue countdown / auto-cancel / resolve flow.
import 'dart:io';

import 'package:dyspatch_rider/Features/Home/Screen/activity/activity_screen.dart';
import 'package:dyspatch_rider/Features/Home/Screen/activity/issue_order_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:dyspatch_rider/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _app(Widget home, {double scale = 1}) => ChangeNotifierProvider(
  create: (_) => ThemeProvider(),
  child: MaterialApp(
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: home),
  ),
);

ActivityOrder _issue(Duration left) => ActivityOrder(
  route: 'Ring Rd → Textile Mill Rd',
  pickupLocation: 'Benin Agro Mart',
  amount: '',
  orderId: '#BN4821',
  reportText: 'Report: Wrong pickup address',
  autoCancelAt: DateTime.now().add(left),
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('Montserrat');
    for (final f in Directory('assets/fonts').listSync()) {
      if (f.path.endsWith('.ttf')) {
        loader.addFont(
          Future.value(ByteData.view(File(f.path).readAsBytesSync().buffer)),
        );
      }
    }
    await loader.load();
  });

  testWidgets('countdown ticks and auto-cancels when unresolved', (t) async {
    var cancelled = false;
    await t.pumpWidget(_app(IssueOrderDetailsScreen(
      order: _issue(const Duration(seconds: 3, milliseconds: 500)),
      onAutoCancel: () => cancelled = true,
    )));
    await t.pump();
    // ignore: avoid_print
    print('TEXTS: ' + t.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | '));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(cancelled, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('resolving stops the auto-cancel', (t) async {
    var cancelled = false;
    bool? resolved;
    await t.pumpWidget(_app(IssueOrderDetailsScreen(
      order: _issue(const Duration(seconds: 2)),
      onAutoCancel: () => cancelled = true,
      onResolvedChanged: (v) => resolved = v,
    )));
    await t.pump();
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(resolved, isTrue);
    await t.pump(const Duration(seconds: 3));
    expect(cancelled, isFalse);
    expect(find.textContaining('Issue resolved'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('no overflow at 320 wide @${scale}x', (t) async {
      final errors = <String>[];
      final orig = FlutterError.onError;
      FlutterError.onError = (d) {
        final s = d.toString();
        if (s.contains('overflowed')) {
          errors.add((RegExp(r'lib/[^\s:]+\.dart:\d+').firstMatch(s)?.group(0) ?? '') + ' ' + (RegExp(r'overflowed by [\d.]+ pixels on the \w+').firstMatch(s)?.group(0) ?? ''));
        }
      };
      t.view.physicalSize = const Size(320, 1600);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(_app(
        IssueOrderDetailsScreen(order: _issue(const Duration(minutes: 9))),
        scale: scale,
      ));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(_app(const ActivityScreen(), scale: scale));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Issues').first);
      await t.pump(const Duration(milliseconds: 300));
      t.takeException();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      FlutterError.onError = orig;
      t.view.reset();
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
}
