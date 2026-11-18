/// Location groups: the server sends several permitted places instead of one
/// centre, and the punch screen checks against whichever applies.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horilla_mobile/features/home/data/home_models.dart';
import 'package:horilla_mobile/features/punch/data/location_service.dart';
import 'package:horilla_mobile/features/punch/data/punch_controller.dart';

class _At implements LocationService {
  _At(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
  int calls = 0;

  @override
  Future<Coordinates> current() async {
    calls++;
    return Coordinates(latitude: latitude, longitude: longitude);
  }
}

// Two sites about 3 km apart.
final _groups = GeofenceState.fromJson({
  'enabled': true,
  'points': [
    {
      'name': 'Mill',
      'latitude': -5.13,
      'longitude': 119.41,
      'radius_in_meters': 100,
    },
    {
      'name': 'Office',
      'latitude': -5.1477,
      'longitude': 119.4327,
      'radius_in_meters': 150,
    },
  ],
});

Future<PunchPreparation> _prepare(LocationService location, GeofenceState g) {
  final container = ProviderContainer(
    overrides: [locationServiceProvider.overrideWithValue(location)],
  );
  addTearDown(container.dispose);
  return container
      .read(punchControllerProvider)
      .prepare(isClockingIn: true, geofence: g);
}

void main() {
  test('points are read from the server, a single centre is not needed', () {
    expect(_groups.enabled, isTrue);
    expect(_groups.latitude, isNull);
    expect(_groups.allPoints.map((p) => p.name), ['Mill', 'Office']);
  });

  test('broken point entries are skipped, not fatal', () {
    final g = GeofenceState.fromJson({
      'enabled': true,
      'points': [
        {'latitude': 'x', 'longitude': 1, 'radius_in_meters': 10},
        'nonsense',
        {'latitude': 1, 'longitude': 2, 'radius_in_meters': 30},
      ],
    });
    expect(g.allPoints.length, 1);
  });

  test('inside the second place is allowed', () async {
    final p = await _prepare(_At(-5.1477, 119.4327), _groups);
    expect(p.canSubmit, isTrue);
    expect(p.fence!.isInside, isTrue);
    expect(p.coordinates, isNotNull);
  });

  test('outside every place is refused, measured from the nearest', () async {
    // About 1.6 km from either site.
    final p = await _prepare(_At(-5.14, 119.42), _groups);
    expect(p.canSubmit, isFalse);
    expect(p.fence!.metresOutside, greaterThan(1000));
    expect(p.blockedReason, contains('outside your workplace'));
  });

  test('enabled with no places still sends coordinates', () async {
    // Policy "must be in a group" with no group: the server decides.
    final location = _At(-5.13, 119.41);
    final p = await _prepare(
      location,
      GeofenceState.fromJson({'enabled': true, 'points': <Object>[]}),
    );
    expect(location.calls, 1);
    expect(p.coordinates, isNotNull);
    expect(p.fence, isNull);
    expect(p.canSubmit, isTrue);
  });

  test('the old single fence still works', () async {
    const single = GeofenceState(
      enabled: true,
      latitude: -5.13,
      longitude: 119.41,
      radiusInMeters: 100,
    );
    expect((await _prepare(_At(-5.13, 119.41), single)).canSubmit, isTrue);
    expect((await _prepare(_At(-5.1477, 119.4327), single)).canSubmit, isFalse);
  });
}
