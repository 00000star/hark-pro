import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/hark_models.dart';
import '../models/sdui_schema.dart';

// ============================================================================
// DUAL-MODE API SERVICE: LIVE WEBSOCKET + OFFLINE AUTONOMOUS SIMULATION
// Parity with backend STARBOY PRIME FastAPI + WebSocket telemetry server
// ============================================================================

enum HarkApiMode {
  online_live,
  offline_autonomous,
}

class HarkTelemetryFrame {
  final double cursorX;
  final double cursorY;
  final bool isMouseDown;
  final String thought;
  final int activeStep;
  final String domSelector;
  final String status;
  final Uint8List? screenFrameJpeg;
  final int timestamp;
  final bool requiresApproval;
  final String? pendingAction;

  const HarkTelemetryFrame({
    required this.cursorX,
    required this.cursorY,
    this.isMouseDown = false,
    this.thought = '',
    this.activeStep = 0,
    this.domSelector = '',
    this.status = 'running',
    this.screenFrameJpeg,
    required this.timestamp,
    this.requiresApproval = false,
    this.pendingAction,
  });
}

class HarkApiService {
  static final HarkApiService instance = HarkApiService._internal();

  String _baseUrl = 'http://127.0.0.1:8000';
  String _wsUrl = 'ws://127.0.0.1:8000/ws/telemetry';

  final ValueNotifier<HarkApiMode> connectionStatus =
      ValueNotifier(HarkApiMode.offline_autonomous);

  final StreamController<HarkTelemetryFrame> _telemetryController =
      StreamController<HarkTelemetryFrame>.broadcast();
  Stream<HarkTelemetryFrame> get telemetryStream =>
      _telemetryController.stream;

  final StreamController<HarkRemoteWidget> _remoteWidgetController =
      StreamController<HarkRemoteWidget>.broadcast();
  Stream<HarkRemoteWidget> get remoteWidgetStream =>
      _remoteWidgetController.stream;

  final StreamController<HarkTask> _taskUpdateController =
      StreamController<HarkTask>.broadcast();
  Stream<HarkTask> get taskUpdateStream => _taskUpdateController.stream;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _healthCheckTimer;
  Timer? _simulationTimer;

  HarkTask? _currentRunningTask;
  bool _isSimulationPaused = false;
  int _simulationStepIndex = 0;

  HarkApiService._internal() {
    // Attempt initial backend probe with silent graceful failover
    checkBackendHealth();
    // Periodic liveness heartbeat every 15 seconds
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkBackendHealth();
    });
  }

  void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    final wsBase = _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    _wsUrl = '$wsBase/ws/telemetry';
    checkBackendHealth();
  }

  /// Automatic seamless reachability probe
  Future<bool> checkBackendHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/task/status');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        if (connectionStatus.value != HarkApiMode.online_live) {
          connectionStatus.value = HarkApiMode.online_live;
          _connectWebSocket();
        }
        return true;
      }
    } catch (_) {
      // Offline fallback: silence exceptions completely
    }

    if (connectionStatus.value != HarkApiMode.offline_autonomous) {
      connectionStatus.value = HarkApiMode.offline_autonomous;
      _disconnectWebSocket();
    }
    return false;
  }

  void _connectWebSocket() {
    _disconnectWebSocket();
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _wsChannel = channel;
      _wsSubscription = channel.stream.listen(
        (message) {
          _handleLiveTelemetryMessage(message);
        },
        onError: (_) {
          connectionStatus.value = HarkApiMode.offline_autonomous;
          _disconnectWebSocket();
        },
        onDone: () {
          if (connectionStatus.value == HarkApiMode.online_live) {
            connectionStatus.value = HarkApiMode.offline_autonomous;
          }
        },
        cancelOnError: true,
      );
    } catch (_) {
      connectionStatus.value = HarkApiMode.offline_autonomous;
    }
  }

  void _disconnectWebSocket() {
    try {
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsSubscription = null;
    _wsChannel = null;
  }

  double _normalizeCoord(
    Map<String, dynamic> payload,
    String normKey,
    String rawKey,
    double viewportMax,
    double fallback,
  ) {
    final normVal = payload[normKey];
    if (normVal is num) {
      return normVal.toDouble().clamp(0.0, 1.0);
    }
    final rawVal = payload[rawKey];
    if (rawVal is num) {
      final d = rawVal.toDouble();
      return (d > 1.0 ? d / viewportMax : d).clamp(0.0, 1.0);
    }
    return fallback;
  }

  void _handleLiveTelemetryMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final event = data['event']?.toString() ?? '';
      final payload = (data['data'] as Map<String, dynamic>?) ?? {};

      if (event == 'cursor_position') {
        final frame = HarkTelemetryFrame(
          cursorX: _normalizeCoord(payload, 'norm_x', 'x', 1280.0, 0.5),
          cursorY: _normalizeCoord(payload, 'norm_y', 'y', 800.0, 0.5),
          isMouseDown: payload['is_mouse_down'] as bool? ?? false,
          status: 'live_stream',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _telemetryController.add(frame);
      } else if (event == 'action_start') {
        final thought = payload['thought']?.toString() ?? '';
        final stepIdx = (payload['active_step'] as num?)?.toInt() ?? 0;
        final frame = HarkTelemetryFrame(
          cursorX: _normalizeCoord(payload, 'norm_x', 'x', 1280.0, 0.5),
          cursorY: _normalizeCoord(payload, 'norm_y', 'y', 800.0, 0.5),
          thought: thought,
          activeStep: stepIdx,
          domSelector: payload['dom_selector']?.toString() ?? '',
          status: 'executing_step',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _telemetryController.add(frame);
        if (_currentRunningTask != null) {
          final totalSteps = math.max(1, _currentRunningTask!.steps.length);
          _currentRunningTask!.currentStepIndex =
              stepIdx.clamp(0, totalSteps - 1);
          _currentRunningTask!.progress =
              ((stepIdx + 1) / totalSteps).clamp(0.0, 0.95);
          _taskUpdateController.add(_currentRunningTask!);
        }
      } else if (event == 'remote_widget') {
        final remoteWidget = HarkRemoteWidget.fromJson(payload);
        _remoteWidgetController.add(remoteWidget);
      } else if (event == 'task_finished') {
        if (_currentRunningTask != null) {
          _currentRunningTask!.status = TaskStatus.completed;
          _currentRunningTask!.progress = 1.0;
          _taskUpdateController.add(_currentRunningTask!);
        }
        _telemetryController.add(
          HarkTelemetryFrame(
            cursorX: 0.5,
            cursorY: 0.5,
            thought: payload['result']?.toString() ??
                'Task completed successfully in Hark Secure Sandbox.',
            status: 'completed',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else if (event == 'task_aborted') {
        if (_currentRunningTask != null) {
          _currentRunningTask!.status = TaskStatus.idle;
          _currentRunningTask!.progress = 0.0;
          _taskUpdateController.add(_currentRunningTask!);
        }
      } else if (event == 'operator_approval_required') {
        final thought = payload['thought']?.toString() ??
            'High-stakes action requires operator confirmation.';
        final action = payload['action']?.toString() ?? 'confirm';
        _telemetryController.add(
          HarkTelemetryFrame(
            cursorX: 0.5,
            cursorY: 0.5,
            thought: thought,
            status: 'approval_required',
            requiresApproval: true,
            pendingAction: action,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else if (event == 'operator_approval_granted') {
        _telemetryController.add(
          HarkTelemetryFrame(
            cursorX: 0.5,
            cursorY: 0.5,
            thought: 'Operator authorization granted. Resuming execution...',
            status: 'running',
            requiresApproval: false,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } else if (event == 'operator_input') {
        final normX = (payload['norm_x'] as num?)?.toDouble() ?? 0.5;
        final normY = (payload['norm_y'] as num?)?.toDouble() ?? 0.5;
        _telemetryController.add(
          HarkTelemetryFrame(
            cursorX: normX.clamp(0.0, 1.0),
            cursorY: normY.clamp(0.0, 1.0),
            thought: 'Operator takeover input received.',
            status: 'takeover',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    } catch (_) {}
  }

  /// Submit task with transparent dual-mode fallback
  Future<HarkTask> submitTask(String prompt) async {
    final lower = prompt.toLowerCase();
    final task = _buildTaskForPrompt(prompt);
    _currentRunningTask = task;

    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/task');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'task': prompt, 'max_steps': task.steps.length}),
            )
            .timeout(const Duration(milliseconds: 2000));

        if (response.statusCode == 200) {
          task.status = TaskStatus.running;
          _taskUpdateController.add(task);
          try {
            final decoded = jsonDecode(response.body) as Map<String, dynamic>;
            if (decoded['sdui_widget'] is Map<String, dynamic>) {
              _remoteWidgetController.add(
                HarkRemoteWidget.fromJson(
                  decoded['sdui_widget'] as Map<String, dynamic>,
                ),
              );
              return task;
            }
          } catch (_) {}
          _emitMatchingRemoteWidget(lower);
          return task;
        }
      } catch (_) {
        // Fall through to autonomous client-side simulation on connection glitch
        connectionStatus.value = HarkApiMode.offline_autonomous;
      }
    }

    // High-Fidelity Client-Side Simulation Mode
    _startAutonomousSimulation(task, lower);
    return task;
  }

  void _startAutonomousSimulation(HarkTask task, String lowerQuery) {
    _simulationTimer?.cancel();
    _isSimulationPaused = false;
    _simulationStepIndex = 0;
    task.status = TaskStatus.running;
    task.currentStepIndex = 0;
    task.progress = 0.05;
    _taskUpdateController.add(task);

    _emitMatchingRemoteWidget(lowerQuery);

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (_isSimulationPaused) return;

      if (_simulationStepIndex >= task.steps.length) {
        task.status = TaskStatus.completed;
        task.progress = 1.0;
        _taskUpdateController.add(task);
        timer.cancel();

        // Emit final telemetry completion frame
        _telemetryController.add(
          HarkTelemetryFrame(
            cursorX: 0.5,
            cursorY: 0.5,
            thought: 'Task completed successfully in Hark Secure Sandbox.',
            status: 'completed',
            activeStep: task.steps.length,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return;
      }

      final currentStep = task.steps[_simulationStepIndex];
      task.currentStepIndex = _simulationStepIndex;
      task.progress = (_simulationStepIndex + 1) / task.steps.length;
      _taskUpdateController.add(task);

      // Emulate Bezier cursor positioning & telemetry
      _telemetryController.add(
        HarkTelemetryFrame(
          cursorX: currentStep.targetPosition.dx,
          cursorY: currentStep.targetPosition.dy,
          thought: currentStep.thoughtTicker,
          domSelector: currentStep.domSelector,
          activeStep: _simulationStepIndex,
          status: 'running',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      _simulationStepIndex++;
    });
  }

  void _emitMatchingRemoteWidget(String query) {
    HarkRemoteWidget widget;
    if (query.contains('flight') || query.contains('delta') || query.contains('seat')) {
      widget = const HarkRemoteWidget(
        id: 'widget_flight_checkin',
        type: RemoteWidgetType.actionButton,
        headline: 'Delta DL 412 Check-In Ready',
        verb: 'Confirm Seat 14A',
        accentHex: '#002244',
        targetWorkflow: 'delta_checkin_flow',
        requiresBiometricAuth: true,
        payload: {'flight': 'DL 412', 'seat': '14A', 'passenger': 'Brett'},
      );
    } else if (query.contains('bill') || query.contains('electric') || query.contains('pge') || query.contains('pay')) {
      widget = const HarkRemoteWidget(
        id: 'widget_bill_pay',
        type: RemoteWidgetType.actionButton,
        headline: 'PG&E Statement Due Tomorrow (\$84.20)',
        verb: 'Pay \$84.20',
        accentHex: '#0A84FF',
        targetWorkflow: 'automated_bill_payment',
        requiresBiometricAuth: true,
        payload: {'biller': 'PG&E', 'amount': 84.20},
      );
    } else if (query.contains('pizza') || query.contains('food') || query.contains('doordash')) {
      widget = const HarkRemoteWidget(
        id: 'widget_doordash_cart',
        type: RemoteWidgetType.actionButton,
        headline: "Tony's Pizza Napoletana Cart Ready",
        verb: 'Place Order (\$32.50)',
        accentHex: '#FF3008',
        targetWorkflow: 'doordash_checkout',
        requiresBiometricAuth: true,
        payload: {'restaurant': "Tony's Pizza", 'total': 32.50},
      );
    } else if (query.contains('nutrition') || query.contains('health') || query.contains('panel')) {
      widget = const HarkRemoteWidget(
        id: 'widget_health_panel',
        type: RemoteWidgetType.interactiveMetrics,
        title: 'Active Daily Calories',
        metricTitle: 'Caloric Target Burn',
        metricValue: 2400.0,
        unit: 'kcal',
        trend: '+12% vs last week',
        accentHex: '#FF2D55',
        colorHex: '#FF2D55',
      );
    } else {
      widget = HarkRemoteWidget(
        id: 'widget_general_${DateTime.now().millisecondsSinceEpoch}',
        type: RemoteWidgetType.actionButton,
        headline: 'Execute Autonomous Workflow',
        verb: 'Launch Handoff',
        accentHex: '#00E5FF',
        targetWorkflow: 'general_automation',
        requiresBiometricAuth: false,
        payload: {'query': query},
      );
    }

    _remoteWidgetController.add(widget);
  }

  HarkTask _buildTaskForPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    final mockTasks = HarkMockData.getMockTasks();
    if (lower.contains('flight') || lower.contains('delta')) {
      return mockTasks[1];
    } else if (lower.contains('bill') || lower.contains('pge') || lower.contains('electric') || lower.contains('pay')) {
      return mockTasks[0];
    } else if (lower.contains('pizza') || lower.contains('food') || lower.contains('doordash')) {
      return mockTasks[2];
    } else if (lower.contains('amazon') || lower.contains('return')) {
      return mockTasks[3];
    }

    // Default dynamic task
    return HarkTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: prompt.length > 28 ? '${prompt.substring(0, 25)}...' : prompt,
      verb: 'Automate',
      service: 'Hark Web Sandbox',
      url: 'https://app.hark.com/sandbox',
      accentColor: const Color(0xFF00E5FF),
      icon: Icons.auto_awesome_rounded,
      steps: [
        TaskStep(
          id: 's1',
          description: 'Spawning Chromium Sandbox & navigating target URL',
          thoughtTicker: 'Evaluating DOM elements & Set-of-Marks tags...',
          targetPosition: const Offset(0.48, 0.22),
          elementBadgeIndex: 1,
          domSelector: 'input[name="q"]',
        ),
        TaskStep(
          id: 's2',
          description: 'Executing neural click on primary intent button',
          thoughtTicker: 'Synthesizing human-like Bezier cursor curve...',
          targetPosition: const Offset(0.72, 0.45),
          elementBadgeIndex: 4,
          domSelector: 'button[type="submit"]',
        ),
        TaskStep(
          id: 's3',
          description: 'Extracting verified completion tokens',
          thoughtTicker: 'Verifying zero-knowledge state seal...',
          targetPosition: const Offset(0.50, 0.65),
          elementBadgeIndex: 7,
          domSelector: '.confirmation-badge',
        ),
      ],
    );
  }

  /// Pause execution
  Future<void> pauseTask() async {
    _isSimulationPaused = true;
    if (_currentRunningTask != null) {
      _currentRunningTask!.status = TaskStatus.paused;
      _taskUpdateController.add(_currentRunningTask!);
    }
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        await http.post(Uri.parse('$_baseUrl/api/task/pause')).timeout(const Duration(milliseconds: 1000));
      } catch (_) {}
    }
  }

  /// Resume execution
  Future<void> resumeTask() async {
    _isSimulationPaused = false;
    if (_currentRunningTask != null) {
      _currentRunningTask!.status = TaskStatus.running;
      _taskUpdateController.add(_currentRunningTask!);
    }
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        await http.post(Uri.parse('$_baseUrl/api/task/resume')).timeout(const Duration(milliseconds: 1000));
      } catch (_) {}
    }
  }

  /// Abort execution
  Future<void> abortTask() async {
    _simulationTimer?.cancel();
    _isSimulationPaused = false;
    if (_currentRunningTask != null) {
      _currentRunningTask!.status = TaskStatus.idle;
      _currentRunningTask!.progress = 0.0;
      _taskUpdateController.add(_currentRunningTask!);
    }
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        await http.post(Uri.parse('$_baseUrl/api/task/abort')).timeout(const Duration(milliseconds: 1000));
      } catch (_) {}
    }
  }

  /// Send manual operator input (click, drag, text, scroll) for bidirectional takeover
  Future<Map<String, dynamic>> sendOperatorInput({
    required String action,
    double? normX,
    double? normY,
    String? text,
    double? deltaY,
  }) async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/sandbox/input');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'action': action,
                if (normX != null) 'norm_x': normX,
                if (normY != null) 'norm_y': normY,
                if (text != null) 'text': text,
                if (deltaY != null) 'delta_y': deltaY,
              }),
            )
            .timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return {
      'status': 'applied',
      'action': action,
      'cursor': {'norm_x': normX ?? 0.5, 'norm_y': normY ?? 0.5},
    };
  }

  /// Operator approves high-stakes pending action (payment, submission, checkout)
  Future<bool> approvePendingAction() async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/task/approve');
        final response = await http
            .post(uri)
            .timeout(const Duration(milliseconds: 1500));
        return response.statusCode == 200;
      } catch (_) {}
    }
    _telemetryController.add(
      HarkTelemetryFrame(
        cursorX: 0.5,
        cursorY: 0.5,
        thought: 'Approved locally in offline mode.',
        status: 'running',
        requiresApproval: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return true;
  }

  /// Switch the active backend model provider (Gemini, Claude, GPT, Grok, Hermes, Ollama, Simulator)
  Future<Map<String, dynamic>> selectBackendModel({
    required String provider,
    String? modelName,
    String? baseUrl,
  }) async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/models/select');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'provider': provider,
                if (modelName != null) 'model_name': modelName,
                if (baseUrl != null) 'base_url': baseUrl,
              }),
            )
            .timeout(const Duration(milliseconds: 2000));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return {
      'status': 'offline_mock',
      'active': {'provider': provider, 'model_name': modelName ?? 'default'},
    };
  }

  /// Fetch list of supported backend model providers & metadata
  Future<Map<String, dynamic>> getBackendModels() async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/models');
        final response = await http
            .get(uri)
            .timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return {
      'active': {'provider': 'simulator', 'model_name': 'heuristic-som-v1'},
      'providers': [
        'simulator',
        'gemini',
        'anthropic',
        'openai',
        'grok',
        'nous',
        'openrouter',
        'ollama'
      ],
      'descriptions': {
        'simulator': 'Zero-cost deterministic heuristic simulator',
        'gemini': 'Google Gemini 2.5 Flash / Pro Multimodal VLM',
        'anthropic': 'Anthropic Claude 3.7 Sonnet Computer Use API',
        'openai': 'OpenAI GPT-4o / Dots Cloud-Computer VLM',
        'grok': 'xAI Grok 2 Vision',
        'nous': 'Nous Hermes 3 Reasoning with SOUL.md system prompts',
        'openrouter': 'Universal OpenRouter API Gateway',
        'ollama': 'Local open-weight VLM (Qwen 2.5 VL / MiniCPM-V)',
      }
    };
  }

  /// Retrieve persistent memory summary & episode history
  Future<Map<String, dynamic>> getMemorySummary() async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/memory');
        final response = await http
            .get(uri)
            .timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return {
      'total_episodes': 0,
      'preferences': {},
      'vault_handles': [],
    };
  }

  /// Save user preference to long-term memory
  Future<bool> saveMemoryPreference(String key, dynamic value) async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/memory');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'key': key, 'value': value}),
            )
            .timeout(const Duration(milliseconds: 1500));
        return response.statusCode == 200;
      } catch (_) {}
    }
    return true;
  }

  /// Retrieve list of opaque zero-knowledge vault handles ($VAULT:<handle>)
  Future<List<String>> listVaultHandles() async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/vault/handles');
        final response = await http
            .get(uri)
            .timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final list = data['handles'] as List<dynamic>?;
          if (list != null) {
            return list.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  /// Store a secret into the zero-knowledge vault
  Future<bool> setVaultSecret(String handle, String secretValue) async {
    if (connectionStatus.value == HarkApiMode.online_live) {
      try {
        final uri = Uri.parse('$_baseUrl/api/vault/secret');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'handle': handle, 'secret_value': secretValue}),
            )
            .timeout(const Duration(milliseconds: 1500));
        return response.statusCode == 200;
      } catch (_) {}
    }
    return true;
  }

  void switchMode(HarkApiMode mode) {
    connectionStatus.value = mode;
    if (mode == HarkApiMode.online_live) {
      checkBackendHealth();
    } else {
      _disconnectWebSocket();
    }
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _simulationTimer?.cancel();
    _disconnectWebSocket();
    _telemetryController.close();
    _remoteWidgetController.close();
    _taskUpdateController.close();
  }
}
