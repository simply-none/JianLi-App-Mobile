// 待办显示风格（列表 / 卡片 / 日历）—— 画布「09 待办·设置 显示风格」的三选一
//
// 独立成文件的原因：页面（todo_page）与弹层（todo_sheets）都要用这个枚举，
// 放在页面里会让两者互相 import。持久化同放此处，键 `todo.viewMode`。
import 'package:shared_preferences/shared_preferences.dart';

/// 显示风格
enum TodoViewMode { list, card, calendar }

/// 显示风格的字面量与说明（画布 09 三个选项：☰ 列表 / ▦ 卡片 / ▤ 日历）
const List<(TodoViewMode, String, String)> kTodoViewModeOptions = [
  (TodoViewMode.list, '列表', '紧凑三行，信息密度最高'),
  (TodoViewMode.card, '卡片', '卡片网格，视觉优先'),
  (TodoViewMode.calendar, '日历', '按月历查看到期分布'),
];

/// 显示风格持久化（shared_preferences）
abstract final class TodoViewModeStore {
  static const _key = 'todo.viewMode';

  static Future<TodoViewMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    return TodoViewMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => TodoViewMode.list,
    );
  }

  static Future<void> save(TodoViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
