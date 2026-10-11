import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task_model.dart';
import '../services/auth_services.dart';
import '../services/notification_service.dart';
import '../services/task_services.dart';
import 'task_form_screen.dart';

enum TaskFilter { all, pending, completed }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();

  TaskFilter _filter = TaskFilter.all;
  bool _searching = false;
  String _query = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Priority color
  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  // Format date
  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  // Show message
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // Delete task
  Future<void> _confirmDelete(TaskModel task) async {
    final user = _user;

    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('"${task.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TaskService().instance.deleteTask(user.uid, task.id);

      await NotificationService.cancelTaskNotification(
        id: NotificationService.notificationIdFor(task.id),
      );

      _showMessage('Task deleted successfully.');
    } catch (e) {
      _showMessage('Could not delete task: $e');
    }
  }

  // Add / Edit task
  Future<void> _openForm([TaskModel? task]) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));

    if (!mounted || result != true) return;

    _showMessage(
      task == null ? 'Task added successfully.' : 'Task updated successfully.',
    );
  }

  // Copy FCM token
  Future<void> _copyToken() async {
    try {
      final token = await NotificationService.getFCMToken();

      if (token == null || token.isEmpty) {
        _showMessage('FCM token not available yet.');
        return;
      }

      await Clipboard.setData(ClipboardData(text: token));

      _showMessage('FCM token copied.');
    } catch (e) {
      _showMessage('Could not get FCM token: $e');
    }
  }

  // Sign out
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _showMessage('Sign out failed: $e');
    }
  }

  // Search and filter
  List<TaskModel> _apply(List<TaskModel> tasks) {
    final query = _query.trim().toLowerCase();

    return tasks.where((task) {
      final matchesFilter = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.pending => !task.isCompleted,
        TaskFilter.completed => task.isCompleted,
      };

      final matchesQuery =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();
  }

  // Complete / Incomplete task
  Future<void> _toggleCompleted(TaskModel task, bool completed) async {
    final user = _user;

    if (user == null) return;

    try {
      await TaskService().instance.setCompleted(user.uid, task.id, completed);

      if (completed) {
        await NotificationService.cancelTaskNotification(
          id: NotificationService.notificationIdFor(task.id),
        );
      } else {
        final dueDate = task.dueDate;

        if (dueDate != null && dueDate.isAfter(DateTime.now())) {
          await NotificationService.scheduleTaskNotification(
            id: NotificationService.notificationIdFor(task.id),
            title: task.title,
            scheduledDate: dueDate,
          );
        }
      }
    } catch (e) {
      _showMessage('Could not update task: $e');
    }
  }

  // Filter chip
  Widget _buildFilterChip(TaskFilter filter) {
    final label = switch (filter) {
      TaskFilter.all => 'All',
      TaskFilter.pending => 'Pending',
      TaskFilter.completed => 'Completed',
    };

    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) {
        setState(() {
          _filter = filter;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your tasks.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              )
            : const Text('My Tasks'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;

                if (!_searching) {
                  _query = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'token') {
                _copyToken();
              } else if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'token', child: Text('Copy FCM Token')),
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: TaskFilter.values.map(_buildFilterChip).toList(),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: TaskService().instance.watchTasks(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading tasks:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = _apply(snapshot.data ?? <TaskModel>[]);

                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    final dueDate = task.dueDate?.toLocal();

                    final overdue =
                        !task.isCompleted &&
                        dueDate != null &&
                        dueDate.isBefore(DateTime.now());

                    final priorityColor = _priorityColor(task.priority);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        onTap: () => _openForm(task),

                        leading: Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) {
                            _toggleCompleted(task, value ?? false);
                          },
                        ),

                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            const SizedBox(height: 6),

                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    task.priority.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: priorityColor,
                                    ),
                                  ),
                                ),

                                if (dueDate != null)
                                  Text(
                                    'Due: ${_formatDate(dueDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: overdue ? Colors.red : null,
                                    ),
                                  ),

                                if (overdue)
                                  const Text(
                                    'OVERDUE',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        trailing: IconButton(
                          tooltip: 'Delete task',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(task),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}
