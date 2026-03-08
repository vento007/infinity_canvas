import 'package:flutter/material.dart';
import 'package:tiny_ecs/tiny_ecs.dart';

class MegaPositionC extends Component {
  double x;
  double y;

  MegaPositionC(this.x, this.y);

  Offset get offset => Offset(x, y);

  set offset(Offset value) {
    x = value.dx;
    y = value.dy;
  }
}

class MegaLaneFollowerC extends Component {
  int laneIndex;
  double distance;
  double speed;

  MegaLaneFollowerC({
    required this.laneIndex,
    required this.distance,
    required this.speed,
  });
}

class MegaCreepC extends Component {
  double radius;
  double hue;

  MegaCreepC({required this.radius, required this.hue});
}

class MegaTowerC extends Component {
  double radius;
  double range;

  MegaTowerC({required this.radius, required this.range});
}
