import 'package:flutter/material.dart';

class KssV3TpStyle {
  static Color background(int level) {
    if (level <= 2) return const Color(0xFFF4CCCC);
    if (level <= 4) return const Color(0xFFFFF2CC);
    return const Color(0xFFD9EAD3);
  }

  static Color foreground(int level) {
    if (level <= 2) return const Color(0xFF8B1E1E);
    if (level <= 4) return const Color(0xFF7A5A00);
    return const Color(0xFF276738);
  }

  static Widget badge(dynamic value) {
    final level = int.tryParse(value.toString()) ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background(level),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('TP $level',
          style:
              TextStyle(color: foreground(level), fontWeight: FontWeight.w800)),
    );
  }
}
