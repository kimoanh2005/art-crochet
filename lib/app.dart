import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/charts/chart_designer_screen.dart';
import 'screens/charts/chart_detail_screen.dart';
import 'screens/charts/create_chart_screen.dart';
import 'screens/charts/crochet_guide_screen.dart';
import 'screens/charts/my_charts_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/yarn_colors_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'state/app_state.dart';
import 'widgets/app_navigation.dart';

class CrochetStudioApp extends StatefulWidget {
  const CrochetStudioApp({super.key});

  @override
  State<CrochetStudioApp> createState() => _CrochetStudioAppState();
}

class _CrochetStudioAppState extends State<CrochetStudioApp> {
  final AppState _state = AppState();
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
    _state.initialize();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Art Crochet',
        theme: AppTheme.light,
        home: ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            if (_state.isInitializing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (_state.initializationError != null) {
              return Scaffold(
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không thể tải dữ liệu từ Supabase',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _state.initializationError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _state.retryInitialization,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Thử lại'),
                          ),
                          if (_state.isAuthenticated) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _state.signOut,
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            if (!_state.isAuthenticated) {
              return _showRegister
                  ? RegisterScreen(
                      onLogin: () => setState(() => _showRegister = false),
                      onRegistered: () => setState(() => _showRegister = false),
                    )
                  : LoginScreen(
                      onRegister: () => setState(() => _showRegister = true),
                      onSignedIn: () => setState(() {}),
                    );
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  _SubPage _subPage = _SubPage.none;
  String? _selectedChartId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
        final fullScreen = _subPage == _SubPage.designer;
        final body = _buildContent();

        if (fullScreen) {
          return Scaffold(body: SafeArea(child: body));
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  AppSidebar(
                    selectedIndex: _selectedIndex,
                    onSelected: _selectDestination,
                  ),
                Expanded(child: body),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : AppBottomNavigation(
                  selectedIndex: _selectedIndex,
                  onSelected: _selectDestination,
                ),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_subPage) {
      case _SubPage.create:
        return CreateChartScreen(
          onCancel: () => setState(() => _subPage = _SubPage.none),
          onCreated: _openDesigner,
        );
      case _SubPage.detail:
        return ChartDetailScreen(
          chartId: _selectedChartId!,
          onBack: () => setState(() => _subPage = _SubPage.none),
          onOpenDesigner: () => _openDesigner(_selectedChartId!),
          onOpenGuide: () => _openGuide(_selectedChartId!),
        );
      case _SubPage.designer:
        return ChartDesignerScreen(
          key: ValueKey('designer-$_selectedChartId'),
          chartId: _selectedChartId!,
          onBack: () => setState(() {
            _subPage = _SubPage.detail;
            _selectedIndex = 1;
          }),
          onOpenGuide: () => _openGuide(_selectedChartId!),
        );
      case _SubPage.guide:
        return CrochetGuideScreen(
          chartId: _selectedChartId!,
          onBack: () => setState(() {
            _subPage = _SubPage.detail;
            _selectedIndex = 1;
          }),
          onOpenDesigner: () => _openDesigner(_selectedChartId!),
        );
      case _SubPage.yarnColors:
        return YarnColorsScreen(
          onBack: () => setState(() => _subPage = _SubPage.none),
        );
      case _SubPage.none:
        return switch (_selectedIndex) {
          0 => HomeScreen(
            onCreateChart: _openCreate,
            onOpenChart: _openDetail,
            onEditChart: _openDesigner,
            onOpenProgress: _openGuide,
          ),
          1 => MyChartsScreen(
            onOpenChart: _openDetail,
            onEditChart: _openDesigner,
          ),
          2 => CreateChartScreen(
            onCancel: () => _selectDestination(0),
            onCreated: _openDesigner,
          ),
          3 => ProgressScreen(onContinue: _openGuide),
          _ => ProfileScreen(
            onOpenYarnColors: () =>
                setState(() => _subPage = _SubPage.yarnColors),
            onSignedOut: () => setState(() {
              _selectedIndex = 0;
              _subPage = _SubPage.none;
              _selectedChartId = null;
            }),
          ),
        };
    }
  }

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _subPage = _SubPage.none;
      _selectedChartId = null;
    });
  }

  void _openCreate() => setState(() {
    _selectedIndex = 2;
    _subPage = _SubPage.create;
  });

  void _openDetail(String chartId) => setState(() {
    _selectedChartId = chartId;
    _selectedIndex = 1;
    _subPage = _SubPage.detail;
  });

  void _openDesigner(String chartId) => setState(() {
    _selectedChartId = chartId;
    _selectedIndex = 2;
    _subPage = _SubPage.designer;
  });

  void _openGuide(String chartId) => setState(() {
    _selectedChartId = chartId;
    _selectedIndex = 3;
    _subPage = _SubPage.guide;
  });
}

enum _SubPage { none, create, detail, designer, guide, yarnColors }
