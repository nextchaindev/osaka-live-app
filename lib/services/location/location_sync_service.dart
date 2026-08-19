import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationSyncService {
  factory LocationSyncService() => _instance;

  LocationSyncService._internal();

  static final LocationSyncService _instance = LocationSyncService._internal();

  StreamSubscription<Position>? _positionSubscription;
  bool _starting = false;

  Future<void> start({
    required void Function(Position position) onPosition,
  }) async {
    if (_starting || _positionSubscription != null) {
      return;
    }

    _starting = true;
    try {
      final ready = await _ensurePermissionAndService();
      if (!ready) {
        return;
      }

      await _pushCurrentPosition(onPosition);
      await _startPositionStream(onPosition);
    } catch (e) {
      debugPrint('LocationSyncService start failed: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<bool> _ensurePermissionAndService() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    final permission = await Geolocator.checkPermission();

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _pushCurrentPosition(
    void Function(Position position) onPosition,
  ) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    debugPrint(
      '[OsakaLive][location][flutter] current position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}, updatedAt=${position.timestamp.millisecondsSinceEpoch}',
    );
    onPosition(position);
  }

  Future<void> _startPositionStream(
    void Function(Position position) onPosition,
  ) async {
    _positionSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen(
      (position) {
        debugPrint(
          '[OsakaLive][location][flutter] stream position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}, updatedAt=${position.timestamp.millisecondsSinceEpoch}',
        );
        onPosition(position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }
}
