import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_router_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _crefController = TextEditingController();

  String _mode = 'login';
  String _role = 'athlete';
  bool _loading = false;
  String? _message;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      if (_mode == 'register') {
        if (_role == 'coach' && _crefController.text.trim().isEmpty) {
          setState(() {
            _message = 'CREF/CRN é obrigatório para cadastro de treinador.';
            _loading = false;
          });
          return;
        }

        final response = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
          userRole: _role,
          crefNumber: _role == 'coach' ? _crefController.text.trim() : null,
        );

        setState(() {
          _message = response.session == null
              ? 'Conta criada. Confirme seu e-mail e depois faça login.'
              : 'Cadastro realizado com sucesso.';
        });
      } else {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final profile = await _authService.getMyProfile();

        setState(() {
          _message =
              'Login realizado com sucesso. Perfil: ${profile?['user_role'] ?? 'sem perfil'}';
        });

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeRouterScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _message = 'Erro: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _crefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == 'register';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trinium Sports'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isRegister ? 'Criar conta' : 'Entrar',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (isRegister)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (isRegister && _role == 'coach')
                  Column(
                    children: [
                      TextField(
                        controller: _crefController,
                        decoration: const InputDecoration(
                          labelText: 'CREF/CRN (obrigatório)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                if (isRegister) const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (isRegister)
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de usuário',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'athlete',
                        child: Text('Atleta'),
                      ),
                      DropdownMenuItem(
                        value: 'coach',
                        child: Text('Treinador'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _role = value;
                        });
                      }
                    },
                  ),
                if (isRegister) const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _loading
                          ? 'Processando...'
                          : isRegister
                              ? 'Cadastrar'
                              : 'Entrar',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _mode = isRegister ? 'login' : 'register';
                            _message = null;
                          });
                        },
                  child: Text(
                    isRegister ? 'Já tenho conta' : 'Criar uma conta',
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
