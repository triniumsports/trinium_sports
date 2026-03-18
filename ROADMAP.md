# Trinium Sports — ROADMAP (100% alinhado ao Supabase)

> Este roadmap é guiado pelo schema do backend (Supabase/Postgres + RLS + Storage).
> Regras:
> - Tudo que entra no app deve existir (ou ser compatível) com o backend.
> - Sempre que um fluxo for concluído, registrar: (1) o que foi feito no frontend, (2) o que foi configurado no Supabase, (3) como testar.
> - “Produção real”: scripts e docs no repo são a fonte de verdade.

---

## 0) Base do produto e execução (infra + estabilidade)

### 0.1 Execução estável no Codespaces (Web)
**Objetivo:** rodar sempre igual, sem tela branca por build antigo e sem depender de device Chrome.

**Já implementado (Frontend):**
- Script `run_web.sh` como padrão único de execução.
  - Faz clean/build web e serve em `8080`.
  - Reinstala Flutter em `/workspaces/flutter` se necessário.
- Fluxo recomendado: `cd /workspaces/trinium_sports && ./run_web.sh`.

**Critério de aceite:**
- App abre em 8080 sempre.
- Se o codespace reiniciar, o app volta a rodar com o mesmo comando.
- Não depender de `flutter run -d chrome`.

---

## 1) Identidade, papéis e autenticação (produção real)

### 1.1 Auth (Email) — signUp + confirmação + signIn
**Objetivo:** cadastro real com confirmação por e-mail, sem atalhos que quebrem produção.

**Já implementado (Frontend):**
- Telas de cadastro/login.
- Fluxo: signUp → confirmação de e-mail → signIn.
- Roteamento central pós-login via `HomeRouterScreen`.

**Já implementado (Supabase):**
- Hook de criação de profile em `auth.users`:
  - Função/trigger `handle_new_user()` cria `public.profiles` automaticamente no signUp.
  - Preenche `user_role` a partir de `raw_user_meta_data->>'user_role'`, com fallback `athlete`.
- Constraints de `profiles.user_role` para evitar nulo/vazio e garantir conjunto permitido.

**Critério de aceite:**
- Usuário aparece em Auth/Users.
- Profiles sempre é criado com `user_role` válido.
- Cadastro não dá erro 500 por violação de constraint.
- Confirmar e-mail e retornar ao app sem travar o fluxo.

### 1.2 Papéis (roles)
**Objetivo:** roteamento correto e seguro por papel.

Papéis:
- `athlete`
- `coach` (inclui treinador/nutri/híbrido; tipo define CREF/CRN)
- `admin` (opcional para operação futura)

**Já implementado (Frontend):**
- Roteamento por `profiles.user_role` no `HomeRouterScreen`.

**Já implementado (Supabase):**
- Função `is_admin()` e proteção para mudança de role (sem quebrar SQL Editor/Dashboard).

**Critério de aceite:**
- Login athlete → home athlete (ou onboarding atleta se incompleto).
- Login coach → onboarding profissional se incompleto.
- Login admin → painel admin (se habilitado).

---

## 2) Onboarding do Profissional (Treinador/Nutricionista) — dados completos do schema

### 2.1 Captura de dados obrigatórios do profissional (marketplace)
**Objetivo:** profissional completar o perfil com os campos necessários do backend e aparecer na busca.

**Campos alvo (alinhados ao backend):**
- `profiles.full_name`
- `profiles.avatar_url` (foto)
- `coaches.professional_type` (coach/nutritionist/hybrid)
- `coaches.cref_number` (CREF/CRN dependendo do tipo)
- `coaches.phone_mobile`
- `coaches.address_zip_code`
- `coaches.specialties` (array):
  - run, swim, bike, strength, trail, triathlon
- `coaches.bio` (opcional)

**Já implementado (Frontend):**
- `ProfessionalProfileFormScreen`:
  - Upload de foto (avatars)
  - Form tipo/registro/celular/CEP/especialidades/bio
  - Salva em `profiles` e `coaches`

**Dependências (Supabase):**
- Bucket `avatars` (público) para imagem de perfil.
- Policies permitindo:
  - update do próprio `profiles.avatar_url` e `profiles.full_name`
  - update do próprio registro em `coaches`

**Critério de aceite:**
- Coach loga e cai no formulário se estiver incompleto.
- Ao salvar, retorna ao Router e entra no fluxo normal.
- Dados aparecem em `profiles` e `coaches`.

### 2.2 Documentos para auditoria (sem OCR e sem aprovação manual)
**Objetivo:** coletar RG/CNH + Conselho + Print consulta pública e armazenar no Storage. Sem bloqueio manual.

Documentos:
- identity (RG/CNH)
- council (doc CREF/CRN)
- lookup_print (print consulta pública)

**Já implementado (Frontend):**
- Upload dos 3 documentos no onboarding via `VerificationService.pickAndUpload(docType)`.

**Já implementado (Supabase):**
- Bucket privado `professional-verification`.
- Policies:
  - upload apenas na pasta do próprio usuário `user_id/...`
  - leitura do próprio usuário
  - (admin read pode existir, mas o produto não depende de aprovação)

**Critério de aceite:**
- Profissional envia os 3 docs.
- Arquivos aparecem no Storage `professional-verification/<user_id>/...`.
- Registro em `coaches.verification_documents` contém lista JSON com `type`, `bucket`, `path`, `filename`, `uploaded_at`.
- `verification_submitted_at` preenchido quando os 3 tipos existem.
- Profissional NÃO fica bloqueado por `verification_status` (modelo de auditoria).

---

## 3) Onboarding do Atleta — dados completos do schema (motor de treino)

### 3.1 Cadastro do atleta completo (tabela athletes)
**Objetivo:** capturar dados fisiológicos e de nível necessários ao motor.

**Campos alvo (backend `public.athletes`):**
Obrigatórios no app (mínimo para prescrição v1):
- `birth_date`
- `gender` (male/female/other)
- `height_cm`
- `weight_kg`
- `experience_level` (beginner/intermediate/advanced/elite)
- `resting_hr`
- `max_hr`

Recomendados (opcionais no app, mas úteis ao motor):
- `vo2_max`
- `fitness_level`
- `basal_metabolic_rate`
- `dietary_restrictions` (array)
- `phase` (base/build/peak etc)

**Já implementado (Frontend):**
- `AthleteProfileFormScreen`:
  - grava `athletes`
  - garante defaults em `athlete_capacity` e `athlete_zones`

**Dependências (Supabase):**
- Policies: atleta pode upsert/update do próprio `athletes`.
- Tabelas `athlete_capacity` e `athlete_zones` aceitam upsert por atleta.

**Critério de aceite:**
- Atleta loga e cai no formulário se incompleto.
- Ao salvar, volta ao Router e entra no Home do atleta.
- `athletes`, `athlete_capacity` e `athlete_zones` ficam consistentes.

### 3.2 Evolução futura: calibração de zonas e capacidade
**Objetivo:** calibrar zonas (pace/FC) e capacidade semanal para prescrição mais precisa.

**Tabelas backend:**
- `athlete_zones` (pace_z1..z5, hr_max etc)
- `athlete_capacity` (leg/push/pull/core, total_weekly_hours, calibration)

**Status:**
- Defaults são criados.
- UI de calibração ainda não implementada.

---

## 4) Marketplace — busca e relacionamento atleta ↔ profissional

### 4.1 Busca de profissionais (nome / especialidade / CEP)
**Objetivo:** atleta encontra profissionais por nome, especialidade e localização (CEP).

**Já implementado (Supabase):**
- RPC `search_professionals(p_name, p_specialty, p_zip, p_limit, p_offset)` com regras de “perfil mínimo completo”.

**Já implementado (Frontend):**
- `AthleteSearchProfessionalsScreen` chamando a RPC e listando resultados.

**Critério de aceite:**
- Busca por nome parcial, especialidade e CEP retorna profissionais completos com registro exibido.

### 4.2 Relacionamento (coach_athlete_relation)
**Objetivo:** atleta solicita vínculo e profissional aceita/rejeita.

**Backend esperado:**
- `coach_athlete_relation` com status: pending/active/rejected/archived (ou equivalente)

**Ainda a fazer (Frontend):**
- Atleta: “Solicitar vínculo” no card do profissional.
- Profissional: tela “Solicitações” para aceitar/rejeitar.
- Atleta: lista “Meus profissionais”.

**Critério de aceite:**
- Cria relation pending.
- Profissional aprova e vira active.
- Ambos veem vínculo ativo.

---

## 5) Motor de prescrição (treino automático) — v1

### 5.1 Objetivo e prova (target_races)
**Backend existente:**
- `race_definitions`, `target_races`, `target_race_segments`

**A fazer (Frontend):**
- Tela para cadastrar prova/objetivo (data, modalidade, distância/segmentos)

### 5.2 Restrições semanais e padrão de semana
**Backend existente:**
- `weekly_constraints`
- `standard_week_patterns` + `standard_week_pattern_sessions`

**A fazer (Frontend):**
- Tela “Disponibilidade semanal”
- Opção de padrão pronto

### 5.3 Regras e templates → prescrição
**Backend existente:**
- `session_rules`
- `phase_volume_targets`
- `workout_templates` + `workout_template_steps`
- `prescribed_workouts` + `prescribed_workout_steps`

**A fazer (Backend/Edge/RPC):**
- RPC `generate_week(athlete_id, week_start)` que instancia treinos e steps.

**A fazer (Frontend):**
- Botão “Gerar semana”
- Agenda da semana
- Detalhe do treino (steps)

---

## 6) Motor v2 — feedback, execução real e ajustes

### 6.1 Check-in pós-treino
**Backend existente:**
- feedbacks no `prescribed_workouts`
- domínios RPE/dor/sensação

**A fazer (Frontend):**
- Form rápido pós treino

### 6.2 Registro de atividade real
**Backend existente:**
- `completed_activities`, `activity_geo_streams`

**A fazer (Frontend):**
- Marcar executado
- Integração futura (Garmin/Strava)

### 6.3 Métricas e alertas
**Backend existente:**
- `athlete_metrics_log`
- `smart_alerts`
- `knowledge_base_risk_matrix`

**A fazer (Backend/Edge/RPC):**
- atualizar métricas e alertas

**A fazer (Frontend):**
- dashboard e alertas

---

## 7) Nutrição (opcional; existe no backend)
**Backend existente:**
- `nutrition_plans`, `nutrition_daily_menus`, `nutrition_daily_logs`

**A fazer (Frontend):**
- planos e logs simples
