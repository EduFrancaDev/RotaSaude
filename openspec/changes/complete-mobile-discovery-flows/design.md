## Context

Ver [proposal.md](proposal.md) e as seis specs em `specs/mobile/`. O checkout principal já contém alterações **não commitadas** de onboarding de localização, bloqueio por permissão e `MapScreen` com `flutter_map`; elas são trabalho em andamento e constituem a base real deste plano. O checkout desta tarefa em `~/.codex/worktrees/aaa1/rotasaude` está no commit inicial e não representa o estado do app. Antes de implementar, o agente coordenador deve partir do checkout principal ou transportar conscientemente essas alterações; não restaurar arquivos para o commit antigo.

O app é Flutter/Dart para Android e iOS; `AGENTS.md`, `docs/arquitetura-mobile.md`, `assets/brand/README.md` e a skill `rotasaude-mobile` orientam a implementação. As imagens em `references/` são referência de **estrutura, hierarquia e conteúdo**, não um pedido para desenhar barra de status falsa, usar valores clínicos reais ou trocar a paleta da marca.

| Referência | Superfície/estado |
| --- | --- |
| [01-mapa-resumo](references/01-mapa-resumo.png) | Mapa, busca, marcadores, resumo e abas |
| [02-lista](references/02-lista.png) | Lista, filtro, ordenação e seleção |
| [03-detalhes](references/03-detalhes.png) | Detalhes com dados disponíveis |
| [04-comparar-carro](references/04-comparar-carro.png) | Comparação por carro |
| [05-rota-carro](references/05-rota-carro.png) | Prévia de carro |
| [06-rota-onibus](references/06-rota-onibus.png) | Prévia de ônibus |
| [07-dados-indisponiveis](references/07-dados-indisponiveis.png) | Detalhes sem dados operacionais |
| [08-localizacao-manual](references/08-localizacao-manual.png) | Escolha manual de área |
| [09-comparar-onibus](references/09-comparar-onibus.png) | Comparação por ônibus; a 10ª imagem enviada era duplicata desta |
| [10-disponibilidade](references/10-disponibilidade.png) | Explicação dos indicadores |

## Goals / Non-Goals

**Goals:** uma jornada demonstrável entre as dez referências, dados coerentes ao trocar de tela, permissão atual preservada, UI nativa legível e marca existente respeitada. A experiência serve para apoiar uma escolha informada no modo **Operate** do Impeccable: números escaneáveis, rótulos explícitos e ação principal clara por tela.

**Non-Goals:** integrar sistemas de saúde, calcular disponibilidade, consultar tráfego ou transporte em tempo real, geocodificar texto livre, navegar por GPS, enviar o usuário a um app de mapas ou alterar a política de localização obrigatória. Não prometer que um trajeto demonstrativo liga a posição real do usuário à unidade.

## Decisions

### 1. Contrato compartilhado antes das telas

Criar um modelo imutável de área e unidade com identificador estável, nome, endereço, coordenadas de demonstração, serviços, horário e telefone opcionais; um bloco operacional anulável com disponibilidade, espera, fila e eventual referência de atualização **de exemplo**; e prévias de deslocamento opcionais por meio. “Sem dados operacionais” é um estado próprio, não `0 min`, nem um quarto nível de disponibilidade. Os rótulos dos quatro níveis ficam em um único lugar. Alternativa rejeitada: mapas de valores soltos em cada widget, que fariam lista, detalhes e comparação divergir.

Um catálogo local determinístico contém Centro, Sul e Norte com os valores da referência (espera 20/40/65 min, carro 14/9/7 min, ônibus 29/24/18 min, distância 5,8/3,2/2,1 km) e Oeste como caso de dados operacionais ausentes. O catálogo pode incluir apenas endereços e serviços claramente demonstrativos, sem inferir que as UPAs “Exemplo” existem. A quarta unidade aparece na descoberta para que o estado de indisponibilidade seja alcançável; por isso a contagem da lista pode diferir do “3 unidades” da imagem. Goiânia é a área com fixtures; Aparecida de Goiânia pode ser sugestão sem unidades, acionando o estado vazio. Nenhum timestamp é atualizado artificialmente ao abrir a tela.

### 2. Uma fonte de estado para a exploração

Uma camada leve no topo da jornada mantém área consultada, unidade selecionada, aba, busca, filtro, ordenação e meio de comparação. Estado local simples em Flutter é suficiente; preferir `StatefulWidget`/`setState` ou um controlador pequeno se a passagem por telas ficar confusa. Não adicionar gerenciador global ou roteador como prevenção abstrata. O agente integrador é dono desse contrato e de `lib/app.dart`; as telas recebem dados e callbacks claros. Ações de detalhe e rota usam `unitId`, evitando cópias da unidade.

A seleção manual apenas troca a **área de consulta**. O marcador “Você” representa o aparelho e nunca a cidade escolhida. Fora da região coberta pelas fixtures, a posição do aparelho leva a estado vazio com convite para escolher Goiânia; não chamar unidades distantes de “próximas”. A seleção manual dura a sessão, sem novo armazenamento de coordenadas. O bloqueio existente continua acima de todas as telas quando permissão ou serviço desaparecem.

### 3. Mapa real para descoberta; esquema para rota

Reaproveitar `flutter_map` e sua atribuição OpenStreetMap no mapa principal. Marcadores de unidades usam coordenadas do catálogo e ícones/legendas textuais; busca e filtro alteram os marcadores visíveis. Falha no carregamento dos blocos não impede abrir a lista. A rota das referências deve ser um esquema demonstrativo local, com legenda “Trajeto ilustrativo”, e não uma polyline sobre ruas reais fingindo cálculo a partir do GPS. Alternativa rejeitada: adicionar API de roteamento ou desenhar um percurso inventado no OpenStreetMap como se fosse real.

### 4. Linguagem visual e estados

Conservar a paleta do JPG de `assets/brand/` e os tokens já em `lib/theme/`; acrescentar apenas tokens recorrentes necessários para superfícies claras, bordas, foco e indicadores. As cores operacionais seguem os quatro níveis documentados no N1, sempre acompanhadas do texto. Usar barra de status real do sistema, `SafeArea`, navegação inferior nativa, folhas/cartões com boa hierarquia e alvos de pelo menos 48 dp. A imagem fixa em 388×848 é referência, não dimensão rígida: rolagem, teclado e escala de fonte devem funcionar em telas menores e com texto ampliado. Reduzir animações se o sistema pedir.

O aviso “Dados ilustrativos” precisa estar visível em mapa/resumo, lista, comparação, detalhes e rotas; não depender de uma nota escondida. Não usar “Atualizado há 2 min” sozinho, porque a fixture não é uma atualização real. Para a página de indisponibilidade, manter cadastro e serviços úteis, mas retirar espera, fila e status operacional. Ao navegar, mostrar estados de carregamento apenas onde houver operação assíncrona real (posição e blocos do mapa); o catálogo local não precisa de spinner fictício.

### 5. Verificação por contrato e por fluxo

Testes focados devem cobrir a permanência do bloqueio, o mesmo `unitId` em mapa/lista/detalhes/rota, filtros combinados, alternância carro/ônibus, dados ausentes e área sem fixtures. Revisão visual limitada em Android deve comparar todos os estados únicos com `references/`, primeiro em tela de telefone e, se disponível, em largura menor ou texto ampliado; corrigir problemas materiais em um lote e confirmar uma vez. `dart format`, `flutter analyze` e testes de widget encerram a validação. iOS precisa de macOS/Xcode para build.

## Risks / Trade-offs

- **O protótipo parecer serviço em tempo real** → repetir identificação de dados ilustrativos, nunca usar atualização artificial e mostrar indisponibilidade como ausência.
- **Localização manual ser confundida com substituta da permissão** → manter o bloqueio no topo, distinguir dispositivo de área de consulta e testar retirada de permissão em qualquer tela.
- **Divergência visual entre agentes** → contrato de dados, tokens e navegação definidos antes da divisão; um integrador controla arquivos compartilhados e revisa as telas juntas.
- **Comparação enganosa por campos vazios** → representar ausência explicitamente e ordenar espera desconhecida após esperas conhecidas.
- **Mapa/rota não funcionarem offline** → lista local permanece acessível; rotas são esquemas locais e não dependem dos blocos do mapa.

## Migration Plan

1. Preservar alterações não commitadas do checkout principal e registrar a base de implementação.
2. Fixar modelos, fixtures, estado, interfaces de navegação e tokens compartilhados em um primeiro lote integrador.
3. Implementar as três frentes independentes descritas em `tasks.md`, com arquivos exclusivos.
4. Integrar no shell, revisar fluxos completos, atualizar `docs/arquitetura-mobile.md` e validar no Android. Nenhuma migração de dados remotos é necessária; a escolha manual pode permanecer apenas em memória.
