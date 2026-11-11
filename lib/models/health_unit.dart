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
    this.city,
  });

  final String id;
  final String name;
  final LatLng center;
  final String suggestionSubtitle;

  /// Cidade usada no filtro `?city=` da API; `null` quando não há consulta.
  final String? city;

  static const goiania = SearchArea(
    id: 'goiania',
    name: 'Goiânia, GO',
    center: LatLng(-16.6869, -49.2648),
    suggestionSubtitle: 'Centro da cidade',
    city: 'Goiânia',
  );

  static const aparecida = SearchArea(
    id: 'aparecida',
    name: 'Aparecida de Goiânia, GO',
    center: LatLng(-16.8198, -49.2469),
    suggestionSubtitle: 'Região metropolitana',
    city: 'Aparecida de Goiânia',
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

/// Janela em que uma leitura operacional ainda é tratada como atual. A API não
/// define validade; o app aplica esta janela e, fora dela, não exibe espera nem
/// disponibilidade como informação atual.
const operationalDataMaxAge = Duration(
  minutes: int.fromEnvironment('OPERATIONAL_MAX_AGE_MINUTES', defaultValue: 30),
);

/// Tolerância para relógio do aparelho adiantado em relação à fonte.
const _operationalClockSkew = Duration(minutes: 5);

enum OperationalDataState {
  /// Leitura com conteúdo e atualização confiável dentro da janela.
  current,

  /// Há leitura, mas a atualização é antiga, futura ou sem data confiável.
  stale,

  /// A unidade não tem leitura, ou a leitura não traz nenhum valor.
  missing,
}

class UnitOperationalData {
  const UnitOperationalData({
    required this.availability,
    required this.waitMinutes,
    required this.peopleWaiting,
    this.updatedAt,
  });

  /// `null` quando a fonte não informou o nível.
  final AvailabilityLevel? availability;
  final int? waitMinutes;
  final int? peopleWaiting;

  /// Instante da leitura na fonte (`source_updated_at`).
  final DateTime? updatedAt;

  bool get hasValues =>
      availability != null || waitMinutes != null || peopleWaiting != null;
}

class HealthUnit {
  const HealthUnit({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.services,
    required this.operationalData,
    this.isDemo = false,
    this.openingHours,
    this.phone,
    this.distanceKm,
    this.carRoute,
    this.busRoute,
  });

  final String id;
  final String name;
  final String address;
  final LatLng position;
  final List<String> services;

  /// Última leitura recebida, mesmo antiga. Para exibir, use
  /// [currentOperationalData].
  final UnitOperationalData? operationalData;

  /// Cadastro ou leitura marcados como demonstrativos pela API.
  final bool isDemo;
  final String? openingHours;
  final String? phone;

  /// Distância e rotas dependem da posição do usuário e de um provedor de
  /// rotas; a API de unidades não as fornece e o app ainda não as calcula.
  final double? distanceKm;
  final UnitRoutePreview? carRoute;
  final UnitRoutePreview? busRoute;

  OperationalDataState operationalState({DateTime? now}) {
    final data = operationalData;
    if (data == null || !data.hasValues) return OperationalDataState.missing;
    final updatedAt = data.updatedAt;
    if (updatedAt == null) return OperationalDataState.stale;
    final age = (now ?? DateTime.now()).difference(updatedAt);
    if (age > operationalDataMaxAge || age < -_operationalClockSkew) {
      return OperationalDataState.stale;
    }
    return OperationalDataState.current;
  }

  /// Dados operacionais que podem ser mostrados como atuais, ou `null`.
  UnitOperationalData? get currentOperationalData =>
      operationalState() == OperationalDataState.current
      ? operationalData
      : null;

  UnitRoutePreview? routeFor(TravelMode mode) => switch (mode) {
    TravelMode.car => carRoute,
    TravelMode.bus => busRoute,
  };
}
