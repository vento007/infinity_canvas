import 'package:flutter/material.dart';

import '../painters.dart';

CustomPainter buildBackgroundGridPainter(Matrix4 transform, _) {
  return InfiniteGridPainter(transform: transform);
}
