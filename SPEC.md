# Trinium Sports — SPEC (MVP Atual)

## Auth
- signUp -> confirmação de e-mail -> signIn
- user_role inicial vem do metadata no signUp, mas:
  - profiles.user_role é fonte de verdade
  - app não sobrescreve user_role existente (preserva admin)

## Roles
- athlete
- coach
- admin (profiles.user_role = 'admin')

## Coach verification
- Coach/nutri cadastra com CREF/CRN (obrigatório)
- Após login, profile coach existe e trigger cria registro em coaches
- Coach pending vê tela de "Aguardando Aprovação" com upload do documento
- Upload vai para Storage bucket: professional-verification (privado)
- Documento é registrado em coaches.verification_documents (json list)
- Admin aprova/reprova: verified/rejected via painel admin

## Admin panel (web)
- Abas:
  - Fila (claim_next_pending_coach) + review_coach
  - Listas (pending/verified/rejected)
- Admin consegue gerar signed URL para abrir documento e decidir

## Execução
- `./run_web.sh` -> build web + serve em 8080
