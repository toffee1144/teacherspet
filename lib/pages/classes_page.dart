import 'package:flutter/material.dart';
import '../services/api_client.dart';

const kBaseUrl = 'http://72.60.79.89:5005'; // ganti ke domain/tunnel kamu

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final List<String> days = const ['Monday','Tuesday','Wednesday','Thursday','Friday'];
  late int selectedDay = () {
    final wd = DateTime.now().weekday;
    return (wd>=1 && wd<=5) ? wd-1 : 0;
  }();

  late final ApiClient api = ApiClient(kBaseUrl);

  UserDto? _user;
  List<SubjectDto> _subjects = [];
  List<ScheduleDto> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Demo: auto-login "alice"
      final u = await api.login('alice','password123');
      _user = u;
      _subjects = await api.getClassSubjects(u.classId);
      _rows = await api.getSchedule(u.classId, selectedDay);
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _reloadSchedule() async {
    if (_user == null) return;
    _rows = await api.getSchedule(_user!.classId, selectedDay);
    setState((){});
  }

  Future<void> _addClass() async {
    if (_user == null) return;
    final res = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _ClassEditDialog(subjects: _subjects),
    );
    if (res != null) {
      await api.createSchedule(_user!.classId,
        day: selectedDay,
        subjectId: res.subjectId,
        start: res.start,
        end: res.end,
      );
      await _reloadSchedule();
    }
  }

  Future<void> _editClass(int idx) async {
    final row = _rows[idx];
    final res = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _ClassEditDialog(
        subjects: _subjects,
        initial: _EditResult(subjectId: row.subjectId, start: row.start, end: row.end),
      ),
    );
    if (res != null) {
      await api.updateSchedule(row.id, subjectId: res.subjectId, start: res.start, end: res.end);
      await _reloadSchedule();
    }
  }

  Future<void> _removeClass(int idx) async {
    final row = _rows[idx];
    await api.deleteSchedule(row.id);
    await _reloadSchedule();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    final nickname = _user?.nickname ?? '';

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addClass,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        tooltip: 'Add Class',
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final selected = i == selectedDay;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade700])
                          : null,
                      color: selected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? Colors.blue.shade700 : Colors.blue.shade100,
                        width: selected ? 2.2 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (selected ? Colors.blue : Colors.grey).withOpacity(0.12),
                          blurRadius: selected ? 10 : 4,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () async {
                          setState(() => selectedDay = i);
                          await _reloadSchedule();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 22),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.blue.shade700,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 17,
                            ),
                            child: Text(days[i].substring(0, 3)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Classes: ${_rows.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
                Text(
                  days[selectedDay],
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // List
          Expanded(
            child: _rows.isEmpty
                ? Center(child: Text('No classes for ${days[selectedDay]}',
                      style: const TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final c = _rows[idx];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text('#${idx+1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(c.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          subtitle: Text('${c.start} - ${c.end}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue),  onPressed: () => _editClass(idx)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeClass(idx)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Footer hint
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Tap + to add a schedule. Edit or delete items using the icons.',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===== Dialog & model (UI layer) ===== */

class _EditResult {
  final int subjectId;
  final String start;
  final String end;
  _EditResult({required this.subjectId, required this.start, required this.end});
}

class _ClassEditDialog extends StatefulWidget {
  final List<SubjectDto> subjects;
  final _EditResult? initial;
  const _ClassEditDialog({required this.subjects, this.initial, super.key});
  @override
  State<_ClassEditDialog> createState() => _ClassEditDialogState();
}

class _ClassEditDialogState extends State<_ClassEditDialog> {
  int? _subjectId;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initial?.subjectId ?? (widget.subjects.isNotEmpty ? widget.subjects.first.id : null);
    _startTime = widget.initial != null ? _parse(widget.initial!.start) : const TimeOfDay(hour: 8, minute: 0);
    _endTime   = widget.initial != null ? _parse(widget.initial!.end)   : const TimeOfDay(hour: 8, minute: 50);
  }

  TimeOfDay _parse(String t) {
    final p = t.split(':'); return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }
  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.initial == null ? 'Add Schedule' : 'Edit Schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Subject'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _subjectId,
                isExpanded: true,
                items: widget.subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _startTime);
                    if (picked != null) setState(() => _startTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.access_time, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text('Start: ${_fmt(_startTime)}'),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _endTime);
                    if (picked != null) setState(() => _endTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.access_time, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text('End: ${_fmt(_endTime)}'),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _subjectId == null ? null : () {
            Navigator.pop(context, _EditResult(subjectId: _subjectId!, start: _fmt(_startTime), end: _fmt(_endTime)));
          },
          child: Text(widget.initial == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
