import 'package:flutter/material.dart';

enum TaskStatus {
  idle,
  running,
  paused,
  userTakeover,
  completed,
  failed,
}

class TaskStep {
  final String id;
  final String description;
  final String thoughtTicker;
  final Offset targetPosition; // Viewport position (0.0 to 1.0)
  final int elementBadgeIndex;
  final Duration duration;
  final String domSelector;

  const TaskStep({
    required this.id,
    required this.description,
    required this.thoughtTicker,
    required this.targetPosition,
    required this.elementBadgeIndex,
    this.duration = const Duration(milliseconds: 2200),
    this.domSelector = '',
  });
}

class HarkTask {
  final String id;
  final String title;
  final String verb;
  final String service;
  final String url;
  final Color accentColor;
  final IconData icon;
  final List<TaskStep> steps;
  final Map<String, dynamic> metadata;
  
  TaskStatus status;
  double progress;
  int currentStepIndex;

  HarkTask({
    required this.id,
    required this.title,
    required this.verb,
    required this.service,
    required this.url,
    required this.accentColor,
    required this.icon,
    required this.steps,
    this.metadata = const {},
    this.status = TaskStatus.idle,
    this.progress = 0.0,
    this.currentStepIndex = 0,
  });

  HarkTask copyWith({
    TaskStatus? status,
    double? progress,
    int? currentStepIndex,
  }) {
    final task = HarkTask(
      id: id,
      title: title,
      verb: verb,
      service: service,
      url: url,
      accentColor: accentColor,
      icon: icon,
      steps: steps,
      metadata: metadata,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
    return task;
  }
}

class DynamicPanel {
  final String id;
  final String title;
  final String category; // 'flight', 'fitness', 'energy', 'media'
  final IconData icon;
  final Map<String, dynamic> data;

  const DynamicPanel({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.data,
  });
}

class ConnectedAccount {
  final String id;
  final String name;
  final String emailOrUsername;
  final String serviceType;
  final IconData icon;
  final Color brandColor;
  final String securityLevel;
  final String lastSynced;
  bool isConnected;

  ConnectedAccount({
    required this.id,
    required this.name,
    required this.emailOrUsername,
    required this.serviceType,
    required this.icon,
    required this.brandColor,
    required this.securityLevel,
    required this.lastSynced,
    this.isConnected = true,
  });
}

class ChatMessage {
  final String id;
  final String sender; // 'user' or 'hark'
  final String text;
  final DateTime timestamp;
  final HarkTask? spawnedTask;
  final String? dynamicPanelType;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.spawnedTask,
    this.dynamicPanelType,
  });
}

class HarkMockData {
  static List<HarkTask> getMockTasks() {
    return [
      // 1. PG&E Utility Bill Pay ($84.20)
      HarkTask(
        id: 'pge_bill',
        title: 'PG&E Electric Bill Due',
        verb: 'Pay \$84.20',
        service: 'Pacific Gas and Electric',
        url: 'https://pge.com/bill-pay',
        accentColor: const Color(0xFF0A84FF),
        icon: Icons.electric_bolt_rounded,
        metadata: {
          'accountNumber': '****-9012',
          'amountDue': '\$84.20',
          'dueDate': 'Oct 12, 2026',
          'kwhUsage': '342 kWh',
          'rate': '\$0.246/kWh',
        },
        steps: const [
          TaskStep(
            id: 'pge_1',
            description: 'Locating Statement & Balance Ledger',
            thoughtTicker: 'Scanning DOM for statement ledger & invoice balance [1]...',
            targetPosition: Offset(0.38, 0.32),
            elementBadgeIndex: 1,
            domSelector: 'div#statement-balance-due',
          ),
          TaskStep(
            id: 'pge_2',
            description: 'Verifying \$84.20 Smart Meter Ledger',
            thoughtTicker: 'Confirming invoice \$84.20 matches smart meter consumption [2]...',
            targetPosition: Offset(0.68, 0.44),
            elementBadgeIndex: 2,
            domSelector: 'input#payment-amount-val',
          ),
          TaskStep(
            id: 'pge_3',
            description: 'Selecting Funding Account (Chase ...9042)',
            thoughtTicker: 'Selecting verified zero-fee funding checking account [3]...',
            targetPosition: Offset(0.42, 0.62),
            elementBadgeIndex: 3,
            domSelector: 'select#funding-source-select',
          ),
          TaskStep(
            id: 'pge_4',
            description: 'Executing Cryptographic Payment Authorization',
            thoughtTicker: 'Signing cryptographically & confirming zero-fee receipt [4]...',
            targetPosition: Offset(0.50, 0.84),
            elementBadgeIndex: 4,
            domSelector: 'button#btn-authorize-pay',
          ),
        ],
      ),

      // 2. Delta Flight Check-In (SFO -> JFK, Seat 14A)
      HarkTask(
        id: 'delta_checkin',
        title: 'Flight Check-In Available',
        verb: 'Confirm SFO -> JFK Seat 14A',
        service: 'Delta Air Lines',
        url: 'https://delta.com/checkin',
        accentColor: const Color(0xFFBF5AF2),
        icon: Icons.flight_takeoff_rounded,
        metadata: {
          'flightNumber': 'DL 412',
          'origin': 'SFO',
          'destination': 'JFK',
          'seat': '14A',
          'departureTime': '08:15 AM',
          'gate': 'B22',
          'terminal': 'Terminal 2',
        },
        steps: const [
          TaskStep(
            id: 'delta_1',
            description: 'Retrieving SkyMiles Reservation DL-4912',
            thoughtTicker: 'Authenticating SkyMiles #8829012 and retrieving reservation [1]...',
            targetPosition: Offset(0.35, 0.30),
            elementBadgeIndex: 1,
            domSelector: 'input#pnr-locator-input',
          ),
          TaskStep(
            id: 'delta_2',
            description: 'Verifying Passenger Manifest & TSA PreCheck',
            thoughtTicker: 'Validating PreCheck Known Traveler #99248102 [2]...',
            targetPosition: Offset(0.58, 0.46),
            elementBadgeIndex: 2,
            domSelector: 'div#passenger-tsa-verify',
          ),
          TaskStep(
            id: 'delta_3',
            description: 'Locking Preferred Window Seat 14A',
            thoughtTicker: 'Selecting Seat 14A (Main Cabin Extra, Window, Legroom) [3]...',
            targetPosition: Offset(0.65, 0.64),
            elementBadgeIndex: 3,
            domSelector: 'button.seat-14a-select',
          ),
          TaskStep(
            id: 'delta_4',
            description: 'Generating Apple Wallet Boarding Pass',
            thoughtTicker: 'Confirming check-in & dispatching digital pass PKPass [4]...',
            targetPosition: Offset(0.50, 0.85),
            elementBadgeIndex: 4,
            domSelector: 'button#btn-complete-checkin',
          ),
        ],
      ),

      // 3. DoorDash Pizza Order ($32.50)
      HarkTask(
        id: 'doordash_order',
        title: 'DoorDash Reorder Ready',
        verb: 'Reorder Pizza (\$32.50)',
        service: 'DoorDash',
        url: 'https://doordash.com/store/tonys-pizza',
        accentColor: const Color(0xFFFF9F0A),
        icon: Icons.local_pizza_rounded,
        metadata: {
          'restaurant': "Tony's Pizza Napoletana",
          'item': '1x Margherita 16" Pie + Fresh Basil',
          'subtotal': '\$28.00',
          'taxAndFee': '\$4.50',
          'total': '\$32.50',
          'deliveryAddress': '450 Mission St, Apt 21B',
          'eta': '28-38 mins',
        },
        steps: const [
          TaskStep(
            id: 'dash_1',
            description: "Opening Tony's Pizza Frequent Order",
            thoughtTicker: 'Accessing restaurant menu & loading 16" Margherita pie [1]...',
            targetPosition: Offset(0.40, 0.32),
            elementBadgeIndex: 1,
            domSelector: 'div#cart-reorder-item',
          ),
          TaskStep(
            id: 'dash_2',
            description: 'Confirming Delivery Address: 450 Mission St',
            thoughtTicker: 'Verifying delivery destination Apt 21B & gate code [2]...',
            targetPosition: Offset(0.55, 0.48),
            elementBadgeIndex: 2,
            domSelector: 'input#delivery-address-field',
          ),
          TaskStep(
            id: 'dash_3',
            description: 'Applying DashPass \$0 Fee & Tip',
            thoughtTicker: 'DashPass active: \$4.99 delivery waived, 18% driver tip [3]...',
            targetPosition: Offset(0.62, 0.66),
            elementBadgeIndex: 3,
            domSelector: 'div#tip-option-18pct',
          ),
          TaskStep(
            id: 'dash_4',
            description: 'Submitting Apple Pay Authorization (\$32.50)',
            thoughtTicker: 'Transacting \$32.50 via tokenized Apple Pay secure enclave [4]...',
            targetPosition: Offset(0.50, 0.85),
            elementBadgeIndex: 4,
            domSelector: 'button#btn-place-order',
          ),
        ],
      ),

      // 4. Amazon Return Processing
      HarkTask(
        id: 'amazon_return',
        title: 'Amazon Return Pending',
        verb: 'Generate Return Label',
        service: 'Amazon',
        url: 'https://amazon.com/returns/order-114-8921',
        accentColor: const Color(0xFF30D158),
        icon: Icons.assignment_return_rounded,
        metadata: {
          'orderId': '114-8921932-849120',
          'item': 'Sony WH-1000XM5 Wireless Headphones',
          'refundAmount': '\$348.00',
          'reason': 'Performance or quality not adequate',
          'dropoff': 'The UPS Store (No Box / No Label Needed)',
          'distance': '0.3 mi away',
        },
        steps: const [
          TaskStep(
            id: 'amz_1',
            description: 'Selecting Order #114-8921932',
            thoughtTicker: 'Verifying return eligibility within 30-day window [1]...',
            targetPosition: Offset(0.38, 0.30),
            elementBadgeIndex: 1,
            domSelector: 'input#radio-order-item',
          ),
          TaskStep(
            id: 'amz_2',
            description: 'Specifying Reason: Audio Quality Defect',
            thoughtTicker: 'Injecting feedback description & return category [2]...',
            targetPosition: Offset(0.52, 0.48),
            elementBadgeIndex: 2,
            domSelector: 'select#return-reason-dropdown',
          ),
          TaskStep(
            id: 'amz_3',
            description: 'Selecting No-Box UPS Store Drop-off',
            thoughtTicker: 'Selecting frictionless UPS Store dropoff (0.3 mi) [3]...',
            targetPosition: Offset(0.65, 0.65),
            elementBadgeIndex: 3,
            domSelector: 'input#dropoff-ups-nobox',
          ),
          TaskStep(
            id: 'amz_4',
            description: 'Generating Encrypted Return QR Code',
            thoughtTicker: 'Authorizing refund of \$348.00 to original card [4]...',
            targetPosition: Offset(0.50, 0.86),
            elementBadgeIndex: 4,
            domSelector: 'button#btn-confirm-return',
          ),
        ],
      ),
    ];
  }

  static List<DynamicPanel> getMockPanels() {
    return const [
      DynamicPanel(
        id: 'flight_panel',
        title: 'Flight Tracker',
        category: 'flight',
        icon: Icons.flight_rounded,
        data: {
          'flightNumber': 'DL 412',
          'route': 'SFO ➔ JFK',
          'status': 'On Time',
          'departure': '08:15 AM',
          'arrival': '04:45 PM',
          'gate': 'B22',
          'terminal': 'T2',
          'seat': '14A',
          'baggage': 'Claim 4',
          'duration': '5h 30m',
          'progress': 0.62,
        },
      ),
      DynamicPanel(
        id: 'fitness_panel',
        title: 'Health & Activity',
        category: 'fitness',
        icon: Icons.favorite_rounded,
        data: {
          'moveCalories': 680,
          'moveGoal': 700,
          'exerciseMinutes': 42,
          'exerciseGoal': 30,
          'standHours': 11,
          'standGoal': 12,
          'weeklyMileage': '24.8 mi',
          'hydrationOz': 80,
          'hydrationGoal': 100,
          'sleepHours': '7.4 hrs',
        },
      ),
      DynamicPanel(
        id: 'energy_panel',
        title: 'Home Energy Monitor',
        category: 'energy',
        icon: Icons.bolt_rounded,
        data: {
          'currentKw': 2.4,
          'solarGenerationKw': 3.8,
          'netExport': true,
          'isPeak': true,
          'ratePerKwh': '\$0.42',
          'offPeakInMinutes': 45,
          'currentTemp': 71,
          'targetTemp': 68,
        },
      ),
      DynamicPanel(
        id: 'media_panel',
        title: 'Media Player',
        category: 'media',
        icon: Icons.music_note_rounded,
        data: {
          'track': 'Synthetic Horizons',
          'artist': 'Hark Neural Audio',
          'album': 'Autonomous Mindscape',
          'isPlaying': true,
          'progress': 0.44,
          'duration': '3:45',
          'currentTime': '1:39',
        },
      ),
    ];
  }

  static List<ConnectedAccount> getMockAccounts() {
    return [
      ConnectedAccount(
        id: 'acc_google',
        name: 'Google Workspace',
        emailOrUsername: 'brett@hark.ai',
        serviceType: 'Identity & Gmail',
        icon: Icons.g_mobiledata_rounded,
        brandColor: const Color(0xFF4285F4),
        securityLevel: 'OAuth 2.1 PKCE • Enclave Tied',
        lastSynced: '2 mins ago',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_delta',
        name: 'Delta Air Lines',
        emailOrUsername: 'SkyMiles #8829012',
        serviceType: 'Travel Automation',
        icon: Icons.flight_rounded,
        brandColor: const Color(0xFFC70851),
        securityLevel: '256-bit AES Tokenized',
        lastSynced: '14 mins ago',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_doordash',
        name: 'DoorDash',
        emailOrUsername: 'brett@hark.ai',
        serviceType: 'Food & Merchant',
        icon: Icons.fastfood_rounded,
        brandColor: const Color(0xFFFF3008),
        securityLevel: 'Hardware Keystore Sandboxed',
        lastSynced: '1 hr ago',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_amazon',
        name: 'Amazon Prime',
        emailOrUsername: 'adcock.brett@gmail.com',
        serviceType: 'Commerce & Returns',
        icon: Icons.shopping_bag_rounded,
        brandColor: const Color(0xFFFF9900),
        securityLevel: 'Biometric Gate • 256-bit AES',
        lastSynced: '3 hrs ago',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_pge',
        name: 'Pacific Gas & Electric',
        emailOrUsername: 'Acct #****-9012',
        serviceType: 'Utilities & Billing',
        icon: Icons.electric_bolt_rounded,
        brandColor: const Color(0xFF0072CE),
        securityLevel: 'Zero-Knowledge ACH Vault',
        lastSynced: 'Yesterday',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_slack',
        name: 'Slack Enterprise',
        emailOrUsername: 'brett@hark-os.slack.com',
        serviceType: 'Internal Workspaces',
        icon: Icons.chat_bubble_outline_rounded,
        brandColor: const Color(0xFF4A154B),
        securityLevel: 'mTLS Client Certificate',
        lastSynced: '4 mins ago',
        isConnected: true,
      ),
      ConnectedAccount(
        id: 'acc_opentable',
        name: 'OpenTable',
        emailOrUsername: 'brett@hark.ai',
        serviceType: 'Dining Reservations',
        icon: Icons.restaurant_rounded,
        brandColor: const Color(0xFFDA3743),
        securityLevel: 'Ephemeral Token Session',
        lastSynced: '2 days ago',
        isConnected: false,
      ),
    ];
  }

  static List<ChatMessage> getMockChatMessages() {
    final tasks = getMockTasks();
    return [
      ChatMessage(
        id: 'm1',
        sender: 'hark',
        text: 'Good morning, Brett. Living Sky atmosphere synchronized with San Francisco. I have audited your pending accounts and prepared proactive tasks.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      ChatMessage(
        id: 'm2',
        sender: 'user',
        text: 'What needs my attention before my flight?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 22)),
      ),
      ChatMessage(
        id: 'm3',
        sender: 'hark',
        text: 'Your PG&E bill is due tomorrow ($84.20), and Delta check-in for flight DL 412 is now live with Seat 14A available. I can execute both via autonomous Handoff.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 21)),
        spawnedTask: tasks[0], // PG&E bill
      ),
      ChatMessage(
        id: 'm4',
        sender: 'hark',
        text: 'Here is the flight check-in task ready for one-tap execution:',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        spawnedTask: tasks[1], // Delta checkin
      ),
    ];
  }
}
