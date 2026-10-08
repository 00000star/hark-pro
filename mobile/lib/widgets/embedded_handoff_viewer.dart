import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hark_models.dart';

class EmbeddedHandoffViewer extends StatefulWidget {
  final HarkTask activeTask;
  final bool isRunning;
  final VoidCallback? onTogglePause;
  final VoidCallback? onTakeOver;
  final VoidCallback? onMaximizeToggle;
  final ValueChanged<HarkTask>? onTaskStatusChanged;
  final bool isMaximized;

  const EmbeddedHandoffViewer({
    super.key,
    required this.activeTask,
    this.isRunning = false,
    this.onTogglePause,
    this.onTakeOver,
    this.onMaximizeToggle,
    this.onTaskStatusChanged,
    this.isMaximized = false,
  });

  @override
  State<EmbeddedHandoffViewer> createState() => _EmbeddedHandoffViewerState();
}

class _EmbeddedHandoffViewerState extends State<EmbeddedHandoffViewer>
    with TickerProviderStateMixin {
  late AnimationController _cursorController;
  late AnimationController _rippleController;
  late AnimationController _pulseController;

  Offset _cursorPos = const Offset(0.5, 0.5);
  Offset _startPos = const Offset(0.5, 0.5);
  Offset _targetPos = const Offset(0.5, 0.5);
  Offset _controlPos = const Offset(0.5, 0.5);

  bool _isClicking = false;
  bool _isUserTakeover = false;
  bool _isPaused = false;
  int _activeStepIndex = 0;
  Timer? _stepExecutionTimer;
  Offset? _userTouchOffset;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _cursorController.addListener(() {
      final t = _cursorController.value;
      // Quadratic Bezier interpolation: B(t) = (1-t)^2 P0 + 2(1-t)t P1 + t^2 P2
      final invT = 1.0 - t;
      final x = (invT * invT * _startPos.dx) +
          (2 * invT * t * _controlPos.dx) +
          (t * t * _targetPos.dx);
      final y = (invT * invT * _startPos.dy) +
          (2 * invT * t * _controlPos.dy) +
          (t * t * _targetPos.dy);

      setState(() {
        _cursorPos = Offset(x, y);
      });
    });

    _cursorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerClickAtTarget();
      }
    });

    if (widget.isRunning) {
      _startSimulation();
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedHandoffViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTask.id != widget.activeTask.id) {
      _activeStepIndex = 0;
      _isPaused = false;
      _isUserTakeover = false;
      if (widget.isRunning) {
        _startSimulation();
      } else {
        _resetCursor();
      }
    } else if (!oldWidget.isRunning && widget.isRunning) {
      _startSimulation();
    } else if (oldWidget.isRunning && !widget.isRunning) {
      _stepExecutionTimer?.cancel();
    }
  }

  void _resetCursor() {
    _stepExecutionTimer?.cancel();
    _cursorController.stop();
    setState(() {
      _startPos = const Offset(0.5, 0.5);
      _targetPos = const Offset(0.5, 0.5);
      _controlPos = const Offset(0.5, 0.5);
      _cursorPos = const Offset(0.5, 0.5);
      _isClicking = false;
    });
  }

  void _startSimulation() {
    _stepExecutionTimer?.cancel();
    _activeStepIndex = 0;
    _isPaused = false;
    _moveToStep(_activeStepIndex);
  }

  void _moveToStep(int stepIndex) {
    if (_isPaused || _isUserTakeover) return;
    if (stepIndex >= widget.activeTask.steps.length) {
      // Completed!
      final updated = widget.activeTask.copyWith(
        status: TaskStatus.completed,
        progress: 1.0,
        currentStepIndex: widget.activeTask.steps.length,
      );
      widget.onTaskStatusChanged?.call(updated);
      return;
    }

    final step = widget.activeTask.steps[stepIndex];
    final nextTarget = step.targetPosition;

    setState(() {
      _activeStepIndex = stepIndex;
      _startPos = _cursorPos;
      _targetPos = nextTarget;
      // Curve control point with organic arc offset
      final midX = (_startPos.dx + nextTarget.dx) / 2.0;
      final midY = (_startPos.dy + nextTarget.dy) / 2.0;
      final dx = nextTarget.dx - _startPos.dx;
      final dy = nextTarget.dy - _startPos.dy;
      // Perpendicular displacement for natural bezier arc
      _controlPos = Offset(
        midX - dy * 0.35 + (math.Random().nextDouble() - 0.5) * 0.1,
        midY + dx * 0.35 + (math.Random().nextDouble() - 0.5) * 0.1,
      );
    });

    _cursorController.duration = step.duration;
    _cursorController.forward(from: 0.0);
  }

  void _triggerClickAtTarget() {
    if (!mounted) return;
    setState(() {
      _isClicking = true;
    });
    _rippleController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isClicking = false;
        });
      }
    });

    // Update task progress
    final progress = (_activeStepIndex + 1) / widget.activeTask.steps.length;
    final updated = widget.activeTask.copyWith(
      status: TaskStatus.running,
      progress: progress,
      currentStepIndex: _activeStepIndex,
    );
    widget.onTaskStatusChanged?.call(updated);

    // Schedule next step
    _stepExecutionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_isPaused && !_isUserTakeover) {
        _moveToStep(_activeStepIndex + 1);
      }
    });
  }

  void _togglePauseInternal() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _cursorController.stop();
        _stepExecutionTimer?.cancel();
      } else {
        _cursorController.forward();
      }
    });
    widget.onTogglePause?.call();
  }

  void _toggleTakeOverInternal() {
    setState(() {
      _isUserTakeover = !_isUserTakeover;
      if (_isUserTakeover) {
        _cursorController.stop();
        _stepExecutionTimer?.cancel();
      } else {
        _moveToStep(_activeStepIndex);
      }
    });
    widget.onTakeOver?.call();
  }

  @override
  void dispose() {
    _stepExecutionTimer?.cancel();
    _cursorController.dispose();
    _rippleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double viewerHeight = widget.isMaximized ? 420.0 : 250.0;
    final step = (_activeStepIndex < widget.activeTask.steps.length)
        ? widget.activeTask.steps[_activeStepIndex]
        : null;

    final thoughtText = _isUserTakeover
        ? "User manual takeover active. Control sandbox directly."
        : _isPaused
            ? "Handoff paused by operator. Tap Resume to proceed."
            : widget.activeTask.status == TaskStatus.completed
                ? "Task completed successfully. Credentials encrypted."
                : widget.isRunning
                    ? (step?.thoughtTicker ?? "Executing autonomous workflow...")
                    : "Virtual Computer Ready. Tap Run to initiate Handoff.";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      height: viewerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isRunning
              ? widget.activeTask.accentColor.withOpacity(0.4)
              : Colors.white.withOpacity(0.12),
          width: widget.isRunning ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isRunning
                ? widget.activeTask.accentColor.withOpacity(0.18)
                : Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Browser Chrome Header Bar
          _buildBrowserChrome(context),

          // 2. Interactive Virtual Viewport with DOM Simulation
          Expanded(
            child: Stack(
              children: [
                // Simulated Web Page Content
                Positioned.fill(
                  child: GestureDetector(
                    onTapDown: _isUserTakeover
                        ? (details) {
                            setState(() {
                              _userTouchOffset = details.localPosition;
                            });
                          }
                        : null,
                    child: _buildWebPageSimulation(context),
                  ),
                ),

                // Element Bounding Badges ([1], [2], [3], [4])
                ...widget.activeTask.steps.map((s) {
                  final isActive = s.elementBadgeIndex ==
                      (step?.elementBadgeIndex ?? -1);
                  return Positioned(
                    left: s.targetPosition.dx *
                            MediaQuery.of(context).size.width *
                            0.82 -
                        12,
                    top: s.targetPosition.dy * (viewerHeight - 85) - 12,
                    child: _buildElementBadge(s.elementBadgeIndex, isActive),
                  );
                }),

                // Animated Bezier Cursor & Click Ripples
                if (!_isUserTakeover) _buildAnimatedCursor(context, viewerHeight),

                // User takeover touch indicator
                if (_isUserTakeover && _userTouchOffset != null)
                  Positioned(
                    left: _userTouchOffset!.dx - 16,
                    top: _userTouchOffset!.dy - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                      ),
                    ),
                  ),

                // Top Floating Toolbar (Pause, Take Over, Maximize)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildFloatingControls(),
                ),

                // User Takeover Notification Banner
                if (_isUserTakeover)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            "Operator Takeover Active",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Agent Thought Ticker Footer
          _buildThoughtTickerFooter(thoughtText),
        ],
      ),
    );
  }

  Widget _buildBrowserChrome(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Traffic light dots
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5F56),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFBD2E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF27C93F),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // URL Bar
          Expanded(
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      color: Color(0xFF30D158), size: 11),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.activeTask.url,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.isRunning)
                    RotationTransition(
                      turns: _pulseController,
                      child: const Icon(Icons.sync_rounded,
                          color: Color(0xFF0A84FF), size: 12),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sandbox badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "Sandbox v2.4",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementBadge(int index, bool isActive) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: isActive ? 1.25 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF2A6D)
              : const Color(0xFF0A84FF).withOpacity(0.75),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? const Color(0xFFFF2A6D).withOpacity(0.7)
                  : Colors.black38,
              blurRadius: isActive ? 8 : 4,
            ),
          ],
        ),
        child: Text(
          "[$index]",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCursor(BuildContext context, double viewerHeight) {
    final double areaWidth = MediaQuery.of(context).size.width * 0.85;
    final double areaHeight = viewerHeight - 85;

    final cursorX = _cursorPos.dx * areaWidth;
    final cursorY = _cursorPos.dy * areaHeight;

    return Positioned(
      left: cursorX - 6,
      top: cursorY - 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Click Ripple Effect
          if (_isClicking)
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, _) {
                final rippleSize = 14.0 + (_rippleController.value * 32.0);
                final rippleOpacity = (1.0 - _rippleController.value).clamp(0.0, 1.0);
                return Container(
                  width: rippleSize,
                  height: rippleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF2A6D).withOpacity(rippleOpacity),
                      width: 2.0,
                    ),
                  ),
                );
              },
            ),

          // Cyber Cursor Arrow & Glowing Halo
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: widget.activeTask.accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.activeTask.accentColor.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.navigation_rounded, color: Colors.white, size: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F16).withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pause / Resume
          IconButton(
            iconSize: 14,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: _isPaused ? "Resume Agent" : "Pause Agent",
            icon: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: _isPaused ? const Color(0xFF30D158) : Colors.white70,
            ),
            onPressed: _togglePauseInternal,
          ),
          const SizedBox(width: 4),

          // Take Over
          IconButton(
            iconSize: 14,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: _isUserTakeover ? "Hand back to AI" : "Take Over",
            icon: Icon(
              _isUserTakeover ? Icons.smart_toy_rounded : Icons.pan_tool_rounded,
              color: _isUserTakeover ? const Color(0xFFFF9F0A) : Colors.white70,
            ),
            onPressed: _toggleTakeOverInternal,
          ),
          const SizedBox(width: 4),

          // Maximize / Minimize
          IconButton(
            iconSize: 14,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: widget.isMaximized ? "Minimize" : "Maximize",
            icon: Icon(
              widget.isMaximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white70,
            ),
            onPressed: widget.onMaximizeToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtTickerFooter(String text) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141620),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Pulsing neural cyber-indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.isRunning
                  ? const Color(0xFF00E5FF)
                  : widget.activeTask.status == TaskStatus.completed
                      ? const Color(0xFF30D158)
                      : Colors.white38,
              shape: BoxShape.circle,
              boxShadow: [
                if (widget.isRunning)
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isRunning ? Colors.white : Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (widget.isRunning) ...[
            const SizedBox(width: 6),
            Text(
              "${_activeStepIndex + 1}/${widget.activeTask.steps.length}",
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebPageSimulation(BuildContext context) {
    switch (widget.activeTask.id) {
      case 'pge_bill':
        return _buildPgeSim();
      case 'delta_checkin':
        return _buildDeltaSim();
      case 'doordash_order':
        return _buildDoorDashSim();
      case 'amazon_return':
        return _buildAmazonSim();
      default:
        return _buildPgeSim();
    }
  }

  Widget _buildPgeSim() {
    final isDone = widget.activeTask.status == TaskStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF0D141C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PGE Brand Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0072CE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "PG&E Energy Center",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Text(
                "Acct ****-9012",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Statement Balance Card [1]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF162232),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0072CE).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Current Statement Due",
                        style: TextStyle(color: Colors.white54, fontSize: 10)),
                    SizedBox(height: 2),
                    Text("\$84.20",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text("Due Oct 12",
                      style: TextStyle(
                          color: Color(0xFFFF9F0A),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Funding Source Card [2] & [3]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131924),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.account_balance_rounded,
                    color: Colors.white70, size: 14),
                SizedBox(width: 6),
                Text("Chase Checking (...9042)",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Spacer(),
                Text("Fee: \$0.00",
                    style: TextStyle(color: Color(0xFF30D158), fontSize: 10)),
              ],
            ),
          ),
          const Spacer(),

          // Pay Now Action Button [4]
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF30D158)
                  : const Color(0xFF0072CE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                isDone ? "✓ Payment Confirmed (\$84.20)" : "Pay \$84.20 via ACH",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaSim() {
    final isDone = widget.activeTask.status == TaskStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF140D1C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("DELTA AIR LINES • DL 412",
                  style: TextStyle(
                      color: Color(0xFFBF5AF2),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              Text("Terminal 2 • Gate B22",
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),

          // Route Banner [1]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("SFO",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  Text("08:15 AM",
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const Icon(Icons.flight_takeoff_rounded,
                  color: Color(0xFFBF5AF2), size: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text("JFK",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  Text("04:45 PM",
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Seat & TSA PreCheck Badge [2] & [3]
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF241535),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text("Seat 14A (Window)",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("TSA PreCheck ✓",
                    style: TextStyle(
                        color: Color(0xFF30D158),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Spacer(),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF30D158)
                  : const Color(0xFFBF5AF2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                isDone
                    ? "✓ Boarding Pass Synced to Apple Wallet"
                    : "Confirm Check-In (Seat 14A)",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorDashSim() {
    final isDone = widget.activeTask.status == TaskStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF191208),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Tony's Pizza Napoletana",
                  style: TextStyle(
                      color: Color(0xFFFF9F0A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("DashPass Active",
                  style: TextStyle(
                      color: Color(0xFF30D158),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF261C10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("1x 16\" Margherita Pie",
                    style: TextStyle(color: Colors.white, fontSize: 11)),
                Text("\$28.00",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          const Text("Delivery: 450 Mission St, Apt 21B (24-34 mins)",
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          const Spacer(),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF30D158)
                  : const Color(0xFFFF9F0A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                isDone
                    ? "✓ Order Dispatched (\$32.50 Paid)"
                    : "Authorize Apple Pay (\$32.50)",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmazonSim() {
    final isDone = widget.activeTask.status == TaskStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF0B1712),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Amazon Return Center",
                  style: TextStyle(
                      color: Color(0xFF30D158),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("Order #114-89219",
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF13281E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.headphones_rounded,
                    color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sony WH-1000XM5 Headphones (Refund \$348.00)",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text("Drop-off: The UPS Store (No Box / No Label Needed)",
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          const Spacer(),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                isDone
                    ? "✓ Return Approved • QR Code Saved"
                    : "Generate Encrypted Return QR",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
