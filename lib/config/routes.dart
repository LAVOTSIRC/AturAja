import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../providers/app_provider.dart';
import '../screens/brain_dump_finance_screen.dart';
import '../screens/budget_limit_screen.dart';
import '../screens/category_detail_screen.dart';
import '../screens/cloud_backup_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/nlp_simulation_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/privacy_security_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/task_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String finance = '/finance';
  static const String tasks = '/tasks';
  static const String profile = '/profile';
  static const String scan = '/scan';
  static const String brainDump = '/brain-dump';
  static const String taskForm = '/tasks/form';
  static const String taskDetail = '/tasks/detail';
  static const String financeCategory = '/finance/category';
  static const String notificationSettings = '/settings/notifications';
  static const String cloudBackup = '/settings/cloud-backup';
  static const String budgetLimit = '/settings/budget-limit';
  static const String nlpSimulation = '/settings/nlp-simulation';
  static const String privacySecurity = '/settings/privacy-security';
}

GoRouter createAppRouter({String initialLocation = AppRoutes.splash}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) {
          return LoginScreen(
            onLogin: () {
              context.read<AppProvider>().setLoggedIn(true);
              context.go(AppRoutes.home);
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (BuildContext context, GoRouterState state) =>
            const ScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.brainDump,
        builder: (BuildContext context, GoRouterState state) =>
            const BrainDumpFinanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskForm,
        builder: (BuildContext context, GoRouterState state) {
          final AppProvider app = context.read<AppProvider>();
          final TaskItem? task = state.extra as TaskItem?;
          return TaskFormScreen(
            taskToEdit: task,
            nextTaskId: app.nextTaskId,
            onSave: (TaskItem saved) {
              final bool isUpdate = app.tasks.any(
                (TaskItem item) => item.id == saved.id,
              );
              app.upsertTask(saved);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    isUpdate
                        ? 'Tugas berhasil diperbarui.'
                        : 'Tugas berhasil ditambahkan.',
                  ),
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (BuildContext context, GoRouterState state) {
          final AppProvider app = context.read<AppProvider>();
          final TaskItem task = state.extra as TaskItem;
          return TaskDetailScreen(
            task: task,
            onToggleDone: () => app.toggleTask(task.id),
            onEdit: () => context.push(AppRoutes.taskForm, extra: task),
            onDelete: () => app.deleteTask(task.id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.financeCategory,
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, dynamic> args = state.extra as Map<String, dynamic>;
          final AppProvider app = context.read<AppProvider>();
          return CategoryDetailScreen(
            categoryLabel: args['label'] as String,
            categoryColor: args['color'] as Color,
            transactions: args['transactions'] as List<TransactionItem>,
            onTransactionUpdated: (TransactionItem updated) {
              final int index = transactionStore.indexWhere(
                (TransactionItem item) => item.id == updated.id,
              );
              if (index >= 0) {
                transactionStore[index] = updated;
                app.transactionsChanged();
              }
            },
            onTransactionDeleted: (int id) {
              transactionStore.removeWhere(
                (TransactionItem item) => item.id == id,
              );
              app.transactionsChanged();
            },
            onTransactionRestored: (TransactionItem restored) {
              transactionStore.insert(0, restored);
              app.transactionsChanged();
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (BuildContext context, GoRouterState state) {
          return NotificationSettingsScreen(
            settings: context.read<AppProvider>().settings,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.cloudBackup,
        builder: (BuildContext context, GoRouterState state) {
          return CloudBackupScreen(
            settings: context.read<AppProvider>().settings,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.budgetLimit,
        builder: (BuildContext context, GoRouterState state) {
          return BudgetLimitScreen(
            settings: context.read<AppProvider>().settings,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.nlpSimulation,
        builder: (BuildContext context, GoRouterState state) {
          return NlpSimulationScreen(
            settings: context.read<AppProvider>().settings,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacySecurity,
        builder: (BuildContext context, GoRouterState state) {
          return PrivacySecurityScreen(
            settings: context.read<AppProvider>().settings,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return MainShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) {
                  return Consumer<AppProvider>(
                    builder: (BuildContext context, AppProvider app, _) {
                      return HomeScreen(
                        onScan: () => context.push(AppRoutes.scan),
                        onAddTask: () => context.push(AppRoutes.taskForm),
                        onBrainDump: () => _openBrainDump(context),
                        onViewFinance: () => context.go(AppRoutes.finance),
                        onViewTasks: () => context.go(AppRoutes.tasks),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.finance,
                builder: (BuildContext context, GoRouterState state) {
                  return Consumer<AppProvider>(
                    builder: (BuildContext context, AppProvider app, _) {
                      return FinanceScreen(
                        onScan: () => context.push(AppRoutes.scan),
                        onTransactionsChanged: app.transactionsChanged,
                      );
                    },
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.tasks,
                builder: (BuildContext context, GoRouterState state) {
                  return Consumer<AppProvider>(
                    builder: (BuildContext context, AppProvider app, _) {
                      return TaskScreen(
                        tasks: app.tasks,
                        nextTaskId: app.nextTaskId,
                        onAddTask: () => context.push(AppRoutes.taskForm),
                        onToggleTask: app.toggleTask,
                        onSaveTask: app.upsertTask,
                        onDeleteTask: app.deleteTask,
                      );
                    },
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                builder: (BuildContext context, GoRouterState state) {
                  return Consumer<AppProvider>(
                    builder: (BuildContext context, AppProvider app, _) {
                      return ProfileScreen(
                        settings: app.settings,
                        initialProfile: app.profile,
                        onProfileChanged: app.updateProfile,
                        onLogout: () {
                          app.setLoggedIn(false);
                          context.go(AppRoutes.login);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _openBrainDump(BuildContext context) async {
  final AppProvider app = context.read<AppProvider>();
  final TransactionItem? note = await context.push<TransactionItem>(
    AppRoutes.brainDump,
  );
  if (note == null || !context.mounted) {
    return;
  }
  app.transactionsChanged();
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        note.amount >= 0
            ? 'Catatan keuangan "${note.label}" dicatat.'
            : 'Catatan pengeluaran "${note.label}" dicatat.',
      ),
    ),
  );
}
