# Trinium Sports — Especificação Funcional (MVP Atual)

## 1. Visão geral
Trinium Sports é uma plataforma para conectar atletas e profissionais (inicialmente treinadores), permitindo gestão de vínculo, acompanhamento e evolução futura para treino + nutrição.

O MVP atual está focado em:
- autenticação
- criação de perfil base
- preparação para vínculo atleta-profissional

## 2. Perfis de usuário
Tipos de usuário suportados no fluxo atual:
- `athlete`
- `coach`

O tipo é definido no momento do cadastro e salvo no metadata do usuário no Supabase Auth.

## 3. Fluxo de autenticação validado
### 3.1 Cadastro
No cadastro:
1. usuário informa:
   - nome completo
   - e-mail
   - senha
   - tipo de usuário (`athlete` ou `coach`)
2. o app executa `signUp` no Supabase Auth
3. o app salva no metadata:
   - `full_name`
   - `user_role`

### 3.2 Confirmação de e-mail
- O projeto mantém o fluxo real de produção.
- A confirmação de e-mail permanece ativa no Supabase Auth.
- Após o cadastro, o usuário deve confirmar o e-mail antes do primeiro login.

### 3.3 Login
Após confirmar o e-mail:
1. usuário faz login com e-mail e senha
2. o app obtém a sessão autenticada
3. o app lê o metadata do usuário
4. o app cria/garante os registros base no banco:
   - `profiles`
   - `athletes` (se `user_role = athlete`)
   - `coaches` (se `user_role = coach`)

## 4. Regra de criação de perfil
### 4.1 Regra importante
A tabela `profiles` não deve ser escrita antes de existir sessão autenticada.

### 4.2 Motivo
A RLS exige compatibilidade com `auth.uid()`.
Com confirmação de e-mail ativa, o `signUp` pode criar o usuário sem sessão autenticada no momento do cadastro.
Por isso, a criação do perfil deve ocorrer após login autenticado.

## 5. Estrutura lógica atual
### 5.1 Tabelas principais
- `profiles`
- `athletes`
- `coaches`

### 5.2 Regras atuais
- `profiles` recebe:
  - `id`
  - `email`
  - `full_name`
  - `user_role`
- `athletes` recebe:
  - `id`
- `coaches` recebe:
  - `id`
  - `full_name`
  - `professional_type = coach`
  - `verification_status = pending`
  - `cref_number = PENDENTE`

## 6. Aprovação de treinador
A aprovação de treinador é separada da autenticação.

### 6.1 Auth
- confirmação de e-mail no Supabase Auth libera o login

### 6.2 Negócio
- `coaches.verification_status` controla a aprovação funcional do treinador dentro do app
- status inicial:
  - `pending`
- status esperado para liberação futura:
  - `approved`

## 7. Execução no GitHub Codespaces
O fluxo mais estável validado até agora é:

1. gerar build:
   - `flutter build web`
2. entrar em:
   - `build/web`
3. servir com:
   - `python3 -m http.server 8080`

## 8. Próximos requisitos imediatos
1. redirecionamento pós-login
2. home inicial do atleta
3. home inicial do treinador
4. bloqueio de coach com `verification_status != approved`
5. fluxo de logout
6. início do vínculo atleta -> treinador

