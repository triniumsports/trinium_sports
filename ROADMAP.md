# Roadmap — Trinium Sports

## Fase 0 — Fundação (MVP 1)
**Objetivo:** fluxo ponta-a-ponta mínimo com Supabase (Auth + perfis + vínculo).

- Auth (email/senha; social opcional depois)
- Perfis: Atleta / Treinador / Nutricionista
- Onboarding:
  - Atleta: objetivo + nível + provas alvo (A/B/C)
  - Profissionais: cadastro + documentos (CREF/CRN) e status
- Catálogo: listar treinadores e nutricionistas
- Solicitação de vínculo:
  - Atleta → Treinador (solicita, profissional aceita/rejeita)
  - Atleta → Nutri (só após treinador ativo)
- Área do Atleta: profissionais vinculados + status
- Área do Profissional: lista de atletas + solicitações pendentes
- Contato (ex.: botão WhatsApp)
- Logs básicos / auditoria (criado_em, atualizado_em, status)

## Fase 1 — Operação (MVP 2)
- Check-in do atleta (aderência, dor, fadiga)
- Profissional registra ajustes (treino/plano em texto simples)
- Notificações simples (push/email: “solicitação recebida”, “aceito”)

## Fase 2 — Integrações
- Importação básica de dados (smartwatch/Strava/Health) — se fizer sentido
- Alertas simples de carga (regras)

## Fase 3 — Inteligência
- Recomendação de carga/ajustes com base em histórico e regras/modelos
- Detecção de risco (overreaching/overtraining) com explainability

## Critérios de sucesso do MVP 1
- Atleta consegue se cadastrar e solicitar um treinador
- Treinador consegue aceitar e visualizar o atleta
- Vínculo fica registrado no banco com RLS funcionando
