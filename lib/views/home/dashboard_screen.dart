import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'dart:math' as math;

/// Modern 2024/2025 Fitness Dashboard
/// Inspired by Apple Fitness+, Strava, Nike Training Club
/// Features: Bold typography, circular progress, dynamic layouts
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const Color _greenAccent = Color(0xFF29603C);
  static const Color _blackPrimary = Color(0xFF000000);
  static const Color _cardWhite = Color(0xFFF5F5F5);
  static const Color _textSecondary = Color(0xFF404040);

  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 15));

    _topAlignmentAnimation = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight).animate(_controller);

    _bottomAlignmentAnimation = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft).animate(_controller);

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? 'Morning'
        : hour < 17
        ? 'Afternoon'
        : 'Evening';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
              colors: const [Color(0xFFD6D6D6), Color(0xFFE8E8E8), Color(0xFFC0C0C0)],
            ),
          ),

          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Obx(() {
                final notificationController = Get.find<NotificationController>();
                final unreadCount = notificationController.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                          Container(
                            width: 25,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                          Container(
                            width: 20,
                            height: 3,
                            decoration: BoxDecoration(color: Color(0xFF29603C), borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ).paddingOnly(left: 10),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }),

              // actions: [
              //   Obx(() {
              //     final notificationController = Get.find<NotificationController>();
              //     final unreadCount = notificationController.unreadCount;
              //     return Stack(
              //       clipBehavior: Clip.none,
              //       children: [
              //         IconButton(
              //           icon: Icon(Icons.notifications_outlined, color: _blackPrimary, size: 28),
              //           onPressed: () => Get.toNamed(AppRoutes.notifications),
              //           padding: EdgeInsets.zero,
              //           constraints: BoxConstraints(),
              //         ),
              //         if (unreadCount > 0)
              //           Positioned(
              //             right: 8,
              //             top: 8,
              //             child: Container(
              //               padding: const EdgeInsets.all(4),
              //               decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              //               constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              //               child: Text(
              //                 unreadCount > 99 ? '99+' : '$unreadCount',
              //                 style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
              //                 textAlign: TextAlign.center,
              //               ),
              //             ),
              //           ),
              //       ],
              //     );
              //   }),
              // ],
              centerTitle: true,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Greeting
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good $greeting',
                            style: TextStyle(color: _textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Let\'s Get Right',
                            style: TextStyle(color: _blackPrimary, fontSize: 40, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Hero Progress Ring
                    _buildProgressRing(),
                    const SizedBox(height: 32),

                    // Quick Start Section
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        'QUICK START',
                        style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickStartScroll(),
                    const SizedBox(height: 40),

                    // Stats Grid
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildStatsGrid()),
                    const SizedBox(height: 40),

                    // Today's Plan
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        'TODAY\'S PLAN',
                        style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildTodaysPlan()),
                    const SizedBox(height: 20),

                    // Recent Activity
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENT',
                            style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                          ),
                          TextButton(
                            onPressed: () => Get.find<HomeNavigationController>().changeTab(2, journalTab: 0),
                            child: Text(
                              'See All',
                              style: TextStyle(color: _greenAccent, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildRecentActivity()),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressRing() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main container with ultra-premium 3D effect
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFAFAFA), Color(0xFFEEEEEE), Color(0xFFE5E5E5)],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                // Deep outer shadow for elevation
                BoxShadow(color: _blackPrimary.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 20), spreadRadius: -8),
                // Mid shadow for depth
                BoxShadow(color: _blackPrimary.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -4),
                // Soft ambient shadow
                BoxShadow(color: _blackPrimary.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
                // Top highlight for 3D pop
                BoxShadow(color: Colors.white.withOpacity(0.9), blurRadius: 2, offset: const Offset(0, -2), spreadRadius: 0),
                // Side highlight
                BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4, offset: const Offset(-2, 0)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Stack(
                children: [
                  // Top glossy highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.2), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Subtle radial glow in center
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(center: Alignment.center, radius: 0.8, colors: [Colors.white.withOpacity(0.3), Colors.transparent]),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Row(
                      children: [
                        // Left side - Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Premium badge with neumorphism
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [_greenAccent.withOpacity(0.12), _greenAccent.withOpacity(0.08)]),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _greenAccent.withOpacity(0.25), width: 1.5),
                                  boxShadow: [BoxShadow(color: _greenAccent.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Text(
                                  'WEEKLY GOAL',
                                  style: TextStyle(color: _greenAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Large number with premium shadow
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '75',
                                    style: TextStyle(
                                      color: _blackPrimary,
                                      fontSize: 68,
                                      fontWeight: FontWeight.w900,
                                      height: 0.85,
                                      letterSpacing: -4,
                                      shadows: [
                                        Shadow(color: _greenAccent.withOpacity(0.2), offset: const Offset(0, 6), blurRadius: 12),
                                        Shadow(color: _blackPrimary.withOpacity(0.08), offset: const Offset(0, 3), blurRadius: 6),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 18, left: 6),
                                    child: Text(
                                      '%',
                                      style: TextStyle(
                                        color: _greenAccent,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                        shadows: [Shadow(color: _greenAccent.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Progress indicator with dot
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [_greenAccent, _greenAccent.withOpacity(0.7)]),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: _greenAccent.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '3 of 4 workouts',
                                      style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right side - Ultra-premium 3D Progress Ring
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow aura
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: _greenAccent.withOpacity(0.25), blurRadius: 32, spreadRadius: 8)],
                                ),
                              ),
                              // Progress ring
                              CustomPaint(
                                size: const Size(130, 130),
                                painter: _UltraPremium3DRingPainter(progress: 0.75, color: _greenAccent),
                              ),
                              // Center neumorphic circle
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFEEEEEE)]),
                                  boxShadow: [
                                    // Outer shadow
                                    BoxShadow(color: _blackPrimary.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                                    // Inner highlight
                                    BoxShadow(color: Colors.white, blurRadius: 4, offset: const Offset(-2, -2)),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [_greenAccent, _greenAccent.withOpacity(0.8)]),
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: _greenAccent.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)],
                                        ),
                                        child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '3/4',
                                        style: TextStyle(color: _blackPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartScroll() {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildQuickStartCard('Start\nWorkout', Icons.play_circle_filled, _greenAccent, () => Get.find<HomeNavigationController>().changeTab(2, journalTab: 0)),
          const SizedBox(width: 16),
          _buildQuickStartCard('Track\nRun', Icons.directions_run_rounded, _blackPrimary, () => Get.find<HomeNavigationController>().changeTab(2, journalTab: 1)),
          const SizedBox(width: 16),
          _buildQuickStartCard('View\nPlanner', Icons.calendar_today_rounded, _blackPrimary, () => Get.toNamed(AppRoutes.planner)),
        ],
      ),
    );
  }

  Widget _buildQuickStartCard(String label, IconData icon, Color accentColor, VoidCallback onTap) {
    final bool isPrimary = accentColor == _greenAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? _greenAccent : _cardWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: isPrimary ? _greenAccent.withOpacity(0.3) : _blackPrimary.withOpacity(0.06), blurRadius: isPrimary ? 20 : 16, offset: Offset(0, isPrimary ? 8 : 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : accentColor, size: 36),
            Text(
              label,
              style: TextStyle(color: isPrimary ? Colors.white : _blackPrimary, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('15', 'Day Streak', Icons.local_fire_department_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('2.4k', 'Calories', Icons.bolt_rounded)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _blackPrimary.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _greenAccent, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(color: _blackPrimary, fontSize: 36, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysPlan() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: _blackPrimary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.fitness_center_rounded, color: _greenAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upper Body Strength',
                      style: TextStyle(color: _blackPrimary, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '45 min • 9:00 AM',
                      style: TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.find<HomeNavigationController>().changeTab(2, journalTab: 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: _greenAccent, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Start Workout',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(children: [_buildActivityItem('Cardio Session', '5:00 PM', false), const SizedBox(height: 12), _buildActivityItem('Morning Run', 'Yesterday', true)]);
  }

  Widget _buildActivityItem(String title, String time, bool completed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _blackPrimary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: completed ? _greenAccent.withOpacity(0.15) : _blackPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
            child: Icon(completed ? Icons.check_circle_rounded : Icons.schedule_rounded, color: completed ? _greenAccent : _textSecondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: _blackPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (completed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _greenAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Done',
                style: TextStyle(color: _greenAccent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ultra-Premium Curved 3D Progress Ring Painter with perspective
class _UltraPremium3DRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _UltraPremium3DRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const baseStrokeWidth = 20.0;

    // Save canvas state for transformations
    canvas.save();

    // Apply subtle perspective tilt for 3D effect
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective
      ..rotateX(0.15); // tilt forward slightly

    canvas.transform(matrix.storage);

    // Background track with neumorphic inner shadow
    final bgPaint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Inner shadow for depth (neumorphism)
    final innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth - 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 6);

    canvas.drawCircle(center, radius - 2, innerShadowPaint);

    // Draw progress with variable stroke width for 3D curve effect
    const segments = 100;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segments; i++) {
      final t = i / segments;
      if (t > progress) break;

      final angle = -math.pi / 2 + (2 * math.pi * t);
      final nextAngle = -math.pi / 2 + (2 * math.pi * (i + 1) / segments);

      // Variable stroke width based on position (thicker at top, thinner at bottom)
      final strokeVariation = math.sin(angle + math.pi / 2) * 4;
      final strokeWidth = baseStrokeWidth + strokeVariation;

      // Color variation for depth (lighter at top, darker at bottom)
      final colorT = (math.sin(angle + math.pi / 2) + 1) / 2;
      progressPaint.color = Color.lerp(color.withOpacity(0.7), color, colorT)!;
      progressPaint.strokeWidth = strokeWidth;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angle, nextAngle - angle, false, progressPaint);
    }

    // Outer glow shadow for progress (stronger at top)
    final outerGlowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth + 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, outerGlowPaint);

    // Top highlight for glossy curved 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius + baseStrokeWidth / 2 - 2), -math.pi / 2, 2 * math.pi * progress * 0.35, false, highlightPaint);

    // Bottom shadow for 3D depth
    final bottomShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - baseStrokeWidth / 2 + 1), math.pi / 4, 2 * math.pi * progress * 0.6, false, bottomShadowPaint);

    // Inner highlight on the left side for curve
    final innerHighlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - baseStrokeWidth / 2 + 3), -math.pi / 2, 2 * math.pi * progress * 0.25, false, innerHighlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_UltraPremium3DRingPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class HomeNavigationController extends GetxController {
  final _currentIndex = 2.obs;
  final journalTabIndex = 0.obs; // 0 = Workout Journal, 1 = Runner Log
  final refreshTrigger = 0.obs; // Trigger to force UI refresh
  GlobalKey<ScaffoldState>? scaffoldKey;

  int get currentIndex => _currentIndex.value;

  void changeTab(int index, {int? journalTab}) {
    if (journalTab != null) {
      journalTabIndex.value = journalTab.clamp(0, 1);
    }
    _currentIndex.value = index;
  }

  void triggerRefresh() {
    refreshTrigger.value++;
  }

  void openDrawer() {
    scaffoldKey?.currentState?.openDrawer();
  }
}
