// lib/pages/dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ================== CONFIG ==================
const String kApiBase = 'http://72.60.79.89:5005';
/// ============================================

class DashboardPage extends StatefulWidget {
  final int classId;

  final DateTime? now;

  const DashboardPage({
    super.key,
    required this.classId,
    this.now,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _now = DateTime.now();
  Future<List<SchoolClass>>? _future;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _future = _fetchToday();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNow = widget.now ?? DateTime.now();
    final dayChanged = _dayKey(_now) != _dayKey(newNow) || oldWidget.classId != widget.classId;
    _now = newNow;
    if (dayChanged) {
      setState(() => _future = _fetchToday());
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  int _apiDayFor(DateTime d) {
    if (d.weekday < DateTime.monday || d.weekday > DateTime.friday) return -1;
    return d.weekday - 1;
  }

  Uri _scheduleUri(int classId, int apiDay) =>
      Uri.parse('$kApiBase/classes/$classId/schedule?day=$apiDay');

  Future<List<SchoolClass>> _fetchToday() async {
    final apiDay = _apiDayFor(_now);
    if (apiDay == -1) return [];

    final res = await http.get(_scheduleUri(widget.classId, apiDay),
        headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('Failed to load schedule: HTTP ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    if (body is! List) return [];

    final all = body
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map<SchoolClass>((m) => SchoolClass(
              name: (m['subject_name'] ?? m['name'] ?? 'Unknown').toString(),
              startMinutes: SchoolClass.parseToMinutes(m['start']),
              endMinutes: SchoolClass.parseToMinutes(m['end']),
            ))
        .toList();

    final cleaned = all.where((c) => c.isValid).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return cleaned;
  }

  String _monthName(int month) => const [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
      ][month - 1];

  String _dayName(DateTime d) => const [
        'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
      ][d.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    _now = now;

    final dayName = _dayName(now);
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}';
    final timeStr = TimeOfDay.fromDateTime(now).format(context);

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _fetchToday());
          await _future;
        },
        child: FutureBuilder<List<SchoolClass>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 24),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _HeaderCard(dayName: dayName, dateStr: dateStr, timeStr: timeStr),
                  const SizedBox(height: 24),
                  _ErrorCard(
                    message:
                        'Failed to load schedule.\n${String.fromCharCodes(snap.error.toString().runes.take(200))}',
                    onRetry: () {
                      setState(() => _future = _fetchToday());
                    },
                  ),
                ],
              );
            }

            final classes = (snap.data ?? []);
            final nowCls = classes.firstWhere(
              (c) => c.isOngoingAt(now),
              orElse: () => SchoolClass.empty,
            );
            final nextCls = classes.firstWhere(
              (c) => !now.isAfter(c.endToday(now)) && !c.isOngoingAt(now),
              orElse: () => SchoolClass.empty,
            );

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(dayName: dayName, dateStr: dateStr, timeStr: timeStr),
                  const SizedBox(height: 24),
                  _NowCard(now: now, nowClass: nowCls, nextClass: nextCls),
                  const SizedBox(height: 24),
                  _TodayListCard(now: now, classes: classes),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ====== Model ======
class SchoolClass {
  final String name;
  final int startMinutes; // minutes since midnight
  final int endMinutes;

  const SchoolClass({
    required this.name,
    required this.startMinutes,
    required this.endMinutes,
  });

  bool get isValid =>
      startMinutes >= 0 &&
      endMinutes >= 0 &&
      endMinutes > startMinutes &&
      endMinutes <= (24 * 60 + 59);

  static int parseToMinutes(dynamic v) {
    try {
      if (v == null) return -1;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty || s.toLowerCase() == 'null') return -1;
        final hm = RegExp(r'^(\d{1,2})\s*:\s*(\d{1,2})$').firstMatch(s);
        if (hm != null) {
          final h = int.parse(hm.group(1)!);
          final m = int.parse(hm.group(2)!);
          return h * 60 + m;
        }
        if (RegExp(r'^\d+$').hasMatch(s)) return int.parse(s);
        return -1;
      }
      if (v is List && v.length >= 2) {
        final h = int.tryParse(v[0].toString()) ?? -1;
        final m = int.tryParse(v[1].toString()) ?? -1;
        if (h >= 0 && m >= 0) return h * 60 + m;
      }
      if (v is Map) {
        final h = int.tryParse((v['hour'] ?? v['h'] ?? '').toString()) ?? -1;
        final m = int.tryParse((v['minute'] ?? v['min'] ?? v['m'] ?? '').toString()) ?? -1;
        if (h >= 0 && m >= 0) return h * 60 + m;
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  TimeOfDay startTod() => TimeOfDay(hour: (startMinutes ~/ 60), minute: (startMinutes % 60));
  TimeOfDay endTod()   => TimeOfDay(hour: (endMinutes ~/ 60),   minute: (endMinutes % 60));

  DateTime startToday(DateTime ref) =>
      DateTime(ref.year, ref.month, ref.day, startMinutes ~/ 60, startMinutes % 60);
  DateTime endToday(DateTime ref) =>
      DateTime(ref.year, ref.month, ref.day, endMinutes ~/ 60, endMinutes % 60);

  bool isOngoingAt(DateTime t) {
    if (!isValid) return false;
    final nowM = t.hour * 60 + t.minute;
    return nowM >= startMinutes && nowM <= endMinutes;
  }

  String statusAt(DateTime t) {
    if (!isValid) return 'invalid';
    final nowM = t.hour * 60 + t.minute;
    if (nowM > endMinutes) return 'done';
    if (nowM >= startMinutes && nowM <= endMinutes) return 'ongoing';
    return 'upcoming';
  }

  static const empty = SchoolClass(name: '', startMinutes: -1, endMinutes: -1);
  bool get isEmpty => name.isEmpty;
}

/// ====== UI widgets ======

class _HeaderCard extends StatelessWidget {
  final String dayName, dateStr, timeStr;
  const _HeaderCard({
    required this.dayName,
    required this.dateStr,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(dateStr, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white70, size: 20),
                      const SizedBox(width: 6),
                      Text(timeStr, style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.2),
              ),
              child: const Column(
                children: [
                  Icon(Icons.school, color: Colors.white, size: 28),
                  SizedBox(height: 6),
                  Text('CLASS',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1)),
                  Text('10A',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  final DateTime now;
  final SchoolClass nowClass;
  final SchoolClass nextClass;
  const _NowCard({
    required this.now,
    required this.nowClass,
    required this.nextClass,
  });

  @override
  Widget build(BuildContext context) {
    if (!nowClass.isEmpty) {
      final start = nowClass.startToday(now);
      final end = nowClass.endToday(now);
      final total = end.difference(start).inSeconds.clamp(1, 1 << 31);
      final elapsed = now.difference(start).inSeconds.clamp(0, total);
      final pct = elapsed / total;

      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.green, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Now',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _Pill(text: 'On going', color: Colors.green.shade50, fg: Colors.green),
                ],
              ),
              const SizedBox(height: 10),
              Text(nowClass.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '${_fmtTod(context, nowClass.startTod())} - ${_fmtTod(context, nowClass.endTod())}',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: Colors.green.withOpacity(0.15),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(pct * 100).toStringAsFixed(0)}% elapsed',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  Text(
                    'Ends ${_fmtTod(context, nowClass.endTod())}',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // No class right now
      String subtitle = 'Enjoy your break';
      if (!nextClass.isEmpty) {
        subtitle = 'Next: ${nextClass.name} at ${_fmtTod(context, nextClass.startTod())}';
      }
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              const Icon(Icons.free_breakfast, color: Colors.blue, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nothing now',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              _Pill(text: 'Break', color: Colors.blue.shade50, fg: Colors.blue),
            ],
          ),
        ),
      );
    }
  }
}

class _TodayListCard extends StatelessWidget {
  final DateTime now;
  final List<SchoolClass> classes;
  const _TodayListCard({required this.now, required this.classes});

  Color _statusColor(String s) {
    switch (s) {
      case 'done':
        return Colors.grey;
      case 'ongoing':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'done':
        return Icons.check_circle_outline;
      case 'ongoing':
        return Icons.play_circle_fill;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ongoingCount = classes.where((c) => c.statusAt(now) == 'ongoing').length;
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Classes",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Row(
                  children: [
                    _Pill(
                      text: 'Ongoing: $ongoingCount',
                      color: Colors.green.shade50,
                      fg: Colors.green.shade800,
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      text: 'Total: ${classes.length}',
                      color: Colors.blue.shade50,
                      fg: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Items
            ...classes.asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              final status = c.statusAt(now);
              final color = _statusColor(status);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Selected: ${c.name}')));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: status == 'ongoing'
                        ? Colors.green.withOpacity(0.08)
                        : status == 'done'
                            ? Colors.grey.withOpacity(0.08)
                            : Colors.blue.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(_statusIcon(status), color: color, size: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        '${_fmtTod(context, c.startTod())} - ${_fmtTod(context, c.endTod())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color fg;
  const _Pill({required this.text, required this.color, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

/// small helper
String _fmtTod(BuildContext context, TimeOfDay t) => t.format(context);
