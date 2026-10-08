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
      title: 'حجوزات_1',
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
        title: const Text('حجوزات_1'),
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
   <!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>نظام الحجوزات والمواعيد</title>

<style>
*{box-sizing:border-box}
body{
 margin:0;
 font-family:Arial,Tahoma,sans-serif;
 background:#f3f4f6;
 color:#111827
}
header{
 background:#111827;
 color:white;
 padding:18px;
 text-align:center
}
nav{
 display:flex;
 gap:6px;
 padding:8px;
 background:white;
 overflow:auto;
 position:sticky;
 top:0;
 z-index:10
}
nav button{
 border:0;
 padding:11px 15px;
 border-radius:10px;
 white-space:nowrap;
 cursor:pointer
}
nav button.active{
 background:#111827;
 color:white
}
main{
 max-width:900px;
 margin:auto;
 padding:15px
}
.page{display:none}
.page.active{display:block}

.cards{
 display:grid;
 grid-template-columns:repeat(3,1fr);
 gap:10px
}
.card{
 background:white;
 padding:18px;
 border-radius:15px;
 box-shadow:0 2px 8px #0001
}
.card b{
 display:block;
 font-size:25px;
 margin-top:8px
}

.box{
 background:white;
 padding:16px;
 border-radius:15px;
 margin-bottom:15px;
 box-shadow:0 2px 8px #0001
}

.grid{
 display:grid;
 grid-template-columns:1fr 1fr;
 gap:10px
}
label{
 display:block;
 font-weight:bold;
 margin-bottom:5px
}
input,select,textarea{
 width:100%;
 padding:12px;
 border:1px solid #ddd;
 border-radius:10px;
 font-size:15px
}
textarea{min-height:90px}

button{
 border:0;
 border-radius:10px;
 padding:11px 15px;
 cursor:pointer
}
.primary{
 background:#111827;
 color:white
}
.danger{
 background:#fee2e2;
 color:#991b1b
}
.success{
 background:#dcfce7;
 color:#166534
}
.actions{
 display:flex;
 gap:8px;
 margin-top:15px;
 flex-wrap:wrap
}

.booking{
 background:white;
 padding:15px;
 margin:10px 0;
 border-radius:15px;
 box-shadow:0 2px 8px #0001
}
.booking-title{
 font-size:18px;
 font-weight:bold
}
.info{
 color:#4b5563;
 line-height:1.9;
 margin:8px 0
}

.search{
 display:grid;
 grid-template-columns:2fr 1fr 1fr;
 gap:8px;
 margin-bottom:12px
}

.empty{
 background:white;
 padding:35px;
 text-align:center;
 border-radius:15px;
 color:#777
}

@media(max-width:600px){
 .cards{grid-template-columns:1fr 1fr}
 .grid{grid-template-columns:1fr}
 .search{grid-template-columns:1fr}
}
</style>
</head>

<body>

<header>
<h2>📅 نظام الحجوزات والمواعيد</h2>
<div id="today"></div>
</header>

<nav>
<button class="active" onclick="showPage('home',this)">الرئيسية</button>
<button onclick="showPage('add',this)">➕ حجز جديد</button>
<button onclick="showPage('bookings',this)">📋 الحجوزات</button>
<button onclick="showPage('employees',this)">👥 الموظفون</button>
<button onclick="showPage('backup',this)">💾 النسخ الاحتياطي</button>
</nav>

<main>

<!-- الرئيسية -->
<section id="home" class="page active">

<div class="cards">
<div class="card">
حجوزات اليوم
<b id="todayCount">0</b>
</div>

<div class="card">
الحجوزات القادمة
<b id="futureCount">0</b>
</div>

<div class="card">
إجمالي الحجوزات
<b id="totalCount">0</b>
</div>
</div>

<div class="box">
<h3>مواعيد اليوم</h3>
<div id="todayList"></div>
</div>

</section>


<!-- إضافة حجز -->
<section id="add" class="page">

<div class="box">

<h3 id="formTitle">إضافة حجز جديد</h3>

<div class="grid">

<div>
<label>اسم الزبون *</label>
<input id="name" placeholder="اسم الزبون">
</div>

<div>
<label>رقم الهاتف</label>
<input id="phone" type="tel" placeholder="07xxxxxxxxx">
</div>

<div>
<label>التاريخ *</label>
<input id="date" type="date">
</div>

<div>
<label>الوقت *</label>
<input id="time" type="time">
</div>

<div>
<label>الخدمة</label>
<input id="service" placeholder="نوع الخدمة">
</div>

<div>
<label>الموظف</label>
<select id="employee"></select>
</div>

<div style="grid-column:1/-1">
<label>ملاحظات</label>
<textarea id="notes"></textarea>
</div>

</div>

<div class="actions">
<button class="primary" onclick="saveBooking()">💾 حفظ الحجز</button>
<button onclick="clearForm()">مسح</button>
</div>

</div>
</section>


<!-- الحجوزات -->
<section id="bookings" class="page">

<div class="search">

<input
id="search"
placeholder="🔎 بحث بالاسم أو الهاتف"
oninput="renderBookings()">

<input
id="filterDate"
type="date"
onchange="renderBookings()">

<select id="filterEmployee"
onchange="renderBookings()">
<option value="">كل الموظفين</option>
</select>

</div>

<div id="bookingList"></div>

</section>


<!-- الموظفون -->
<section id="employees" class="page">

<div class="box">

<h3>إضافة موظف</h3>

<div class="actions">

<input
id="employeeName"
placeholder="اسم الموظف">

<button class="primary" onclick="addEmployee()">
إضافة
</button>

</div>

<hr>

<div id="employeeList"></div>

</div>

</section>


<!-- النسخ الاحتياطي -->
<section id="backup" class="page">

<div class="box">

<h3>النسخ الاحتياطي</h3>

<p>
يمكنك حفظ نسخة من بيانات الحجوزات واستعادتها لاحقاً.
</p>

<div class="actions">

<button class="primary" onclick="exportData()">
⬇️ تصدير نسخة
</button>

<button class="success" onclick="exportCSV()">
📊 تصدير CSV
</button>

<button onclick="document.getElementById('file').click()">
⬆️ استيراد نسخة
</button>

<input
id="file"
type="file"
accept=".json"
style="display:none"
onchange="importData(event)">

</div>

<hr>

<button class="danger" onclick="deleteAll()">
⚠️ حذف جميع البيانات
</button>

</div>

</section>

</main>


<script>

const STORAGE="booking_system_v1";

let data=JSON.parse(
 localStorage.getItem(STORAGE)
)||{
 bookings:[],
 employees:["موظف 1","موظف 2"]
};

let editId=null;


/* حفظ البيانات */

function saveData(){

localStorage.setItem(
 STORAGE,
 JSON.stringify(data)
);

renderAll();

}


/* تغيير الصفحات */

function showPage(id,button){

document
.querySelectorAll(".page")
.forEach(x=>x.classList.remove("active"));

document
.getElementById(id)
.classList.add("active");

document
.querySelectorAll("nav button")
.forEach(x=>x.classList.remove("active"));

button.classList.add("active");

}


/* تاريخ اليوم */

function today(){

let d=new Date();

return d.getFullYear()+"-"+
String(d.getMonth()+1).padStart(2,"0")+"-"+
String(d.getDate()).padStart(2,"0");

}


/* عرض التاريخ */

function formatDate(date){

if(!date)return "";

let p=date.split("-");

return p[2]+"/"+p[1]+"/"+p[0];

}


/* تنظيف النص */

function clean(text){

return String(text||"")
.replaceAll("&","&amp;")
.replaceAll("<","&lt;")
.replaceAll(">","&gt;")
.replaceAll('"',"&quot;");

}


/* الموظفين */

function renderEmployees(){

let select=document.getElementById("employee");

select.innerHTML=
'<option value="">اختر موظف</option>'+
data.employees
.map(x=>`<option>${clean(x)}</option>`)
.join("");

let filter=document.getElementById("filterEmployee");

filter.innerHTML=
'<option value="">كل الموظفين</option>'+
data.employees
.map(x=>`<option>${clean(x)}</option>`)
.join("");

let list=document.getElementById("employeeList");

if(!data.employees.length){

list.innerHTML='<div class="empty">لا يوجد موظفون</div>';

return;
}

list.innerHTML=data.employees.map((x,i)=>`

<div class="booking">

<b>${clean(x)}</b>

<button
class="danger"
style="float:left"
onclick="removeEmployee(${i})">

حذف

</button>

</div>

`).join("");

}


function addEmployee(){

let name=document
.getElementById("employeeName")
.value.trim();

if(!name){

alert("اكتب اسم الموظف");

return;

}

if(data.employees.includes(name)){

alert("الموظف موجود");

return;

}

data.employees.push(name);

document.getElementById("employeeName").value="";

saveData();

}


function removeEmployee(index){

if(!confirm("حذف الموظف؟"))return;

data.employees.splice(index,1);

saveData();

}


/* حفظ الحجز */

function saveBooking(){

let booking={

id:editId||Date.now().toString(),

name:document.getElementById("name").value.trim(),

phone:document.getElementById("phone").value.trim(),

date:document.getElementById("date").value,

time:document.getElementById("time").value,

service:document.getElementById("service").value.trim(),

employee:document.getElementById("employee").value,

notes:document.getElementById("notes").value.trim()

};


if(!booking.name||
!booking.date||
!booking.time){

alert("يرجى إدخال الاسم والتاريخ والوقت");

return;

}


if(editId){

let index=data.bookings
.findIndex(x=>x.id===editId);

data.bookings[index]=booking;

}else{

data.bookings.push(booking);

}


editId=null;

clearForm();

saveData();

alert("تم حفظ الحجز بنجاح");

}


/* مسح النموذج */

function clearForm(){

document.getElementById("name").value="";

document.getElementById("phone").value="";

document.getElementById("date").value=today();

document.getElementById("time").value="";

document.getElementById("service").value="";

document.getElementById("employee").value="";

document.getElementById("notes").value="";

document.getElementById("formTitle").textContent=
"إضافة حجز جديد";

editId=null;

}


/* إنشاء بطاقة حجز */

function bookingCard(b){

return `

<div class="booking">

<div class="booking-title">

${clean(b.name)}

</div>

<div class="info">

📅 ${formatDate(b.date)}

<br>

🕐 ${clean(b.time)}

<br>

📞 ${clean(b.phone||"لا يوجد")}

<br>

🧾 ${clean(b.service||"غير محدد")}

<br>

👤 ${clean(b.employee||"غير محدد")}

${b.notes?
`<br>📝 ${clean(b.notes)}`:""}

</div>

<div class="actions">

<button
class="primary"
onclick="editBooking('${b.id}')">

✏️ تعديل

</button>

<button
class="danger"
onclick="deleteBooking('${b.id}')">

🗑️ حذف

</button>

</div>

</div>

`;

}


/* عرض الحجوزات */

function renderBookings(){

let search=document
.getElementById("search")
.value
.toLowerCase();

let date=document
.getElementById("filterDate")
.value;

let employee=document
.getElementById("filterEmployee")
.value;


let list=data.bookings.filter(b=>{

let text=
(b.name+" "+
b.phone+" "+
b.service+" "+
b.notes)
.toLowerCase();

return

(!search||text.includes(search))&&

(!date||b.date===date)&&

(!employee||b.employee===employee);

});


list.sort((a,b)=>
(a.date+a.time).localeCompare(b.date+b.time)
);


let container=
document.getElementById("bookingList");


if(!list.length){

container.innerHTML=
'<div class="empty">لا توجد حجوزات</div>';

return;

}


container.innerHTML=
list.map(bookingCard).join("");

}


/* تعديل */

function editBooking(id){

let b=data.bookings
.find(x=>x.id===id);

if(!b)return;

editId=id;

document.getElementById("name").value=b.name;

document.getElementById("phone").value=b.phone;

document.getElementById("date").value=b.date;

document.getElementById("time").value=b.time;

document.getElementById("service").value=b.service;

document.getElementById("employee").value=b.employee;

document.getElementById("notes").value=b.notes;

document.getElementById("formTitle").textContent=
"تعديل الحجز";

document
.querySelectorAll("nav button")[1]
.click();

}


/* حذف */

function deleteBooking(id){

if(!confirm("هل تريد حذف هذا الحجز؟"))return;

data.bookings=
data.bookings.filter(x=>x.id!==id);

saveData();

}


/* الرئيسية */

function renderHome(){

let t=today();

let todayBookings=
data.bookings.filter(x=>x.date===t);

let future=
data.bookings.filter(x=>
x.date>t
);

document.getElementById("todayCount")
.textContent=todayBookings.length;

document.getElementById("futureCount")
.textContent=future.length;

document.getElementById("totalCount")
.textContent=data.bookings.length;


let list=document.getElementById("todayList");

if(!todayBookings.length){

list.innerHTML=
'<div class="empty">لا توجد حجوزات اليوم</div>';

}else{

list.innerHTML=
todayBookings
.sort((a,b)=>a.time.localeCompare(b.time))
.map(bookingCard)
.join("");

}

}


/* تصدير JSON */

function exportData(){

let blob=new Blob(
[JSON.stringify(data,null,2)],
{type:"application/json"}
);

let url=URL.createObjectURL(blob);

let a=document.createElement("a");

a.href=url;

a.download="نسخة_الحجوزات.json";

a.click();

URL.revokeObjectURL(url);

}


/* تصدير CSV */

function exportCSV(){

let rows=[

[
"الاسم",
"الهاتف",
"التاريخ",
"الوقت",
"الخدمة",
"الموظف",
"الملاحظات"
]

];

data.bookings.forEach(b=>{

rows.push([
b.name,
b.phone,
b.date,
b.time,
b.service,
b.employee,
b.notes
]);

});


let csv="\uFEFF"+
rows
.map(row=>
row.map(x=>
`"${String(x||"").replaceAll('"','""')}"`
).join(",")
)
.join("\n");


let blob=new Blob(
[csv],
{type:"text/csv;charset=utf-8"}
);

let url=URL.createObjectURL(blob);

let a=document.createElement("a");

a.href=url;

a.download="الحجوزات.csv";

a.click();

URL.revokeObjectURL(url);

}


/* استيراد */

function importData(event){

let file=event.target.files[0];

if(!file)return;

let reader=new FileReader();

reader.onload=function(){

try{

let imported=
JSON.parse(reader.result);

if(!Array.isArray(imported.bookings)||
!Array.isArray(imported.employees)){

throw Error();

}

data=imported;

saveData();

alert("تم استيراد البيانات بنجاح");

}catch{

alert("الملف غير صالح");

}

};

reader.readAsText(file);

}


/* حذف الكل */

function deleteAll(){

if(!confirm(
"سيتم حذف جميع الحجوزات والبيانات. هل أنت متأكد؟"
))return;

data={
bookings:[],
employees:["موظف 1","موظف 2"]
};

saveData();

}


/* تشغيل البرنامج */

document.getElementById("date").value=today();

document.getElementById("today").textContent=
new Date().toLocaleDateString(
"ar-IQ",
{
weekday:"long",
year:"numeric",
month:"long",
day:"numeric"
}
);

function renderAll(){

renderEmployees();

renderBookings();

renderHome();

}

renderAll();

</script>

</body>
</html>
         'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}