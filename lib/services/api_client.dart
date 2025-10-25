// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));

  Future<UserDto> login(String username, String password) async {
    final res = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw Exception('Login failed: HTTP ${res.statusCode} ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return UserDto.fromJson(m);
  }

  Future<List<ClassDto>> getClasses() async {
    final res = await http.get(_u('/classes'), headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('Fetch classes failed: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return <ClassDto>[];
    return body.map<ClassDto>((e) => ClassDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<SubjectDto>> getClassSubjects(int classId) async {
    final res = await http.get(
      _u('/classes/$classId/subjects'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception('Fetch subjects failed: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return <SubjectDto>[];
    return body.map<SubjectDto>((e) => SubjectDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// day: 0=Monday .. 4=Friday (per your Flask route)
  Future<List<ScheduleDto>> getSchedule(int classId, int day) async {
    final res = await http.get(
      _u('/classes/$classId/schedule', {'day': day}),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception('Fetch schedule failed: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body is! List) return <ScheduleDto>[];
    return body.map<ScheduleDto>((e) => ScheduleDto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<int> createSchedule(
    int classId, {
    required int day, // 0..4
    required int subjectId,
    required String start, // "HH:MM"
    required String end,   // "HH:MM"
  }) async {
    final res = await http.post(
      _u('/classes/$classId/schedule'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'day': day,
        'subject_id': subjectId,
        'start': start,
        'end': end,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Create schedule failed: HTTP ${res.statusCode} ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['id'] as num).toInt();
  }

  Future<void> updateSchedule(
    int scheduleId, {
    required int subjectId,
    required String start,
    required String end,
  }) async {
    final res = await http.put(
      _u('/schedules/$scheduleId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subject_id': subjectId,
        'start': start,
        'end': end,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Update schedule failed: HTTP ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    final res = await http.delete(_u('/schedules/$scheduleId'));
    if (res.statusCode != 200) {
      throw Exception('Delete schedule failed: HTTP ${res.statusCode} ${res.body}');
    }
  }
}

// ===== DTOs =====

class UserDto {
  final int id;
  final String username;
  final String nickname;
  final int classId;
  UserDto({required this.id, required this.username, required this.nickname, required this.classId});
  factory UserDto.fromJson(Map<String, dynamic> m) => UserDto(
        id: (m['id'] as num).toInt(),
        username: m['username']?.toString() ?? '',
        nickname: m['nickname']?.toString() ?? '',
        classId: (m['class_id'] as num).toInt(),
      );
}

class ClassDto {
  final int id;
  final String name;
  ClassDto({required this.id, required this.name});
  factory ClassDto.fromJson(Map<String, dynamic> m) =>
      ClassDto(id: (m['id'] as num).toInt(), name: m['name']?.toString() ?? '');
}

class SubjectDto {
  final int id;
  final String name;
  SubjectDto({required this.id, required this.name});
  factory SubjectDto.fromJson(Map<String, dynamic> m) =>
      SubjectDto(id: (m['subject_id'] as num? ?? m['id'] as num).toInt(),
                 name: m['subject_name']?.toString() ?? m['name']?.toString() ?? '');
}

class ScheduleDto {
  final int id;
  final int subjectId;
  final String subjectName;
  final String start; // "HH:MM"
  final String end;   // "HH:MM"
  ScheduleDto({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.start,
    required this.end,
  });
  factory ScheduleDto.fromJson(Map<String, dynamic> m) => ScheduleDto(
        id: (m['id'] as num).toInt(),
        subjectId: (m['subject_id'] as num).toInt(),
        subjectName: m['subject_name']?.toString() ?? '',
        start: m['start']?.toString() ?? '',
        end: m['end']?.toString() ?? '',
      );
}
