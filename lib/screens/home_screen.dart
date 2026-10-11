import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/auth_services.dart';
import '../services/notification_lab_screen.dart';
import '../services/notification_service.dart';
import '../services/task_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = TaskService();
  final _auth = AuthService();
  final _searchController = TextEditingController();

  List<Task> _tasks = [];
  bool _loading = true;

  String _filter = 'all';
  String _query = '';

  static const _primary = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================
  // HELPERS
  // =========================

  int _nid(Task task) => NotificationService.notificationIdFor(task.id);

  // Dialog বন্ধ হওয়ার animation শেষ হলে controller dispose
  void _disposeLater(List<TextEditingController> controllers) {
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  // =========================
  // LOAD TASKS
  // =========================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      _tasks = await _service.getTasks();
    } catch (e) {
      _toast(e.toString());
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // =========================
  // TOAST
  // =========================

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(message),
        ),
      );
  }

  // =========================
  // FILTER
  // =========================

  List<Task> get _visible {
    return _tasks.where((task) {
      final matchQuery =
      task.title.toLowerCase().contains(_query.toLowerCase());

      final matchFilter = _filter == 'all' ||
          (_filter == 'active' && !task.completed) ||
          (_filter == 'done' && task.completed);

      return matchQuery && matchFilter;
    }).toList();
  }

  int get _doneCount => _tasks.where((t) => t.completed).length;
  int get _activeCount => _tasks.where((t) => !t.completed).length;

  // =========================
  // PRIORITY
  // =========================

  Color _priorityColor(String priority) {
    if (priority == 'high') return Colors.red;
    if (priority == 'low') return Colors.green;
    return Colors.orange;
  }

  String _priorityLabel(String priority) {
    if (priority == 'high') return 'High';
    if (priority == 'low') return 'Low';
    return 'Medium';
  }

  // =========================
  // ADD / EDIT TASK
  // =========================

  Future<void> _openForm([Task? task]) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController =
    TextEditingController(text: task?.description ?? '');
    final controllers = [titleController, descriptionController];

    String priority = task?.priority ?? 'medium';

    // Server থেকে UTC এলে local সময়ে নেওয়া হচ্ছে
    DateTime? due = task?.dueDate != null
        ? DateTime.tryParse(task!.dueDate!)?.toLocal()
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      task == null ? Icons.add_task : Icons.edit_note,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    task == null ? 'নতুন টাস্ক' : 'টাস্ক এডিট',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // TITLE
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        prefixIcon: const Icon(Icons.task_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // DESCRIPTION
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 44),
                          child: Icon(Icons.description),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // PRIORITY
                    Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'low', label: Text('Low')),
                          ButtonSegment(
                              value: 'medium', label: Text('Medium')),
                          ButtonSegment(value: 'high', label: Text('High')),
                        ],
                        selected: {priority},
                        onSelectionChanged: (selection) {
                          setD(() {
                            priority = selection.first;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // DUE DATE & TIME
                    Text(
                      'Reminder',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: Text(
                              due == null ? 'Pick date' : _formatDate(due!),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final now = DateTime.now();
                              final initial = due ?? now;

                              final selectedDate = await showDatePicker(
                                context: ctx,
                                initialDate: initial,
                                firstDate:
                                initial.isBefore(now) ? initial : now,
                                lastDate: DateTime(2100),
                              );

                              if (selectedDate == null) return;

                              final existingTime = due != null
                                  ? TimeOfDay.fromDateTime(due!)
                                  : TimeOfDay.now();

                              setD(() {
                                due = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  existingTime.hour,
                                  existingTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              due == null ? 'Pick time' : _formatTime(due!),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final selectedTime = await showTimePicker(
                                context: ctx,
                                initialTime: due != null
                                    ? TimeOfDay.fromDateTime(due!)
                                    : TimeOfDay.now(),
                              );

                              if (selectedTime == null) return;

                              final currentDate = due ?? DateTime.now();

                              setD(() {
                                due = DateTime(
                                  currentDate.year,
                                  currentDate.month,
                                  currentDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // CLEAR REMINDER
                    if (due != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setD(() {
                              due = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear reminder'),
                        ),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      _disposeLater(controllers);
      return;
    }

    // =========================
    // VALIDATE TITLE
    // =========================

    final taskTitle = titleController.text.trim();

    if (taskTitle.isEmpty) {
      _toast('Task title দিন');
      _disposeLater(controllers);
      return;
    }

    // =========================
    // DATA
    // =========================

    final data = {
      'title': taskTitle,
      'description': descriptionController.text.trim(),
      'priority': priority,
      // UTC তে পাঠানো হচ্ছে, যাতে সময় নিয়ে বিভ্রান্তি না হয়
      'dueDate': due?.toUtc().toIso8601String(),
    };

    try {
      // =========================
      // CREATE
      // =========================

      if (task == null) {
        final oldIds = _tasks.map((t) => t.id.toString()).toSet();

        await _service.createTask(data);
        await _load();

        _toast('Task তৈরি হয়েছে');

        // নতুন তৈরি হওয়া task টা খুঁজে তার আসল ID দিয়ে reminder
        if (due != null) {
          final created = _tasks
              .where((t) => !oldIds.contains(t.id.toString()))
              .toList();

          if (created.isNotEmpty) {
            await NotificationService.scheduleTaskNotification(
              id: _nid(created.first),
              title: taskTitle,
              scheduledDate: due!,
            );
          }
        }
      }

      // =========================
      // EDIT
      // =========================

      else {
        await NotificationService.cancelTaskNotification(id: _nid(task));

        await _service.updateTask(task.id, data);

        // Completed task এর reminder দরকার নেই
        if (due != null && !task.completed) {
          await NotificationService.scheduleTaskNotification(
            id: _nid(task),
            title: taskTitle,
            scheduledDate: due!,
          );
        }

        _toast('Task update হয়েছে');
        await _load();
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      _disposeLater(controllers);
    }
  }

  // =========================
  // COMPLETE / ACTIVE
  // =========================

  Future<void> _toggle(Task task) async {
    try {
      final completed = !task.completed;

      await _service.updateTask(task.id, {'completed': completed});

      if (completed) {
        await NotificationService.cancelTaskNotification(id: _nid(task));
        _toast('Task completed এবং reminder বন্ধ হয়েছে');
      } else if (task.dueDate != null) {
        final due = DateTime.tryParse(task.dueDate!)?.toLocal();

        if (due != null && due.isAfter(DateTime.now())) {
          await NotificationService.scheduleTaskNotification(
            id: _nid(task),
            title: task.title,
            scheduledDate: due,
          );
        }
      }

      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  // =========================
  // DELETE
  // =========================

  Future<void> _delete(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 36),
          title: const Text('ডিলিট করবেন?'),
          content: Text(task.title, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await NotificationService.cancelTaskNotification(id: _nid(task));
      await _service.deleteTask(task.id);

      _toast('Task deleted');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> _logout() async {
    await NotificationService.cancelAll();
    await _auth.signOut();
  }

  // =========================
  // FORMAT DATE / TIME
  // =========================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  String _dueText(String value) {
    final date = DateTime.tryParse(value)?.toLocal();

    if (date == null) {
      return value;
    }

    return '${_formatDate(date)} ${_formatTime(date)}';
  }

  // =========================
  // UI PIECES
  // =========================

  Widget _buildHeader() {
    final user = _auth.currentUser;
    final name = user?.displayName ?? user?.email ?? '';
    final total = _tasks.length;
    final done = _doneCount;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade700, Colors.indigo.shade400],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'এখনো কোনো টাস্ক নেই'
                : '$_activeCount টি টাস্ক বাকি আছে',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$done / $total completed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
              });
            },
          ),
          hintText: 'Search tasks',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, IconData icon, int count) {
    final selected = _filter == key;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? _primary : Colors.grey.shade600,
      ),
      label: Text('$label · $count'),
      selected: selected,
      showCheckmark: false,
      selectedColor: Colors.indigo.shade100,
      backgroundColor: Colors.white,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _filter = key;
        });
      },
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('all', 'All', Icons.list_alt, _tasks.length),
          const SizedBox(width: 8),
          _filterChip(
              'active', 'Active', Icons.pending_actions, _activeCount),
          const SizedBox(width: 8),
          _filterChip('done', 'Done', Icons.task_alt, _doneCount),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final searching = _query.isNotEmpty || _filter != 'all';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          searching ? Icons.search_off : Icons.checklist_rounded,
          size: 72,
          color: Colors.indigo.shade200,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            searching ? 'কিছু পাওয়া যায়নি' : 'কোনো টাস্ক নেই',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            searching
                ? 'সার্চ বা ফিল্টার বদলে দেখুন'
                : 'নতুন টাস্ক যোগ করতে নিচের বাটনে চাপুন',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Task task) {
    final color = _priorityColor(task.priority);
    final due =
    task.dueDate != null ? DateTime.tryParse(task.dueDate!)?.toLocal() : null;
    final overdue =
        due != null && !task.completed && due.isBefore(DateTime.now());

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(task);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PRIORITY STRIP
                Container(
                  width: 5,
                  color: task.completed ? Colors.grey.shade300 : color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: task.completed,
                          shape: const CircleBorder(),
                          onChanged: (_) => _toggle(task),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: task.completed
                                        ? Colors.grey
                                        : Colors.black87,
                                    decoration: task.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _infoChip(
                                      Icons.flag,
                                      _priorityLabel(task.priority),
                                      task.completed ? Colors.grey : color,
                                    ),
                                    if (task.dueDate != null)
                                      _infoChip(
                                        overdue
                                            ? Icons.warning_amber_rounded
                                            : Icons.schedule,
                                        _dueText(task.dueDate!),
                                        task.completed
                                            ? Colors.grey
                                            : overdue
                                            ? Colors.red
                                            : _primary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') _openForm(task);
                            if (value == 'delete') _delete(task);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading:
                                Icon(Icons.delete_outline, color: Colors.red),
                                title: Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Notification Lab',
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationLabScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          _buildFilters(),
          const SizedBox(height: 8),

          // TASK LIST
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 90),
                itemCount: list.length,
                itemBuilder: (_, index) => _buildTaskCard(list[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
