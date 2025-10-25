// lib/attendance_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================== CONFIG ==================
const kBaseUrl = 'http://72.60.79.89:5005';
const int kClassId = 1; // id kelas A10/10A di DB kamu

// ================== MODELS ==================
class TodayStudent {
  final int id;
  final String code;
  final String name;
  final bool present;
  TodayStudent({required this.id, required this.code, required this.name, required this.present});
  factory TodayStudent.fromJson(Map<String, dynamic> j) => TodayStudent(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    present: (j['status'] as String) == 'present',
  );
}

class ClassToday {
  final int classId;
  final String date;
  final int total;
  final int present;
  final int absent;
  final List<TodayStudent> students;
  ClassToday({required this.classId,required this.date,required this.total,required this.present,required this.absent,required this.students});
  factory ClassToday.fromJson(Map<String, dynamic> j) => ClassToday(
    classId: j['class_id'] as int,
    date: j['date'] as String,
    total: (j['summary']['total'] as num).toInt(),
    present: (j['summary']['present'] as num).toInt(),
    absent: (j['summary']['absent'] as num).toInt(),
    students: (j['students'] as List).map((e)=>TodayStudent.fromJson(e)).toList(),
  );
}

class StudentHistoryEntry {
  final String date;   // YYYY-MM-DD
  final String classCode;
  final bool present;
  StudentHistoryEntry({required this.date, required this.classCode, required this.present});
  factory StudentHistoryEntry.fromJson(Map<String, dynamic> j) => StudentHistoryEntry(
    date: j['date'] as String,
    classCode: j['class'] as String,
    present: (j['status'] as String) == 'present',
  );
}

class StudentAttendance {
  final int studentId;
  final int windowDays;
  final double attendancePercent;
  final List<StudentHistoryEntry> history;
  StudentAttendance({required this.studentId,required this.windowDays,required this.attendancePercent,required this.history});
  factory StudentAttendance.fromJson(Map<String, dynamic> j) => StudentAttendance(
    studentId: (j['student_id'] as num).toInt(),
    windowDays: (j['window_days'] as num).toInt(),
    attendancePercent: (j['attendance_percent'] as num).toDouble(),
    history: (j['history'] as List).map((e)=>StudentHistoryEntry.fromJson(e)).toList(),
  );
}

// ================== API CALLS ==================
Future<ClassToday> fetchClassToday(int classId) async {
  final uri = Uri.parse('$kBaseUrl/classes/$classId/attendance/today');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('Failed to load today attendance (${res.statusCode})');
  }
  return ClassToday.fromJson(json.decode(res.body) as Map<String, dynamic>);
}

Future<StudentAttendance> fetchStudentAttendance(int studentId, {int limit = 7}) async {
  final uri = Uri.parse('$kBaseUrl/students/$studentId/attendance?limit=$limit');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('Failed to load student attendance (${res.statusCode})');
  }
  return StudentAttendance.fromJson(json.decode(res.body) as Map<String, dynamic>);
}

// ================== PAGES ==================
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late Future<ClassToday> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchClassToday(kClassId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<ClassToday>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Failed to load: ${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = fetchClassToday(kClassId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Class 10A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    Text('Attendance Today', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black54)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ${data.summaryTotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    Text('Present: ${data.present}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.green)),
                    Text('Absent: ${data.absent}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.red)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 0),
                  itemCount: data.students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final s = data.students[idx];
                    final present = s.present;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentDashboardPage(student: s),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: present ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(present ? Icons.check : Icons.close, color: present ? Colors.green : Colors.red),
                        ),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        subtitle: Text('ID: ${s.id}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: present ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: present ? Colors.green : Colors.red, width: 1.2),
                          ),
                          child: Text(
                            present ? 'Present' : 'Absent',
                            style: TextStyle(color: present ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap a student to view their dashboard. Attendance is for today only.',
                        style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on ClassToday {
  int get summaryTotal => total;
}

// ================== STUDENT DASHBOARD ==================
class StudentDashboardPage extends StatefulWidget {
  final TodayStudent student;
  const StudentDashboardPage({required this.student, super.key});
  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  late Future<StudentAttendance> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchStudentAttendance(widget.student.id, limit: 7);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('${s.name} (ID: ${s.id})', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FutureBuilder<StudentAttendance>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Failed to load: ${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => setState(() => _future = fetchStudentAttendance(s.id)), child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final data = snap.data!;
          final presentToday = s.present;
          final about = 'This student really loves the number 67 for some reason.';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            s.name.isNotEmpty ? s.name.split(' ').map((e) => e[0]).take(2).join() : '',
                            style: const TextStyle(fontSize: 28, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(s.name,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(presentToday ? Icons.check_circle : Icons.cancel, color: presentToday ? Colors.green : Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      presentToday ? 'Present Today' : 'Absent Today',
                      style: TextStyle(color: presentToday ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const Spacer(),
                    const Icon(Icons.percent, color: Colors.blue, size: 22),
                    const SizedBox(width: 6),
                    const Text('Attendance: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    Text('${data.attendancePercent.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 22),
                Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
                  child: Text(about, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
                ),
                const SizedBox(height: 22),
                Text('Previous Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in data.history)
                          Container(
                            width: 90,
                            margin: EdgeInsets.only(right: e == data.history.last ? 0 : 10),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              color: e.present ? Colors.green.shade100 : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: e.present ? Colors.green : Colors.red, width: 1.2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  e.classCode,
                                  style: TextStyle(color: e.present ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Icon(e.present ? Icons.check : Icons.close, color: e.present ? Colors.green : Colors.red, size: 22),
                                const SizedBox(height: 4),
                                Text(e.date.length >= 5 ? e.date.substring(5) : e.date,
                                    style: const TextStyle(fontSize: 13, color: Colors.black54), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Attendance Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
                  ]),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                    dividerThickness: 0,
                    dataRowColor: MaterialStateProperty.all(Colors.white),
                    columns: const [
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      for (final e in data.history)
                        DataRow(cells: [
                          DataCell(Text(e.date)),
                          DataCell(Text(e.classCode)),
                          DataCell(Row(children: [
                            Icon(e.present ? Icons.check : Icons.close, color: e.present ? Colors.green : Colors.red, size: 18),
                            const SizedBox(width: 4),
                            Text(e.present ? 'Present' : 'Absent', style: TextStyle(color: e.present ? Colors.green : Colors.red)),
                          ])),
                        ])
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
