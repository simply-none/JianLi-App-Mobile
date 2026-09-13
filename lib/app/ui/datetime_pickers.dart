// 时间 / 日期时间选择抽屉（共享原子）—— 封装 forui 轮式 picker 为底部抽屉
//
// 全 App 的时刻/日期时间录入统一走这里（interaction-patterns §4.6 同源思路：
// 输入一律组件化，禁止再用手写文本框收日期时间）：
//   - [showTimePickerSheet]     纯时刻（HH:mm）→ FTimePicker 轮式
//   - [showDateTimePickerSheet] 日期时间（含日期轮）→ FDateTimePicker 轮式
// 均为三档制抽屉：时间 = md（50vh，2026-09-13 定）/ 日期时间 = md；返回 null = 用户取消。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'sheet_form.dart';
import 'sheet_surface.dart';

/// 时间选择抽屉（md 档 = 50vh，24 小时制轮式）；返回所选 [TimeOfDay]，取消返回 null
Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  TimeOfDay? initial,
  String title = '选择时间',
}) async {
  FTime? picked;
  final init = initial ?? TimeOfDay.now();
  return showFSheet<TimeOfDay?>(
    context: context,
    side: FLayout.btt,
    // ⚠️ 嵌套抽屉（从其他抽屉内打开）必须走 forui 默认参数路径：
    // 传 mainAxisMaxRatio 会让 ShiftedSheet 走非紧约束 + 尺寸回报路径，
    // 嵌套场景下重入布局直接断言崩溃（2026-09-13 实 crash，镜像
    // showTodoDateTimeSheet 这个已验证可用的嵌套先例）
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.md,
      body: SizedBox(
        height: 160,
        child: FTimePicker(
          hour24: true,
          control: FTimePickerControl.managed(
            controller: FTimePickerController(
              time: FTime(init.hour, init.minute),
            ),
            onChange: (t) => picked = t,
          ),
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: '确定',
        onAction: () {
          final t = picked;
          Navigator.pop(
            c,
            t == null ? null : TimeOfDay(hour: t.hour, minute: t.minute),
          );
        },
      ),
    ),
  );
}

/// 日期时间选择抽屉（md 档，24 小时制轮式：日期/时/分）；取消返回 null
Future<DateTime?> showDateTimePickerSheet(
  BuildContext context, {
  DateTime? initial,
  String title = '选择日期时间',
}) async {
  DateTime? picked;
  return showFSheet<DateTime?>(
    context: context,
    side: FLayout.btt,
    // ⚠️ 嵌套抽屉（从其他抽屉内打开）必须走 forui 默认参数路径：
    // 传 mainAxisMaxRatio 会让 ShiftedSheet 走非紧约束 + 尺寸回报路径，
    // 嵌套场景下重入布局直接断言崩溃（2026-09-13 实 crash，镜像
    // showTodoDateTimeSheet 这个已验证可用的嵌套先例）
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.md,
      body: SizedBox(
        height: 200,
        child: FDateTimePicker(
          hour24: true,
          control: FDateTimePickerControl.managed(
            controller: FDateTimePickerController(
              dateTime: initial ?? DateTime.now(),
            ),
            onChange: (dt) => picked = dt,
          ),
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: '确定',
        onAction: () => Navigator.pop(c, picked),
      ),
    ),
  );
}
