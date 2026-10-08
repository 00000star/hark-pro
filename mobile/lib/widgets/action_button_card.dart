import 'package:flutter/material.dart';
import '../models/hark_models.dart';

class ActionButtonCard extends StatefulWidget {
  final HarkTask task;
  final VoidCallback onRun;
  final VoidCallback? onTap;

  const ActionButtonCard({
    super.key,
    required this.task,
    required this.onRun,
    this.onTap,
  });

  @override
  State<ActionButtonCard> createState() => _ActionButtonCardState();
}

class _ActionButtonCardState extends State<ActionButtonCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isRunning = task.status == TaskStatus.running;
    final isCompleted = task.status == TaskStatus.completed;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF14161F).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRunning
                  ? task.accentColor.withOpacity(0.6)
                  : isCompleted
                      ? const Color(0xFF30D158).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
              width: isRunning ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isRunning
                    ? task.accentColor.withOpacity(0.18)
                    : Colors.black.withOpacity(0.35),
                blurRadius: isRunning ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Service / Category Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF30D158).withOpacity(0.15)
                      : task.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFF30D158).withOpacity(0.3)
                        : task.accentColor.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : task.icon,
                  color: isCompleted ? const Color(0xFF30D158) : task.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // 2. Title & Verb
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          task.service.toUpperCase(),
                          style: TextStyle(
                            color: task.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.verb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 3. Dynamic Action State Badge / Button
              _buildActionStateButton(task, isRunning, isCompleted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionStateButton(
      HarkTask task, bool isRunning, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF30D158).withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30D158).withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, color: Color(0xFF30D158), size: 14),
            SizedBox(width: 4),
            Text(
              "Done",
              style: TextStyle(
                color: Color(0xFF30D158),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    if (isRunning) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final glow = 0.4 + (_pulseController.value * 0.6);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: task.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: task.accentColor.withOpacity(glow),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: task.accentColor.withOpacity(glow * 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(task.accentColor),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "${(task.progress * 100).toInt()}%",
                  style: TextStyle(
                    color: task.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Idle State - Tappable "Run" Action Pill
    return GestureDetector(
      onTap: widget.onRun,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: task.accentColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: task.accentColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
            SizedBox(width: 3),
            Text(
              "Run",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
