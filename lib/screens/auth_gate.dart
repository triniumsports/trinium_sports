import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_router_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _crefController =
      TextEditingController();

  String _mode = 'login';

  /*
   * Opção visual escolhida pelo usuário:
   *
   * athlete
   * coach
   * nutritionist
   */
  String _accountType = 'athlete';

  bool _loading = false;
  bool _obscurePassword = true;

  String? _message;

  bool get _isRegister => _mode == 'register';

  bool get _isProfessional {
    return _accountType == 'coach' ||
        _accountType == 'nutritionist';
  }

  /*
   * O roteador atual reconhece profissionais como coach.
   *
   * O tipo específico fica em coaches.professional_type.
   */
  String get _databaseUserRole {
    switch (_accountType) {
      case 'coach':
      case 'nutritionist':
        return 'coach';

      case 'athlete':
      default:
        return 'athlete';
    }
  }

  String? get _databaseProfessionalType {
    switch (_accountType) {
      case 'coach':
        return 'coach';

      case 'nutritionist':
        return 'nutritionist';

      case 'athlete':
      default:
        return null;
    }
  }

  String get _registrationLabel {
    return _accountType == 'nutritionist' ? 'CRN' : 'CREF';
  }

  String get _professionalLabel {
    return _accountType == 'nutritionist'
        ? 'nutricionista'
        : 'treinador';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _crefController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      if (_isRegister) {
        if (_nameController.text.trim().isEmpty) {
          setState(() {
            _message = 'Informe o nome completo.';
          });
          return;
        }

        if (_emailController.text.trim().isEmpty) {
          setState(() {
            _message = 'Informe o e-mail.';
          });
          return;
        }

        if (_passwordController.text.trim().length < 6) {
          setState(() {
            _message =
                'A senha deve ter pelo menos 6 caracteres.';
          });
          return;
        }

        if (_isProfessional &&
            _crefController.text.trim().isEmpty) {
          setState(() {
            _message =
                '$_registrationLabel é obrigatório para '
                'cadastro de $_professionalLabel.';
          });
          return;
        }

        final response = await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),

          /*
           * Nutricionista continua sendo profissional
           * no roteamento principal.
           */
          userRole: _databaseUserRole,

          /*
           * Diferencia treinador e nutricionista
           * dentro da tabela coaches.
           */
          professionalType: _databaseProfessionalType,

          /*
           * A coluna atual do banco é cref_number,
           * mas também armazena o CRN do nutricionista.
           */
          crefNumber: _isProfessional
              ? _crefController.text.trim()
              : null,
        );

        if (!mounted) return;

        if (response.session == null) {
          setState(() {
            _message =
                'Conta criada. Confirme seu e-mail e depois '
                'faça login.';
            _mode = 'login';
          });
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeRouterScreen(),
            ),
          );
        }
      } else {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeRouterScreen(),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = 'Erro: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeMode() {
    setState(() {
      _mode = _isRegister ? 'login' : 'register';
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trinium Sports'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isRegister
                          ? 'Criar conta'
                          : 'Entrar',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium,
                    ),
                    const SizedBox(height: 24),

                    if (_isRegister) ...[
                      TextField(
                        controller: _nameController,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Nome completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration:
                          const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction:
                          TextInputAction.done,
                      autofillHints: _isRegister
                          ? const [
                              AutofillHints.newPassword,
                            ]
                          : const [
                              AutofillHints.password,
                            ],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        border:
                            const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),

                    if (_isRegister) ...[
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _accountType,
                        decoration:
                            const InputDecoration(
                          labelText: 'Tipo de usuário',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'athlete',
                            child: Text('Atleta'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'coach',
                            child: Text('Treinador'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'nutritionist',
                            child: Text(
                              'Nutricionista',
                            ),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _accountType = value;
                                  _message = null;

                                  if (!_isProfessional) {
                                    _crefController
                                        .clear();
                                  }
                                });
                              },
                      ),

                      if (_isProfessional) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller:
                              _crefController,
                          textCapitalization:
                              TextCapitalization
                                  .characters,
                          decoration: InputDecoration(
                            labelText:
                                'Número do $_registrationLabel',
                            hintText:
                                'Informe o registro profissional',
                            border:
                                const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _loading ? null : _submit,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isRegister
                                      ? 'Criar conta'
                                      : 'Entrar',
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed:
                          _loading ? null : _changeMode,
                      child: Text(
                        _isRegister
                            ? 'Já tenho conta'
                            : 'Criar uma conta',
                      ),
                    ),

                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(12),
                          color:
                              const Color(0xFFF1F2F6),
                        ),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
