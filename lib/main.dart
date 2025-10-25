import 'package:flutter/material.dart';
import 'dart:async';

// Your pages
import 'pages/dashboard_page.dart';
import 'pages/classes_page.dart';
import 'pages/attendance_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const TeachersPetApp());
}

/// ================== FAKE MONDAY SETTINGS ==================
/// Set to true to force the UI date to Monday while keeping a live clock.
const bool kForceMonday = false;

const bool kUseCurrentWeeksMonday = true;

/// Only used when kUseCurrentWeeksMonday == false
final DateTime kFixedMonday = DateTime(2025, 10, 27, 9, 15);

const String? kFakeStartTime = null;
/// ==========================================================

class TeachersPetApp extends StatelessWidget {
  const TeachersPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teachers Pet',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          elevation: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  late DateTime _now;
  Timer? _timer;
  late DateTime _fakeBaseMonday; // computed once per run if needed

  @override
  void initState() {
    super.initState();
    _fakeBaseMonday = _computeFakeBaseMonday(DateTime.now());
    _now = _computeNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = _computeNow();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Build the "Monday base date" depending on settings.
  DateTime _computeFakeBaseMonday(DateTime realNow) {
    if (!kForceMonday) return realNow; 
    if (kUseCurrentWeeksMonday) {
      final diffToMonday = realNow.weekday - DateTime.monday;
      return DateTime(realNow.year, realNow.month, realNow.day)
          .subtract(Duration(days: diffToMonday));
    } else {
      return DateTime(kFixedMonday.year, kFixedMonday.month, kFixedMonday.day);
    }
  }

  DateTime _computeNow() {
    final real = DateTime.now();

    if (!kForceMonday) return real;

    if (kFakeStartTime != null) {
      final parts = kFakeStartTime!.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      
      return DateTime(
        _fakeBaseMonday.year, _fakeBaseMonday.month, _fakeBaseMonday.day,
        h, m, real.second,
      );
    } else {
      return DateTime(
        _fakeBaseMonday.year, _fakeBaseMonday.month, _fakeBaseMonday.day,
        real.hour, real.minute, real.second,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    late final Widget bodyWidget;
    switch (_selectedIndex) {
      case 0:
        bodyWidget = DashboardPage(
          classId: 1,   // <-- USE a real class_id that has schedules
          now: _now,
        );
        break;
      case 1:
        bodyWidget = const ClassesPage();
        break;
      case 2:
        bodyWidget = const AttendancePage();
        break;
      default:
        bodyWidget = const ProfilePage();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leadingWidth: 180,
        leading: Row(
          children: [
            const SizedBox(width: 8),
            Image.asset(
              'lib/assets/teachers_pet_logo.png',
              height: 70,
              width: 100,
              errorBuilder: (context, _, __) =>
                  const Icon(Icons.school, color: Colors.white),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 3),
              child: const Row(
                children: [
                  Text(
                    'Mr Probz',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.account_circle, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: bodyWidget,
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  const CustomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavBarItem(icon: Icons.home, label: 'Home'),
      _NavBarItem(icon: Icons.menu_book, label: 'Classes'),
      _NavBarItem(icon: Icons.qr_code_scanner, label: 'Attendance'),
      _NavBarItem(icon: Icons.person, label: 'Profile'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final selected = selectedIndex == index;
              return GestureDetector(
                onTap: () => onItemTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  padding: selected
                      ? const EdgeInsets.symmetric(horizontal: 18, vertical: 8)
                      : const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[index].icon,
                        color: selected
                            ? Colors.blue
                            : Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Text(
                          items[index].label,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final String label;
  const _NavBarItem({required this.icon, required this.label});
}
