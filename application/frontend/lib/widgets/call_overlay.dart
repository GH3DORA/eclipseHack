import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/chat_message.dart';

/// Overlay shown above the input bar during voice call mode.
class CallOverlay extends StatelessWidget {
  final bool isCallMode;
  final CallState callState;
  final List<double> waveBars;
  final VoidCallback onEndCall;

  const CallOverlay({
    super.key,
    required this.isCallMode,
    required this.callState,
    required this.waveBars,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCallMode) return const SizedBox.shrink();

    final stateLabel = switch (callState) {
      CallState.listening => 'Listening…',
      CallState.processing => 'Thinking…',
      CallState.speaking => 'Speaking…',
      CallState.idle => 'Ready',
    };

    final stateColor = switch (callState) {
      CallState.listening => kPrimaryColor,
      CallState.processing => kSecondaryColor,
      CallState.speaking => kOrangeColor,
      CallState.idle => Colors.white38,
    };

    return Container(
      color: kBgColor,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Waveform bars (only during listening)
          if (callState == CallState.listening)
            SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(waveBars.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: 8 + waveBars[i] * 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: kPrimaryColor
                          .withValues(alpha: 0.5 + waveBars[i] * 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

          if (callState == CallState.processing ||
              callState == CallState.speaking)
            SizedBox(
              height: 50,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: stateColor,
                ),
              ),
            ),

          if (callState == CallState.idle) const SizedBox(height: 50),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stateLabel,
                style: TextStyle(
                  color: stateColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // End call button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEndCall,
              icon: const Icon(Icons.call_end_rounded, size: 18),
              label: const Text('End Voice Call'),
              style: FilledButton.styleFrom(
                backgroundColor: kDangerColor.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
