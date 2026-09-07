import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'core/telemetry/telemetry_service.dart';
import 'core/permissions/permission_service.dart';
import 'ui/cockpit/cockpit_screen.dart';
import 'ui/planner/planner_screen.dart';
import 'ui/explore/explore_screen.dart';
import 'ui/analytics/analytics_screen.dart';
import 'ui/navigation/bottom_nav_bar.dart';

class TrailPulseApp extends StatelessWidget {
  const TrailPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryService()),
      ],
      child: MaterialApp(
        title: 'TrailPulse Telemetry OS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainNavigationHost(),
      ),
    );
  }
}

class MainNavigationHost extends StatefulWidget {
  const MainNavigationHost({super.key});

  @override
  State<MainNavigationHost> createState() => _MainNavigationHostState();
}

class _MainNavigationHostState extends State<MainNavigationHost> {
  final List<Widget> _screens = const [
    ExploreScreen(),
    PlannerScreen(),
    CockpitScreen(),
    AnalyticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePermissionsAndStorage();
    });
  }

  Future<void> _initializePermissionsAndStorage() async {
    if (!mounted) return;
    final telemetry = context.read<TelemetryService>();
    final status = await PermissionService.requestInitialAppPermissions();
    telemetry.updatePermissionStatus(status);
    await telemetry.loadSavedRoutesFromDisk();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryService>();
    final currentIndex = telemetry.selectedTabIndex;

    return Container(
      color: const Color(0xFF060B14), // Deep OLED backdrop for desktop browser margins
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavBar(
              currentIndex: currentIndex,
              onTabSelected: (index) {
                telemetry.setSelectedTabIndex(index);
              },
            ),
          ),
        ),
      ),
    );
  }
}
