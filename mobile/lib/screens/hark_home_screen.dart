import 'package:flutter/material.dart';
import '../models/hark_models.dart';
import '../widgets/living_sky_background.dart';
import '../widgets/embedded_handoff_viewer.dart';
import '../widgets/action_button_card.dart';
import '../widgets/dynamic_panel_card.dart';

class HarkHomeScreen extends StatefulWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenChat;
  final HarkTask? externalActiveTask;

  const HarkHomeScreen({
    super.key,
    required this.onOpenVault,
    required this.onOpenChat,
    this.externalActiveTask,
  });

  @override
  State<HarkHomeScreen> createState() => _HarkHomeScreenState();
}

class _HarkHomeScreenState extends State<HarkHomeScreen> {
  late List<HarkTask> _tasks;
  late HarkTask _activeTask;
  bool _isTaskRunning = false;
  bool _isViewerMaximized = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tasks = HarkMockData.getMockTasks();
    _activeTask = widget.externalActiveTask ?? _tasks[0];
  }

  @override
  void didUpdateWidget(covariant HarkHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalActiveTask != null &&
        widget.externalActiveTask!.id != _activeTask.id) {
      _executeTask(widget.externalActiveTask!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _executeTask(HarkTask task) {
    setState(() {
      _activeTask = task;
      _activeTask.status = TaskStatus.running;
      _isTaskRunning = true;
    });

    // Scroll smoothly to top to watch Handoff viewer
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onTaskStatusChanged(HarkTask updatedTask) {
    setState(() {
      _activeTask = updatedTask;
      final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
      if (updatedTask.status == TaskStatus.completed) {
        _isTaskRunning = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPhase = LivingSkyBackground.getCurrentPhase();
    final phaseName = LivingSkyBackground.getPhaseDisplayName(currentPhase);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          children: [
            // 1. Top Bar: Weather, Clock & "Secured by Hark" Shield Badge
            _buildTopBar(phaseName),
            const SizedBox(height: 16),

            // 2. Prominent Handoff Virtual Computer Viewer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "HANDOFF VIRTUAL COMPUTER",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _activeTask.accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeTask.accentColor.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    _activeTask.service.toUpperCase(),
                    style: TextStyle(
                      color: _activeTask.accentColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            EmbeddedHandoffViewer(
              activeTask: _activeTask,
              isRunning: _isTaskRunning,
              isMaximized: _isViewerMaximized,
              onMaximizeToggle: () {
                setState(() => _isViewerMaximized = !_isViewerMaximized);
              },
              onTaskStatusChanged: _onTaskStatusChanged,
            ),
            const SizedBox(height: 24),

            // 3. Proactive Action Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "PROACTIVE ACTION FEED",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  "4 Prepared",
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ..._tasks.map((task) {
              return ActionButtonCard(
                task: task,
                onRun: () => _executeTask(task),
                onTap: () {
                  setState(() => _activeTask = task);
                },
              );
            }),
            const SizedBox(height: 20),

            // 4. Dynamic Panels Grid
            const Text(
              "DYNAMIC PANELS • LIVE MODULES",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            const FlightTrackerPanel(),
            const HealthFitnessPanel(),
            const HomeEnergyPanel(),
            const MediaAudioPanel(),

            const SizedBox(height: 80), // Padding for floating command bar
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String phaseName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand & Living Atmosphere indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text(
                  "HARK PRO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "OS 3.0",
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    color: Color(0xFFFFB37C), size: 12),
                const SizedBox(width: 4),
                const Text(
                  "72°F SFO • ",
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                Text(
                  phaseName,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Secured by Hark Shield Badge (Tappable to open Vault)
        GestureDetector(
          onTap: widget.onOpenVault,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF30D158).withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF30D158).withOpacity(0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_rounded, color: Color(0xFF30D158), size: 14),
                SizedBox(width: 5),
                Text(
                  "Secured",
                  style: TextStyle(
                    color: Color(0xFF30D158),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
