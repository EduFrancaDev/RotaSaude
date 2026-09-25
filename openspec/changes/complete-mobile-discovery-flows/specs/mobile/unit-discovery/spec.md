## Purpose

Permitir encontrar unidades públicas do conjunto demonstrativo por mapa ou lista e entender as diferenças relevantes antes de escolher uma.

## ADDED Requirements

### Requirement: Mapa e lista compartilham o mesmo conjunto de unidades
O aplicativo SHALL apresentar as abas “Mapa”, “Lista” e “Comparar” com a mesma área de consulta e o mesmo conjunto local de unidades. Mapa e lista SHALL mostrar nome, distância demonstrativa quando disponível e disponibilidade textual; o mapa SHALL distinguir posição do aparelho e marcadores de unidades. A troca de aba SHALL preservar área, unidade selecionada, filtro e busca aplicáveis.

#### Scenario: Alternância entre mapa e lista
- **WHEN** uma unidade é selecionada no mapa e a pessoa abre a lista
- **THEN** a mesma unidade aparece selecionada na lista e os resultados correspondem à mesma área

#### Scenario: Unidade selecionada no mapa
- **WHEN** a pessoa toca no marcador de uma unidade
- **THEN** surge um resumo com nome, disponibilidade, espera, distância, tempo de carro, aviso de dados ilustrativos e ação “Ver detalhes”

### Requirement: Busca, filtro e ordenação afetam os resultados
O aplicativo SHALL permitir buscar por nome de unidade, filtrar pelos atendimentos cadastrados e ordenar a lista, incluindo “Menor espera”. Critérios SHALL ser combinados e aplicados de modo consistente às unidades visíveis no mapa e na lista; uma unidade sem espera disponível SHALL NOT ser tratada como se tivesse espera zero.

#### Scenario: Busca e filtro com resultados
- **WHEN** a pessoa informa parte do nome e escolhe um atendimento
- **THEN** mapa e lista exibem apenas unidades que satisfazem ambos os critérios e informam a quantidade resultante

#### Scenario: Nenhum resultado
- **WHEN** busca e filtros não encontram unidades
- **THEN** o aplicativo explica que nenhum resultado atende aos critérios e oferece uma forma de limpá-los

#### Scenario: Ordenação por menor espera
- **WHEN** a pessoa escolhe “Menor espera”
- **THEN** unidades com espera conhecida aparecem em ordem crescente e unidades sem esse dado ficam separadas ao final

### Requirement: Estado demonstrativo é inequívoco
Todas as unidades, distâncias, esperas, disponibilidades e tempos do catálogo local SHALL ser identificados como dados ilustrativos nas superfícies em que aparecem. O aplicativo SHALL NOT apresentar hora de atualização simulada como atualização real ou usar os valores para recomendação clínica.

#### Scenario: Consulta de unidades demonstrativas
- **WHEN** a pessoa visualiza mapa, lista ou resumo de unidade
- **THEN** há aviso legível de que os dados são ilustrativos, sem depender apenas de cor ou ícone

### Requirement: A interface trata ausência de unidades e falha de mapa
O aplicativo SHALL mostrar um estado vazio quando a área selecionada não tiver unidades demonstrativas. Caso os blocos do mapa não carreguem, SHALL manter acesso à lista e às informações textuais, sem atribuir a falha à disponibilidade das unidades.

#### Scenario: Área sem unidades
- **WHEN** não há unidades no catálogo para a área escolhida
- **THEN** o mapa e a lista apresentam estado vazio e a comparação não mostra cartões inventados

#### Scenario: Mapa indisponível
- **WHEN** os blocos do mapa falham ou não há conexão
- **THEN** a pessoa ainda consegue abrir a lista e os detalhes das unidades locais
