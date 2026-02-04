# Contrato Supabase — Trinium Sports

> Fonte de verdade para o front-end: tabelas, colunas, RLS, storage e enums.

## A preencher (MVP 1)
### Auth
- Providers:
- Estrutura de user_id e profile:

### Tabelas essenciais (sugestão)
- profiles (user_id, role, nome, foto, created_at…)
- athlete_profile (user_id, objetivos, nivel, provas A/B/C…)
- professional_profile (user_id, tipo: treinador/nutri, bio, preco, regiao…)
- professional_verification (user_id, status, doc_url, reviewed_at…)
- links (atleta_id, profissional_id, tipo, status, created_at…)

### RLS (por tabela)
- Quem pode ler/escrever o quê?
- Ex.: atleta só vê seus próprios vínculos; profissional só vê vínculos onde ele é parte.

### Storage
- Bucket: documents (CREF/CRN, selfie doc)
- Bucket: avatars

### Enums / Status
- role: athlete | coach | nutritionist
- verification_status: pending | approved | rejected
- link_status: requested | accepted | rejected | active | closed

## Checklist de export
- [ ] Export do schema (SQL)
- [ ] Export das RLS policies
- [ ] Lista de buckets + regras
- [ ] Edge functions (se houver)
