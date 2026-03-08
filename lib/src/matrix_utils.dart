import 'package:vector_math/vector_math_64.dart' show Matrix4;

bool matrixApproxEquals(Matrix4? a, Matrix4? b, {double epsilon = 1e-9}) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  final av = a.storage;
  final bv = b.storage;
  for (var i = 0; i < 16; i++) {
    if ((av[i] - bv[i]).abs() > epsilon) return false;
  }
  return true;
}
