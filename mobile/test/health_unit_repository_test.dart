import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';
import 'package:rotasaude/widgets/unit_ui.dart';

import 'support/health_unit_fixtures.dart';

http.Response jsonResponse(Object body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      // O DRF não declara charset; o app não pode depender dele.
      headers: const {'content-type': 'application/json'},
    );

Map<String, dynamic> page(
  List<Object?> results, {
  String? next,
  String? previous,
}) => {
  'count': results.length,
  'next': next,
  'previous': previous,
  'results': results,
};

ApiHealthUnitRepository repositoryFor(
  Future<http.Response> Function(http.Request request) handler, {
  String base = 'http://api.test:8000',
  Duration timeout = const Duration(seconds: 2),
}) => ApiHealthUnitRepository(
  client: MockClient(handler),
  baseUri: Uri.parse(base),
  timeout: timeout,
);

Future<HealthApiException> failureOf(Future<Object?> Function() action) async {
  try {
    await action();
  } on HealthApiException catch (error) {
    return error;
  }
  fail('Esperava HealthApiException.');
}

void main() {
  group('GET /api/v1/units/', () {
    test('converte uma resposta válida e consulta pela cidade', () async {
      late http.Request seen;
      final repository = repositoryFor((request) async {
        seen = request;
        return jsonResponse(page(goianiaUnitsJson()));
      });

      final units = await repository.fetchUnits(city: 'Goiânia');

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/units/');
      expect(seen.url.queryParameters, {'city': 'Goiânia', 'page_size': '100'});
      expect(seen.headers['Accept'], 'application/json');
      // Nenhuma credencial é enviada pelo app.
      expect(seen.headers.containsKey('Authorization'), isFalse);

      expect(units.map((unit) => unit.id), [
        'upa-centro',
        'upa-norte',
        'upa-oeste',
        'upa-sul',
      ]);
      final centro = units.first;
      expect(centro.name, 'UPA Exemplo Centro');
      expect(centro.address, 'Rua Exemplo, 1 · Goiânia');
      expect(centro.position.latitude, -16.6862);
      expect(centro.position.longitude, -49.264);
      expect(centro.services, ['Clínica geral', 'Ortopedia', 'Pediatria']);
      expect(centro.openingHours, '24 horas');
      expect(centro.isDemo, isTrue);
      expect(centro.operationalData?.availability, AvailabilityLevel.high);
      expect(centro.operationalData?.waitMinutes, 20);
      expect(centro.operationalData?.peopleWaiting, 18);
      expect(centro.operationalData?.updatedAt, isNotNull);
      expect(centro.operationalState(), OperationalDataState.current);
    });

    test('decodifica acentos como UTF-8 mesmo sem charset', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse(
          page([
            unitJson(
              id: 'u1',
              name: 'Unidade São José',
              address: 'Avenida Ângelo, 10 · Goiânia',
            ),
          ]),
        ),
      );

      final unit = (await repository.fetchUnits()).single;

      expect(unit.name, 'Unidade São José');
      expect(unit.address, 'Avenida Ângelo, 10 · Goiânia');
    });

    test('segue a paginação e reaplica next ao host configurado', () async {
      final requested = <Uri>[];
      final repository = repositoryFor((request) async {
        requested.add(request.url);
        return switch (request.url.queryParameters['page']) {
          null => jsonResponse(
            page(
              [unitJson(id: 'a', name: 'A')],
              // O backend monta `next` com o Host da requisição, que pode ser
              // outro (proxy, túnel): o app mantém a URL base configurada.
              next: 'http://outro-host:9999/api/v1/units/?page=2&page_size=1',
            ),
          ),
          '2' => jsonResponse(
            page(
              [unitJson(id: 'b', name: 'B')],
              previous: 'http://outro-host:9999/api/v1/units/?page_size=1',
              next: 'http://outro-host:9999/api/v1/units/?page=3&page_size=1',
            ),
          ),
          _ => jsonResponse(
            page([unitJson(id: 'c', name: 'C')], previous: 'x'),
          ),
        };
      });

      final units = await repository.fetchUnits();

      expect(units.map((unit) => unit.id), ['a', 'b', 'c']);
      expect(requested, hasLength(3));
      for (final url in requested) {
        expect(url.host, 'api.test');
        expect(url.port, 8000);
        expect(url.path, '/api/v1/units/');
      }
      expect(requested[1].queryParameters['page'], '2');
    });

    test('interrompe paginação em ciclo', () async {
      final repository = repositoryFor(
        (request) async => jsonResponse(
          page([
            unitJson(id: 'a', name: 'A'),
          ], next: 'http://api.test:8000/api/v1/units/?page_size=100'),
        ),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.invalidResponse);
    });

    test('lista vazia é um resultado válido', () async {
      final repository = repositoryFor((_) async => jsonResponse(page([])));

      expect(await repository.fetchUnits(city: 'Aparecida'), isEmpty);
    });

    test('falha de rede vira erro de conexão', () async {
      final repository = repositoryFor(
        (_) async => throw const SocketException('sem rota'),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.connection);
    });

    test('falha do cliente HTTP vira erro de conexão', () async {
      final repository = repositoryFor(
        (_) async => throw http.ClientException('conexão encerrada'),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.connection);
    });

    test('resposta que não chega a tempo vira timeout', () async {
      final never = Completer<http.Response>();
      final repository = repositoryFor(
        (_) => never.future,
        timeout: const Duration(milliseconds: 50),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.timeout);
    });

    test('HTTP 500 vira erro do servidor', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse({'detail': 'boom'}, status: 500),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.server);
      expect(error.statusCode, 500);
    });

    test('HTTP 503 vira erro do servidor', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse({'status': 'error'}, status: 503),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.server);
    });

    test('HTTP 400 vira erro do cliente', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse({'detail': 'host'}, status: 400),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.client);
      expect(error.statusCode, 400);
    });

    test('falha em página posterior não devolve resultado parcial', () async {
      final repository = repositoryFor((request) async {
        if (request.url.queryParameters['page'] == '2') {
          return jsonResponse({}, status: 500);
        }
        return jsonResponse(
          page([
            unitJson(id: 'a', name: 'A'),
          ], next: 'http://api.test:8000/api/v1/units/?page=2'),
        );
      });

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.server);
    });

    test('corpo que não é JSON vira resposta inválida', () async {
      final repository = repositoryFor(
        (_) async => http.Response('<html>proxy</html>', 200),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.invalidResponse);
    });

    test('JSON fora do contrato paginado vira resposta inválida', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse([unitJson(id: 'a', name: 'A')]),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.invalidResponse);
    });

    test('unidade sem campo obrigatório vira resposta inválida', () async {
      final broken = unitJson(id: 'a', name: 'A')..remove('latitude');
      final repository = repositoryFor(
        (_) async => jsonResponse(page([broken])),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.invalidResponse);
    });

    test('coordenada fora da faixa vira resposta inválida', () async {
      final repository = repositoryFor(
        (_) async =>
            jsonResponse(page([unitJson(id: 'a', name: 'A', latitude: 123)])),
      );

      final error = await failureOf(repository.fetchUnits);

      expect(error.kind, HealthApiFailureKind.invalidResponse);
    });

    test('respeita prefixo de caminho na URL base', () async {
      late Uri seen;
      final repository = repositoryFor((request) async {
        seen = request.url;
        return jsonResponse(page([]));
      }, base: 'https://exemplo.test/rotasaude/');

      await repository.fetchUnits();

      expect(
        seen.toString(),
        startsWith('https://exemplo.test/rotasaude/api/v1/units/'),
      );
    });
  });

  group('dados operacionais', () {
    Future<HealthUnit> parse(Map<String, dynamic> json) async {
      final repository = repositoryFor((_) async => jsonResponse(page([json])));
      return (await repository.fetchUnits()).single;
    }

    test('operational_status nulo vira dados ausentes', () async {
      final unit = await parse(unitJson(id: 'a', name: 'A'));

      expect(unit.operationalData, isNull);
      expect(unit.operationalState(), OperationalDataState.missing);
      expect(unit.currentOperationalData, isNull);
    });

    test('leitura com todos os campos nulos conta como ausente', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(level: null, wait: null, people: null),
        ),
      );

      expect(unit.operationalState(), OperationalDataState.missing);
      expect(unit.currentOperationalData, isNull);
    });

    test('campos nulos isolados são preservados como nulos', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(level: 'LOW', wait: null, people: 7),
        ),
      );

      expect(unit.operationalState(), OperationalDataState.current);
      expect(unit.currentOperationalData?.waitMinutes, isNull);
      expect(unit.currentOperationalData?.peopleWaiting, 7);
      expect(unit.currentOperationalData?.availability, AvailabilityLevel.low);
    });

    test('mapeia os quatro níveis de disponibilidade', () async {
      const expected = {
        'HIGH': AvailabilityLevel.high,
        'MODERATE': AvailabilityLevel.moderate,
        'LOW': AvailabilityLevel.low,
        'CRITICAL': AvailabilityLevel.critical,
      };
      for (final entry in expected.entries) {
        final unit = await parse(
          unitJson(
            id: 'a',
            name: 'A',
            operationalStatus: statusJson(level: entry.key),
          ),
        );
        expect(
          unit.operationalData?.availability,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('nível desconhecido não vira disponibilidade inventada', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(level: 'SUPERB'),
        ),
      );

      expect(unit.operationalData?.availability, isNull);
      expect(unit.currentAvailability, isNull);
    });

    test('valores numéricos inválidos viram nulos', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(wait: -3, people: '12'),
        ),
      );

      expect(unit.operationalData?.waitMinutes, isNull);
      expect(unit.operationalData?.peopleWaiting, isNull);
    });

    test('leitura antiga é desatualizada e não é exibida como atual', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(age: const Duration(hours: 3)),
        ),
      );

      expect(unit.operationalData, isNotNull);
      expect(unit.operationalState(), OperationalDataState.stale);
      expect(unit.currentOperationalData, isNull);
      expect(unit.operationalSummary, 'Dados desatualizados');
    });

    test('leitura no futuro não é confiável', () async {
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: statusJson(age: const Duration(hours: -2)),
        ),
      );

      expect(unit.operationalState(), OperationalDataState.stale);
    });

    test('data inválida deixa a leitura desatualizada', () async {
      final status = statusJson()..['source_updated_at'] = 'ontem';
      final unit = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          operationalStatus: status,
          lastOperationalUpdateAt: 'ontem',
        ),
      );

      expect(unit.operationalState(), OperationalDataState.stale);
    });

    test('is_demo vem da unidade ou da leitura', () async {
      final unitDemo = await parse(unitJson(id: 'a', name: 'A'));
      final real = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          isDemo: false,
          operationalStatus: statusJson(isDemo: false),
        ),
      );
      final readingDemo = await parse(
        unitJson(
          id: 'a',
          name: 'A',
          isDemo: false,
          operationalStatus: statusJson(isDemo: true),
        ),
      );

      expect(unitDemo.isDemo, isTrue);
      expect(real.isDemo, isFalse);
      expect(readingDemo.isDemo, isTrue);
    });

    test('distância e rotas não são inventadas pela API', () async {
      final unit = await parse(
        unitJson(id: 'a', name: 'A', operationalStatus: statusJson()),
      );

      expect(unit.distanceKm, isNull);
      expect(unit.carRoute, isNull);
      expect(unit.busRoute, isNull);
    });
  });

  group('GET /api/v1/units/{id}/', () {
    test('converte o detalhe da unidade', () async {
      late Uri seen;
      final repository = repositoryFor((request) async {
        seen = request.url;
        return jsonResponse(
          unitJson(id: 'upa-centro', name: 'UPA Exemplo Centro'),
        );
      });

      final unit = await repository.fetchUnit('upa-centro');

      expect(seen.path, '/api/v1/units/upa-centro/');
      expect(unit.id, 'upa-centro');
    });

    test('HTTP 404 vira erro do cliente', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse({'detail': 'Não encontrado.'}, status: 404),
      );

      final error = await failureOf(() => repository.fetchUnit('x'));

      expect(error.kind, HealthApiFailureKind.client);
      expect(error.statusCode, 404);
    });
  });

  group('GET /api/v1/services/', () {
    test('lista os nomes dos serviços e segue a paginação', () async {
      final repository = repositoryFor((request) async {
        if (request.url.queryParameters['page'] == '2') {
          return jsonResponse(
            page([
              {'id': 2, 'name': 'Pediatria', 'description': ''},
            ]),
          );
        }
        return jsonResponse(
          page([
            {'id': 1, 'name': 'Clínica geral', 'description': ''},
          ], next: 'http://api.test:8000/api/v1/services/?page=2'),
        );
      });

      expect(await repository.fetchServices(), ['Clínica geral', 'Pediatria']);
    });

    test('erro do servidor é propagado', () async {
      final repository = repositoryFor(
        (_) async => jsonResponse({}, status: 502),
      );

      final error = await failureOf(repository.fetchServices);

      expect(error.kind, HealthApiFailureKind.server);
    });
  });
}
