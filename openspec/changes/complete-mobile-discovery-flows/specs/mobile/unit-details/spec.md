## Purpose

Exibir informações de cada unidade e deixar evidente quando faltarem dados operacionais recentes, sem esconder dados cadastrais úteis.

## ADDED Requirements

### Requirement: Detalhes de unidade com dados operacionais disponíveis
A tela “Detalhes da unidade” SHALL mostrar nome, endereço, disponibilidade textual, espera estimada, número aguardando quando existente, distância, serviços cadastrados, funcionamento e telefone quando cadastrados. Estimativas SHALL vir acompanhadas de aviso de que podem mudar e de que, neste protótipo, são ilustrativas. A ação de rota SHALL referir-se à unidade exibida.

#### Scenario: Abrir unidade com dados completos
- **WHEN** a pessoa abre uma unidade com dados operacionais demonstrativos
- **THEN** todos os campos disponíveis são rotulados corretamente, serviços são legíveis e “Ver opções de rota” abre essa mesma unidade

#### Scenario: Campo cadastral ausente
- **WHEN** telefone ou funcionamento não estão cadastrados
- **THEN** a tela indica a ausência ou omite o campo sem fabricar um valor

### Requirement: Dados operacionais indisponíveis não parecem atuais
Se uma unidade não tiver dados operacionais utilizáveis, a tela SHALL mostrar “Dados temporariamente indisponíveis” e explicar que não há informação recente. Espera, fila e indicador de disponibilidade SHALL NOT ser mostrados a partir de registros antigos como se fossem atuais; serviços cadastrais podem continuar visíveis com ressalva. A tela SHALL oferecer “Ver outras unidades”.

#### Scenario: Unidade sem dados recentes
- **WHEN** a pessoa abre uma unidade com cadastro, mas sem dados operacionais utilizáveis
- **THEN** não aparecem números de espera, fila ou estado de disponibilidade e a tela mostra os serviços cadastrados e o aviso de confirmação direta

#### Scenario: Ver outras unidades
- **WHEN** a pessoa toca “Ver outras unidades”
- **THEN** retorna à exploração na área selecionada sem perder filtros e busca

### Requirement: Caminho de retorno preserva contexto
A navegação de volta SHALL retornar à aba, área e seleção de origem, sem criar cópias divergentes da unidade.

#### Scenario: Voltar após abrir pela lista
- **WHEN** a pessoa abre detalhes pela lista e retorna
- **THEN** a lista reaparece na posição e com os critérios anteriores
