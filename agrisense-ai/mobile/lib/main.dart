// AgriSense AI - Mobile App
// 5 tabs: Dashboard, Add Reading, History, Journey, Diagnose.

import 'package:flutter/material.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'theme.dart';
import 'moisture_gauge.dart';
import 'add_reading_screen.dart';
import 'history_screen.dart';
import 'journey_screen.dart';
import 'diagnose_screen.dart';
import 'login_screen.dart';

void main() {
  runApp(const AgriSenseApp());
}

class AgriSenseApp extends StatelessWidget {
  const AgriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSense AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

// Decides whether to show the login screen or the main app, based on
// whether a session token was saved from a previous launch.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getStoredToken();
    setState(() {
      _loggedIn = token != null;
      _checking = false;
    });
  }

  void _handleLoggedIn() => setState(() => _loggedIn = true);

  void _handleLogout() {
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.moss)),
      );
    }
    if (!_loggedIn) {
      return LoginScreen(onLoggedIn: _handleLoggedIn);
    }
    return RootShell(onLogout: _handleLogout);
  }
}

// Hosts the tabs with an animated crossfade + slight rise between them,
// instead of an abrupt swap.
class RootShell extends StatefulWidget {
  final VoidCallback onLogout;
  const RootShell({super.key, required this.onLogout});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  // Bumping this forces the Dashboard to reload its data — used after saving
  // a new reading so the dashboard doesn't show stale data.
  int _dashboardRefreshKey = 0;

  void _goToDashboard() {
    setState(() {
      _index = 0;
      _dashboardRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(key: ValueKey(_dashboardRefreshKey), onLogout: widget.onLogout),
      AddReadingScreen(onSaved: _goToDashboard),
      const HistoryScreen(),
      const JourneyScreen(),
      const DiagnoseScreen(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: screens[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.moss.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), selectedIcon: Icon(Icons.add_circle_rounded), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline_rounded), label: 'Journey'),
          NavigationDestination(icon: Icon(Icons.image_search_outlined), selectedIcon: Icon(Icons.image_search_rounded), label: 'Diagnose'),
        ],
      ),
    );
  }
}

// Moisture stress thresholds, matching agri_logic.py, used only to draw the
// gauge's marker line — the real evaluation always happens on the backend.
const Map<String, double> _moistureThreshold = {'soybean': 25, 'wheat': 30};

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReadingWithAdvisory? _data;
  bool _loading = true;
  String? _error;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getStoredUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in any time with your email and password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.logout();
      widget.onLogout();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.fetchLatestWithAdvisory();
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user != null && _user!.name.isNotEmpty ? 'Hi, ${_user!.name.split(' ').first}' : 'AgriSense AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
            tooltip: 'Log out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.moss,
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.moss));
    }

    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Can\'t reach the backend',
        message:
            'Start it with `uvicorn main:app --reload` in your backend folder, '
            'then pull down to retry.\n\n$_error',
      );
    }

    if (_data == null) {
      return const _EmptyState(
        icon: Icons.eco_outlined,
        title: 'No readings yet',
        message: 'Add one from the "Add" tab to see it here.',
      );
    }

    final reading = _data!.reading;
    final advisories = _data!.advisories;
    final threshold = _moistureThreshold[reading.crop] ?? 25;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(reading: reading, threshold: threshold),
          const SizedBox(height: 20),
          Text('Sensor readings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _SensorGrid(reading: reading),
          const SizedBox(height: 24),
          Text('Advisories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...advisories.map((a) => _AdvisoryCard(advisory: a)),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Reading reading;
  final double threshold;

  const _HeaderCard({required this.reading, required this.threshold});

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.moss,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(reading.crop),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reading.district} · ${_capitalize(reading.soilType.replaceAll('_', ' '))} soil',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      reading.timestamp.split('.')[0].replaceAll('T', '  '),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(70)),
            child: MoistureGauge(moisturePercent: reading.soilMoisture, threshold: threshold),
          ),
        ],
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  final Reading reading;
  const _SensorGrid({required this.reading});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('N', reading.nitrogen, 'kg/ha'),
      ('P', reading.phosphorus, 'kg/ha'),
      ('K', reading.potassium, 'kg/ha'),
      ('Temp', reading.temperature, '°C'),
      ('Humidity', reading.humidity, '%'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          width: (MediaQuery.of(context).size.width - 16 * 2 - 10 * 2) / 3,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.moss.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.$1, style: TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(item.$2.toStringAsFixed(item.$2 % 1 == 0 ? 0 : 1), style: AppTheme.mono(size: 17)),
                  const SizedBox(width: 3),
                  Text(item.$3, style: TextStyle(fontSize: 10, color: AppColors.inkMuted)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  final Advisory advisory;
  const _AdvisoryCard({required this.advisory});

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  IconData get _icon => switch (advisory.category) {
        'irrigation' => Icons.water_drop_rounded,
        'nutrient' => Icons.eco_rounded,
        'pest' => Icons.bug_report_rounded,
        _ => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(advisory.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(_icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_capitalize(advisory.category), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                const SizedBox(height: 3),
                Text(advisory.message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: AppColors.moss.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}