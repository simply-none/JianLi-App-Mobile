// 时间 / 日期时间选择抽屉（共享原子）—— 封装 forui 轮式 picker 为底部抽屉
//
// 全 App 的时刻/日期时间录入统一走这里（interaction-patterns §4.6 同源思路：
// 输入一律组件化，禁止再用手写文本框收日期时间）：
//   - [showTimePickerSheet]      纯时刻「时/分」两列独立滚轮（中文单位）→ FPicker 自拼
//   - [showDateTimePickerSheet]  日期时间（一列日期 + 时 + 分）→ FDateTimePicker 轮式（forui 原生，无秒）
//   - [showDateTimeWheelSheet]   年月日时分秒**六列独立滚轮**（中文单位）→ FPicker 自拼（跨年跨月好选）
// 均为三档制抽屉（时刻 = sm 30vh、日期时间 / 六列 = md 50vh）；返回 null = 用户取消。
//
// ⚠️ forui 原生两个 picker 的分隔符**写死、改不了**（`FTimePicker` 用 `:`，`FDateTimePicker`
// 时刻格式写死 `.Hm`）——本 App 要求时刻/日期时间都用中文单位（`08时00分` /
// `2026年 09月 13日 06时 10分 12秒`），故 [showTimePickerSheet] 与 [showDateTimeWheelSheet]
// 都改用公开原语 `FPicker`+`FPickerWheel` 自拼；`FDateTimePicker` 仅剩 [showDateTimePickerSheet]
// 一处（免拆列的简单场景，如二维码参数里的日期时间）。
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'sheet_form.dart';
import 'sheet_surface.dart';

/// 时刻选择抽屉（sm 档 = 30vh，24 小时制「时 / 分」两列独立滚轮）；返回所选 [TimeOfDay]，取消返回 null
///
/// ⚠️ 不用 forui `FTimePicker` 的原因：它两列之间的 `:` 分隔符**写死、改不了**，本 App 要求时刻也走
/// 中文单位（`08时00分`）→ 改用公开原语 `FPicker`+`FPickerWheel` 自拼两列（2026-09-13 用户要求）。
Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  TimeOfDay? initial,
  String title = '选择时间',
}) async {
  final init = initial ?? TimeOfDay.now();
  // 闭包带出「抽屉内的当前值」：确定时直接 pop 它
  var value = TimeOfDay(hour: init.hour, minute: init.minute);
  return showFSheet<TimeOfDay?>(
    context: context,
    side: FLayout.btt,
    // ⚠️ 嵌套抽屉（从其他抽屉内打开）必须走 forui 默认参数路径：
    // 传 mainAxisMaxRatio 会让 ShiftedSheet 走非紧约束 + 尺寸回报路径，
    // 嵌套场景下重入布局直接断言崩溃（2026-09-13 实 crash，镜像
    // showTodoDateTimeSheet 这个已验证可用的嵌套先例）
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.sm,
      // 30vh 抽屉：把滚轮高度压到「可用体高 − 固定头尾（把手+标题+底栏≈144）」内，
      // 避免溢出被拖进中间滚动区、滚轮被夹成可滚动（§一 三档制）。下限 80 兜底极小屏。
      body: SizedBox(
        height: (sheetMaxHeight(c, SheetSize.sm) - 144).clamp(80.0, 420.0),
        child: _TimeWheelBody(
          value: value,
          onChanged: (t) => value = t,
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: '确定',
        onAction: () => Navigator.pop(c, value),
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

/// 年月日时分秒「六列独立滚轮」选择抽屉（md 档，24 小时制）；取消返回 null
///
/// 为什么不用 [showDateTimePickerSheet]：forui 的 `FDateTimePicker` 只有「一列连续日期 + 时 + 分」，
/// 跨月/跨年时要在一条长长的日期列表里一直滚，跨度一大就很难选到目标日期。这里改用 forui 的底层
/// **公开原语** `FPicker` + `FPickerWheel` 自拼 6 列（年 / 月 / 日 / 时 / 分 / 秒 各一列），
/// 任意跨度都能直接拨到位（2026-09-13 用户要求）。
///
/// 列与列之间用**中文单位**做分隔（`年`/`月`/`日 `(后带空格)/`时`/`分`/`秒`），
/// 整体读作「2026年 09月 13日 06时 10分 12秒」（2026-09-13 用户要求把 `-`/`:` 换中文）。
///
/// [firstYear] / [lastYear] 决定年列范围，默认「今年 -10 ~ 今年 +30」；[withSeconds] = false 时只剩 5 列。
Future<DateTime?> showDateTimeWheelSheet(
  BuildContext context, {
  DateTime? initial,
  String title = '选择日期时间',
  int? firstYear,
  int? lastYear,
  bool withSeconds = true,
}) async {
  final now = DateTime.now();
  final from = firstYear ?? now.year - 10;
  final to = lastYear ?? now.year + 30;
  final start = _clampDate(initial ?? now, from, to);
  // 闭包带出「抽屉内的当前值」：确定时直接 pop 它
  var value = start;

  return showFSheet<DateTime?>(
    context: context,
    side: FLayout.btt,
    // ⚠️ 嵌套抽屉（从其他抽屉内打开）必须走 forui 默认参数路径：传 mainAxisMaxRatio 会让
    // ShiftedSheet 走非紧约束 + 尺寸回报路径，嵌套场景重入布局直接断言崩溃（2026-09-13 实 crash，
    // 与上方两个 picker 同一条禁令）
    builder: (c) => SheetScaffold(
      title: title,
      size: SheetSize.md,
      body: SizedBox(
        height: 200,
        child: _DateTimeWheelBody(
          value: start,
          firstYear: from,
          lastYear: to,
          withSeconds: withSeconds,
          onChanged: (v) => value = v,
        ),
      ),
      bottomBar: sheetBottomActions(
        c,
        actionLabel: '确定',
        onAction: () => Navigator.pop(c, value),
      ),
    ),
  );
}

/// 某年某月的天数（「下月第 0 天」即本月最后一天）
int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// 把日期夹进「年列区间 + 当月真实天数」——否则 [DateTime] 会把 2 月 31 日静默归一成 3 月 3 日
DateTime _clampDate(DateTime v, int from, int to) {
  final year = v.year.clamp(from, to);
  return DateTime(
    year,
    v.month,
    v.day.clamp(1, _daysIn(year, v.month)),
    v.hour,
    v.minute,
    v.second,
  );
}

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 一列滚轮（[items] 为展示文本，下标 0 = 列表第一项）；[unit] 也用于读屏单位后缀
FPickerWheel _wheel(String unit, List<String> items, {int flex = 1}) =>
    FPickerWheel(
      flex: flex,
      semanticsLabel: unit,
      semanticsValueBuilder: (index) =>
          index < items.length ? '${items[index]}$unit' : unit,
      children: [for (final s in items) Text(s)],
    );

/// 列间分隔（中文单位，纯装饰，不参与读屏）
Widget _sep(String s) => ExcludeSemantics(child: Text(s));

/// 用 picker 的文本样式量一段文字的宽度
///
/// 用途：forui 的 `FPicker` 会把每个轮子包成 `Flexible` 均分整行（`picker_wheel.dart`），
/// 数字在轮子里居中、中文单位被甩到格边 → 数字和单位之间空一大片（2026-09-13 用户实指「隔得太开」）。
/// 这里量出每列「最长内容」和单位的真实宽度，再用两端固定占位把滚轮压到「刚好够宽」，
/// 数字与单位自然贴在一起。宽度随主题字号 / 系统字体缩放走，不写死像素。
double _textWidth(String text, TextStyle style, TextScaler scale) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scale,
  )..layout();
  return painter.width;
}

/// 六列滚轮本体（有状态：值随滚轮滚动更新）
class _DateTimeWheelBody extends StatefulWidget {
  const _DateTimeWheelBody({
    required this.value,
    required this.firstYear,
    required this.lastYear,
    required this.withSeconds,
    required this.onChanged,
  });

  final DateTime value;
  final int firstYear;
  final int lastYear;
  final bool withSeconds;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DateTimeWheelBody> createState() => _DateTimeWheelBodyState();
}

class _DateTimeWheelBodyState extends State<_DateTimeWheelBody> {
  /// 已提交给 build 的值（决定年/月列位置与「日」列长度）
  late DateTime _value;

  /// 最新值：滚动回调里同步记录，可能领先 [_value] 一帧
  late DateTime _latest;

  @override
  void initState() {
    super.initState();
    _latest = _value = widget.value;
  }

  /// 六列的初始下标（顺序 = 从左到右：年 月 日 时 分 [秒]）
  List<int> get _indexes => [
    _value.year - widget.firstYear,
    _value.month - 1,
    _value.day - 1,
    _value.hour,
    _value.minute,
    if (widget.withSeconds) _value.second,
  ];

  DateTime _decode(List<int> i) {
    final year = widget.firstYear + i[0];
    final month = i[1] + 1;
    // 日先夹到当月真实天数，否则 DateTime(2026, 2, 31) 会被归一成 3 月 3 日
    final day = (i[2] + 1).clamp(1, _daysIn(year, month));
    return DateTime(
      year,
      month,
      day,
      i[3],
      i[4],
      widget.withSeconds ? i[5] : 0,
    );
  }

  void _onIndexes(List<int> i) {
    final next = _decode(i);
    if (next == _latest) return;
    _latest = next;
    // 同步交给外层：确定按钮读的就是它（避免帧末回调还没跑就点了确定）
    widget.onChanged(next);
    // ⚠️ 本回调由 FPicker 的滚动通知同步触发，直接 setState 会和 forui 的滚轮动画/尺寸回报打架
    //（同一个坑 forui 自己在 `_ProxyController` 里用帧末回调规避）→ 延迟到帧末再落状态。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _value != _latest) setState(() => _value = _latest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = context.theme.pickerStyle;
    final scale = MediaQuery.textScalerOf(context);
    // 各列「刚好够宽」：两位数字 + 一点呼吸；年列靠 flex:2 拿到约两倍宽（放得下四位年份）
    final numW = _textWidth('00', style.textStyle, scale) + scale.scale(10);
    final wheelCount = widget.withSeconds ? 6 : 5;
    // 单位分隔符宽度（「日 」含尾部空格，日期与时刻之间留顿挫）
    final units = const ['年', '月', '日 ', '时', '分', '秒'].take(wheelCount);
    final unitTotal = units.fold<double>(
      0,
      (sum, u) => sum + _textWidth(u, style.textStyle, scale),
    );
    final flexSum = wheelCount + 1; // 年列 flex 2 + 其余各 flex 1

    return LayoutBuilder(
      builder: (context, constraints) {
        // 轮子目标总宽：让「其余各列」宽 = numW，则年列（flex 2:1）得 2·numW
        final target = flexSum * numW;
        // 固定占位总量 = 总宽 − 轮子目标宽 − 单位总宽 − 相邻间距（2·wheelCount+2 个孩子）
        final spare = constraints.maxWidth -
            target -
            unitTotal -
            style.spacing * (2 * wheelCount + 1);
        final side = spare > 0 ? spare / 2 : 0.0; // 窄屏 / 大字号时退回 0，宁散不溢出
        return FPicker(
          // 日列长度随年月变化（2 月 28/29 天）→ 换年/换月时换 key 重建 FPicker，让新的
          // `initial` 重新生效（forui 的 managed control 在 update 时**不会**重读 initial）。
          key: ValueKey('${_value.year}-${_value.month}'),
          debugLabel: 'DateTimeWheelPicker',
          control: FPickerControl.managed(initial: _indexes, onChange: _onIndexes),
          children: [
            SizedBox(width: side),
            _wheel(
              '年',
              [for (var y = widget.firstYear; y <= widget.lastYear; y++) '$y'],
              flex: 2,
            ),
            _sep('年'),
            _wheel('月', [for (var m = 1; m <= 12; m++) _pad2(m)]),
            _sep('月'),
            _wheel('日', [
              for (var d = 1; d <= _daysIn(_value.year, _value.month); d++) _pad2(d),
            ]),
            // 「日」与「时」之间留一个空格，日期与时刻读起来有顿挫
            _sep('日 '),
            _wheel('时', [for (var h = 0; h < 24; h++) _pad2(h)]),
            _sep('时'),
            _wheel('分', [for (var m = 0; m < 60; m++) _pad2(m)]),
            _sep('分'),
            if (widget.withSeconds) ...[
              _wheel('秒', [for (var s = 0; s < 60; s++) _pad2(s)]),
              _sep('秒'),
            ],
            SizedBox(width: side),
          ],
        );
      },
    );
  }
}

/// 「时 / 分」两列滚轮本体（有状态：值随滚轮滚动更新）——列间用中文单位，读作「08时00分」
///
/// 与 [_DateTimeWheelBody] 同构，但不含年/月/日/秒，也不需要「列长度变化换 key」那套
/// （时恒 24 项、分恒 60 项，长度固定）。
class _TimeWheelBody extends StatefulWidget {
  const _TimeWheelBody({required this.value, required this.onChanged});

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<_TimeWheelBody> createState() => _TimeWheelBodyState();
}

class _TimeWheelBodyState extends State<_TimeWheelBody> {
  /// 已提交给 build 的值（决定两列位置）
  late TimeOfDay _value;

  /// 最新值：滚动回调里同步记录，可能领先 [_value] 一帧
  late TimeOfDay _latest;

  @override
  void initState() {
    super.initState();
    _latest = _value = widget.value;
  }

  /// 两列初始下标（顺序 = 从左到右：时、分）
  List<int> get _indexes => [_value.hour, _value.minute];

  void _onIndexes(List<int> i) {
    final next = TimeOfDay(hour: i[0], minute: i[1]);
    if (next == _latest) return;
    _latest = next;
    // 同步交给外层：确定按钮读的就是它（避免帧末回调还没跑就点了确定）
    widget.onChanged(next);
    // ⚠️ 与 [_DateTimeWheelBodyState] 同一条禁忌：滚动回调由 FPicker 同步触发，直接 setState
    // 会和 forui 的滚轮动画/尺寸回报打架 → 延迟到帧末再落状态（forui 自己用帧末回调规避同一坑）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _value != _latest) setState(() => _value = _latest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = context.theme.pickerStyle;
    final scale = MediaQuery.textScalerOf(context);
    // 每个轮子「刚好够宽」= 两位数字 + 一点呼吸；再用两端固定占位把整行压回来，
    // 避免 Flexible 均分整行把数字与单位拉开（详见 _textWidth 注释）
    final wheelW = _textWidth('00', style.textStyle, scale) + scale.scale(10);
    final hourUnitW = _textWidth('时', style.textStyle, scale);
    final minUnitW = _textWidth('分', style.textStyle, scale);
    final midGap = scale.scale(16); // 「时」簇与「分」簇之间的间隙

    return LayoutBuilder(
      builder: (context, constraints) {
        // 固定占位总量 = 总宽 − 两轮目标宽 − 两个单位宽 − 6 段相邻间距（共 7 个孩子）
        final spare = constraints.maxWidth -
            2 * wheelW -
            hourUnitW -
            minUnitW -
            midGap -
            style.spacing * 6;
        final side = spare > 0 ? spare / 2 : 0.0; // 窄屏 / 大字号时退回 0，宁散不溢出
        return FPicker(
          debugLabel: 'TimeWheelPicker',
          control: FPickerControl.managed(initial: _indexes, onChange: _onIndexes),
          children: [
            SizedBox(width: side),
            _wheel('时', [for (var h = 0; h < 24; h++) _pad2(h)], flex: 1),
            _sep('时'),
            SizedBox(width: midGap),
            _wheel('分', [for (var m = 0; m < 60; m++) _pad2(m)], flex: 1),
            _sep('分'),
            SizedBox(width: side),
          ],
        );
      },
    );
  }
}
