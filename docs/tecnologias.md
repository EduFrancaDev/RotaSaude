# Tecnologias do RotaSaúde

## Estado do projeto

Esta documentação registra as ferramentas apresentadas na etapa N1 e o papel previsto para cada tecnologia. Os protótipos foram desenhados no Figma. A base do aplicativo Flutter/Dart foi iniciada; backend, dados, mapas e infraestrutura continuam **planejados** e não são implementados neste repositório. Os dados e tempos exibidos nos protótipos são ilustrativos.

Fonte: [apresentação visual N1](n1/RotaSaude_N1_apresentacao_visual_final.pdf), especialmente as páginas 6, 10 a 15.

## Tecnologias

| Camada | Tecnologia | Papel no projeto | Estado |
| --- | --- | --- | --- |
| Prototipação | Figma | Desenho das telas e dos fluxos de localização, listagem, comparação, indicador e ausência de dados. | Protótipos apresentados na N1 |
| Aplicativo móvel | Flutter e Dart | Aplicativo para Android e iOS; mapa, detalhes das unidades, comparação e rotas serão implementados por etapas. | Base iniciada |
| API e backend | Python, Django e Django REST Framework | Receber dados agregados das unidades, padronizá-los e oferecer consultas ao aplicativo. | Planejado |
| Banco de dados | PostgreSQL e PostGIS | Armazenar dados das unidades e permitir consultas por localização. | Planejado |
| Processamento em segundo plano | Redis, Celery e Celery Beat | Executar tarefas e atualizações periódicas dos dados e indicadores. | Planejado |
| Mapas e rotas | Google Maps e Routes | Exibir mapas e calcular deslocamentos de carro e transporte público. | Planejado |
| Execução e infraestrutura | Docker, Nginx e Uvicorn/ASGI | Empacotar e executar os serviços, receber requisições e servir a aplicação backend. | Planejado |

Nenhuma versão, configuração de hospedagem ou contrato de API foi definida na apresentação N1.

## Como os componentes se relacionam

1. Os sistemas das unidades de saúde fornecem cadastro, horários, serviços e dados **agregados** de fila e operação.
2. A API RotaSaúde recebe e padroniza esses dados, registrando a hora da última atualização.
3. O processamento calcula uma estimativa de espera e um indicador de disponibilidade. A apresentação propõe considerar pessoas aguardando, classificação de risco, ritmo recente de atendimentos e capacidade informada pela unidade; a fórmula ainda precisa ser definida e calibrada.
4. O aplicativo consulta unidades, serviços, situação e rotas e mostra quando os dados foram atualizados.

```text
Sistemas das unidades → API e processamento → Banco de dados → Aplicativo
                                      ↘ Mapas e rotas ↗
```

## Recursos do celular e privacidade

- **Localização:** depende de permissão; também deve existir entrada manual do local.
- **Internet:** necessária para apresentar disponibilidade e condições de viagem como atuais. Quando os dados não estiverem disponíveis, o aplicativo deve avisar o usuário.
- **Acessibilidade:** requisito transversal da interface e dos fluxos.
- **Notificações:** opcionais. Câmera, microfone, arquivos e biometria não fazem parte do MVP descrito na N1.
- **Dados pessoais:** a proposta não requer prontuário, CPF ou diagnóstico. A localização do usuário é temporária, conforme a apresentação.

## Limite do MVP

O MVP proposto usa poucas unidades e dados operacionais simulados para demonstrar mapa, localização, serviços, disponibilidade, espera aproximada, comparação e rotas de carro e ônibus. Para uso com dados reais, será necessário confirmar o acesso a informações confiáveis das instituições, definir as integrações e calibrar o indicador de disponibilidade.
