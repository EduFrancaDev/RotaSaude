# Arquitetura do aplicativo Flutter

## Escopo

O monorepo reúne o aplicativo Flutter/Dart em [`mobile/`](../mobile/) e a API Django em [`backend/`](../backend/). O app usa os endpoints de leitura (`/api/v1/units/`, `/api/v1/units/{id}/`, `/api/v1/services/` e `/api/v1/routes/`). Os sistemas dos estabelecimentos enviam suas leituras operacionais para a API de ingestão do backend.

O projeto foi criado com Flutter 3.47.5 e Dart 3.13.4 para **Android e iOS**. O identificador de pacote é `com.edufrancadev.rotasaude`. No Linux, é possível desenvolver e executar a versão Android; o build iOS depende de macOS e Xcode.

## Código atual

```text
mobile/lib/
├── main.dart                 entrada do processo e runApp
├── app.dart                  MaterialApp e configuração principal
├── screens/
│   ├── home_screen.dart      primeira entrada e estados da localização
│   ├── origin_selection_screen.dart  definição de origem por GPS ou ponto manual
│   ├── map_screen.dart       estado, consultas e navegação da descoberta
│   ├── discovery/            abas Mapa, Lista e Comparar e fluxo de localização
│   ├── location_selection_screen.dart  escolha de área de consulta
│   ├── manual_location_picker_screen.dart  ponto no mapa sem GPS
│   ├── unit_details_screen.dart  detalhes e dados indisponíveis da unidade
│   ├── route_preview_screen.dart  rota de carro no mapa e estados de falha
│   └── availability_screen.dart  explicação dos indicadores
├── models/
│   ├── health_unit.dart      áreas, unidade, leitura operacional e atualidade dos dados
│   ├── user_location_origin.dart  origem GPS ou manual para distâncias e rotas
│   └── driving_route.dart    rota de carro normalizada (distância, duração, polyline)
├── repositories/
│   ├── health_unit_repository.dart  cliente HTTP da API e erros tipados
│   ├── health_unit_parser.dart  JSON da API para o modelo do app
│   ├── route_repository.dart  cliente HTTP de `/api/v1/routes/`
│   └── route_parser.dart  GeoJSON LineString → pontos do mapa
├── services/
│   ├── api_config.dart       URL base (--dart-define) e timeout
│   ├── location_access.dart  acesso à localização do dispositivo
│   ├── location_onboarding_store.dart  guarda a primeira entrada e a cidade escolhida
│   ├── user_location_session_store.dart  persiste origem manual ou modo GPS
│   ├── straight_line_distance.dart  distância geográfica local (linha reta)
│   └── external_maps.dart   abertura do destino no app de mapas
├── widgets/
│   └── unit_ui.dart          indicadores, métricas e aviso ilustrativo
└── theme/
    ├── app_colors.dart       cores da marca
    └── app_theme.dart        tema Material 3
```

`main.dart` equivale ao ponto de entrada da aplicação. `RotaSaudeApp` é o widget raiz, semelhante ao componente raiz de um app React Native. `HomeScreen` é uma tela composta por widgets Flutter. O `ThemeData` centraliza cores e estilos compartilhados, em vez de espalhar valores por todas as telas.

A entrada oferece duas ações. **Usar minha localização** solicita permissão de primeiro plano e sugere uma cidade pela posição. **Escolher cidade** abre a Lista sem solicitar GPS. A cidade escolhida fica salva separadamente da origem no `shared_preferences`. Sessões anteriores que já haviam escolhido GPS ainda tentam restaurar a posição, sem interpor um bloqueio se ela estiver indisponível. A descoberta continua acessível ao perder a permissão ou desligar o serviço. Ao retomar o app, a atualização do GPS acontece em segundo plano. Se a leitura falhar, o app sinaliza que está usando a última posição conhecida.

`MapScreen` controla a cidade consultada, a busca, o filtro, a ordenação e até dois IDs de comparação. A seleção de um marcador é independente desses IDs. Trocar de cidade abre a Lista e mantém o ponto de partida. Cada aba guarda o enquadramento ou a rolagem enquanto a cidade é a mesma. O mapa usa `flutter_map` e OpenStreetMap. O pino central do seletor manual indica o ponto de partida. A integração atual não entrega bairro ou endereço para esse ponto.

### Integração com a API

`ApiHealthUnitRepository` usa o pacote `http` (já presente como dependência transitiva do `flutter_map`; declarado porque o app passou a usá-lo diretamente e porque oferece `Client` injetável e `MockClient` para testes). A URL base vem de `--dart-define=API_BASE_URL=...`; não há credenciais no app. Cada requisição tem timeout de 10 s. A paginação (`results`/`next`) é seguida até o fim, reaplicando cada `next` ao host configurado, porque o Django o monta com o `Host` da requisição, que pode ser um proxy ou túnel; há limite de páginas e detecção de ciclo. O corpo é decodificado como UTF-8, pois o DRF não declara charset. Falhas viram `HealthApiException` com `kind`: `connection`, `timeout`, `client` (4xx), `server` (5xx) ou `invalidResponse` (JSON inválido ou campo obrigatório ausente; o app não completa dados faltantes). `fetchUnit` e `fetchServices` estão implementados e testados, mas as telas ainda não os usam: a lista já traz o mesmo detalhe e o filtro de atendimento deriva das unidades carregadas.

`MapScreen` trata carregamento, falha (com “Tentar novamente” e mensagem por tipo de erro), cidade sem unidades, busca sem correspondência e filtro sem resultados. Resultados de consultas substituídas por uma troca de área são descartados.

### Atualidade dos dados operacionais

A API não define validade, então o app aplica uma janela (`operationalDataMaxAge`, 30 min; ajustável com `--dart-define=OPERATIONAL_MAX_AGE_MINUTES=...`). `HealthUnit.operationalState()` devolve `current`, `stale` (antiga, no futuro além de 5 min de tolerância, ou sem data válida) ou `missing` (sem leitura ou com todos os campos nulos). Somente `current` alimenta indicadores, espera, ordenação e marcadores; Ao vencer, a espera passa a “Espera sem atualização”; detalhes, comparação e rota mostram a hora da última leitura quando disponível. Quando falta uma estimativa em uma leitura atual ou a unidade não tem leitura, o app exibe “Espera sem estimativa”. A idade é calculada com o relógio do aparelho. `MapScreen` dispara `setState` a cada minuto para reavaliar a janela sem consultar o backend.

### Dados demonstrativos

O aviso ilustrativo só aparece quando a unidade ou a leitura vêm com `is_demo: true`. Os dados do `seed_demo_units` são marcados assim. Como o seed grava a leitura uma única vez, ela envelhece e passa a `stale`; para demonstrar dados atuais, envie uma nova leitura pela integração do backend.

### Localização, distâncias e rotas

O GPS e o ponto confirmado no mapa são origens opcionais. O app pede origem para ordenar por proximidade ou calcular deslocamentos. A distância em linha reta é calculada localmente por `Geolocator.distanceBetween()` e rotulada separadamente do trajeto. A ordenação por espera coloca estimativas atuais primeiro.

`RoutePreviewScreen` consulta `GET /api/v1/routes/?origin_lat=&origin_lon=&unit_id=&mode=driving`. Exibe o destino durante carregamento e falhas e mantém o endereço selecionável. O trajeto e a duração vêm do OSRM. A comparação consulta as unidades selecionadas em sequência, respeitando o intervalo padrão do provedor, e reaproveita os tempos calculados para a origem atual também nos cards. O provedor não entrega rotas de ônibus. A abertura externa usa o plugin Flutter `url_launcher` para repassar coordenadas ou endereço ao sistema. Se o sistema não abrir um aplicativo externo, o endereço permanece acessível.

### Rede em desenvolvimento

O manifesto de debug (`mobile/android/app/src/debug/AndroidManifest.xml`) habilita tráfego HTTP em texto claro para falar com o Django local; builds de release continuam exigindo HTTPS. Para iOS, o App Transport Security exigirá exceção ou HTTPS; isso não foi configurado nem verificado.

O cadastro lista os serviços da unidade. O backend não informa disponibilidade atual por serviço e aceita o nível de disponibilidade operacional enviado pela integração sem definir limites ou fórmula por nível. A legenda explica o indicador com essa distinção. Uma unidade pode ter rota mesmo sem leitura operacional.

## Identidade visual

As cores usadas em `AppColors` seguem o [JPG de referência da marca](../mobile/assets/brand/originais/rota-saude-jpg-colorido-fonte-da-verdade.jpeg): azul `#0D74C8`, verde água `#06A8AB` e azul escuro `#12466A`. Os valores são aproximações obtidas de um JPG comprimido. Os [SVGs da marca](../mobile/assets/brand/README.md) estão preservados como arquivos vetoriais. A tela inicial desenha a logo com `flutter_svg`, porque o Flutter não renderiza SVG sozinho.

## Evolução prevista

1. Usar `StatefulWidget` e `setState` para estado local simples. Avaliar outra solução apenas quando o fluxo mostrar uma necessidade concreta.
2. Evoluir transporte público e endereços de pontos manuais quando houver integrações que entreguem esses dados.
3. Atualizar os dados sem reabrir a tela (puxar para atualizar ou ao voltar ao app) e HTTPS/ATS para produção, quando solicitados.

## Desenvolvimento no celular

Com o dispositivo Android autorizado na depuração USB, execute a partir da raiz do repositório:

```bash
cd mobile
flutter doctor
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

No terminal do `flutter run`, `r` aplica Hot Reload, `R` reinicia o estado com Hot Restart e `q` encerra. Use `flutter analyze` após alterações de código. O `flutter doctor` pode apontar ferramentas de desktop Linux ausentes; elas não são necessárias para executar o app no Android.

## Organização dos materiais

- `docs/n1/`: apresentação e requisitos acadêmicos da N1.
- `mobile/assets/brand/originais/`: JPG de referência e SVG preto de origem.
- `mobile/assets/brand/svg/`: versões vetoriais da marca.
- `mobile/assets/brand/gerar_svg.py`: gerador reproduzível das versões SVG a partir do vetor original.

O `mobile/pubspec.lock` é mantido no repositório para fixar as dependências resolvidas do aplicativo. Artefatos de build, caches e arquivos locais do Android/iOS são ignorados pelo Git.
