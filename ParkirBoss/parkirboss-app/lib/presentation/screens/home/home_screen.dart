import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/screens/home/dashboard_view.dart';
import 'package:parkirboss/presentation/screens/home/slot_map_view.dart';
import 'package:parkirboss/presentation/screens/home/sessions_view.dart';
import 'package:parkirboss/presentation/screens/home/profile_view.dart';
import 'package:parkirboss/core/services/gps_service.dart';
import 'package:parkirboss/core/services/notification_service.dart';

/// Home screen with neo-brutalist bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GpsService _gpsService = GpsService();
  final NotificationService _notificationService = NotificationService();

  static const List<Widget> _pages = <Widget>[
    DashboardView(),
    SlotMapView(),
    SessionsView(),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    _gpsService.startTracking();
    _notificationService.initialize().then((_) {
      _notificationService.startPolling();
    });
  }

  @override
  void dispose() {
    _gpsService.stopTracking();
    _notificationService.stopPolling();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/parkirboss_logo_horizontal.png',
          height: 28,
          fit: BoxFit.contain,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSpacing.borderMedium),
          child: Container(
            color: AppColors.onSurface,
            height: AppSpacing.borderMedium,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            color: AppColors.onSurface,
            iconSize: 28,
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
            },
          ),
        ],
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.onSurface,
              width: AppSpacing.borderMedium,
            ),
          ),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryContainer,
          unselectedItemColor: AppColors.onSurfaceVariant,
          selectedLabelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
