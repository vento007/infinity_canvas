import 'package:flutter/material.dart';

import '../painters.dart';

CustomPainter buildBackgroundGridPainter(Matrix4 transform) {
  return InfiniteGridPainter(transform: transform);
}
