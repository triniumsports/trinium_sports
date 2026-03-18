# Trinium Sports — BACKEND_SCHEMA_SNAPSHOT (Supabase source of truth)

Este arquivo é o “contrato” entre Frontend e Backend.  
Antes de criar campos/tabelas no app, conferir aqui.

---

## 1) Auth & Profiles

### 1.1 auth.users (Supabase Auth)
- Armazena metadata do signUp:
  - `raw_user_meta_data->>'user_role'`
  - `raw_user_meta_data->>'full_name'`
  - (opcional) `raw_user_meta_data->>'cref_number'`

### 1.2 public.profiles
**Chaves**
- `id` (uuid, PK, = auth.users.id)

**Campos**
- `email` (text)
- `full_name` (text)
- `avatar_url` (text)
- `user_role` (text) — permitido: athlete | coach | admin (NOT NULL e não vazio)

**Gatilho**
- `public.handle_new_user()` (trigger em auth.users) cria/atualiza `public.profiles` preenchendo `user_role` com fallback `athlete`.

---

## 2) Profissional (Coach/Nutri/Híbrido)

### 2.1 public.coaches
**Chaves**
- `id` (uuid, PK, FK = profiles.id)

**Campos importantes do produto**
- `professional_type` (text): coach | nutritionist | hybrid
- `cref_number` (text): usado como registro (CREF/CRN dependendo do tipo)
- `phone_mobile` (text)
- `address_zip_code` (text)
- `specialties` (text[]): run, swim, bike, strength, trail, triathlon
- `bio` (text)

**Documentos (auditoria)**
- `verification_documents` (json/jsonb list)
  - items com: type, bucket, path, filename, uploaded_at
  - type: identity | council | lookup_print
- `verification_submitted_at` (timestamptz) — quando os 3 tipos existem

**Status (pode existir, mas não bloqueia no modelo atual)**
- `verification_status`: pending/verified/rejected (se existir)
- `verification_mode`: manual/auto (se existir)
- `auto_score`, `auto_result`, `auto_reason` (se existirem; OCR foi abandonado)

---

## 3) Atleta (base do motor)

### 3.1 public.athletes
**Chaves**
- `id` (uuid, PK, FK = profiles.id)

**Campos fisiológicos e de nível**
- `birth_date` (date)
- `gender` (text): male|female|other
- `height_cm` (double)
- `weight_kg` (double)
- `experience_level` (text): beginner|intermediate|advanced|elite
- `resting_hr` (int)
- `max_hr` (int)
- `vo2_max` (double)

**Campos adicionais**
- `fitness_level` (text)
- `basal_metabolic_rate` (int)
- `dietary_restrictions` (text[])
- `phase` (text) — ex.: base/build/peak

**Integrações**
- `garmin_connected` (bool)
- `garmin_access_token` (text)

### 3.2 public.athlete_capacity
**Chave**
- `athlete_id` (uuid, UNIQUE)

**Campos**
- `leg_capacity_max`, `push_capacity_max`, `pull_capacity_max`, `core_capacity_max`
- `total_weekly_hours`
- `last_calibration_date`

### 3.3 public.athlete_zones
**Chave**
- `athlete_id` (uuid)

**Campos**
- `hr_max`, `vo2_max`
- `pace_z1_sec` ... `pace_z5_sec`
- `updated_at`

---

## 4) Marketplace e Relacionamentos

### 4.1 public.coach_athlete_relation
- Vincula atleta ↔ profissional
- Esperado: status (pending/active/rejected/archived), timestamps

---

## 5) Motor de treino (prescrição)

### 5.1 Templates e regras
- `workout_templates`
- `workout_template_steps`
- `session_rules`
- `phase_volume_targets`
- `weekly_constraints`
- `standard_week_patterns`
- `standard_week_pattern_sessions`

### 5.2 Prescrição gerada
- `prescribed_workouts`
- `prescribed_workout_steps`

### 5.3 Execução e feedback
- `completed_activities`
- `activity_geo_streams`
- `athlete_metrics_log`
- `smart_alerts`
- `knowledge_base_risk_matrix`
- `athlete_pain_logs`, `athlete_anamnesis`

---

## 6) Nutrição (opcional)
- `nutrition_plans`
- `nutrition_daily_menus`
- `nutrition_daily_logs`

---

## 7) Storage (Supabase)

### 7.1 Bucket: avatars (público)
- Fotos de perfil

### 7.2 Bucket: professional-verification (privado)
- Documentos do profissional (auditoria)
- Estrutura: `<user_id>/<type>_timestamp.ext`
