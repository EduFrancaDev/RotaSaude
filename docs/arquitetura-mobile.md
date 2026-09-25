# Arquitetura inicial do aplicativo

## Escopo

Este repositório implementa somente o aplicativo Flutter/Dart. Sistemas das unidades, API, banco de dados e cálculo do indicador pertencem a integrações externas. O app poderá consumir uma API no futuro, mas não implementa o backend.

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
│   └── demo_health_unit.dart  áreas, unidades e dados locais ilustrativos
├── services/
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

`MapScreen` mantém a área consultada, unidade selecionada, busca, filtro, ordenação, meio de transporte e as abas Mapa/Lista/Comparar. O mapa usa `flutter_map` e blocos do OpenStreetMap, com atribuição visível; a lista e os dados locais continuam acessíveis se os blocos falharem. `DemoHealthUnits` contém dados determinísticos para Goiânia e mantém Aparecida de Goiânia como sugestão sem resultados. Os nomes, endereços, espera, disponibilidade, distâncias e deslocamentos com “Exemplo” são demonstrativos, com aviso visível. A escolha manual muda apenas a área consultada e não substitui a permissão obrigatória do aparelho.

Os detalhes preservam a unidade de origem e ocultam espera e disponibilidade quando os dados operacionais estão ausentes. `AvailabilityScreen` explica os quatro níveis textuais e a ressalva clínica. As telas de rota desenham um esquema local marcado como ilustrativo; não calculam trajeto, trânsito ou transporte em tempo real.

## Identidade visual

As cores usadas em `AppColors` seguem o [JPG de referência da marca](../assets/brand/originais/rota-saude-jpg-colorido-fonte-da-verdade.jpeg): azul `#0D74C8`, verde água `#06A8AB` e azul escuro `#12466A`. Os valores são aproximações obtidas de um JPG comprimido. Os [SVGs da marca](../assets/brand/README.md) estão preservados como arquivos vetoriais. A tela inicial desenha a logo com `flutter_svg`, porque o Flutter não renderiza SVG sozinho.

## Evolução prevista

1. Substituir as fixtures por uma fonte de dados definida quando integração real for solicitada e acordada.
2. Manter serviços/repositórios fora dos widgets se a fonte de dados passar a ser assíncrona.
3. Usar `StatefulWidget` e `setState` para estado local simples. Avaliar outra solução apenas quando o fluxo mostrar uma necessidade concreta.
4. Implementar roteamento real somente quando houver provedor e contrato definidos; as telas atuais são demonstrações locais.

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
