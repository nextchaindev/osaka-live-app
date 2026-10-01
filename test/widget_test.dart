import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osaka_app/widgets/common/dialog.dart';

void main() {
  testWidgets('permission dialog returns false when dismissed for later',
      (tester) async {
    late Future<bool> result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                result = AppDialog().showPermissionDialog(
                  context,
                  title: 'Storage permission required',
                  message: 'Allow storage access to download files.',
                  icon: Icons.download_outlined,
                );
              },
              child: const Text('Show dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Storage permission required'), findsOneWidget);
    expect(
        find.text('Allow storage access to download files.'), findsOneWidget);

    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });
}
