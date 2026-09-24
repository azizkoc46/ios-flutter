import 'compass_service_base.dart';
import 'compass_service_stub.dart'
    if (dart.library.io) 'compass_service_io.dart'
    if (dart.library.html) 'compass_service_web.dart';

class CompassService {
  static final CompassService _instance = CompassService._internal();
  factory CompassService() => _instance;
  CompassService._internal() {
    _platformService = getCompassService();
  }

  late final CompassServiceBase _platformService;

  Stream<double?> get headingStream => _platformService.headingStream;

  Future<void> init() => _platformService.init();

  Future<bool> requestPermission() => _platformService.requestPermission();

  void dispose() => _platformService.dispose();
}
