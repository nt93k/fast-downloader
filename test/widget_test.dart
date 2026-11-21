import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fast_downloader/app.dart';

void main() {
  testWidgets('shows the download input and empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const FastDownloaderApp());

    expect(find.text('تنزيل سريع'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('لا توجد تنزيلات بعد'), findsOneWidget);
  });
}
