import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PipComputerViewer extends StatefulWidget {
  final String serverHost;
  const PipComputerViewer({super.key, this.serverHost = '127.0.0.1:8000'});

  @override
  State<PipComputerViewer> createState() => _PipComputerViewerState();
}

class _PipComputerViewerState extends State<PipComputerViewer> {
  WebSocketChannel? _channel;
  Offset _cursorPos = const Offset(640, 400);
  bool _isMouseDown = false;
  String _agentStatus = "Standby";

  @override
  void initState() {
    super.initState();
    _connectTelemetry();
  }

  void _connectTelemetry() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://${widget.serverHost}/ws/telemetry'),
      );
      _channel?.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['event'] == 'cursor_position') {
          final pos = data['data'];
          if (mounted) {
            setState(() {
              _cursorPos = Offset(
                (pos['x'] as num).toDouble(),
                (pos['y'] as num).toDouble(),
              );
              _isMouseDown = pos['is_mouse_down'] ?? false;
            });
          }
        } else if (data['event'] == 'task_started') {
          if (mounted) setState(() => _agentStatus = "Navigating...");
        } else if (data['event'] == 'task_finished') {
          if (mounted) setState(() => _agentStatus = "Task Completed");
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Simulated or live stream image
          Positioned.fill(
            child: Image.network(
              'http://${widget.serverHost}/stream/video',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Text(
                  "Virtual Computer Idle",
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ),
          ),
          // Cursor Overlay
          Positioned(
            left: (_cursorPos.dx / 1280.0) * MediaQuery.of(context).size.width,
            top: (_cursorPos.dy / 800.0) * 220,
            child: Transform.translate(
              offset: const Offset(-8, -8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _isMouseDown ? 18 : 14,
                height: _isMouseDown ? 18 : 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A6D),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withOpacity(0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Top Status Badge
          Positioned(
            top: 12,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _agentStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}
