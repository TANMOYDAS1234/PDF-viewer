// Basic smoke test for PDF Viewer Pro.
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_viewer_pro/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PdfViewerApp());
    await tester.pump();
  });
}
