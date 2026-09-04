import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'core/telemetry/telemetry_service.dart';
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
  int _currentIndex = 2; // Default to Cockpit (Index 2)

  final List<Widget> _screens = const [
    ExploreScreen(),
    PlannerScreen(),
    CockpitScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
