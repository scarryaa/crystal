import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockEditorTabManager extends Mock implements EditorTabManager {
  @override
  final List<List<SplitView>> horizontalSplits = [];
}

class MockSplitView extends Mock implements SplitView {
  @override
  final EditorState activeEditor = MockEditorState();
}

class MockEditorState extends Mock implements EditorState {}

void main() {
  late MockEditorTabManager mockTabManager;
  late EditorStateProvider provider;

  setUp(() {
    mockTabManager = MockEditorTabManager();
    provider = EditorStateProvider(editorTabManager: mockTabManager);
  });

  tearDown(() {
    provider.dispose();
  });

  group('EditorStateProvider', () {
    test('getSplitIndex calculates correct index', () {
      mockTabManager.horizontalSplits.addAll([
        List.generate(2, (_) => MockSplitView()),
        List.generate(3, (_) => MockSplitView()),
      ]);

      expect(provider.getSplitIndex(0, 1), equals(1));
      expect(provider.getSplitIndex(1, 0), equals(2));
      expect(provider.getSplitIndex(1, 2), equals(4));
    });

    test('getEditorViewKey returns consistent keys', () {
      final key1 = provider.getEditorViewKey(0, 0);
      final key2 = provider.getEditorViewKey(0, 0);
      final key3 = provider.getEditorViewKey(0, 1);

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('getScrollManager creates and reuses scroll managers', () {
      final manager1 = provider.getScrollManager(0, 0);
      final manager2 = provider.getScrollManager(0, 0);
      final manager3 = provider.getScrollManager(0, 1);

      expect(manager1, equals(manager2));
      expect(manager1, isNot(equals(manager3)));
    });

    // testWidgets('_handleEditorScroll synchronizes scroll positions',
    //     (WidgetTester tester) async {
    //   final mockSplitView = MockSplitView();
    //   mockTabManager.horizontalSplits.add([mockSplitView]);

    //   final scrollManager = provider.getScrollManager(0, 0);

    //   await tester.pumpWidget(
    //     MaterialApp(
    //       home: Scaffold(
    //         body: SingleChildScrollView(
    //           controller: scrollManager.editorVerticalScrollController,
    //           child: Container(height: 1000),
    //         ),
    //       ),
    //     ),
    //   );

    //   await tester.pumpAndSettle();

    //   // Simulate scroll
    //   await tester.drag(
    //       find.byType(SingleChildScrollView), const Offset(0, -100));
    //   await tester.pumpAndSettle();

    //   provider.handleEditorScroll(0, 0);

    //   verify(mockSplitView.activeEditor.updateVerticalScrollOffset(100.0))
    //       .called(1);
    // });

    // testWidgets('_handleGutterScroll synchronizes scroll positions',
    //     (WidgetTester tester) async {
    //   final mockSplitView = MockSplitView();
    //   mockTabManager.horizontalSplits.add([mockSplitView]);

    //   final scrollManager = provider.getScrollManager(0, 0);

    //   await tester.pumpWidget(
    //     MaterialApp(
    //       home: Scaffold(
    //         body: SingleChildScrollView(
    //           controller: scrollManager.gutterScrollController,
    //           child: Container(height: 1000),
    //         ),
    //       ),
    //     ),
    //   );

    //   await tester.pumpAndSettle();

    //   // Simulate scroll
    //   await tester.drag(
    //       find.byType(SingleChildScrollView), const Offset(0, -100));
    //   await tester.pumpAndSettle();

    //   provider.handleGutterScroll(0, 0);

    //   verify(mockSplitView.activeEditor.updateVerticalScrollOffset(100.0))
    //       .called(1);
    // });

    test('getTabBarScrollController creates and reuses scroll controllers', () {
      final controller1 = provider.getTabBarScrollController(0, 0);
      final controller2 = provider.getTabBarScrollController(0, 0);
      final controller3 = provider.getTabBarScrollController(0, 1);

      expect(controller1, equals(controller2));
      expect(controller1, isNot(equals(controller3)));
    });

    test('getTabBarKey returns consistent keys', () {
      final key1 = provider.getTabBarKey(0, 0);
      final key2 = provider.getTabBarKey(0, 0);
      final key3 = provider.getTabBarKey(0, 1);

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });
  });
}
