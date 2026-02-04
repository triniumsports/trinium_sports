# Trinium Sports — Project State

## Visão do produto
Trinium Sports é um app que conecta **atletas**, **treinadores** e **nutricionistas** em uma mesma plataforma para entregar treino + nutrição com acompanhamento, reduzindo risco de lesão e overtraining.

## Objetivo do MVP
Validar a proposta com um fluxo simples:
- Atleta cria conta e completa onboarding
- Atleta encontra/solicita treinador
- (Opcional) atleta solicita nutricionista **após** ter treinador
- Profissionais recebem solicitações e aceitam/rejeitam
- Atleta e profissional têm um canal de contato (ex.: WhatsApp) + visão básica do plano

## Status atual
- ✅ Backend no Supabase existe e está funcionando (detalhes a documentar no contrato).
- ✅ Vamos começar o **front do zero** pelo navegador (GitHub + Codespaces).
- ⏳ Precisamos fechar “Contrato do Supabase” (tabelas, RLS, storage, enums).

## Decisões importantes
- Todo requisito/fluxo deve estar registrado em `SPEC.md` e `DECISIONS.md`.
- Toda mudança de escopo vira uma decisão datada em `DECISIONS.md`.
- Backend é “source of truth” para dados; o front segue o contrato.

## Próximo passo imediato
1. Fechar o **MVP Fase 0** (telas e fluxos) em `SPEC.md`
2. Mapear o **Supabase Contract** (tabelas/policies/storage)
3. Subir o front em Flutter Web via Codespaces e começar a UI
