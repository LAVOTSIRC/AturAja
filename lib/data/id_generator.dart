import 'dart:math';

final Random _random = Random.secure();

String newDocumentId() {
  final int timestamp = DateTime.now().microsecondsSinceEpoch;
  final String suffix = _random.nextInt(0x7fffffff).toRadixString(36);
  return '$timestamp-$suffix';
}
