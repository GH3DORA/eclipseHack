import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';

/// Welcome screen shown when there are no messages in the current chat.
class EmptyState extends StatelessWidget {
  final void Function(String) onQuickAction;

  const EmptyState({super.key, required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> quickActions = [
      {'icon': Icons.sick_outlined, 'title': 'Symptoms'},
      {'icon': Icons.medication_liquid_outlined, 'title': 'Medicines'},
      {'icon': Icons.medical_information_outlined, 'title': 'First Aid'},
      {'icon': Icons.restaurant_menu_outlined, 'title': 'Nutrition'},
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kSurfaceColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: kPrimaryColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.health_and_safety,
                  color: kPrimaryColor, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              'MediGuide',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your private health assistant.\nType or speak to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white38,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Quick Access Chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: quickActions.map((action) {
                return ActionChip(
                  backgroundColor: kSurfaceColor,
                  side: const BorderSide(color: kSurfaceBorderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  avatar: Icon(
                    action['icon'] as IconData,
                    size: 16,
                    color: kPrimaryColor,
                  ),
                  label: Text(
                    action['title'] as String,
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    final queryMap = {
                      'Symptoms': 'I am feeling unwell, can you help evaluate my symptoms?',
                      'Medicines': 'Can you tell me more about my medication?',
                      'First Aid': 'What should I do in a medical emergency for first aid?',
                      'Nutrition': 'What are some basic medical nutrition guidelines?',
                    };
                    onQuickAction(queryMap[action['title']] ?? 'Hi');
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
