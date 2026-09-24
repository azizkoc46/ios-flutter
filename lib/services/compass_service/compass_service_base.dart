import 'dart:async';

abstract class CompassServiceBase {
  Stream<double?> get headingStream;
  Future<void> init();
  Future<bool> requestPermission();
  void dispose();
}
