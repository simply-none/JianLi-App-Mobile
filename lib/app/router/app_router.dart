// 路由表（go_router）—— 对应桌面端 vue-router
//
// 结构：StatefulShellRoute 四分支（首页/效率/内容/工具，底部导航保持各自状态）
//       + 全屏功能路由（从各分组页 push 进入）。
// 转场：全屏 push 路由用 pageBuilder 包 fadeSlidePage（横向滑入+淡入，见
//       lib/app/anim/jianli_transitions.dart）；底部四分支保持 builder，由导航壳
//       以 indexedStack 保持状态，转场在 Phase 2 再精细化（fadePage 已备好）。
import 'package:go_router/go_router.dart';

import '../../features/habit/components/habit_page.dart';
import '../../features/home/components/dashboard_page.dart';
import '../../features/hubs/hub_pages.dart';
import '../../features/notes/components/note_detail_page.dart';
import '../../features/notes/components/note_editor_page.dart';
import '../../features/notes/components/note_list_page.dart';
import '../../features/pomodoro/components/pomodoro_page.dart';
import '../../features/pomodoro/components/pomodoro_records_page.dart';
import '../../features/todo/components/todo_page.dart';
import '../../features/twofactor/components/two_factor_page.dart';
import '../../features/countdown/components/countdown_page.dart';
import '../../features/reminder/components/reminder_list_page.dart';
import '../../features/qr/components/qr_page.dart';
import '../../features/password_vault/components/password_vault_page.dart';
import '../../features/file_vault/components/file_vault_page.dart';
import '../../features/ebook/components/bookshelf_page.dart';
import '../../features/ebook/components/epub_reader_page.dart';
import '../../features/conversation/components/conversation_page.dart';
import '../../features/sync/components/sync_page.dart';
import '../anim/jianli_transitions.dart';
import '../shell/main_shell.dart';

/// 全局路由配置
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ---- 底部导航四分支（保持 builder，导航壳 indexedStack 管理状态） ----
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/efficiency',
              builder: (context, state) => const EfficiencyHubPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/content',
              builder: (context, state) => const ContentHubPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => const ToolsHubPage(),
            ),
          ],
        ),
      ],
    ),
    // ---- 效率 ----
    GoRoute(
      path: '/habit',
      pageBuilder: (context, state) => fadeSlidePage(const HabitPage(), state),
    ),
    GoRoute(
      path: '/todo',
      pageBuilder: (context, state) => fadeSlidePage(const TodoPage(), state),
    ),
    GoRoute(
      path: '/pomodoro',
      pageBuilder: (context, state) =>
          fadeSlidePage(const PomodoroPage(), state),
    ),
    GoRoute(
      path: '/pomodoro/records',
      pageBuilder: (context, state) =>
          fadeSlidePage(const PomodoroRecordsPage(), state),
    ),
    GoRoute(
      path: '/countdown',
      pageBuilder: (context, state) =>
          fadeSlidePage(const CountdownPage(), state),
    ),
    GoRoute(
      path: '/reminders',
      pageBuilder: (context, state) =>
          fadeSlidePage(const ReminderListPage(), state),
    ),
    // ---- 内容 ----
    GoRoute(
      path: '/notes',
      pageBuilder: (context, state) =>
          fadeSlidePage(const NoteListPage(), state),
      routes: [
        GoRoute(
          path: 'edit',
          pageBuilder: (context, state) => fadeSlidePage(
            NoteEditorPage(noteKey: state.uri.queryParameters['noteKey']),
            state,
          ),
        ),
        GoRoute(
          path: ':key',
          pageBuilder: (context, state) => fadeSlidePage(
            NoteDetailPage(noteKey: state.pathParameters['key'] ?? ''),
            state,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/conversation',
      pageBuilder: (context, state) =>
          fadeSlidePage(const ConversationPage(), state),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => fadeSlidePage(
            // highlight：跨主题引用跳转时定位高亮的消息 id（右侧抽屉点入）
            ConversationMessagesPage(
              themeId: state.pathParameters['id'] ?? '',
              highlightId: int.tryParse(
                state.uri.queryParameters['highlight'] ?? '',
              ),
            ),
            state,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/ebook',
      pageBuilder: (context, state) =>
          fadeSlidePage(const BookshelfPage(), state),
      routes: [
        GoRoute(
          path: 'reader',
          pageBuilder: (context, state) => fadeSlidePage(
            EpubReaderPage(filePath: state.uri.queryParameters['path'] ?? ''),
            state,
          ),
        ),
      ],
    ),
    // ---- 工具 ----
    GoRoute(
      path: '/twofactor',
      pageBuilder: (context, state) =>
          fadeSlidePage(const TwoFactorPage(), state),
    ),
    GoRoute(
      path: '/password-vault',
      pageBuilder: (context, state) =>
          fadeSlidePage(const PasswordVaultPage(), state),
    ),
    GoRoute(
      path: '/file-vault',
      pageBuilder: (context, state) =>
          fadeSlidePage(const FileVaultPage(), state),
    ),
    GoRoute(
      path: '/qr',
      pageBuilder: (context, state) => fadeSlidePage(const QrPage(), state),
    ),
    GoRoute(
      path: '/sync',
      pageBuilder: (context, state) => fadeSlidePage(const SyncPage(), state),
    ),
  ],
);
