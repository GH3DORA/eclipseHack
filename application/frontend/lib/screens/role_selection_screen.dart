// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';
import 'chat_screen.dart';

/// Maps a role ID to its display info.
class _RoleOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color accent;

  const _RoleOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
  });
}

const List<_RoleOption> _roles = [
  _RoleOption(
    id: 'doctor',
    label: 'Doctor',
    description:
        'Diagnosis, treatment planning, prescriptions & clinical decisions.',
    icon: Icons.medical_services_outlined,
    accent: Color(0xFF00E5C8),
  ),
  _RoleOption(
    id: 'nurse',
    label: 'Nurse',
    description:
        'Patient care, medication administration & monitoring protocols.',
    icon: Icons.favorite_outline_rounded,
    accent: Color(0xFF7B61FF),
  ),
  _RoleOption(
    id: 'surgeon',
    label: 'Surgeon',
    description:
        'Surgical procedures, operative notes & post-op care guidelines.',
    icon: Icons.biotech_outlined,
    accent: Color(0xFFFF9500),
  ),
];

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;
  bool _isSaving = false;

  late AnimationController _staggerController;
  final List<Animation<double>> _itemAnimations = [];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    for (int i = 0; i < _roles.length; i++) {
      final start = i * 0.2;
      final end = start + 0.5;
      _itemAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
              curve: Curves.easeOut),
        ),
      );
    }

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _confirmRole() async {
    if (_selectedRole == null) return;
    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await AuthService.setRole(uid, _selectedRole!);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ChatScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save role: $e'),
          backgroundColor: kDangerColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'Clinician';

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Header ──────────────────────────────────────────────────────
              _buildHeader(name),

              const SizedBox(height: 40),

              // ── Role cards ──────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) {
                    return FadeTransition(
                      opacity: _itemAnimations[i],
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(_itemAnimations[i]),
                        child: _buildRoleCard(_roles[i]),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── Confirm button ───────────────────────────────────────────────
              _buildConfirmButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: kPrimaryColor, size: 14),
              const SizedBox(width: 6),
              Text(
                'Account created',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hi, $name! 👋',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your clinical role. This determines the\nRAG context and access level you receive.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white38,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(_RoleOption role) {
    final isSelected = _selectedRole == role.id;

    return GestureDetector(
      key: ValueKey('role_${role.id}'),
      onTap: () => setState(() => _selectedRole = role.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? role.accent.withOpacity(0.08)
              : kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? role.accent.withOpacity(0.7)
                : kSurfaceBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: role.accent.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: role.accent.withOpacity(isSelected ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(role.icon,
                  color: role.accent.withOpacity(isSelected ? 1.0 : 0.6),
                  size: 26),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white38,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? role.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? role.accent : Colors.white24,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final isReady = _selectedRole != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isReady ? 1.0 : 0.4,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isReady ? kPrimaryGradient : null,
          color: isReady ? null : kSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('btn_confirm_role'),
            onTap: isReady && !_isSaving ? _confirmRole : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isReady
                              ? 'Continue as ${_roles.firstWhere((r) => r.id == _selectedRole).label}'
                              : 'Select a role to continue',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (isReady) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
