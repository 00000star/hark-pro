import 'package:flutter/material.dart';
import '../widgets/pip_computer_viewer.dart';
import '../widgets/action_button_card.dart';
import '../widgets/dynamic_panel_card.dart';

class HarkHomeScreen extends StatelessWidget {
  const HarkHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HARK PRO",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      "Autonomous Operating System",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF30D158).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF30D158), size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Secured",
                        style: TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Virtual Computer PiP View
            const Text(
              "VIRTUAL COMPUTER",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const PipComputerViewer(),
            const SizedBox(height: 24),

            // Proactive Action Buttons
            const Text(
              "ACTION FEED",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            ActionButtonCard(
              title: "PG&E Electric Bill Due",
              verb: "Pay \$84.20",
              accentColor: const Color(0xFF0A84FF),
              onTap: () {},
            ),
            ActionButtonCard(
              title: "Flight Check-In Available",
              verb: "Confirm SFO -> JFK Seat",
              accentColor: const Color(0xFFBF5AF2),
              onTap: () {},
            ),
            const SizedBox(height: 16),

            // Dynamic Panels
            const Text(
              "PANELS",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            DynamicPanelCard(
              title: "Weekly Activity & Health",
              widgets: [
                _buildMetric("24.8 mi", "Running", const Color(0xFFFC5200)),
                _buildMetric("92 oz", "Hydration", const Color(0xFF00E5FF)),
                _buildMetric("7.4 hrs", "Sleep", const Color(0xFF5E5CE6)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
