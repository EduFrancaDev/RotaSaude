# Arquitetura inicial do aplicativo

## Escopo

Este repositório implementa somente o aplicativo Flutter/Dart. Sistemas das unidades, API, banco de dados e cálculo do indicador pertencem a integrações externas. O app consome a API Django de leitura (`/api/v1/units/`, `/api/v1/units/{id}/` e `/api/v1/services/`), mas não implementa o backend nem usa a API de ingestão, exclusiva dos estabelecimentos.

O projeto foi criado com Flutter 3.47.5 e Dart 3.13.4 para **Android e iOS**. O identificador de pacote é `com.edufrancadev.rotasaude`. No Linux, é possível desenvolver e executar a versão Android; o build iOS depende de macOS e Xcode.

## Código atual

```text
lib/
├── main.dart                 entrada do processo e runApp
├── app.dart                  MaterialApp e configuração principal
├── screens/
│   ├── home_screen.dart      primeira entrada e estados da localização
│   ├── location_required_screen.dart  bloqueio se a localização for desligada
│   ├── map_screen.dart       exploração em mapa, lista e comparação
│   ├── location_selection_screen.dart  escolha de área de consulta
│   ├── unit_details_screen.dart  detalhes e dados indisponíveis da unidade
│   ├── route_preview_screen.dart  prévias ilustrativas por transporte
│   └── availability_screen.dart  explicação dos indicadores
├── models/
│   └── health_unit.dart      áreas, unidade, leitura operacional e atualidade dos dados
├── repositories/
│   ├── health_unit_repository.dart  cliente HTTP da API e erros tipados
│   └── health_unit_parser.dart  JSON da API para o modelo do app
├── services/
│   ├── api_config.dart       URL base (--dart-define) e timeout
│   ├── location_access.dart  acesso à localização do dispositivo
│   └── location_onboarding_store.dart  lembra a primeira aceitação
├── widgets/
│   └── unit_ui.dart          indicadores, métricas e aviso ilustrativo
└── theme/
    ├── app_colors.dart       cores da marca
    └── app_theme.dart        tema Material 3
```

`main.dart` equivale ao ponto de entrada da aplicação. `RotaSaudeApp` é o widget raiz, semelhante ao componente raiz de um app React Native. `HomeScreen` é uma tela composta por widgets Flutter. O `ThemeData` centraliza cores e estilos compartilhados, em vez de espalhar valores por todas as telas.

A tela inicial aparece só na primeira entrada e pede a localização após o toque no botão. Quando a pessoa aceita e o mapa abre, essa escolha fica gravada com `shared_preferences`. Nas próximas aberturas o app vai direto ao mapa. Se a permissão for desligada ou o serviço de localização estiver desativado, `LocationRequiredScreen` cobre qualquer tela até o acesso voltar. `HomeScreen` verifica permissão e serviço separadamente, trata negação, bloqueio, serviço desligado e falha de posição e reavalia os estados ao voltar dos ajustes. `LocationAccess` isola o plugin `geolocator` para testar o fluxo sem depender do aparelho. A permissão solicitada é apenas de uso em primeiro plano. A entrada no mapa usa uma revelação circular a partir do botão, omitida quando o sistema pede redução de movimento.

`MapScreen` mantém a área consultada, unidade selecionada, busca, filtro, ordenação, meio de transporte e as abas Mapa/Lista/Comparar. O mapa usa `flutter_map` e blocos do OpenStreetMap, com atribuição visível. As unidades vêm de um `HealthUnitRepository` (a API por padrão; os testes injetam um simulado) e são consultadas por `?city=` da área escolhida, sempre que a área muda. A escolha manual muda apenas a área consultada e não substitui a permissão obrigatória do aparelho.

### Integração com a API

`ApiHealthUnitRepository` usa o pacote `http` (já presente como dependência transitiva do `flutter_map`; declarado porque o app passou a usá-lo diretamente e porque oferece `Client` injetável e `MockClient` para testes). A URL base vem de `--dart-define=API_BASE_URL=...`; não há credenciais no app. Cada requisição tem timeout de 10 s. A paginação (`results`/`next`) é seguida até o fim, reaplicando cada `next` ao host configurado, porque o Django o monta com o `Host` da requisição, que pode ser um proxy ou túnel; há limite de páginas e detecção de ciclo. O corpo é decodificado como UTF-8, pois o DRF não declara charset. Falhas viram `HealthApiException` com `kind`: `connection`, `timeout`, `client` (4xx), `server` (5xx) ou `invalidResponse` (JSON inválido ou campo obrigatório ausente; o app não completa dados faltantes). `fetchUnit` e `fetchServices` estão implementados e testados, mas as telas ainda não os usam: a lista já traz o mesmo detalhe e o filtro de atendimento deriva das unidades carregadas.

`MapScreen` trata carregamento, falha (com “Tentar novamente” e mensagem por tipo de erro), lista vazia da API e lista vazia por filtro. Resultados de consultas substituídas por uma troca de área são descartados.

### Atualidade dos dados operacionais

A API não define validade, então o app aplica uma janela (`operationalDataMaxAge`, 30 min; ajustável com `--dart-define=OPERATIONAL_MAX_AGE_MINUTES=...`). `HealthUnit.operationalState()` devolve `current`, `stale` (antiga, no futuro além de 5 min de tolerância, ou sem data válida) ou `missing` (sem leitura ou com todos os campos nulos). Somente `current` alimenta indicadores, espera, ordenação e marcadores; `stale` mostra “Dados desatualizados” e, nos detalhes, a hora da última atualização; `missing` mostra “Dados operacionais indisponíveis”. A idade é calculada com o relógio do aparelho a cada construção da tela; a tela não se atualiza sozinha enquanto está aberta.

### Dados demonstrativos

O aviso ilustrativo só aparece quando a unidade ou a leitura vêm com `is_demo: true`. Os dados do `seed_demo_units` são marcados assim. Como o seed grava a leitura uma única vez, ela envelhece e passa a `stale`; para demonstrar dados atuais, envie uma nova leitura pela integração do backend.

### Localização, distâncias e rotas

A localização do aparelho é mantida como antes. A API não fornece distância nem rota, e o app ainda não tem provedor de roteamento: `distanceKm`, `carRoute` e `busRoute` ficam nulos, as telas mostram “— km”/“Indisponível” e a tela de rota informa que o cálculo não está disponível. Os tempos e trajetos de exemplo das fixtures anteriores foram removidos de `lib/`.

### Rede em desenvolvimento

O manifesto de debug (`android/app/src/debug/AndroidManifest.xml`) habilita tráfego HTTP em texto claro para falar com o Django local; builds de release continuam exigindo HTTPS. Para iOS, o App Transport Security exigirá exceção ou HTTPS; isso não foi configurado nem verificado.

Os detalhes preservam a unidade de origem e ocultam espera e disponibilidade quando os dados operacionais estão ausentes. `AvailabilityScreen` explica os quatro níveis textuais e a ressalva clínica. As telas de rota desenham um esquema local marcado como ilustrativo; não calculam trajeto, trânsito ou transporte em tempo real.

## Identidade visual

As cores usadas em `AppColors` seguem o [JPG de referência da marca](../assets/brand/originais/rota-saude-jpg-colorido-fonte-da-verdade.jpeg): azul `#0D74C8`, verde água `#06A8AB` e azul escuro `#12466A`. Os valores são aproximações obtidas de um JPG comprimido. Os [SVGs da marca](../assets/brand/README.md) estão preservados como arquivos vetoriais. A tela inicial desenha a logo com `flutter_svg`, porque o Flutter não renderiza SVG sozinho.

## Evolução prevista

1. Usar `StatefulWidget` e `setState` para estado local simples. Avaliar outra solução apenas quando o fluxo mostrar uma necessidade concreta.
2. Implementar roteamento e distância reais somente quando houver provedor e contrato definidos; hoje não há cálculo e o conteúdo de `UnitRoutePreview` só é exibido se alguma fonte o preencher.
3. Atualizar os dados sem reabrir a tela (puxar para atualizar ou ao voltar ao app) e HTTPS/ATS para produção, quando solicitados.

## Desenvolvimento no celular

Com o dispositivo Android autorizado na depuração USB:

```bash
flutter doctor
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

No terminal do `flutter run`, `r` aplica Hot Reload, `R` reinicia o estado com Hot Restart e `q` encerra. Use `flutter analyze` após alterações de código. O `flutter doctor` pode apontar ferramentas de desktop Linux ausentes; elas não são necessárias para executar o app no Android.

## Organização dos materiais

- `docs/n1/`: apresentação e requisitos acadêmicos da N1.
- `assets/brand/originais/`: JPG de referência e SVG preto de origem.
- `assets/brand/svg/`: versões vetoriais da marca.
- `assets/brand/gerar_svg.py`: gerador reproduzível das versões SVG a partir do vetor original.

O `pubspec.lock` é mantido no repositório para fixar as dependências resolvidas do aplicativo. Artefatos de build, caches e arquivos locais do Android/iOS são ignorados pelo Git.
