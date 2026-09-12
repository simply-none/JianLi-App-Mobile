// 复现 + 回归：待办「高级搜索」抽屉点「取消」崩溃
//
// 现象（2026-09-12 真机实踩）：高级搜索抽屉里点「取消」→ 整屏红，
// 断言 `'_dependents.isEmpty': is not true`（framework.dart → InheritedElement.debugDeactivated）。
//
// 本测试的作用：把「崩溃」变成可执行断言 —— 改完再跑，绿了才算修好，
// 而不是靠肉眼看截图。跑法：
//   flutter test test/features/todo/filter_sheet_pop_test.dart
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:jianli_mobile_app/app/theme/app_theme.dart';
import 'package:jianli_mobile_app/features/todo/components/todo_sheets.dart';
import 'package:jianli_mobile_app/features/todo/models/todo_filter.dart';

void main() {
  /// 宿主树与 app.dart 的根结构保持一致（MaterialApp → builder 注入 FTheme/FToaster），
  /// 这样抽屉链路（showFSheet → Sheet → SheetSurface）与线上完全相同。
  Widget harness() => ProviderScope(
    child: MaterialApp(
      builder: (context, child) => FTheme(
        data: AppTheme.light(),
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      home: const _HostPage(),
    ),
  );

  testWidgets('高级搜索抽屉：打开 → 点取消，不应抛异常', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('打开高级搜索'));
    await tester.pumpAndSettle();
    expect(find.text('高级搜索'), findsOneWidget, reason: '抽屉应已弹出');

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '点取消后不应有异常（原崩溃点）');
  });

  testWidgets('高级搜索抽屉：打开 → 点查看结果，不应抛异常', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('打开高级搜索'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看结果'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('高级搜索抽屉：改关键词后点取消，不应抛异常', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('打开高级搜索'));
    await tester.pumpAndSettle();

    // 关键词框有输入 → 走到 controller 的真实使用路径（原以为的崩溃诱因）
    await tester.enterText(find.byType(TextField), '报告');
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showTodoFilterSheet(
          context,
          current: const TodoFilterState(),
          tags: const [],
        ),
        child: const Text('打开高级搜索'),
      ),
    ),
  );
}
