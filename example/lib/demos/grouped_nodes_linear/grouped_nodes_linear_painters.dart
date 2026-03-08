import 'package:flutter/material.dart';

class GroupedNodesLinearGridPainter extends CustomPainter {
  const GroupedNodesLinearGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8FAFC),
    );

    final minor = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2;

    const spacing = 48.0;
    for (double x = 0; x <= size.width; x += spacing) {
      final paint = (x / spacing).round() % 4 == 0 ? major : minor;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      final paint = (y / spacing).round() % 4 == 0 ? major : minor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
