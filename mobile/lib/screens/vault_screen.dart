import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hark_models.dart';
import '../services/vault_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late List<VaultAccount> _accounts;
  bool _biometricsActive = true;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _accounts = VaultService.instance.getConnectedAccounts();
  }

  Future<void> _handleBiometricAuthToggle(bool value) async {
    setState(() => _isAuthenticating = true);
    final success = await VaultService.instance.authenticateBiometrics(
      reason: value
          ? "Enable Biometric Gate for Hardware Enclave"
          : "Disable Biometric Gate",
    );
    if (!mounted) return;
    setState(() {
      _isAuthenticating = false;
      if (success) {
        _biometricsActive = value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF161A26),
        content: Text(
          success
              ? (_biometricsActive
                  ? "Biometric Gate Armed: Hardware Keystore Bound"
                  : "Biometric Gate Disarmed")
              : "Biometric Authentication Cancelled",
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleAccount(VaultAccount account, bool value) async {
    if (value && _biometricsActive) {
      // Require real biometric verification to reconnect an account
      final verified = await VaultService.instance.authenticateBiometrics(
        reason: "Authenticate Enclave to connect ${account.name}",
      );
      if (!verified) return;
    }

    setState(() {
      VaultService.instance.toggleAccount(account.id, value);
    });

    final action = value ? "connected to" : "disconnected from";
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF161A26),
        content: Text(
          "${account.name} $action Hark Secure Enclave",
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _inspectEncryptedPayload(VaultAccount account) {
    final payload = account.encryptedPayload;
    if (payload == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_clock_rounded,
                      color: account.brandColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "${account.name} • AES-256 GCM Payload",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCipherRow("IV (96-Bit Nonce):", payload.ivHex),
              const SizedBox(height: 8),
              _buildCipherRow("Ciphertext Hex:", payload.ciphertextHex),
              const SizedBox(height: 8),
              _buildCipherRow("GHASH Tag (128-Bit):", payload.tagHex),
              const SizedBox(height: 8),
              _buildCipherRow("Master Key Fingerprint:", payload.keyFingerprint),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text("Copy Encrypted Payload"),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: payload.ciphertextHex));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Encrypted payload copied to clipboard"),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCipherRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // Top Header
            _buildVaultHeader(),
            const SizedBox(height: 20),

            // Security Status Cards Grid
            _buildSecurityMatrix(),
            const SizedBox(height: 24),

            // Connected Accounts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CONNECTED SERVICES",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  "${_accounts.where((a) => a.isConnected).length} of ${_accounts.length} Active",
                  style: const TextStyle(
                    color: Color(0xFF30D158),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Accounts List
            ..._accounts.map((acc) => _buildAccountCard(acc)),
            const SizedBox(height: 20),

            // Audit Trail / Access Log
            const Text(
              "AUDIT TRAIL & ZERO-KNOWLEDGE LEDGER",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            _buildAuditTrailCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF30D158), Color(0xFF00E5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF30D158).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.shield_rounded, color: Colors.black, size: 28),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Hark Security Vault",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Zero-Knowledge • Hardware-Backed Enclave",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityMatrix() {
    return Column(
      children: [
        Row(
          children: [
            // Biometrics Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF30D158).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.fingerprint_rounded,
                            color: Color(0xFF30D158), size: 22),
                        CupertinoSwitch(
                          value: _biometricsActive,
                          activeColor: const Color(0xFF30D158),
                          onChanged: _isAuthenticating
                              ? null
                              : _handleBiometricAuthToggle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Biometric Gate",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _biometricsActive ? "Biometrics Active" : "Disabled",
                      style: TextStyle(
                        color: _biometricsActive
                            ? const Color(0xFF30D158)
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Encryption Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.vpn_key_rounded,
                        color: Color(0xFF00E5FF), size: 22),
                    SizedBox(height: 12),
                    Text(
                      "AES-GCM 256-Bit",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Hardware Keystore",
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
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
        const SizedBox(height: 12),

        // Zero-Knowledge Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121522).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_user_rounded,
                  color: Color(0xFF30D158), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Zero-Knowledge Architecture: No plaintext passwords or bank logins ever touch external cloud servers.",
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(VaultAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151825).withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: account.isConnected
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon Container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: account.brandColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: account.brandColor.withOpacity(0.3),
                  ),
                ),
                child: Icon(account.icon, color: account.brandColor, size: 20),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          account.name,
                          style: TextStyle(
                            color: account.isConnected
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (account.isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Synced",
                              style: TextStyle(
                                color: Color(0xFF30D158),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.emailOrUsername,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.securityLevel,
                      style: TextStyle(
                        color: account.brandColor.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Connect / Disconnect Toggle
              CupertinoSwitch(
                value: account.isConnected,
                activeColor: const Color(0xFF30D158),
                onChanged: (val) => _toggleAccount(account, val),
              ),
            ],
          ),

          // Cryptographic Session Token & AES-256 GCM Pill
          if (account.isConnected) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _inspectEncryptedPayload(account),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Color(0xFF00E5FF), size: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        account.sessionToken,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "AES-256 GCM",
                        style: TextStyle(
                          color: Color(0xFF30D158),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditTrailCard() {
    final events = [
      {
        'time': 'Today 2:14 PM',
        'desc': 'PG&E Bill Inquiry (ACH Token Signed)',
        'type': 'PAYMENT',
      },
      {
        'time': 'Today 11:03 AM',
        'desc': 'Delta SkyMiles Check-In (Seat 14A Locked)',
        'type': 'TRAVEL',
      },
      {
        'time': 'Yesterday 7:30 PM',
        'desc': 'DoorDash Session Token Revalidated',
        'type': 'COMMERCE',
      },
      {
        'time': 'Yesterday 9:15 AM',
        'desc': 'Zero-Knowledge Root Key Rotated',
        'type': 'ENCLAVE',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131622).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: events.map((event) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF30D158),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['desc']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        event['time']!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    event['type']!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
