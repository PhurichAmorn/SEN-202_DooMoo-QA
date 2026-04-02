import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/responsive.dart';

void main() {
  group('test responsive utils', () {
    testWidgets(
        'where screen dimensions are queried then it returns correct values',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveUtils.screenWidth(context), 800);
              expect(ResponsiveUtils.screenHeight(context), 600);
              expect(ResponsiveUtils.width(context, 50), 400);
              expect(ResponsiveUtils.height(context, 10), 60);
              expect(ResponsiveUtils.isTablet(context), isTrue);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets(
        'where safe area and status bar are queried then it returns correct values',
        (tester) async {
      const padding = EdgeInsets.only(top: 40, bottom: 20);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: padding),
            child: Builder(
              builder: (context) {
                expect(ResponsiveUtils.safeAreaPadding(context), padding);
                expect(ResponsiveUtils.statusBarHeight(context), 40);
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('where fontSize is queried then it scales based on base width',
        (tester) async {
      // 800 / 375 = 2.1333
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                  ResponsiveUtils.fontSize(context, 10), closeTo(21.33, 0.01));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets(
        'where responsivePadding is called with various options then it calculates correctly',
        (tester) async {
      // Scale factor = 800 / 375 = 2.1333
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final p1 = ResponsiveUtils.responsivePadding(context, all: 10);
              expect(p1.left, closeTo(21.33, 0.01));

              final p2 = ResponsiveUtils.responsivePadding(context,
                  horizontal: 10, vertical: 5);
              expect(p2.left, closeTo(21.33, 0.01));
              expect(p2.top, closeTo(10.66, 0.01));

              final p3 = ResponsiveUtils.responsivePadding(context,
                  left: 1, top: 2, right: 3, bottom: 4);
              expect(p3.left, closeTo(2.13, 0.01));
              expect(p3.top, closeTo(4.26, 0.01));
              expect(p3.right, closeTo(6.40, 0.01));
              expect(p3.bottom, closeTo(8.53, 0.01));

              return Container();
            },
          ),
        ),
      );
    });
  });
}
