import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Animated send button that changes gradient when text is entered.
class SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final TextEditingController controller;

  const SendButton({super.key, required this.onTap, required this.controller});

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _hasText ? kPrimaryGradient : null,
        color: _hasText ? null : kSurfaceBorderColor,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: _hasText ? widget.onTap : null,
        icon: Icon(
          Icons.arrow_upward_rounded,
          color: _hasText ? Colors.white : Colors.white30,
          size: 18,
        ),
      ),
    );
  }
}
