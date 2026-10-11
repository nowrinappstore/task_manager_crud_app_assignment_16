import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskService {
  // Android emulator -> 10.0.2.2
  // Physical phone -> your PC's LAN IP, e.g. http://192.168.0.105:3000/api/tasks
  static const baseUrl = 'http://10.0.2.2:3000/api/tasks';

  static const _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Shows the real status code and server message instead of a generic error
  Exception _error(String action, http.Response res) {
    debugPrint('$action failed: ${res.statusCode} ${res.body}');
    return Exception('$action failed (${res.statusCode}): ${res.body}');
  }

  Future<List<Task>> getTasks() async {
    final res = await http
        .get(Uri.parse(baseUrl), headers: await _headers())
        .timeout(_timeout);
    if (res.statusCode != 200) throw _error('Load tasks', res);
    return (jsonDecode(res.body) as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<void> createTask(Map<String, dynamic> data) async {
    final res = await http
        .post(Uri.parse(baseUrl),
        headers: await _headers(), body: jsonEncode(data))
        .timeout(_timeout);
    // Accept both 200 and 201 as success
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw _error('Create task', res);
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    final res = await http
        .put(Uri.parse('$baseUrl/$id'),
        headers: await _headers(), body: jsonEncode(data))
        .timeout(_timeout);
    if (res.statusCode != 200) throw _error('Update task', res);
  }

  Future<void> deleteTask(String id) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/$id'), headers: await _headers())
        .timeout(_timeout);
    // Accept both 204 and 200 as success
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw _error('Delete task', res);
    }
  }
}
