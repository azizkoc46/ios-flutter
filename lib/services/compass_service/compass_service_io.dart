import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'compass_service_base.dart';

class CompassServiceIo implements CompassServiceBase {
  final StreamController<double?> _controller = StreamController<double?>.broadcast();
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  bool _receivedFlutterCompass = false;
  double _lastAx = 0, _lastAy = 0, _lastAz = 9.8;
  double _lastMx = 0, _lastMy = 0, _lastMz = 0;
  bool _hasMag = false;

  @override
  Stream<double?> get headingStream => _controller.stream;

  @override
  Future<void> init() async {
    // 1. Önce FlutterCompass (Cihazın yerel rotasyon vektör sensörü)
    try {
      final events = FlutterCompass.events;
      if (events != null) {
        _compassSub = events.listen((event) {
          final double? h = event.heading ?? event.headingForCameraMode;
          if (h != null && !h.isNaN) {
            _receivedFlutterCompass = true;
            double validHeading = (h + 360.0) % 360.0;
            _controller.add(validHeading);
          }
        }, onError: (_) {});
      }
    } catch (_) {}

    // 2. Yedek Motor: Eğer 1.5 saniye içinde FlutterCompass veri vermezse
    // sensors_plus (Manyetometre + İvmeölçer) doğrudan devreye girer
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_receivedFlutterCompass) {
        _startSensorsPlusFallback();
      }
    });
  }

  void _startSensorsPlusFallback() {
    try {
      _accelSub = accelerometerEventStream().listen((accel) {
        _lastAx = accel.x;
        _lastAy = accel.y;
        _lastAz = accel.z;
        if (_hasMag) _computeHeadingFromVectors();
      }, onError: (_) {});

      _magSub = magnetometerEventStream().listen((mag) {
        _lastMx = mag.x;
        _lastMy = mag.y;
        _lastMz = mag.z;
        _hasMag = true;
        _computeHeadingFromVectors();
      }, onError: (_) {});
    } catch (_) {}
  }

  void _computeHeadingFromVectors() {
    try {
      double ax = _lastAx;
      double ay = _lastAy;
      double az = _lastAz;
      double mx = _lastMx;
      double my = _lastMy;
      double mz = _lastMz;

      // Yerçekimi vektörünü normalize et
      double normA = math.sqrt(ax * ax + ay * ay + az * az);
      if (normA < 0.001) return;
      ax /= normA;
      ay /= normA;
      az /= normA;

      // Manyetik vektörü normalize et
      double normM = math.sqrt(mx * mx + my * my + mz * mz);
      if (normM < 0.001) return;
      mx /= normM;
      my /= normM;
      mz /= normM;

      // Doğu Vektörü (East) = İvme (A) x Manyetik (M)
      double ex = ay * mz - az * my;
      double ey = az * mx - ax * mz;
      double ez = ax * my - ay * mx;
      double normE = math.sqrt(ex * ex + ey * ey + ez * ez);
      if (normE < 0.001) return;
      ex /= normE;
      ey /= normE;
      ez /= normE;

      // Kuzey Vektörü (North) = Doğu (E) x İvme (A)
      double nx = ey * az - ez * ay;
      double ny = ez * ax - ex * az;

      // Yatay Düzlemdeki Azimut Açısı
      double azimuthRad = math.atan2(ex, nx);
      double headingDeg = (azimuthRad * (180.0 / math.pi) + 360.0) % 360.0;

      if (!headingDeg.isNaN) {
        _controller.add(headingDeg);
      }
    } catch (_) {}
  }

  @override
  Future<bool> requestPermission() async {
    return true;
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _controller.close();
  }
}

CompassServiceBase getCompassService() => CompassServiceIo();
