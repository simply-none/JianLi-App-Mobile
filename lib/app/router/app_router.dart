// 路由表（go_router）—— 对应桌面端 vue-router
//
// 结构：StatefulShellRoute 四分支（首页/效率/内容/工具，底部导航保持各自状态）
//       + 全屏功能路由（从各分组页 push 进入）。
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
import '../shell/main_shell.dart';

/// 全局路由配置
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ---- 底部导航四分支 ----
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/efficiency', builder: (context, state) => const EfficiencyHubPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/content', builder: (context, state) => const ContentHubPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/tools', builder: (context, state) => const ToolsHubPage()),
        ]),
      ],
    ),
    // ---- 效率 ----
    GoRoute(path: '/habit', builder: (context, state) => const HabitPage()),
    GoRoute(path: '/todo', builder: (context, state) => const TodoPage()),
    GoRoute(path: '/pomodoro', builder: (context, state) => const PomodoroPage()),
    GoRoute(path: '/pomodoro/records', builder: (context, state) => const PomodoroRecordsPage()),
    GoRoute(path: '/countdown', builder: (context, state) => const CountdownPage()),
    GoRoute(path: '/reminders', builder: (context, state) => const ReminderListPage()),
    // ---- 内容 ----
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NoteListPage(),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              NoteEditorPage(noteKey: state.uri.queryParameters['noteKey']),
        ),
        GoRoute(
          path: ':key',
          builder: (context, state) =>
              NoteDetailPage(noteKey: state.pathParameters['key'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/conversation',
      builder: (context, state) => const ConversationPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              ConversationMessagesPage(themeId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/ebook',
      builder: (context, state) => const BookshelfPage(),
      routes: [
        GoRoute(
          path: 'reader',
          builder: (context, state) =>
              EpubReaderPage(filePath: state.uri.queryParameters['path'] ?? ''),
        ),
      ],
    ),
    // ---- 工具 ----
    GoRoute(path: '/twofactor', builder: (context, state) => const TwoFactorPage()),
    GoRoute(path: '/password-vault', builder: (context, state) => const PasswordVaultPage()),
    GoRoute(path: '/file-vault', builder: (context, state) => const FileVaultPage()),
    GoRoute(path: '/qr', builder: (context, state) => const QrPage()),
    GoRoute(path: '/sync', builder: (context, state) => const SyncPage()),
  ],
);
