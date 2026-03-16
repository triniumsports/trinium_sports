# Trinium Sports — Project State (Checkpoint)

## Onde estamos
- Frontend Flutter Web rodando no GitHub Codespaces.
- Execução estável via script: `./run_web.sh` (build web + python server 8080).
- Supabase conectado com Publishable Key e API URL.
- Fluxo de autenticação em produção:
  - signUp -> confirmação de e-mail -> signIn
  - criação/garantia de profile sem sobrescrever user_role já existente
- Perfis suportados: athlete, coach, admin.

## Backend (Supabase)
- Postgres com RLS ativo.
- Tabelas principais: profiles, athletes, coaches.
- Coaches:
  - verification_status: pending / verified / rejected
  - cref_number obrigatório (coach/nutri).
  - verification_documents (json) registra docs enviados.
- Trigger criado:
  - ao inserir profile com user_role = coach, cria linha em coaches automaticamente (evita INSERT via frontend e evita conflitos RLS).

## Verificação de documento
- Upload do documento do CREF/CRN no bucket Storage: `professional-verification` (bucket existente).
- App do coach pendente mostra botão "Enviar foto do CREF/CRN".
- Storage policies ajustadas:
  - upload permitido apenas na pasta do próprio usuário (foldername(name)[1] = auth.uid()).
  - leitura do próprio usuário.
  - leitura admin (is_admin()) para aprovação no app.
- Coach update policy:
  - usuário pode atualizar o próprio registro para gravar verification_documents.

## Admin
- Não existia admin inicialmente; admin é definido em `profiles.user_role = 'admin'`.
- Corrigido bug: app não deve sobrescrever user_role para athlete no login.
- Painel Admin Web criado:
  - rota via HomeRouter quando user_role == admin.
  - botão Sair.
  - Tab Fila: pegar próximo (RPC) e aprovar/reprovar (RPC).
  - Tab Listas: listar pendentes/aprovados/reprovados.
- RPCs criadas para escala:
  - claim_next_pending_coach (lock e timeout).
  - review_coach (aprovar/reprovar + auditoria).

## Problemas resolvidos recentemente
- Tela branca / build antigo no Codespaces: padronizado via build web + python e script `run_web.sh`.
- Volta para "APP MINIMO OK": causa era build falhando ou build antigo; resolvido com fluxo padronizado.
- user_role vazio em profiles causava erro pós-login; foi corrigido com backfill e guard.
- Upload falhando com “Bucket not found”: corrigido para bucket correto `professional-verification`.

## Próximos passos
1) Melhorar UX do painel admin:
   - abrir doc em nova aba automaticamente (signed URL).
   - atalhos teclado (A aprova, R reprova, N próximo).
   - mostrar nome/email do profissional (join profiles).
2) Separar “coach” e “nutritionist” no cadastro:
   - campo professional_type no coaches (coach/nutritionist/hybrid).
3) Vínculo atleta -> profissional (coach_athlete_relation):
   - listar profissionais verified
   - solicitar vínculo
   - aprovar/rejeitar vínculo pelo profissional
4) Métricas operacionais:
   - aprovados por hora/dia
   - backlog
