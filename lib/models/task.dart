class Task {
  final String id;
  final String title;
  final String description;
  final String? dueDate;
  final String priority; // low | medium | high
  final bool completed;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.priority = 'medium',
    this.completed = false,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'],
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    dueDate: j['dueDate'],
    priority: j['priority'] ?? 'medium',
    completed: j['completed'] ?? false,
  );
}