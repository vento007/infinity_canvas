import 'package:flutter/material.dart';

class DemoNode {
  final String id;
  final Color color;
  final double tiltRadians;

  final ValueNotifier<Offset> position;
  final ValueNotifier<Size> size;
  final ValueNotifier<bool> dragging;
  final ValueNotifier<bool> resizing;

  DemoNode({
    required this.id,
    required Offset initialPosition,
    required Size initialSize,
    required this.color,
    this.tiltRadians = 0.0,
  }) : position = ValueNotifier<Offset>(initialPosition),
       size = ValueNotifier<Size>(initialSize),
       dragging = ValueNotifier<bool>(false),
       resizing = ValueNotifier<bool>(false);

  void dispose() {
    position.dispose();
    size.dispose();
    dragging.dispose();
    resizing.dispose();
  }
}
