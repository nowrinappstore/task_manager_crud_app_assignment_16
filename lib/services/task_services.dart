
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/task_model.dart';

class TaskService {
// Android Emulator API URL
static const String baseUrl = 'http://10.0.2.2:3000/api/tasks';

static const Duration _timeout = Duration(seconds: 15);

  get instance => null;

// Authentication headers
Future<Map<String, String>> _headers() async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
throw Exception('Please login first.');
}

final String? token = await user.getIdToken();

if (token == null || token.isEmpty) {
throw Exception('Unable to get Firebase authentication token.');
}

return {
'Authorization': 'Bearer $token',
'Content-Type': 'application/json',
};
}

// Handle API errors
Exception _error(String action, http.Response response) {
debugPrint(
'$action failed: ${response.statusCode} ${response.body}',
);

return Exception(
'$action failed (${response.statusCode}): ${response.body}',
);
}

// Get all tasks
Future<List<TaskModel>> getTasks() async {
final response = await http
    .get(
Uri.parse(baseUrl),
headers: await _headers(),
)
    .timeout(_timeout);

if (response.statusCode != 200) {
throw _error('Load tasks', response);
}

final dynamic decoded = jsonDecode(response.body);

if (decoded is! List) {
throw Exception(
'Invalid API response: expected a list of tasks.',
);
}

return decoded.map<TaskModel>((item) {
if (item is! Map<String, dynamic>) {
throw Exception('Invalid task data received from server.');
}

return TaskModel.fromJson(item);
}).toList();
}

// Create a task
Future<void> createTask(Map<String, dynamic> data) async {
final response = await http
    .post(
Uri.parse(baseUrl),
headers: await _headers(),
body: jsonEncode(data),
)
    .timeout(_timeout);

if (response.statusCode != 200 &&
response.statusCode != 201) {
throw _error('Create task', response);
}

debugPrint('Task created successfully.');
}

// Update a task
Future<void> updateTask(
String id,
Map<String, dynamic> data,
) async {
final response = await http
    .put(
Uri.parse('$baseUrl/$id'),
headers: await _headers(),
body: jsonEncode(data),
)
    .timeout(_timeout);

if (response.statusCode != 200) {
throw _error('Update task', response);
}

debugPrint('Task updated successfully: $id');
}

// Delete a task
Future<void> deleteTask(String id) async {
final response = await http
    .delete(
Uri.parse('$baseUrl/$id'),
headers: await _headers(),
)
    .timeout(_timeout);

if (response.statusCode != 200 &&
response.statusCode != 204) {
throw _error('Delete task', response);
}

debugPrint('Task deleted successfully: $id');
}
}

