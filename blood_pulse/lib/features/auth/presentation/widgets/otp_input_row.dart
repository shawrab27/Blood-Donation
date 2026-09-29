import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInputRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> nodes;
  final ValueChanged<String>? onPaste;
  final void Function(String value, int index) onChanged;
  
  const OtpInputRow({
    super.key,
    required this.controllers,
    required this.nodes,
    required this.onChanged,
    this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 45,
          height: 55,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                if (controllers[index].text.isEmpty && index > 0) {
                  nodes[index - 1].requestFocus();
                }
              }
            },
            child: TextFormField(
              controller: controllers[index],
              focusNode: nodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => onChanged(val, index),
            ),
          ),
        );
      }),
    );
  }
}
