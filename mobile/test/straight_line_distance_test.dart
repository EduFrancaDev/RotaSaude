import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/straight_line_distance.dart';

import 'support/health_unit_fixtures.dart';

void main() {
  final goianiaCenter = SearchArea.goiania.center;
  final norte = goianiaUnits().firstWhere((u) => u.id == 'upa-norte');

  group('computeStraightLineDistanceKm', () {
    test('converte metros em quilômetros', () {
      final meters = Geolocator.distanceBetween(
        goianiaCenter.latitude,
        goianiaCenter.longitude,
        norte.position.latitude,
        norte.position.longitude,
      );
      final km = computeStraightLineDistanceKm(
        userPosition: goianiaCenter,
        unitPosition: norte.position,
      );
      expect(km, closeTo(meters / 1000, 0.0001));
    });

    test('retorna null sem posição do usuário', () {
      expect(
        computeStraightLineDistanceKm(
          userPosition: null,
          unitPosition: norte.position,
        ),
        isNull,
      );
    });

    test('retorna null para coordenada inválida da unidade', () {
      expect(
        computeStraightLineDistanceKm(
          userPosition: goianiaCenter,
          unitPosition: const LatLng(double.nan, -49.26),
        ),
        isNull,
      );
      expect(
        computeStraightLineDistanceKm(
          userPosition: goianiaCenter,
          unitPosition: const LatLng(95, -49.26),
        ),
        isNull,
      );
    });
  });

  group('formatStraightLineDistanceValue', () {
    test('formata com uma casa decimal em pt-BR', () {
      expect(formatStraightLineDistanceValue(2.44), '2,4 km');
    });

    test('indisponível quando distância é null', () {
      expect(
        formatStraightLineDistanceValue(null),
        straightLineDistanceUnavailable,
      );
    });
  });

  group('compareUnitsByStraightLineDistance', () {
    late HealthUnit a;
    late HealthUnit b;
    late HealthUnit c;

    setUp(() {
      final units = goianiaUnits();
      a = units.firstWhere((u) => u.id == 'upa-centro');
      b = units.firstWhere((u) => u.id == 'upa-norte');
      c = units.firstWhere((u) => u.id == 'upa-sul');
    });

    test('ordena da menor para a maior distância', () {
      expect(compareUnitsByStraightLineDistance(a, 1.0, b, 3.0), lessThan(0));
      expect(
        compareUnitsByStraightLineDistance(b, 3.0, a, 1.0),
        greaterThan(0),
      );
    });

    test('unidades sem distância ficam após as demais', () {
      expect(compareUnitsByStraightLineDistance(a, 2.0, b, null), lessThan(0));
      expect(
        compareUnitsByStraightLineDistance(a, null, b, 2.0),
        greaterThan(0),
      );
    });

    test('desempata por nome quando ambas sem distância', () {
      expect(
        compareUnitsByStraightLineDistance(a, null, b, null),
        a.name.compareTo(b.name),
      );
    });

    test('desempata por nome com mesma distância', () {
      final ordered = [
        c,
        b,
        a,
      ]..sort((u1, u2) => compareUnitsByStraightLineDistance(u1, 2.0, u2, 2.0));
      expect(ordered.map((u) => u.id).toList(), [
        'upa-centro',
        'upa-norte',
        'upa-sul',
      ]);
    });
  });

  group('buildStraightLineDistanceLookup', () {
    test('unidade sem coordenada válida fica por último na ordenação', () {
      final invalid = HealthUnit(
        id: 'upa-invalid',
        name: 'UPA Coordenada inválida',
        address: 'Endereço',
        position: const LatLng(95, -49.26),
        services: const ['Clínica geral'],
        operationalData: null,
      );
      final units = [...goianiaUnits(), invalid];
      final distances = buildStraightLineDistanceLookup(
        userPosition: goianiaCenter,
        units: units,
      );
      final sorted = [...units]
        ..sort(
          (a, b) => compareUnitsByStraightLineDistance(
            a,
            distances[a.id],
            b,
            distances[b.id],
          ),
        );
      expect(sorted.last.id, 'upa-invalid');
      expect(distances['upa-invalid'], isNull);
    });

    test('atualiza quando a origem muda', () {
      final units = goianiaUnits();
      final nearCenter = buildStraightLineDistanceLookup(
        userPosition: goianiaCenter,
        units: units,
      );
      final nearNorte = buildStraightLineDistanceLookup(
        userPosition: norte.position,
        units: units,
      );
      expect(nearCenter['upa-centro'], lessThan(nearNorte['upa-centro']!));
    });
  });
}
