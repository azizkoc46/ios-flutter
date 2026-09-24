// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'compass_service_base.dart';

class CompassServiceWeb implements CompassServiceBase {
  final StreamController<double?> _controller = StreamController<double?>.broadcast();
  StreamSubscription<html.DeviceOrientationEvent>? _orientationSub;
  html.EventListener? _absListener;
  html.EventListener? _stdListener;

  @override
  Stream<double?> get headingStream => _controller.stream;

  @override
  Future<void> init() async {
    _startListening();
  }

  void _startListening() {
    try {
      // 1. Android Chrome / Absolute Sensor Listener
      _absListener = (html.Event event) {
        _extractAndDispatchHeading(event);
      };

      try {
        html.window.addEventListener('deviceorientationabsolute', _absListener!);
      } catch (_) {}

      // 2. Standard deviceorientation listener via addEventListener
      _stdListener = (html.Event event) {
        _extractAndDispatchHeading(event);
      };

      try {
        html.window.addEventListener('deviceorientation', _stdListener!);
      } catch (_) {}

      // 3. Fallback onDeviceOrientation stream
      try {
        _orientationSub = html.window.onDeviceOrientation.listen((event) {
          _extractAndDispatchHeading(event);
        });
      } catch (_) {}
    } catch (_) {}
  }

  void _extractAndDispatchHeading(dynamic event) {
    if (event == null) return;
    try {
      // iOS Safari webkitCompassHeading (Doğrudan manyetik Kuzey açısı 0..360)
      try {
        final jsObj = js.JsObject.fromBrowserObject(event);
        final dynamic webkitHeading = jsObj['webkitCompassHeading'];
        if (webkitHeading != null && webkitHeading is num && !webkitHeading.isNaN && webkitHeading > 0) {
          _controller.add(webkitHeading.toDouble());
          return;
        }
      } catch (_) {}

      // Android Chrome alpha (Cihazın z ekseni etrafındaki dönüş açısı)
      if (event is html.DeviceOrientationEvent) {
        final num? alpha = event.alpha;
        if (alpha != null && !alpha.isNaN) {
          double heading = (360.0 - alpha.toDouble()) % 360.0;
          _controller.add(heading);
        }
      }
    } catch (_) {}
  }

  @override
  Future<bool> requestPermission() async {
    try {
      // iOS 13+ Safari izin sorgusu
      final dynamic doe = js.context['DeviceOrientationEvent'];
      if (doe != null && doe is js.JsObject && doe.hasProperty('requestPermission')) {
        final completer = Completer<bool>();
        final dynamic promise = doe.callMethod('requestPermission');
        if (promise is js.JsObject && promise.hasProperty('then')) {
          promise.callMethod('then', [
            (dynamic res) {
              if (res == 'granted') {
                _startListening();
                completer.complete(true);
              } else {
                completer.complete(false);
              }
            }
          ]);
          return await completer.future
              .timeout(const Duration(seconds: 4), onTimeout: () => true);
        }
      }
    } catch (_) {}

    // Android veya standart tarayıcılar için tekrar dinleme başlat
    _startListening();
    return true;
  }

  @override
  void dispose() {
    _orientationSub?.cancel();
    if (_absListener != null) {
      try {
        html.window.removeEventListener('deviceorientationabsolute', _absListener!);
      } catch (_) {}
    }
    if (_stdListener != null) {
      try {
        html.window.removeEventListener('deviceorientation', _stdListener!);
      } catch (_) {}
    }
    _controller.close();
  }
}

CompassServiceBase getCompassService() => CompassServiceWeb();
