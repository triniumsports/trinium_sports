# Roadmap — Trinium Sports

## Fase 0 — Fundação (MVP 1)
Objetivo: fluxo ponta-a-ponta mínimo com Supabase (Auth + perfis + vínculo).

### Etapa 0.1 — Infra e base técnica
- [x] Recriar o frontend em Flutter Web no GitHub Codespaces
- [x] Configurar projeto Flutter funcional
- [x] Integrar Supabase no frontend
- [x] Validar inicialização do app
- [x] Validar execução estável no Codespaces com build web + servidor Python

### Etapa 0.2 — Autenticação
- [x] Criar tela inicial de login/cadastro
- [x] Permitir seleção de tipo de usuário no cadastro (athlete / coach)
- [x] Conectar cadastro ao Supabase Auth
- [x] Conectar login ao Supabase Auth
- [x] Identificar comportamento real de produção com confirmação de e-mail
- [ ] Consolidar versão final do fluxo:
  - signUp salva metadados
  - login autenticado cria `profiles`
  - login autenticado cria `athletes` ou `coaches`

### Etapa 0.3 — Perfil base
- [ ] Criar registro em `profiles` após sessão autenticada
- [ ] Criar registro em `athletes` para atleta
- [ ] Criar registro em `coaches` para treinador
- [ ] Validar leitura de `user_role`
- [ ] Validar status de aprovação do treinador (`verification_status`)

### Etapa 0.4 — Pós-login
- [ ] Redirecionar automaticamente após login
- [ ] Home inicial do atleta
- [ ] Home inicial do treinador
- [ ] Logout funcional

### Etapa 0.5 — Vínculo atleta-profissional
- [ ] Listar treinadores disponíveis
- [ ] Solicitar vínculo atleta -> treinador
- [ ] Profissional aceitar/rejeitar solicitação
- [ ] Registrar vínculo em banco com RLS respeitada

## Fase 1 — Operação (MVP 2)
- [ ] Check-in do atleta (aderência, dor, fadiga)
- [ ] Profissional registra ajustes de treino/plano em texto simples
- [ ] Notificações simples (push/email)

## Fase 2 — Integrações
- [ ] Importação básica de dados (wearables / Strava / Health), se fizer sentido
- [ ] Alertas simples de carga

## Fase 3 — Inteligência
- [ ] Recomendação de carga/ajustes com base em histórico
- [ ] Detecção de risco de overreaching / overtraining com regras e explainability

## Critérios de sucesso do MVP 1
- Usuário consegue se cadastrar
- Usuário confirma e-mail
- Usuário consegue logar
- Perfil correto é criado no banco após autenticação
- Atleta consegue solicitar um treinador
- Treinador consegue aceitar e visualizar o atleta
- Vínculo fica registrado com RLS funcionando
