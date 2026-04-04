import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';

class RoleSwitcherMenu extends StatefulWidget {
  final bool isOpen;
  final String activeRole;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onTapOutside;

  const RoleSwitcherMenu({
    super.key,
    required this.isOpen,
    required this.activeRole,
    required this.onRoleSelected,
    required this.onTapOutside,
  });

  @override
  State<RoleSwitcherMenu> createState() => _RoleSwitcherMenuState();
}

class _RoleSwitcherMenuState extends State<RoleSwitcherMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RoleSwitcherMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRoleButton(String role, String label, IconData icon) {
    final isActive = widget.activeRole == role;
    return GestureDetector(
      onTap: () => widget.onRoleSelected(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryColor : kSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? kPrimaryColor : kSurfaceBorderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF051A14) : kPrimaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive ? const Color(0xFF051A14) : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible tap detector to dismiss menu
        if (widget.isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onTapOutside,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        
        // Menu content
        Positioned(
          bottom: 140,
          right: 16,
          child: IgnorePointer(
            ignoring: !widget.isOpen,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1017),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kSurfaceBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRoleButton('doctor', 'Doctor', Icons.medical_services_rounded),
                      const SizedBox(height: 8),
                      _buildRoleButton('nurse', 'Nurse', Icons.health_and_safety_rounded),
                      const SizedBox(height: 8),
                      _buildRoleButton('patient', 'Patient', Icons.person_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
