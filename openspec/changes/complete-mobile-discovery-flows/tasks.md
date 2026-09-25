**Diretriz para o agente implementador:** executar esta mudança com **multiagente**, se houver suporte a agentes paralelos. A divisão é viável porque descoberta/localização, detalhes/legenda e comparação/rotas têm telas e testes próprios depois que o contrato comum for fixado. Usar um coordenador integrador e três frentes paralelas; não deixar agentes diferentes editar simultaneamente `lib/app.dart`, tema, modelos, fixtures, `pubspec.*` ou documentação compartilhada. Se o ambiente não oferecer multiagente, manter a mesma ordem de dependências em execução sequencial e registrar a limitação.

**Base de trabalho:** a base efetiva foi conferida em 25/09/2026 no checkout principal `/home/eduardo/Projects/pessoal/rotasaude`, branch `feat/mobile`. O checkout já continha alterações não commitadas de localização, mapa e onboarding; elas foram preservadas durante a continuação. Antes de começar, ler `AGENTS.md`, a skill `rotasaude-mobile`, as specs deste change e as imagens em `references/`; usar Impeccable em modo **Operate** para a revisão das telas. Nenhuma tarefa desta lista foi implementada por este planejamento.

**Execução desta aplicação:** as três frentes foram implementadas em sequência neste atendimento. O contrato e a divisão por arquivos foram mantidos, mas não houve handoff a agentes paralelos.

## 1. Fundação e contrato — coordenador, antes do paralelo

- [x] 1.1 Conferir `git status`, registrar a base efetiva e preservar onboarding, permissões, mapa e testes já alterados no checkout principal; confirmar que o app ainda abre no Android.
- [x] 1.2 Definir e disponibilizar modelos imutáveis, identificadores, disponibilidade anulável, áreas suportadas e catálogo local único com Centro, Sul, Norte e Oeste; verificar os valores das três primeiras e a ausência operacional de Oeste.
- [x] 1.3 Definir interfaces de entrada e retorno das telas (dados/callbacks ou rotas por `unitId`), estado único da exploração e propriedade de arquivos para as três frentes.
- [x] 1.4 Centralizar os tokens visuais recorrentes e a semântica dos quatro indicadores no tema, com texto acessível e aviso reutilizável de dados ilustrativos.

## 2. Frente A — descoberta e área de consulta

- [x] 2.1 Implementar a escolha manual de área com sugestões locais, validação, confirmação e retorno sem alteração; a permissão do aparelho continua obrigatória (`mobile/location-context`, referência 08).
- [x] 2.2 Evoluir o mapa existente com marcadores de unidade, seleção e resumo inferior; conservar atribuição OpenStreetMap, marcador do aparelho e acesso à lista se o mapa falhar (`mobile/unit-discovery`, referência 01).
- [x] 2.3 Implementar lista com seleção, busca, filtro de atendimento, ordenação, contagem e estado vazio; sincronizar critérios com o mapa pelo contrato comum (`mobile/unit-discovery`, referência 02).
- [x] 2.4 Criar testes focados da área manual, resultados combinados, seleção mapa↔lista, espera desconhecida na ordenação e ausência de unidades; manter os arquivos de teste exclusivos desta frente.

## 3. Frente B — detalhes e disponibilidade

- [x] 3.1 Implementar detalhes com dados demonstrativos disponíveis, serviços, cadastro opcional e entrada para a rota da mesma unidade (`mobile/unit-details`, referência 03).
- [x] 3.2 Implementar o estado “Dados temporariamente indisponíveis” sem números antigos, com serviços cadastrais, ressalva e retorno às unidades (`mobile/unit-details`, referência 07).
- [x] 3.3 Implementar tela “Disponibilidade” com quatro níveis textuais, significado operacional, ressalva clínica e retorno ao contexto (`mobile/availability-guidance`, referência 10).
- [x] 3.4 Criar testes focados para detalhes completos, campos ausentes, estado indisponível, leitor de tela/semântica dos níveis e preservação do `unitId`.

## 4. Frente C — comparação e prévias de rota

- [x] 4.1 Implementar comparação com cartões da mesma área/critério, valores rotulados, serviços, dados ausentes explícitos e alternância Carro↔Ônibus (`mobile/unit-comparison`, referências 04 e 09).
- [x] 4.2 Implementar prévia de carro específica da unidade, com esquema de trajeto local marcado “ilustrativo”, distância/tempo/descrição cadastrados e estado de rota ausente (`mobile/route-preview`, referência 05).
- [x] 4.3 Implementar prévia de ônibus com duração e etapas cadastradas, ação de retorno ao carro e ausência de rota explícita (`mobile/route-preview`, referência 06).
- [x] 4.4 Criar testes focados para troca de meio sem alterar destino, etiquetas corretas das métricas, passos de ônibus e campos não cadastrados.

## 5. Integração, revisão e entrega — coordenador

- [x] 5.1 Integrar as frentes no shell e na navegação inferior sem sobrepor alterações não commitadas; verificar abertura de detalhes a partir de mapa, lista e comparação, retorno com contexto e rota da unidade correta.
- [x] 5.2 Confirmar que retirar permissão ou desligar o serviço bloqueia qualquer tela, inclusive após escolha manual, e que retornar dos ajustes preserva a sessão (`mobile/location-context`).
- [x] 5.3 Revisar os dez estados visuais únicos contra `references/` em Android, com `SafeArea`, texto ampliado, teclado, rolagem, contraste, alvos de toque e redução de movimento; corrigir os defeitos materiais em lote e confirmar uma vez.
- [x] 5.4 Garantir aviso visível “Dados ilustrativos” em cada superfície de dados, ausência de atualização falsa e nenhuma rota ou recomendação apresentada como informação clínica ou em tempo real.
- [x] 5.5 Atualizar `docs/arquitetura-mobile.md` para a estrutura e decisões realmente implementadas; atualizar `README.md` somente se execução ou uso mudarem.
- [x] 5.6 Executar `dart format --output=none --set-exit-if-changed lib`, `flutter analyze` e os testes focados; validar os fluxos no Android físico quando disponível e relatar a limitação do build iOS neste Linux.

**Confirmação final após revisão (25/09/2026):** a revisão independente encontrou três defeitos P2: não era possível fechar a busca vazia na lista/comparação, o marcador não expunha o estado selecionado à semântica, e a nova tentativa de localização ainda podia mostrar o erro anterior enquanto aguardava. Os três foram corrigidos e cobertos por testes. `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` e `flutter test` passaram (24 testes). `flutter build apk --debug` passou; o APK atualizado foi instalado e aberto no Android físico SM-S721B. O build iOS não foi executado porque este ambiente é Linux e não dispõe de Xcode.

**Avaliação multiagente:** as frentes de implementação A/B/C são paralelizáveis depois de fixados os modelos, contratos e propriedade dos arquivos compartilhados, como descrito acima. A implementação dessas frentes já havia sido feita sequencialmente antes desta retomada. Nesta retomada, um agente separado fez revisão independente; como 1.1, 5.3 e 5.6 são tarefas de coordenação e verificação, as correções e a integração final ficaram centralizadas.
