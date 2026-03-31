# PROJECT STATE - TRINIUM SPORTS

## Data
2026-03-31

## Estado atual
- Backend do motor validado.
- `path_b_generate_plan(...)` corrigida e gerando treinos.
- Correção aplicada em `coach_requests_screen.dart` para compatibilidade com o client Supabase.
- Erro atual no Codespaces era apenas ambiente: `flutter: command not found`.
- Flutter precisa ser reexportado no PATH em novas sessões.

## Comando base do ambiente
export PATH="/workspaces/flutter/bin:$PATH"

## Próximo passo
- Rodar `flutter pub get`
- Rodar `flutter analyze`
- Rodar `flutter build web`
- Validar telas atuais antes da próxima etapa do frontend
