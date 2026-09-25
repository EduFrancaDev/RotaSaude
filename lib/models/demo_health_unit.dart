import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum AvailabilityLevel { high, moderate, low, critical }

extension AvailabilityLevelLabel on AvailabilityLevel {
  String get label => switch (this) {
    AvailabilityLevel.high => 'Alta disponibilidade',
    AvailabilityLevel.moderate => 'Disponibilidade moderada',
    AvailabilityLevel.low => 'Baixa disponibilidade',
    AvailabilityLevel.critical => 'Situação crítica',
  };

  Color get color => switch (this) {
    AvailabilityLevel.high => const Color(0xFF69BDF2),
    AvailabilityLevel.moderate => const Color(0xFF5BB7A7),
    AvailabilityLevel.low => const Color(0xFFE87524),
    AvailabilityLevel.critical => const Color(0xFF7041E8),
  };

  Color get surfaceColor => switch (this) {
    AvailabilityLevel.high => const Color(0xFFEAF6FC),
    AvailabilityLevel.moderate => const Color(0xFFEAF7F3),
    AvailabilityLevel.low => const Color(0xFFFCF0E8),
    AvailabilityLevel.critical => const Color(0xFFF1EBFE),
  };
}

enum TravelMode { car, bus }

extension TravelModeLabel on TravelMode {
  String get label => switch (this) {
    TravelMode.car => 'Carro',
    TravelMode.bus => 'Ônibus',
  };
}

class SearchArea {
  const SearchArea({
    required this.id,
    required this.name,
    required this.center,
    this.suggestionSubtitle = '',
  });

  final String id;
  final String name;
  final LatLng center;
  final String suggestionSubtitle;

  static const goiania = SearchArea(
    id: 'goiania',
    name: 'Goiânia, GO',
    center: LatLng(-16.6869, -49.2648),
    suggestionSubtitle: 'Centro da cidade',
  );

  static const aparecida = SearchArea(
    id: 'aparecida',
    name: 'Aparecida de Goiânia, GO',
    center: LatLng(-16.8198, -49.2469),
    suggestionSubtitle: 'Região metropolitana',
  );

  static const suggestions = [goiania, aparecida];

  static SearchArea? fromPosition(Position position) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      goiania.center.latitude,
      goiania.center.longitude,
    );
    return distance <= 35000 ? goiania : null;
  }
}

class UnitRoutePreview {
  const UnitRoutePreview({
    required this.durationMinutes,
    this.distanceKm,
    this.traffic,
    this.description,
    this.steps = const [],
  });

  final int durationMinutes;
  final double? distanceKm;
  final String? traffic;
  final String? description;
  final List<String> steps;
}

class UnitOperationalData {
  const UnitOperationalData({
    required this.availability,
    required this.waitMinutes,
    required this.peopleWaiting,
  });

  final AvailabilityLevel availability;
  final int? waitMinutes;
  final int? peopleWaiting;
}

class DemoHealthUnit {
  const DemoHealthUnit({
    required this.id,
    required this.name,
    required this.address,
    required this.areaId,
    required this.position,
    required this.services,
    required this.distanceKm,
    required this.operationalData,
    this.openingHours,
    this.phone,
    this.carRoute,
    this.busRoute,
  });

  final String id;
  final String name;
  final String address;
  final String areaId;
  final LatLng position;
  final List<String> services;
  final double? distanceKm;
  final UnitOperationalData? operationalData;
  final String? openingHours;
  final String? phone;
  final UnitRoutePreview? carRoute;
  final UnitRoutePreview? busRoute;

  UnitRoutePreview? routeFor(TravelMode mode) => switch (mode) {
    TravelMode.car => carRoute,
    TravelMode.bus => busRoute,
  };
}

abstract final class DemoHealthUnits {
  static const goiania = [
    DemoHealthUnit(
      id: 'upa-centro',
      name: 'UPA Exemplo Centro',
      address: 'Rua Exemplo, 120 · Setor Central, Goiânia',
      areaId: 'goiania',
      position: LatLng(-16.6862, -49.2640),
      services: ['Clínica geral', 'Pediatria', 'Ortopedia'],
      distanceKm: 5.8,
      operationalData: UnitOperationalData(
        availability: AvailabilityLevel.high,
        waitMinutes: 20,
        peopleWaiting: 18,
      ),
      openingHours: '24 horas',
      carRoute: UnitRoutePreview(
        durationMinutes: 14,
        distanceKm: 5.8,
        traffic: 'Trânsito moderado',
        description: 'Via Av. T-9 e Rua Exemplo',
      ),
      busRoute: UnitRoutePreview(
        durationMinutes: 29,
        steps: [
          'Caminhe 6 min até o ponto Central',
          'Linha ilustrativa 005 · 17 min',
          'Desça no ponto UPA · caminhe 4 min',
        ],
      ),
    ),
    DemoHealthUnit(
      id: 'upa-sul',
      name: 'UPA Exemplo Sul',
      address: 'Rua Exemplo, 250 · Setor Sul, Goiânia',
      areaId: 'goiania',
      position: LatLng(-16.7100, -49.2590),
      services: ['Clínica geral', 'Ortopedia'],
      distanceKm: 3.2,
      operationalData: UnitOperationalData(
        availability: AvailabilityLevel.moderate,
        waitMinutes: 40,
        peopleWaiting: 32,
      ),
      openingHours: '24 horas',
      carRoute: UnitRoutePreview(
        durationMinutes: 9,
        distanceKm: 3.2,
        traffic: 'Trânsito moderado',
        description: 'Via Av. C-104 e Rua Exemplo',
      ),
      busRoute: UnitRoutePreview(
        durationMinutes: 24,
        steps: [
          'Caminhe 4 min até o ponto Sul',
          'Linha ilustrativa 010 · 15 min',
          'Desça no ponto UPA Sul · caminhe 5 min',
        ],
      ),
    ),
    DemoHealthUnit(
      id: 'upa-norte',
      name: 'UPA Exemplo Norte',
      address: 'Av. Exemplo, 400 · Setor Norte, Goiânia',
      areaId: 'goiania',
      position: LatLng(-16.6550, -49.2640),
      services: ['Clínica geral'],
      distanceKm: 2.1,
      operationalData: UnitOperationalData(
        availability: AvailabilityLevel.low,
        waitMinutes: 65,
        peopleWaiting: 54,
      ),
      openingHours: '24 horas',
      carRoute: UnitRoutePreview(
        durationMinutes: 7,
        distanceKm: 2.1,
        traffic: 'Trânsito moderado',
        description: 'Via Av. Independência e Rua Exemplo',
      ),
      busRoute: UnitRoutePreview(
        durationMinutes: 18,
        steps: [
          'Caminhe 3 min até o ponto Norte',
          'Linha ilustrativa 020 · 11 min',
          'Desça no ponto UPA Norte · caminhe 4 min',
        ],
      ),
    ),
    DemoHealthUnit(
      id: 'upa-oeste',
      name: 'UPA Exemplo Oeste',
      address: 'Av. Exemplo, 400 · Goiânia, GO',
      areaId: 'goiania',
      position: LatLng(-16.6865, -49.2950),
      services: ['Clínica geral', 'Pediatria'],
      distanceKm: null,
      operationalData: null,
      openingHours: '24 horas',
    ),
  ];

  static List<DemoHealthUnit> forArea(SearchArea? area) =>
      area?.id == SearchArea.goiania.id ? goiania : const [];

  static DemoHealthUnit? byId(String id) {
    for (final unit in goiania) {
      if (unit.id == id) return unit;
    }
    return null;
  }
}
