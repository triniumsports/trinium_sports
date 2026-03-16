# Decisões — Trinium Sports (Resumo)

## Execução no Codespaces
- Decisão: usar build estático e servidor python para evitar instabilidade do web-server.
- Implementação: script `run_web.sh` que faz clean + build + serve em 8080.

## Segurança e RLS
- Decisão: evitar INSERT direto em coaches pelo frontend (RLS bloqueava).
- Implementação: trigger no banco cria coaches automaticamente quando profiles.user_role = coach.

## Aprovação de profissionais
- Status oficial no schema: pending / verified / rejected.
- Documento obrigatório: upload para Storage e registro em coaches.verification_documents.
- Decisão: aprovação via painel admin no app (web desktop), sem service_role no client.
- Implementação:
  - policies admin (is_admin()) em coaches e storage.objects.
  - RPC para claim com lock e review.

## user_role como source of truth
- Decisão: profiles.user_role é fonte de verdade; app não sobrescreve se já existir (preserva admin).
