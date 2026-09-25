## Purpose

Permitir que a pessoa consulte outra área sem perder a proteção de localização obrigatória já existente no aplicativo móvel.

## ADDED Requirements

### Requirement: A localização do aparelho continua obrigatória
O aplicativo SHALL manter permissão de localização em primeiro plano e serviço do aparelho habilitados para entrar e permanecer nos fluxos de unidades, inclusive após escolher uma cidade manualmente. A escolha manual SHALL NOT solicitar uma permissão adicional nem liberar um estado bloqueado.

#### Scenario: Permissão negada antes da escolha manual
- **WHEN** a permissão do aparelho é negada ou bloqueada
- **THEN** o aplicativo apresenta o fluxo de permissão existente e não abre a consulta por cidade manual

#### Scenario: Permissão retirada durante a consulta manual
- **WHEN** a pessoa está consultando uma cidade escolhida e a permissão ou o serviço é desativado
- **THEN** o bloqueio de localização existente cobre o fluxo até o acesso voltar, sem apagar a escolha manual da sessão

### Requirement: Escolha de área de consulta
O aplicativo SHALL oferecer a tela “Escolher localização” a partir do local exibido no mapa. A tela SHALL permitir selecionar apenas cidades ou endereços presentes no catálogo local do protótipo, mostrar sugestões identificáveis e confirmar a área escolhida antes de atualizar mapa, lista e comparação. Texto livre sem correspondência SHALL NOT gerar resultados fictícios.

#### Scenario: Seleção de sugestão conhecida
- **WHEN** a pessoa escolhe uma sugestão e confirma “Ver unidades em <cidade>”
- **THEN** a área exibida e os resultados passam a refletir essa escolha em todas as abas

#### Scenario: Endereço não reconhecido
- **WHEN** o texto digitado não corresponde a uma sugestão suportada
- **THEN** a tela informa que o local não está disponível no protótipo e mantém a confirmação desabilitada

#### Scenario: Voltar sem confirmar
- **WHEN** a pessoa volta da tela antes de confirmar
- **THEN** a área e os resultados anteriores permanecem selecionados

### Requirement: Contexto da localização é compreensível
O aplicativo SHALL distinguir visual e textualmente a posição autorizada do aparelho da área escolhida para consulta. A escolha manual SHALL permanecer disponível durante a sessão e SHALL poder ser alterada novamente.

#### Scenario: Área manual ativa
- **WHEN** uma cidade manual está ativa
- **THEN** o cabeçalho mostra essa cidade e o marcador do aparelho, se exibido, continua identificado como posição do dispositivo
