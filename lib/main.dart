import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mmo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('mmo'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#222222">
<title>دزّلي عين التمر | توصيل طلبات</title>
<style>
:root{--g:#080808;--g2:#d6ad36;--bg:#111111;--ink:#f5f0df;--muted:#c0b89f;--line:#574820}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:Tahoma,Arial,sans-serif}
button,input,textarea,select{font:inherit}
button{border:0;border-radius:13px;padding:12px 15px;background:var(--g);color:#d8b84c;font-weight:750;cursor:pointer}
button:disabled{opacity:.55}
.alt{background:#d6ad36;color:#111}
.outline{background:#1c1b18;color:#e5c75c;border:1px solid var(--line)}
.app{max-width:760px;margin:auto;min-height:100vh}
header{padding:23px 18px 26px;background:linear-gradient(135deg,#050505,#242017);color:#fff;border-bottom:2px solid #c9a227;border-radius:0 0 25px 25px}
h1{font-size:25px;margin:0}
header p{color:#f8edc9;margin:7px 0 0}
.content{padding:16px}
.note{background:#2a2414;border:1px solid #8b7024;border-radius:13px;padding:12px;font-size:13px;line-height:1.7;margin-bottom:14px}
.title{font-size:19px;margin:18px 0 10px}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}
.tile{background:#1c1b18;color:var(--ink);border:1px solid var(--line);border-radius:17px;padding:15px;text-align:right;min-height:110px}
.tile .emoji{font-size:28px}
.tile b{display:block;margin:7px 0 3px}
.tile small,.muted{color:var(--muted)}
.card{background:#1c1b18;border:1px solid var(--line);border-radius:17px;padding:15px;margin-bottom:12px}
.field{display:block;margin:12px 0}
.field span{display:block;font-size:13px;font-weight:750;margin-bottom:6px}
.field input,.field textarea,.field select{width:100%;padding:12px;border:1px solid #8b7024;border-radius:12px;background:#111;color:#f5f0df}
.field textarea{min-height:76px;resize:vertical}
.row{display:flex;gap:9px;align-items:center}
.row>*{flex:1;min-width:0}
.muted{font-size:13px;line-height:1.65}
.hero{background:#242017;border:1px solid #8b7024;border-radius:18px;padding:16px;margin:12px 0}
.hero strong{font-size:18px}
.hidden{display:none!important}
.tabs{display:flex;gap:8px;padding:12px 16px 0;overflow:auto;background:#111}
.tab{white-space:nowrap;background:#29261e;color:#e2c66d;padding:10px 13px}
.tab.active{background:var(--g);color:#d8b84c}
.map{border:1px solid var(--line);background:#242017;border-radius:15px;padding:18px;text-align:center}
.map .pin{font-size:31px}
.coords{font-size:12px;direction:ltr;color:var(--muted);overflow-wrap:anywhere}
.status{display:inline-block;background:#f5e8bd;color:#222;border-radius:99px;padding:5px 9px;font-size:12px}
.order{border-right:4px solid #c9a227}
.price{font-weight:800;color:#e5c75c;font-size:20px}
footer{text-align:center;padding:20px;color:var(--muted);font-size:12px}
@media(min-width:560px){.content{padding:22px}.grid{grid-template-columns:repeat(3,1fr)}}
</style>
</head>
<body>
<div class="app">
<header>
<h1>دزّلي</h1>
<p>توصيل طلباتك من المحلات لباب البيت</p>
</header>

<nav class="tabs">
<button class="tab active" data-page="home">الرئيسية</button>
<button class="tab" data-page="new">اطلب توصيل</button>
<button class="tab" data-page="orders">طلباتي</button>
<button class="tab" data-page="location">موقعي</button>
</nav>

<main class="content">
<div class="note"><b>نسخة تجريبية:</b> الطلبات تنحفظ على هذا الجهاز فقط ولا تصل إلى سائق حقيقي. حتى يشتغل المشروع للزبائن والسائقين فعلياً، يحتاج خادم وقاعدة بيانات مشتركة.</div>

<section id="home">
<div class="hero">
<strong>طلبك يوصل لبابك 🛍️</strong>
<p class="muted">اطلب من مطعم أو محل داخل قضاء عين التمر، وحدد مكان الاستلام والتسليم.</p>
<button id="start">إنشاء طلب توصيل</button>
</div>
<h2 class="title">شنو تريد توصل؟</h2>
<div class="grid">
<button class="tile" data-kind="مطاعم وأكل"><span class="emoji">🍔</span><b>مطاعم وأكل</b><small>وجبات ومشروبات</small></button>
<button class="tile" data-kind="مواد غذائية"><span class="emoji">🛒</span><b>مواد غذائية</b><small>احتياجات البيت</small></button>
<button class="tile" data-kind="طلبات محلات"><span class="emoji">🏪</span><b>طلبات محلات</b><small>مشتريات متنوعة</small></button>
</div>
<div class="card" style="margin-top:14px">
<b>خطوات الطلب</b>
<p class="muted">1. اكتب اسم المحل وطلبك.<br>2. حدد مكان الاستلام وعنوانك.<br>3. اقترح أجرة التوصيل واحفظ الطلب.</p>
</div>
</section>

<section id="new" class="hidden">
<h2 class="title">طلب توصيل جديد</h2>
<div class="card">
<label class="field"><span>نوع الطلب</span>
<select id="kind">
<option>مطاعم وأكل</option><option>مواد غذائية</option><option>طلبات محلات</option><option>أغراض أخرى</option>
</select></label>

<label class="field"><span>اسم الزبون (اختياري)</span><input id="name" maxlength="60" placeholder="اسمك"></label>
<label class="field"><span>رقم الهاتف (اختياري)</span><input id="phone" inputmode="tel" maxlength="20" placeholder="رقم للتواصل"></label>
<label class="field"><span>اسم المحل أو المطعم</span><input id="shop" maxlength="120" placeholder="مثلاً: اسم المطعم"></label>
<label class="field"><span>تفاصيل الطلب</span><textarea id="details" maxlength="500" placeholder="اكتب شنو تريد تشتري والكمية"></textarea></label>
<label class="field"><span>عنوان الاستلام من المحل</span><input id="pickup" maxlength="180" placeholder="اسم المحل أو عنوانه"></label>
<label class="field"><span>عنوان التوصيل</span><input id="dropoff" maxlength="180" placeholder="الحي، أقرب نقطة دالة، أو عنوان البيت"></label>

<div class="row">
<button class="alt" id="getLocation">حدد موقعي الحالي</button>
<button class="outline" id="openMap">افتح الخرائط</button>
</div>
<p id="coords" class="coords"></p>

<div class="row">
<label class="field"><span>سعر الطلب (دينار، اختياري)</span><input id="itemsPrice" type="number" min="0" max="1000000" step="250" placeholder="سعر المشتريات"></label>
<label class="field"><span>أجرة التوصيل المقترحة</span><input id="deliveryFee" type="number" min="0" max="100000" step="250" placeholder="مثلاً 2000"></label>
</div>

<label class="field"><span>طريقة الدفع</span>
<select id="pay"><option>نقداً عند الاستلام</option><option>اتفاق مباشر</option></select>
</label>

<label style="display:flex;gap:8px;font-size:13px;color:var(--muted);line-height:1.6">
<input type="checkbox" id="confirm" style="margin-top:5px">
أفهم أن الطلب سيُحفظ على هذا الجهاز فقط ولن يُرسل تلقائياً إلى سائق.
</label>

<button id="save" style="width:100%;margin-top:14px">حفظ طلب التوصيل</button>
<p id="message" class="muted" role="status"></p>
</div>
</section>

<section id="orders" class="hidden">
<h2 class="title">طلباتي</h2>
<div id="list"></div>
<button id="clear" class="outline">مسح كل الطلبات</button>
</section>

<section id="location" class="hidden">
<h2 class="title">موقعي للتوصيل</h2>
<div class="card">
<div class="map">
<div class="pin">📍</div>
<b id="locStatus">حدد موقعك الحالي</b>
<p class="muted">اسمح للمتصفح باستخدام الموقع. قد يتطلب HTTPS واتصال الإنترنت.</p>
<button id="locatePage">تحديد الموقع</button>
<p id="pageCoords" class="coords"></p>
<a id="mapAnchor" class="hidden" target="_blank" rel="noopener noreferrer">عرض موقعي على Google Maps</a>
</div>
<p class="muted">إذا لم يعمل الموقع، اكتب عنوانك يدوياً في نموذج الطلب.</p>
</div>
</section>
</main>
<footer>دزّلي عين التمر • نموذج توضيحي أولي</footer>
</div>

<script>
(()=>{
const $=id=>document.getElementById(id);
const KEY='dezzili_ain_tamr_orders_v1';
let loc=null;

function orders(){
 try{
  let a=JSON.parse(localStorage.getItem(KEY)||'[]');
  return Array.isArray(a)?a:[];
 }catch(e){return[]}
}
function store(a){
 try{localStorage.setItem(KEY,JSON.stringify(a));return true}
 catch(e){return false}
}
function page(p){
 ['home','new','orders','location'].forEach(x=>$(x).classList.toggle('hidden',x!==p));
 document.querySelectorAll('[data-page]').forEach(b=>b.classList.toggle('active',b.dataset.page===p));
 if(p==='orders')render();
}
document.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>page(b.dataset.page));
$('start').onclick=()=>page('new');
document.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{
 $('kind').value=b.dataset.kind;page('new');
});

function getLoc(target,btn){
 if(!navigator.geolocation){
  $(target).textContent='هذا المتصفح لا يدعم تحديد الموقع.';return;
 }
 $(btn).disabled=true;$(btn).textContent='جارٍ تحديد الموقع…';
 navigator.geolocation.getCurrentPosition(p=>{
  loc={lat:p.coords.latitude,lon:p.coords.longitude,accuracy:Math.round(p.coords.accuracy)};
  let s=loc.lat.toFixed(6)+', '+loc.lon.toFixed(6)+' — دقة تقريبية '+loc.accuracy+' م';
  $(target).textContent=s;
  if(target==='pageCoords'){
   $('locStatus').textContent='تم تحديد موقعك';
   $('mapAnchor').href='https://www.google.com/maps?q='+loc.lat+','+loc.lon;
   $('mapAnchor').classList.remove('hidden');
  }
  $(btn).disabled=false;
  $(btn).textContent=btn==='getLocation'?'حدد موقعي الحالي':'تحديد الموقع';
 },e=>{
  $(target).textContent=({1:'لم تسمح بإذن الموقع. فعّله من إعدادات المتصفح.',2:'تعذر تحديد الموقع؛ جرّب مكاناً مفتوحاً.',3:'انتهت المهلة، حاول مرة ثانية.'})[e.code]||'تعذر تحديد الموقع.';
  $(btn).disabled=false;
  $(btn).textContent=btn==='getLocation'?'حدد موقعي الحالي':'تحديد الموقع';
 },{enableHighAccuracy:true,timeout:12000,maximumAge:60000});
}
$('getLocation').onclick=()=>getLoc('coords','getLocation');
$('locatePage').onclick=()=>getLoc('pageCoords','locatePage');
$('openMap').onclick=()=>{
 let q=loc?loc.lat+','+loc.lon:($('dropoff').value||'عين التمر، كربلاء، العراق');
 window.open('https://www.google.com/maps/search/?api=1&query='+encodeURIComponent(q),'_blank');
};

$('save').onclick=()=>{
 let m=$('message');
 if(!$('confirm').checked){m.textContent='علّم على المربع للتأكيد أولاً.';return}
 if(!$('shop').value.trim()||!$('details').value.trim()||!$('pickup').value.trim()||!$('dropoff').value.trim()){
  m.textContent='املأ اسم المحل وتفاصيل الطلب وعنوان الاستلام والتوصيل.';return
 }
 let price=Number($('itemsPrice').value||0),fee=Number($('deliveryFee').value||0);
 if(price<0||price>1000000||fee<0||fee>100000){
  m.textContent='تأكد من الأسعار المدخلة.';return
 }
 let a=orders(),o={
  id:'WT-'+Date.now().toString().slice(-8),
  kind:$('kind').value,name:$('name').value.trim(),
  phone:$('phone').value.trim(),shop:$('shop').value.trim(),
  details:$('details').value.trim(),pickup:$('pickup').value.trim(),
  dropoff:$('dropoff').value.trim(),itemsPrice:price,fee,
  pay:$('pay').value,loc,created:new Date().toLocaleString('ar-IQ'),
  status:'محفوظ على الجهاز'
 };
 a.unshift(o);
 if(!store(a)){m.textContent='تعذر الحفظ على هذا الجهاز.';return}
 m.textContent='انحفظ الطلب برقم '+o.id+' على هذا الجهاز فقط؛ لم يُرسل إلى سائق.';
 ['name','phone','shop','details','pickup','dropoff','itemsPrice','deliveryFee'].forEach(x=>$(x).value='');
 $('confirm').checked=false;
};

function esc(s){
 return String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function money(n){return Number(n||0).toLocaleString('en-US')+' د.ع'}
function render(){
 let a=orders();
 $('list').innerHTML=a.length?a.map(o=>
  '<div class="card order"><div class="row"><b>'+esc(o.kind)+' • '+esc(o.shop)+'</b><span class="status">'+esc(o.status)+'</span></div>'+
  '<p class="muted">رقم '+esc(o.id)+' — '+esc(o.created)+'</p>'+
  '<p><b>الطلب:</b> '+esc(o.details)+'</p>'+
  '<p><b>الاستلام:</b> '+esc(o.pickup)+'</p>'+
  '<p><b>التوصيل:</b> '+esc(o.dropoff)+'</p>'+
  '<p>المشتريات: '+money(o.itemsPrice)+' | التوصيل: <span class="price">'+money(o.fee)+'</span></p>'+
  '<button class="outline" data-del="'+esc(o.id)+'">حذف الطلب</button></div>'
 ).join(''):'<div class="card muted">ماكو طلبات محفوظة حالياً.</div>';
 $('list').querySelectorAll('[data-del]').forEach(b=>b.onclick=()=>{
  if(confirm('تحذف هذا الطلب؟')){
   store(orders().filter(o=>o.id!==b.dataset.del));render();
  }
 });
}
$('clear').onclick=()=>{
 if(confirm('تمسح جميع الطلبات المحفوظة؟')){store([]);render()}
};
render();
})();
</script>
</body>
</html>
