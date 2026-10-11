import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_services.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskModel? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  DateTime? _dueDate;
  late TaskPriority _priority;

  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _title = TextEditingController(text: task?.title ?? '');

    _description = TextEditingController(text: task?.description ?? '');

    _dueDate = task?.dueDate;
    _priority = task?.priority ?? TaskPriority.medium;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // Select Due Date
  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null && mounted) {
      setState(() {
        final existing = _dueDate;

        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          existing?.hour ?? 23,
          existing?.minute ?? 59,
        );
      });
    }
  }

  // Save Task
  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before saving a task.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final oldTask = widget.task;

      final task = TaskModel(
        id: oldTask?.id ?? '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        isCompleted: oldTask?.isCompleted ?? false,
        createdAt: oldTask?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await TaskService().instance.updateTask(user.uid, task);
      } else {
        await TaskService().instance.addTask(user.uid, task);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Task updated successfully.'
                : 'Task created successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save task: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Task' : 'Add Task')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Task Title
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.task_alt),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // Due Date
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: _dueDate == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() {
                                        _dueDate = null;
                                      });
                                    },
                            ),
                    ),
                    child: Text(
                      _dueDate == null ? 'No due date' : _formatDate(_dueDate!),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Priority
                const Text(
                  'Priority',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                SegmentedButton<TaskPriority>(
                  segments: const [
                    ButtonSegment<TaskPriority>(
                      value: TaskPriority.low,
                      label: Text('Low'),
                      icon: Icon(Icons.keyboard_arrow_down),
                    ),
                    ButtonSegment<TaskPriority>(
                      value: TaskPriority.medium,
                      label: Text('Medium'),
                      icon: Icon(Icons.remove),
                    ),
                    ButtonSegment<TaskPriority>(
                      value: TaskPriority.high,
                      label: Text('High'),
                      icon: Icon(Icons.keyboard_arrow_up),
                    ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          setState(() {
                            _priority = selection.first;
                          });
                        },
                ),

                const SizedBox(height: 28),

                // Save Button
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEdit ? Icons.save : Icons.add_task),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _isEdit
                        ? 'Update Task'
                        : 'Add Task',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
