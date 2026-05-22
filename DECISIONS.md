# DECISIONS — TRINIUM SPORTS

## Decisão
Abandonar temporariamente o fluxo centrado no motor automático como núcleo do MVP.

## Motivo
A complexidade do motor estava travando a evolução do produto e dificultando a entrega do fluxo principal ao usuário final.

## Nova decisão
O MVP passa a ser centrado em:
- conexão atleta ↔ profissional
- criação manual de treinos
- revisão/publicação
- agenda e acompanhamento
- sincronização futura com relógios

## Decisão estrutural
Os steps do treino devem ser armazenados já em formato suficientemente estruturado para futura exportação para relógios.

## Decisão de dados
A base deve suportar dois sentidos:
1. envio do treino estruturado para relógio
2. retorno do realizado pelo atleta para alimentar a base

## Resultado
A arquitetura atual do MVP ficou mais simples, mais rastreável e mais alinhada com a operação real de treinadores.
