import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../providers/setup_provider.dart';
import '../providers/student_provider.dart';
import '../providers/teacher_provider.dart';

// Dummy providers for stats until actual database is implemented
final attendanceAvgProvider = StateProvider<double>((ref) => 0.0);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color primaryGreen = theme.colorScheme.primary;
    final Color goldAccent = theme.colorScheme.secondary;
    final Color bgColor = theme.scaffoldBackgroundColor;

    final settingsState = ref.watch(settingsProvider);
    final studentsState = ref.watch(studentsProvider);
    
    final totalStudents = studentsState.maybeWhen(
      data: (students) => students.length,
      orElse: () => 0,
    );
    
    final teachersState = ref.watch(teachersProvider);
    final totalTeachers = teachersState.maybeWhen(
      data: (teachers) => teachers.length,
      orElse: () => 0,
    );
    
    final attendanceAvg = ref.watch(attendanceAvgProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: settingsState.when(
        data: (settings) {
          if (settings == null) {
            return const Center(child: Text('لا توجد إعدادات محفوظة'));
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, settings, primaryGreen, goldAccent, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإحصائيات العامة',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatsRow(totalStudents, totalTeachers, attendanceAvg, primaryGreen, goldAccent),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'العمليات الإدارية',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Icon(Icons.dashboard_customize_rounded, color: primaryGreen, size: 24),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildActionGrid(context, primaryGreen, goldAccent, isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: primaryGreen)),
        error: (error, stackTrace) => Center(child: Text('حدث خطأ: $error')),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, settings, Color primaryGreen, Color goldAccent, bool isDark) {
    return SliverAppBar(
      expandedHeight: 260.0,
      backgroundColor: primaryGreen,
      pinned: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
            onPressed: () => context.push('/settings'),
            tooltip: 'الإعدادات',
          ),
        )
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.all(0),
        title: LayoutBuilder(
          builder: (context, constraints) {
            double percent = (constraints.maxHeight - kToolbarHeight) / (260.0 - kToolbarHeight);
            percent = percent.clamp(0.0, 1.0);
            return Opacity(
              opacity: 1.0 - percent,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  settings.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryGreen.withOpacity(0.8), primaryGreen.withOpacity(0.9), primaryGreen],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.mosque, size: 250, color: Colors.white),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.menu_book, size: 180, color: Colors.white),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 10))
                        ],
                      ),
                      child: ClipOval(
                        child: settings.logoPath.isNotEmpty
                            ? Image.file(
                                File(settings.logoPath),
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.mosque, size: 50, color: primaryGreen),
                              )
                            : Container(
                                width: 85,
                                height: 85,
                                color: Colors.grey.shade100,
                                child: Icon(Icons.mosque, size: 50, color: primaryGreen),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AutoSizeText(
                      'أهلاً بك',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: AutoSizeText(
                        settings.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int students, int teachers, double attendance, Color primaryGreen, Color goldAccent) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'الطلاب',
            count: students.toString(),
            icon: Icons.people_alt,
            color: primaryGreen,
            accentColor: goldAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'المعلمين',
            count: teachers.toString(),
            icon: Icons.school,
            color: primaryGreen,
            accentColor: goldAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'الحضور',
            count: '${attendance.toStringAsFixed(0)}%',
            icon: Icons.show_chart,
            color: primaryGreen,
            accentColor: goldAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, Color primaryGreen, Color goldAccent, bool isDark) {
    final actions = [
      {'title': 'إدارة الطلاب', 'icon': Icons.people_alt_outlined, 'route': '/students', 'color': Colors.blue},
      {'title': 'المعلمين', 'icon': Icons.person_add_alt_1_outlined, 'route': '/teachers', 'color': Colors.purple},
      {'title': 'سجل الحضور', 'icon': Icons.fact_check_outlined, 'route': '/attendance', 'color': primaryGreen},
      {'title': 'التقارير والإحصاء', 'icon': Icons.insert_chart_outlined, 'route': '/reports', 'color': Colors.orange},
      {'title': 'البطاقات التعريفية', 'icon': Icons.badge_outlined, 'route': '/id_cards', 'color': Colors.teal},
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final actionColor = action['color'] as Color;
        return _ActionCard(
          title: action['title'] as String,
          icon: action['icon'] as IconData,
          route: action['route'] as String,
          color: actionColor,
          isDark: isDark,
          primaryGreen: primaryGreen,
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final Color accentColor;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.accentColor,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              widget.count,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            AutoSizeText(
              widget.title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              minFontSize: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  final bool isDark;
  final Color primaryGreen;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
    required this.isDark,
    required this.primaryGreen,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -5.0 : 0.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? widget.color.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 4),
            )
          ],
          border: Border.all(
            color: _isHovered ? widget.color.withOpacity(0.3) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            splashColor: widget.color.withOpacity(0.1),
            highlightColor: widget.color.withOpacity(0.05),
            onTap: () {
              if (['/students', '/teachers', '/attendance', '/reports', '/id_cards'].contains(widget.route)) {
                context.push(widget.route);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('سيتم تفعيل ${widget.title} قريباً')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isHovered ? widget.color : widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: _isHovered ? Colors.white : widget.color,
                    ),
                  ),
                  const Spacer(),
                  AutoSizeText(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    minFontSize: 12,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

