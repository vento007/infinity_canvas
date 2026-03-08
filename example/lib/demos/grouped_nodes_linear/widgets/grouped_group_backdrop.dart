import 'package:flutter/material.dart';

class GroupedGroupBackdrop extends StatelessWidget {
  final String title;
  final Color fillColor;
  final Color borderColor;
  final Color headerColor;

  const GroupedGroupBackdrop({
    super.key,
    required this.title,
    required this.fillColor,
    required this.borderColor,
    required this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14.8),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Backdrop is a normal CanvasItem.\nDrag here to move several nodes.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
