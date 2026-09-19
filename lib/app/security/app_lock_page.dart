// P1-1 应用锁解锁页 —— 全屏拦截层（PopScope 禁返回，生物识别通过才能走）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../anim/jianli_haptics.dart';
import '../theme/app_theme.dart';
import '../ui/tap_scale.dart';
import 'app_lock.dart';

/// 解锁页（/app-lock，NoTransitionPage）：锁定期间覆盖全 App，禁返回手势
class AppLockPage extends ConsumerStatefulWidget {
  const AppLockPage({super.key});

  @override
  ConsumerState<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends ConsumerState<AppLockPage> {
  String? _error;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    // 进页自动弹一次认证（多数场景一次指纹即过）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final err = await ref.read(appLockControllerProvider.notifier).unlock();
    if (!mounted) return;
    if (err == null) {
      haptic(HapticType.success, context);
      context.pop(); // 解锁成功退拦截层
      return;
    }
    setState(() {
      _authenticating = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return PopScope(
      canPop: false, // 锁定期禁返回手势/返回键
      child: Scaffold(
        backgroundColor: t.colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 76dp 主色渐变圆盘 + 白锁图标（对齐响铃页徽章语言）
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppTokens.primaryGradient(context),
                  shape: BoxShape.circle,
                  boxShadow: AppTokens.elevation(context, level: 2),
                ),
                child: const Icon(
                  FLucideIcons.lockKeyhole,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '渐离App 已锁定',
                style: t.typography.body.lg.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: t.colors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '验证生物识别后继续使用',
                style: t.typography.body.sm.copyWith(
                  color: t.colors.mutedForeground,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.body.xs.copyWith(
                      fontSize: 12,
                      color: t.colors.destructive,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TapScale(
                onTap: _authenticate,
                haptic: HapticType.medium,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: AppTokens.primaryGradient(context),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    boxShadow: AppTokens.elevation(context, level: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_authenticating)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          FLucideIcons.fingerprint,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _authenticating ? '等待验证…' : '生物识别解锁',
                        style: t.typography.body.md.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
