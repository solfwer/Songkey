import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/metadata/rate_limiter.dart';

void main() {
  test('respeta el intervalo mínimo entre peticiones', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 200));
    var callCount = 0;

    final start = DateTime.now();
    await limiter.run(() async {
      callCount++;
      return 'a';
    });
    await limiter.run(() async {
      callCount++;
      return 'b';
    });
    final elapsed = DateTime.now().difference(start);

    expect(callCount, 2);
    // Dos llamadas con 200ms de intervalo → al menos 200ms transcurridos.
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(200));
  });

  test('no espera si ya pasó el intervalo', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 50));
    await limiter.run(() async => 1);
    await Future.delayed(const Duration(milliseconds: 100));
    final start = DateTime.now();
    await limiter.run(() async => 2);
    final elapsed = DateTime.now().difference(start);
    // Ya pasó más de 50ms desde la última llamada, no debe esperar.
    expect(elapsed.inMilliseconds, lessThan(50));
  });
}
