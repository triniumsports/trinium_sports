import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_logout_button.dart';

class NutritionPrescriptionScreen extends StatefulWidget {
  const NutritionPrescriptionScreen({super.key});

  @override
  State<NutritionPrescriptionScreen> createState() =>
      _NutritionPrescriptionScreenState();
}

class _NutritionPrescriptionScreenState
    extends State<NutritionPrescriptionScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _phaseController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _hydrationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _allowed = false;

  String? _error;
  String? _selectedAthleteId;
  String? _selectedPlanId;

  String _status = 'draft';

  DateTime? _validFrom;
  DateTime? _validUntil;

  List<Map<String, dynamic>> _athletes = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _supplements = [];

  final Map<String, List<Map<String, dynamic>>> _itemsByMeal = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _phaseController.dispose();
    _caloriesController.dispose();
    _hydrationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _text(dynamic value) {
    return value == null ? '' : value.toString().trim();
  }

  int? _nullableInt(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  double? _nullableDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is! List) return [];

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  DateTime? _dateFrom(dynamic value) {
    final text = _text(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String? _dateToDatabase(DateTime? value) {
    if (value == null) return null;

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Não definida';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Ativo';
      case 'archived':
        return 'Arquivado';
      case 'draft':
      default:
        return 'Rascunho';
    }
  }

  String _athleteName(Map<String, dynamic> athlete) {
    final value = _text(
      athlete['athlete_name'] ??
          athlete['full_name'] ??
          athlete['name'],
    );

    return value.isEmpty ? 'Atleta' : value;
  }

  Future<void> _loadInitialData() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Usuário não autenticado.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final professional = await _client
          .from('coaches')
          .select('professional_type')
          .eq('id', user.id)
          .maybeSingle();

      final professionalType =
          _text(professional?['professional_type']).toLowerCase();

      _allowed = professionalType == 'nutritionist' ||
          professionalType == 'nutricionista';

      if (!_allowed) {
        return;
      }

      final athleteResponse = await _client
          .from('v_professional_portfolio_operational')
          .select()
          .eq('professional_id', user.id);

      final athleteRows = _rows(athleteResponse);
      final athletesById = <String, Map<String, dynamic>>{};

      for (final row in athleteRows) {
        final athleteId = _text(row['athlete_id']);

        if (athleteId.isNotEmpty) {
          athletesById[athleteId] = row;
        }
      }

      _athletes = athletesById.values.toList()
        ..sort(
          (a, b) => _athleteName(a)
              .toLowerCase()
              .compareTo(_athleteName(b).toLowerCase()),
        );

      if (_selectedAthleteId == null && _athletes.isNotEmpty) {
        _selectedAthleteId = _text(_athletes.first['athlete_id']);
      }

      await _reloadPlans();
    } catch (error) {
      _error = 'Erro ao carregar o módulo nutricional: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reloadPlans() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final response = await _client
        .from('v_nutritionist_plan_portfolio')
        .select()
        .eq('nutritionist_id', user.id)
        .order('updated_at', ascending: false);

    _plans = _rows(response);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPlanChildren(String planId) async {
    final results = await Future.wait([
      _client
          .from('nutrition_plan_meals')
          .select()
          .eq('nutrition_plan_id', planId)
          .order('meal_order', ascending: true),
      _client
          .from('v_nutrition_plan_items_detail')
          .select()
          .eq('nutrition_plan_id', planId)
          .order('meal_order', ascending: true),
      _client
          .from('nutrition_plan_supplements')
          .select()
          .eq('nutrition_plan_id', planId)
          .order('created_at', ascending: true),
    ]);

    _meals = _rows(results[0]);
    _supplements = _rows(results[2]);
    _itemsByMeal.clear();

    for (final row in _rows(results[1])) {
      final mealId = _text(row['meal_id']);
      final itemId = _text(row['item_id']);

      if (mealId.isEmpty || itemId.isEmpty) continue;

      _itemsByMeal.putIfAbsent(mealId, () => []);
      _itemsByMeal[mealId]!.add(row);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _newPlan() {
    setState(() {
      _selectedPlanId = null;
      _titleController.clear();
      _phaseController.clear();
      _caloriesController.clear();
      _hydrationController.clear();
      _notesController.clear();

      _status = 'draft';
      _validFrom = null;
      _validUntil = null;

      _meals = [];
      _supplements = [];
      _itemsByMeal.clear();
      _error = null;
    });
  }

  Future<void> _openPlan(Map<String, dynamic> plan) async {
    final planId = _text(plan['nutrition_plan_id']);

    if (planId.isEmpty) return;

    setState(() {
      _selectedPlanId = planId;
      _selectedAthleteId = _text(plan['athlete_id']);

      _titleController.text = _text(plan['title']);
      _phaseController.text = _text(plan['target_phase']);
      _caloriesController.text = _text(plan['daily_caloric_target']);
      _hydrationController.text = _text(plan['hydration_target_ml']);
      _notesController.text = _text(plan['notes']);

      _status = _text(plan['status']).isEmpty
          ? 'draft'
          : _text(plan['status']);

      _validFrom = _dateFrom(plan['valid_from']);
      _validUntil = _dateFrom(plan['valid_until']);
    });

    await _loadPlanChildren(planId);
  }

  Future<void> _pickValidFrom() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _validFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() => _validFrom = selected);
    }
  }

  Future<void> _pickValidUntil() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _validUntil ??
          _validFrom?.add(const Duration(days: 30)) ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: _validFrom ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() => _validUntil = selected);
    }
  }

  Future<void> _savePlan() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      setState(() => _error = 'Usuário não autenticado.');
      return;
    }

    if (_selectedAthleteId == null ||
        _selectedAthleteId!.trim().isEmpty) {
      setState(() => _error = 'Selecione um atleta.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Informe o título do plano.');
      return;
    }

    if (_validFrom != null &&
        _validUntil != null &&
        _validUntil!.isBefore(_validFrom!)) {
      setState(() {
        _error = 'A data final não pode ser anterior à data inicial.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_status == 'active') {
        if (_selectedPlanId == null) {
          await _client
              .from('nutrition_plans')
              .update({'status': 'archived'})
              .eq('nutritionist_id', user.id)
              .eq('athlete_id', _selectedAthleteId!)
              .eq('status', 'active');
        } else {
          await _client
              .from('nutrition_plans')
              .update({'status': 'archived'})
              .eq('nutritionist_id', user.id)
              .eq('athlete_id', _selectedAthleteId!)
              .eq('status', 'active')
              .neq('id', _selectedPlanId!);
        }
      }

      final payload = <String, dynamic>{
        'nutritionist_id': user.id,
        'athlete_id': _selectedAthleteId,
        'title': _titleController.text.trim(),
        'target_phase': _phaseController.text.trim().isEmpty
            ? null
            : _phaseController.text.trim(),
        'status': _status,
        'valid_from': _dateToDatabase(_validFrom),
        'valid_until': _dateToDatabase(_validUntil),
        'daily_caloric_target':
            _nullableInt(_caloriesController.text),
        'hydration_target_ml':
            _nullableInt(_hydrationController.text),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      Map<String, dynamic> savedPlan;

      if (_selectedPlanId == null) {
        final response = await _client
            .from('nutrition_plans')
            .insert(payload)
            .select()
            .single();

        savedPlan = Map<String, dynamic>.from(response);
      } else {
        final response = await _client
            .from('nutrition_plans')
            .update(payload)
            .eq('id', _selectedPlanId!)
            .select()
            .single();

        savedPlan = Map<String, dynamic>.from(response);
      }

      _selectedPlanId = _text(savedPlan['id']);

      await _reloadPlans();
      await _loadPlanChildren(_selectedPlanId!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plano nutricional salvo com sucesso.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao salvar o plano nutricional: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deletePlan() async {
    if (_selectedPlanId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir plano'),
          content: const Text(
            'As refeições, os alimentos e os suplementos deste plano '
            'também serão excluídos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _client
          .from('nutrition_plans')
          .delete()
          .eq('id', _selectedPlanId!);

      _newPlan();
      await _reloadPlans();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plano excluído.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao excluir o plano: $error');
      }
    }
  }

  Future<void> _addMeal() async {
    if (_selectedPlanId == null) {
      setState(() {
        _error = 'Salve o plano antes de adicionar refeições.';
      });
      return;
    }

    final nameController = TextEditingController();
    final orderController = TextEditingController(
      text: '${_meals.length + 1}',
    );
    final timeController = TextEditingController();
    final goalController = TextEditingController();
    final notesController = TextEditingController();

    String mealType = 'breakfast';

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar refeição'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da refeição',
                          hintText: 'Ex.: Café da manhã',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text('Café da manhã'),
                          ),
                          DropdownMenuItem(
                            value: 'morning_snack',
                            child: Text('Lanche da manhã'),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text('Almoço'),
                          ),
                          DropdownMenuItem(
                            value: 'afternoon_snack',
                            child: Text('Lanche da tarde'),
                          ),
                          DropdownMenuItem(
                            value: 'pre_workout',
                            child: Text('Pré-treino'),
                          ),
                          DropdownMenuItem(
                            value: 'intra_workout',
                            child: Text('Durante o treino'),
                          ),
                          DropdownMenuItem(
                            value: 'post_workout',
                            child: Text('Pós-treino'),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text('Jantar'),
                          ),
                          DropdownMenuItem(
                            value: 'supper',
                            child: Text('Ceia'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Outro'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => mealType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ordem',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                          labelText: 'Horário',
                          hintText: 'Ex.: 07:00',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: goalController,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo da refeição',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Orientações',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;

                    Navigator.pop(
                      dialogContext,
                      {
                        'meal_name': nameController.text.trim(),
                        'meal_type': mealType,
                        'meal_order':
                            int.tryParse(orderController.text.trim()) ?? 1,
                        'scheduled_time':
                            timeController.text.trim().isEmpty
                                ? null
                                : timeController.text.trim(),
                        'goal': goalController.text.trim().isEmpty
                            ? null
                            : goalController.text.trim(),
                        'notes': notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      },
                    );
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    orderController.dispose();
    timeController.dispose();
    goalController.dispose();
    notesController.dispose();

    if (data == null) return;

    try {
      await _client.from('nutrition_plan_meals').insert({
        'nutrition_plan_id': _selectedPlanId,
        ...data,
      });

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao adicionar refeição: $error');
      }
    }
  }

  Future<void> _addItem(String mealId) async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final notesController = TextEditingController();

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Adicionar alimento ou item'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Alimento ou item',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Unidade',
                            hintText: 'g, ml, unidade',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calorias',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: proteinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Proteína (g)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: carbsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Carboidrato (g)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: fatController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Gordura (g)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observações ou substituições',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  {
                    'item_name': nameController.text.trim(),
                    'category': categoryController.text.trim().isEmpty
                        ? null
                        : categoryController.text.trim(),
                    'quantity':
                        _nullableDouble(quantityController.text),
                    'unit': unitController.text.trim().isEmpty
                        ? null
                        : unitController.text.trim(),
                    'calories':
                        _nullableInt(caloriesController.text),
                    'protein_g':
                        _nullableDouble(proteinController.text),
                    'carbs_g':
                        _nullableDouble(carbsController.text),
                    'fat_g': _nullableDouble(fatController.text),
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  },
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    quantityController.dispose();
    unitController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    notesController.dispose();

    if (data == null) return;

    try {
      await _client.from('nutrition_plan_items').insert({
        'nutrition_plan_meal_id': mealId,
        ...data,
      });

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao adicionar alimento: $error');
      }
    }
  }

  Future<void> _addSupplement() async {
    if (_selectedPlanId == null) {
      setState(() {
        _error = 'Salve o plano antes de adicionar suplementos.';
      });
      return;
    }

    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final timingController = TextEditingController();
    final goalController = TextEditingController();
    final notesController = TextEditingController();

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Adicionar suplemento'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Suplemento',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosagem',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: timingController,
                    decoration: const InputDecoration(
                      labelText: 'Horário ou momento',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: goalController,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  {
                    'supplement_name': nameController.text.trim(),
                    'dosage': dosageController.text.trim().isEmpty
                        ? null
                        : dosageController.text.trim(),
                    'timing': timingController.text.trim().isEmpty
                        ? null
                        : timingController.text.trim(),
                    'goal': goalController.text.trim().isEmpty
                        ? null
                        : goalController.text.trim(),
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  },
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    dosageController.dispose();
    timingController.dispose();
    goalController.dispose();
    notesController.dispose();

    if (data == null) return;

    try {
      await _client.from('nutrition_plan_supplements').insert({
        'nutrition_plan_id': _selectedPlanId,
        ...data,
      });

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao adicionar suplemento: $error');
      }
    }
  }

  Future<void> _deleteMeal(String mealId) async {
    try {
      await _client
          .from('nutrition_plan_meals')
          .delete()
          .eq('id', mealId);

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao excluir refeição: $error');
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _client
          .from('nutrition_plan_items')
          .delete()
          .eq('id', itemId);

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao excluir alimento: $error');
      }
    }
  }

  Future<void> _deleteSupplement(String supplementId) async {
    try {
      await _client
          .from('nutrition_plan_supplements')
          .delete()
          .eq('id', supplementId);

      await _loadPlanChildren(_selectedPlanId!);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Erro ao excluir suplemento: $error');
      }
    }
  }

  Widget _card({
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelector() {
    final filteredPlans = _plans.where((plan) {
      return _text(plan['athlete_id']) == _selectedAthleteId;
    }).toList();

    return _card(
      title: 'Atleta e planos',
      actions: [
        FilledButton.icon(
          onPressed: _newPlan,
          icon: const Icon(Icons.add),
          label: const Text('Novo plano'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedAthleteId,
            decoration: const InputDecoration(
              labelText: 'Atleta',
              border: OutlineInputBorder(),
            ),
            items: _athletes.map((athlete) {
              final athleteId = _text(athlete['athlete_id']);

              return DropdownMenuItem(
                value: athleteId,
                child: Text(_athleteName(athlete)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAthleteId = value;
              });

              _newPlan();
            },
          ),
          const SizedBox(height: 16),
          if (filteredPlans.isEmpty)
            const Text('Nenhum plano encontrado para este atleta.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredPlans.map((plan) {
                final planId = _text(plan['nutrition_plan_id']);
                final selected = planId == _selectedPlanId;
                final title = _text(plan['title']);
                final status = _statusLabel(_text(plan['status']));

                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    '${title.isEmpty ? "Plano" : title} • $status',
                  ),
                  onSelected: (_) => _openPlan(plan),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanForm() {
    return _card(
      title: _selectedPlanId == null
          ? 'Novo plano nutricional'
          : 'Editar plano nutricional',
      actions: [
        if (_selectedPlanId != null)
          IconButton(
            tooltip: 'Excluir plano',
            onPressed: _deletePlan,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título do plano',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phaseController,
            decoration: const InputDecoration(
              labelText: 'Objetivo ou fase esportiva',
              hintText: 'Base, build, peak, taper, recuperação...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'draft',
                child: Text('Rascunho'),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text('Ativo'),
              ),
              DropdownMenuItem(
                value: 'archived',
                child: Text('Arquivado'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickValidFrom,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    'Início: ${_dateLabel(_validFrom)}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickValidUntil,
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    'Fim: ${_dateLabel(_validUntil)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Meta calórica diária',
                    suffixText: 'kcal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _hydrationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Meta de hidratação',
                    suffixText: 'ml',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Orientações gerais',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _savePlan,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _saving ? 'Salvando...' : 'Salvar plano',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeals() {
    return _card(
      title: 'Refeições',
      actions: [
        FilledButton.tonalIcon(
          onPressed: _selectedPlanId == null ? null : _addMeal,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar refeição'),
        ),
      ],
      child: _selectedPlanId == null
          ? const Text('Salve o plano para cadastrar as refeições.')
          : _meals.isEmpty
              ? const Text('Nenhuma refeição cadastrada.')
              : Column(
                  children: _meals.map((meal) {
                    final mealId = _text(meal['id']);
                    final items = _itemsByMeal[mealId] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(
                          _text(meal['meal_name']).isEmpty
                              ? 'Refeição'
                              : _text(meal['meal_name']),
                        ),
                        subtitle: Text(
                          [
                            if (_text(meal['scheduled_time']).isNotEmpty)
                              _text(meal['scheduled_time']),
                            if (_text(meal['goal']).isNotEmpty)
                              _text(meal['goal']),
                            '${items.length} item(ns)',
                          ].join(' • '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Excluir refeição',
                          onPressed: () => _deleteMeal(mealId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        children: [
                          if (_text(meal['notes']).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Orientação: ${_text(meal['notes'])}',
                                ),
                              ),
                            ),
                          ...items.map((item) {
                            final quantity =
                                _text(item['quantity']);
                            final unit = _text(item['unit']);

                            return ListTile(
                              title: Text(
                                _text(item['item_name']),
                              ),
                              subtitle: Text(
                                [
                                  if (quantity.isNotEmpty)
                                    '$quantity $unit'.trim(),
                                  if (_text(item['calories']).isNotEmpty)
                                    '${_text(item['calories'])} kcal',
                                  if (_text(item['protein_g']).isNotEmpty)
                                    'P: ${_text(item['protein_g'])}g',
                                  if (_text(item['carbs_g']).isNotEmpty)
                                    'C: ${_text(item['carbs_g'])}g',
                                  if (_text(item['fat_g']).isNotEmpty)
                                    'G: ${_text(item['fat_g'])}g',
                                ].join(' • '),
                              ),
                              trailing: IconButton(
                                tooltip: 'Excluir item',
                                onPressed: () => _deleteItem(
                                  _text(item['item_id']),
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _addItem(mealId),
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  'Adicionar alimento ou item',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildSupplements() {
    return _card(
      title: 'Suplementos',
      actions: [
        FilledButton.tonalIcon(
          onPressed:
              _selectedPlanId == null ? null : _addSupplement,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar suplemento'),
        ),
      ],
      child: _selectedPlanId == null
          ? const Text('Salve o plano para cadastrar suplementos.')
          : _supplements.isEmpty
              ? const Text('Nenhum suplemento cadastrado.')
              : Column(
                  children: _supplements.map((supplement) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.medication_outlined),
                      ),
                      title: Text(
                        _text(supplement['supplement_name']),
                      ),
                      subtitle: Text(
                        [
                          if (_text(supplement['dosage']).isNotEmpty)
                            'Dosagem: ${_text(supplement['dosage'])}',
                          if (_text(supplement['timing']).isNotEmpty)
                            'Momento: ${_text(supplement['timing'])}',
                          if (_text(supplement['goal']).isNotEmpty)
                            'Objetivo: ${_text(supplement['goal'])}',
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Excluir suplemento',
                        onPressed: () => _deleteSupplement(
                          _text(supplement['id']),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_allowed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Prescrição nutricional'),
          actions: const [
            AppLogoutButton(),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'A prescrição nutricional é exclusiva para profissionais '
              'cadastrados como nutricionistas.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Prescrição nutricional'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
          ),
          const AppLogoutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_athletes.isEmpty)
                _card(
                  title: 'Nenhum atleta vinculado',
                  child: const Text(
                    'O nutricionista precisa ter uma relação ativa com '
                    'o atleta antes de criar uma prescrição.',
                  ),
                )
              else ...[
                _buildPlanSelector(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1000) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPlanForm()),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                _buildMeals(),
                                _buildSupplements(),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildPlanForm(),
                        _buildMeals(),
                        _buildSupplements(),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
