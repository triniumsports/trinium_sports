# Roadmap — Trinium Sports

## Fase 0 — Fundação (MVP 1)
### 0.1 Infra
- [x] Flutter Web no Codespaces
- [x] Script `run_web.sh` para execução estável
- [x] Supabase conectado

### 0.2 Auth (produção real)
- [x] signUp com confirmação de e-mail
- [x] signIn cria/garante profiles sem sobrescrever user_role (preserva admin)
- [x] roles: athlete / coach / admin

### 0.3 Coach verification
- [x] CREF/CRN obrigatório no cadastro de coach
- [x] Trigger cria linha em coaches após profile coach
- [x] Upload documento CREF/CRN para Storage (bucket professional-verification)
- [x] Salvar docs em coaches.verification_documents
- [x] Admin policies para ler docs e aprovar
- [x] Painel Admin Web com fila + listas
- [x] RPC lock/timeout para escala (claim_next_pending_coach + review_coach)

### 0.4 Pós-login
- [x] athlete -> home
- [x] coach pending -> aguardando aprovação + upload doc
- [x] coach verified -> home
- [x] coach rejected -> tela rejeitado
- [x] admin -> painel admin

## Fase 1 — Marketplace mínimo
- [ ] Vínculo atleta -> profissional (coach_athlete_relation)
- [ ] Lista de profissionais verified
- [ ] Solicitar vínculo
- [ ] Aceitar/rejeitar vínculo
- [ ] Lista de vínculos

## Fase 2 — Operação
- [ ] Check-in atleta (dor/fadiga/aderência)
- [ ] Plano simples de treino/nutri
- [ ] Notificações

## Fase 3 — Inteligência
- [ ] Alertas e recomendações de carga
- [ ] Integrações (Strava/Health) se fizer sentido

