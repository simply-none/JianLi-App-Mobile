// 清除浏览数据页（/browser/clear-data）
//
// 与「设置」分组的入口对应。四类数据 + 时间范围：
//   · 浏览历史      → drift（**支持时间范围**）
//   · Cookie / 站点数据 → CookieManager（无时间范围 API，一律全清）
//   · 缓存文件      → WebView 缓存（无时间范围 API）
//   · 本地存储      → WebStorage（localStorage / IndexedDB，无时间范围 API）
// 时间范围只对历史生效 —— 这一点在页面上明确写出来，避免用户以为「清了最近 7 天」
// 而实际 Cookie 全没了。
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/segmented.dart';
import '../../../app/ui/sheet_form.dart';
import '../components/browser_subpage.dart';
import '../components/settings_tiles.dart';
import '../providers/browser_providers.dart';

/// 时间范围（只对「浏览历史」生效）
enum _Range {
  all('全部时间'),
  today('今天'),
  week('最近 7 天'),
  month('最近 30 天');

  const _Range(this.label);

  final String label;
}

class BrowserClearDataPage extends ConsumerStatefulWidget {
  const BrowserClearDataPage({super.key});

  @override
  ConsumerState<BrowserClearDataPage> createState() =>
      _BrowserClearDataPageState();
}

class _BrowserClearDataPageState extends ConsumerState<BrowserClearDataPage> {
  _Range _range = _Range.all;
  bool _history = true;
  bool _cookies = true;
  bool _cache = false;
  bool _storage = false;
  bool _busy = false;

  /// 时间范围对应的「清到什么时候为止」（null = 全清）
  int? get _cutoff {
    final now = DateTime.now();
    switch (_range) {
      case _Range.all:
        return null;
      case _Range.today:
        return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      case _Range.week:
        return now
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
      case _Range.month:
        return now
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
    }
  }

  bool get _nothingSelected => !_history && !_cookies && !_cache && !_storage;

  Future<void> _run() async {
    if (_busy || _nothingSelected) return;
    final ok = await showSheetConfirm(
      context,
      title: '清除浏览数据',
      message: _history && _range != _Range.all
          ? '将清除所选数据。注意：时间范围只作用于浏览历史，'
                'Cookie / 缓存 / 本地存储会全部清除。该操作不可撤销。'
          : '将清除所选数据，不可撤销。',
      confirmLabel: '清除',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(browserRepositoryProvider);
    final failed = <String>[];

    if (_history) {
      final cutoff = _cutoff;
      if (cutoff == null) {
        await repo.clearHistory();
      } else {
        await repo.clearHistoryBefore(cutoff);
      }
    }
    if (_cookies) {
      try {
        await CookieManager.instance().deleteAllCookies();
      } catch (_) {
        failed.add('Cookie');
      }
    }
    if (_cache) {
      try {
        await InAppWebViewController.clearAllCache();
      } catch (_) {
        failed.add('缓存');
      }
    }
    if (_storage) {
      try {
        await WebStorageManager.instance().deleteAllData();
      } catch (_) {
        failed.add('本地存储');
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    showFToast(
      context: context,
      variant: failed.isEmpty
          ? FToastVariant.primary
          : FToastVariant.destructive,
      title: Text(
        failed.isEmpty ? '已清除所选数据' : '部分项目清除失败：${failed.join('、')}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return BrowserSubPage(
      title: '清除浏览数据',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.pagePadding,
          4,
          AppTokens.pagePadding,
          AppTokens.pageBottomGapOf(context),
        ),
        children: [
          const SettingsGroupLabel('时间范围'),
          JianliSegmented(
            items: [for (final r in _Range.values) (null, r.label)],
            selected: _Range.values.indexOf(_range),
            onSelect: (i) => setState(() => _range = _Range.values[i]),
          ),
          const SizedBox(height: 10),
          Text(
            '时间范围只作用于「浏览历史」；其它项没有按时间清理的系统接口，会全部清除。',
            style: t.typography.body.xs.copyWith(
              fontSize: 12,
              height: 1.5,
              color: t.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          const SettingsGroupLabel('要清除的内容'),
          SettingsSection(
            title: '',
            children: [
              _CheckRow(
                label: '浏览历史',
                hint: '访问过的地址与次数',
                icon: FLucideIcons.history,
                value: _history,
                onChange: (v) => setState(() => _history = v),
              ),
              _CheckRow(
                label: 'Cookie 及站点数据',
                hint: '会使各站点登录状态失效',
                icon: FLucideIcons.globeLock,
                value: _cookies,
                onChange: (v) => setState(() => _cookies = v),
              ),
              _CheckRow(
                label: '缓存文件',
                hint: '可释放磁盘空间，下次访问会重新下载',
                icon: FLucideIcons.hardDrive,
                value: _cache,
                onChange: (v) => setState(() => _cache = v),
              ),
              _CheckRow(
                label: '本地存储',
                hint: 'localStorage / IndexedDB 等站点持久化数据',
                icon: FLucideIcons.database,
                value: _storage,
                onChange: (v) => setState(() => _storage = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: _busy ? '清除中…' : '清除所选数据',
            icon: FLucideIcons.trash2,
            onPress: (_busy || _nothingSelected) ? null : _run,
          ),
          if (_nothingSelected) ...[
            const SizedBox(height: 10),
            Text(
              '请至少选择一项',
              textAlign: TextAlign.center,
              style: t.typography.body.xs.copyWith(
                fontSize: 12,
                color: t.colors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 勾选行（自绘 22×22 勾选框 —— 不引入原生 Checkbox，避开「缺 Material 祖先」的坑）
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.onChange,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return GestureDetector(
      onTap: () => onChange(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: t.colors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.typography.body.sm.copyWith(
                      fontSize: 15,
                      color: t.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      color: t.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: AppTokens.fast,
              curve: AppTokens.standard,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: value ? AppTokens.primaryGradient(context) : null,
                color: value ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value ? t.colors.primary : t.colors.border,
                ),
              ),
              child: value
                  ? const Icon(
                      FLucideIcons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
