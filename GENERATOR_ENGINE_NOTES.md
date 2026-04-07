# GENERATOR_ENGINE_NOTES

## Objetivo do motor
O motor de geração do TRINIUM é peça central do produto.

Seu papel é:
- aumentar produtividade de treinadores com muitos atletas
- respeitar contexto do atleta
- respeitar nível esportivo
- respeitar disponibilidade e restrições
- reduzir pontos cegos da periodização
- funcionar como agente de apoio à decisão do treinador

---

## Estado atual do motor

### Já faz
- gera plano com sucesso
- usa prova alvo
- usa categoria da prova
- usa nível / fitness level
- usa base de periodização
- usa weekly patterns
- usa workout templates

### Limitação atual
- gera por uma prova por execução
- ainda não é calendar-aware
- ainda não integra o calendário completo do atleta como conjunto

---

## Consequência prática da limitação atual
- o atleta pode ter várias provas no calendário
- mas o motor organiza o plano olhando uma prova por vez
- isso limita a qualidade da periodização em calendários com múltiplos objetivos

---

## Problema observado
- concentração excessiva da carga em build em alguns cenários
- isso parece refletir a parametrização atual do backend
- o dashboard está mostrando o comportamento real do motor, não inventando a leitura

---

## Próxima evolução prioritária do motor
### Calendar-aware planning
O motor deve evoluir para:
- considerar o calendário inteiro do atleta
- diferenciar provas A, B e C
- recalibrar carga entre provas próximas
- distribuir melhor base/build/peak/taper/race
- distribuir melhor carga por atividade
- reduzir sobreposição e desequilíbrio

---

## O que o motor precisa respeitar
- disponibilidade do atleta
- contexto fisiológico
- experiência / fitness level
- modalidade principal
- provas secundárias
- prova alvo principal
- equilíbrio da carga semanal
- taper adequado
- coerência entre fase e atividade

---

## Papel do treinador
Mesmo com o motor evoluído:
- o treinador continua sendo o revisor final
- o motor propõe
- o treinador ajusta
- o treinador publica

---

## Regra estratégica do produto
Não sofisticar demais a edição fina do treino antes de evoluir o motor para calendar-aware.
A prioridade deve ser:
1. inteligência da prescrição
2. coerência do calendário
3. balanço de carga
4. depois edição fina dos steps
