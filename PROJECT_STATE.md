# Trinium Sports — Project State

## Visão do produto
Trinium Sports é um app que conecta atletas, treinadores e nutricionistas em uma mesma plataforma para entregar treino + nutrição com acompanhamento, reduzindo risco de lesão e overtraining.

## Objetivo do MVP
Validar a proposta com um fluxo simples:
- Atleta cria conta
- Usuário confirma e-mail no Supabase Auth
- Usuário faz login
- Perfil base é criado no banco
- Atleta encontra/solicita treinador
- Profissional recebe solicitações e aceita/rejeita
- Atleta e profissional têm uma visão básica do vínculo

## Status atual do projeto
- Backend no Supabase está ativo e acessível.
- Frontend foi recriado em Flutter Web dentro do GitHub Codespaces.
- Projeto Flutter base funcionando.
- Supabase inicializando com sucesso no frontend.
- Tela de autenticação (login/cadastro) carregando com sucesso.
- Fluxo de cadastro já conversa com o Supabase.
- Foi identificado e corrigido o problema de RLS no cadastro inicial:
  - o perfil não deve ser criado antes de existir sessão autenticada.
- O fluxo correto em produção é:
  1. signUp no Auth
  2. confirmação de e-mail
  3. login
  4. criação de profiles + athletes/coaches após sessão autenticada
- O ambiente Codespaces apresentou instabilidade com `flutter run -d web-server`.
- O modo estável de execução no Codespaces, até aqui, é:
  1. `flutter build web`
  2. `cd build/web`
  3. `python3 -m http.server 8080`

## Estrutura atual do frontend
Arquivos principais já criados:
- `lib/core/supabase_config.dart`
- `lib/main.dart`
- `lib/services/auth_service.dart`
- `lib/screens/auth_gate.dart`

## Regras já validadas
- O projeto deve respeitar o fluxo real de produção.
- A confirmação de e-mail do Supabase deve permanecer ativa.
- A aprovação de negócio (ex.: treinador aprovado) é separada da confirmação de e-mail.
- RLS continua como proteção principal do banco.
- O backend continua sendo a source of truth.

## Problema já resolvido nesta etapa
- Tela branca no browser:
  - causa principal: forma de execução no Codespaces
  - solução prática: usar build web + servidor Python local

## Próximo passo imediato
1. Consolidar no código a versão final do `auth_service.dart` com criação de perfil após login autenticado
2. Ajustar a mensagem de cadastro para fluxo com confirmação de e-mail
3. Testar ponta a ponta:
   - cadastro
   - confirmação de e-mail
   - login
   - criação de `profiles`
   - criação de `athletes` ou `coaches`
4. Depois disso, criar a primeira home pós-login por perfil

## Observação importante
Ao continuar em novos chats, usar estes arquivos como fonte de verdade:
- `PROJECT_STATE.md`
- `ROADMAP.md`
- `DECISIONS.md`
- `SPEC.md`
- `SUPABASE_CONTRACT.md`
