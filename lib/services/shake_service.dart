import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class ShakeService {
  static const double _shakeThreshold = 15.0;
  static const Duration _cooldown = Duration(seconds: 2);

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime(2000);
  void Function()? _onShake;

  void startListening({required void Function() onShake}) {
    _onShake = onShake;
    _sub = accelerometerEventStream().listen(_handleEvent);
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _onShake = null;
  }

  void _handleEvent(AccelerometerEvent event) {
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();

    if (magnitude > _shakeThreshold &&
        now.difference(_lastShake) > _cooldown) {
      _lastShake = now;
      _onShake?.call();
    }
  }
}
