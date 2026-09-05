// 应用冒烟测试：验证根组件能正常渲染首页 Dashboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jianli_mobile_app/app/app.dart';

void main() {
  testWidgets('首页渲染冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: JianliApp()));

    // Dashboard 标题与快捷入口区块可见
    // 注：数据库统计依赖 path_provider，测试环境会走错误分支（显示加载/空态），不影响壳渲染
    expect(find.text('渐离'), findsOneWidget);
    expect(find.text('快捷入口'), findsOneWidget);
    // 「效率」同时出现在底部导航与区块标题，至少出现一次即可
    expect(find.text('效率'), findsWidgets);
  });
}
