# SPEC — Trinium Sports (MVP)

## Papéis (roles)
- **Atleta**
- **Treinador** (com validação de documento CREF)
- **Nutricionista** (com validação de documento CRN)

## Regras de negócio (MVP)
1. Atleta só recebe serviços de treino se tiver **treinador ativo**.
2. Atleta só pode solicitar nutricionista após ter **treinador ativo**.
3. Profissionais têm status de validação (ex.: pendente, aprovado, reprovado).
4. Vínculos atleta↔profissional têm status (ex.: solicitado, aceito, rejeitado, ativo, encerrado).
5. O app deve priorizar segurança: reduzir overtraining/lesões (começa como regra/UX, sem “IA” no MVP 1).

## Fluxo do Atleta (alto nível)
1. Cadastro/Login
2. Onboarding (tipo usuário)
3. Anamnese simples + objetivos + provas alvo (A/B/C) (MVP: perguntas básicas)
4. Descobrir treinadores (lista + detalhe)
5. Solicitar vínculo com treinador
6. Após aceite: solicitar nutricionista (opcional)
7. Contato (WhatsApp) para alinhar plano/pagamento (MVP)
8. Área “Meus Profissionais” (status e histórico)

## Fluxo do Profissional (alto nível)
1. Cadastro/Login
2. Onboarding profissional + upload docs
3. Status de validação visível
4. Receber solicitações de atletas
5. Aceitar/Rejeitar
6. Lista de atletas vinculados

## Telas (MVP 1)
### Comuns
- Splash / carregamento de sessão
- Login / cadastro / recuperar senha
- Seleção de role (Atleta / Treinador / Nutri)

### Atleta
- Onboarding atleta (objetivos + provas)
- Lista de treinadores
- Detalhe do treinador + “Solicitar”
- (Depois) Lista de nutris
- Meus profissionais (cards com status)
- Configurações/Perfil

### Treinador / Nutri
- Onboarding profissional (dados + documentos)
- Status de validação
- Solicitações recebidas
- Meus atletas
- Configurações/Perfil

## MVP Scope Guard (para não explodir)
- Sem chat interno no MVP 1 (usar WhatsApp)
- Sem pagamentos no app no MVP 1
- Sem prescrição detalhada de treino/dieta no MVP 1 (apenas vínculo e base operacional)
