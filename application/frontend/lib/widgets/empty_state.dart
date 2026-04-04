import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Welcome screen shown when there are no messages in the current chat.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'MediGuide',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your personal health assistant.\nType or speak to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white38, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
