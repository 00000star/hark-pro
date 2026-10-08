import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hark_models.dart';
import '../widgets/action_button_card.dart';

class ChatAgentScreen extends StatefulWidget {
  final ValueChanged<HarkTask>? onExecuteTask;

  const ChatAgentScreen({
    super.key,
    this.onExecuteTask,
  });

  @override
  State<ChatAgentScreen> createState() => _ChatAgentScreenState();
}

class _ChatAgentScreenState extends State<ChatAgentScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListeningVoice = false;
  bool _isAiTyping = false;
  late AnimationController _micPulseController;

  final List<String> _suggestionChips = [
    "Check my flight",
    "Pay electric bill",
    "Order Tony's Pizza",
    "Amazon return",
    "Create nutrition panel",
  ];

  @override
  void initState() {
    super.initState();
    _messages.addAll(HarkMockData.getMockChatMessages());
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSendMessage(String query) {
    if (query.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'user',
      text: query.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isAiTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    // AI thinking delay
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _respondToQuery(query.toLowerCase());
    });
  }

  void _respondToQuery(String lowerQuery) {
    String responseText = "Understood. I have initiated the workflow in the Handoff Sandbox.";
    HarkTask? taskToSpawn;

    final mockTasks = HarkMockData.getMockTasks();

    if (lowerQuery.contains('flight') || lowerQuery.contains('delta') || lowerQuery.contains('check')) {
      responseText = "Flight DL 412 check-in is ready. Seat 14A is reserved in Main Cabin Extra with TSA PreCheck confirmed.";
      taskToSpawn = mockTasks[1]; // Delta
    } else if (lowerQuery.contains('bill') || lowerQuery.contains('electric') || lowerQuery.contains('pge') || lowerQuery.contains('pay')) {
      responseText = "PG&E Electric statement balance is \$84.20. Ready to execute single-click ACH payment from your Chase Checking account.";
      taskToSpawn = mockTasks[0]; // PGE
    } else if (lowerQuery.contains('pizza') || lowerQuery.contains('doordash') || lowerQuery.contains('order') || lowerQuery.contains('food')) {
      responseText = "Tony's Pizza Napoletana cart loaded with 16\" Margherita. DashPass discount applied with \$0 delivery fee.";
      taskToSpawn = mockTasks[2]; // DoorDash
    } else if (lowerQuery.contains('amazon') || lowerQuery.contains('return') || lowerQuery.contains('label')) {
      responseText = "Amazon Order #114-8921932 is eligible for frictionless drop-off at The UPS Store (0.3 mi away). \$348.00 refund ready.";
      taskToSpawn = mockTasks[3]; // Amazon
    } else if (lowerQuery.contains('nutrition') || lowerQuery.contains('health') || lowerQuery.contains('panel')) {
      responseText = "Dynamic Nutrition & Health Panel generated. Daily caloric target 2,400 kcal, current hydration tracking 80 oz.";
    } else {
      responseText = "I've analyzed your query and prepared an automated computer-use session in your Hark Virtual Sandbox.";
      taskToSpawn = mockTasks[0];
    }

    setState(() {
      _isAiTyping = false;
      _messages.add(
        ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          sender: 'hark',
          text: responseText,
          timestamp: DateTime.now(),
          spawnedTask: taskToSpawn,
        ),
      );
    });
    _scrollToBottom();
  }

  void _toggleVoiceInput() {
    setState(() {
      _isListeningVoice = !_isListeningVoice;
    });

    if (_isListeningVoice) {
      // Simulate speech recognition
      Timer(const Duration(milliseconds: 2000), () {
        if (!mounted || !_isListeningVoice) return;
        setState(() {
          _isListeningVoice = false;
        });
        _handleSendMessage("Pay electric bill");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            _buildTopBar(),

            // Prompt Suggestion Chips
            _buildSuggestionChips(),

            // Message Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isAiTyping) {
                    return _buildAiThinkingBubble();
                  }
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            // Voice Listening Banner
            if (_isListeningVoice) _buildVoiceListeningIndicator(),

            // Bottom Input Command Bar
            _buildBottomInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F17).withOpacity(0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF5E5CE6)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Hark Agent Pro",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    "Autonomous Reasoning • 4 Subagents Online",
                    style: TextStyle(
                      color: Color(0xFF30D158),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF30D158), size: 12),
                SizedBox(width: 4),
                Text(
                  "Enclave",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestionChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = _suggestionChips[index];
          return GestureDetector(
            onTap: () => _handleSendMessage(chip),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2130).withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded,
                      color: Color(0xFF00E5FF), size: 12),
                  const SizedBox(width: 5),
                  Text(
                    chip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.sender == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C2235),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded,
                      color: Color(0xFF00E5FF), size: 15),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF161926).withOpacity(0.92),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Spawned Action Button Card
          if (msg.spawnedTask != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: ActionButtonCard(
                task: msg.spawnedTask!,
                onRun: () {
                  widget.onExecuteTask?.call(msg.spawnedTask!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF161926),
                      content: Text(
                        "Handoff launched for ${msg.spawnedTask!.title}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 36),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161926).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              ),
            ),
            SizedBox(width: 8),
            Text(
              "Hark is reasoning & evaluating DOM...",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceListeningIndicator() {
    return AnimatedBuilder(
      animation: _micPulseController,
      builder: (context, _) {
        final glow = 0.5 + (_micPulseController.value * 0.5);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2A6D).withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF2A6D).withOpacity(glow),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mic_rounded, color: Color(0xFFFF2A6D), size: 16),
              SizedBox(width: 8),
              Text(
                "Listening... Say 'Pay electric bill' or 'Check flight'",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D14).withOpacity(0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Voice Mic Button
          GestureDetector(
            onTap: _toggleVoiceInput,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListeningVoice
                    ? const Color(0xFFFF2A6D)
                    : const Color(0xFF1E2130),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListeningVoice
                      ? Colors.white
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Icon(
                _isListeningVoice ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text Field
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF171A27),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: "Ask Hark to automate anything...",
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: _handleSendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Button
          GestureDetector(
            onTap: () => _handleSendMessage(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A84FF), Color(0xFF00E5FF)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
