# Decisões — Trinium Sports

## 2026-02-04
- Contexto: ambiente local apresentou instabilidade para continuidade do desenvolvimento.
- Decisão: recomeçar o frontend do zero usando GitHub + Codespaces.
- Motivo: garantir continuidade, backup e reduzir dependência do PC local.
- Impacto: o frontend passa a ser construído diretamente no repositório.

## 2026-03-04
- Contexto: foi necessário iniciar o frontend a partir da documentação e do backend já existente no Supabase.
- Decisão: criar uma base mínima em Flutter Web antes de expandir o fluxo do app.
- Motivo: validar ambiente, build, integração com Supabase e reduzir risco técnico.
- Impacto: o projeto passa a ter uma fundação funcional com `main.dart`, configuração do Supabase, serviço de auth e tela inicial de autenticação.

## 2026-03-04
- Contexto: o modo `flutter run -d web-server` no Codespaces apresentou tela branca e comportamento inconsistente para teste no navegador.
- Decisão: adotar, por enquanto, o fluxo de execução via:
  1. `flutter build web`
  2. `cd build/web`
  3. `python3 -m http.server 8080`
- Motivo: foi o modo que validou corretamente o carregamento do app no browser do Codespaces.
- Impacto: durante esta fase, os testes web devem usar build estático em vez do fluxo padrão de servidor web do Flutter.

## 2026-03-04
- Contexto: o cadastro tentou criar `profiles` imediatamente após `signUp`, mas a RLS bloqueou a inserção.
- Decisão: no fluxo de produção, o perfil não deve ser criado antes de existir sessão autenticada.
- Motivo: com confirmação de e-mail ativa, o usuário pode ser criado no Auth sem sessão válida naquele momento; sem sessão, `auth.uid()` não satisfaz a policy da tabela `profiles`.
- Impacto: o fluxo correto deve ser:
  1. `signUp`
  2. confirmação de e-mail
  3. `signIn`
  4. criação de `profiles` e `athletes/coaches`

## 2026-03-04
- Contexto: o projeto precisa ser testado em um fluxo real, equivalente ao comportamento esperado em produção.
- Decisão: manter a confirmação de e-mail ativa no Supabase Auth.
- Motivo: validar o processo real ponta a ponta e evitar atalhos artificiais no fluxo de autenticação.
- Impacto: qualquer teste de cadastro/login deve considerar a etapa obrigatória de confirmação de e-mail antes do primeiro acesso.

## Regras para novas decisões
- Toda mudança relevante de escopo, arquitetura, execução, stack ou regra de negócio deve entrar aqui com data.
- Cada decisão deve ter: Contexto -> Decisão -> Motivo -> Impacto.
