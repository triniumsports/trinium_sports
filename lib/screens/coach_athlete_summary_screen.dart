import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachAthleteSummaryScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const CoachAthleteSummaryScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  State<CoachAthleteSummaryScreen> createState() =>
      _CoachAthleteSummaryScreenState();
}

class _CoachAthleteSummaryScreenState extends State<CoachAthleteSummaryScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _careTeam = [];
  List<Map<String, dynamic>> _injuries = [];
  List<Map<String, dynamic>> _publishedWorkouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();
  num _n(dynamic v) => v is num ? v : 0;

  String _dateText(dynamic v) {
    final s = _s(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _formatHours(num totalSec) =>
      '${(totalSec / 3600).toStringAsFixed(1)}h';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final results = await Future.wait([
        _client
            .from('v_athlete_global_summary')
            .select()
            .eq('athlete_id', widget.athleteId)
            .maybeSingle(),
        _client
            .from('v_athlete_care_team')
            .select()
            .eq('athlete_id', widget.athleteId)
            .order('role_type', ascending: true)
            .order('professional_name', ascending: true),
        _client
            .from('athlete_injuries_restrictions')
            .select()
            .eq('athlete_id', widget.athleteId)
            .order('created_at', ascending: false),
        _client
            .from('v_prescribed_workouts_mvp')
            .select()
            .eq('athlete_id', widget.athleteId)
            .eq('validation_status', 'published')
            .order('scheduled_date', ascending: true),
      ]);

      _summary = results[0] == null
          ? null
          : Map<String, dynamic>.from(results[0] as Map);
      _careTeam = (results[1] as List).cast<Map<String, dynamic>>();
      _injuries = (results[2] as List).cast<Map<String, dynamic>>();
      _publishedWorkouts = (results[3] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _msg = 'Erro ao carregar resumo do atleta: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String raw) {
    switch (raw) {
      case 'running_coach':
        return 'Treinador de Corrida';
      case 'strength_coach':
        return 'Preparador Físico';
      case 'nutritionist':
        return 'Nutricionista';
      case 'physiotherapist':
        return 'Fisioterapeuta';
      case 'swim_coach':
        return 'Treinador de Natação';
      case 'triathlon_coach':
        return 'Treinador de Triathlon';
      case 'trail_coach':
        return 'Treinador de Trail';
      case 'doctor':
        return 'Médico';
      case 'coach':
        return 'Coach';
      default:
        return raw.isEmpty ? 'Profissional' : raw;
    }
  }

  String _activityLabel(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('trail')) return 'Trail';
    if (v.contains('run') || v.contains('corr')) return 'Corrida';
    if (v.contains('swim') || v.contains('nata')) return 'Natação';
    if (v.contains('bike') || v.contains('cicl')) return 'Ciclismo';
    if (v.contains('strength') || v.contains('forca')) return 'Força';
    if (v.contains('triathlon')) return 'Triathlon';
    return raw.isEmpty ? 'Geral' : raw;
  }

  Map<String, dynamic> _workoutSummary() {
    int total = _publishedWorkouts.length;
    num totalDuration = 0;
    final Map<String, int> byActivity = {};

    for (final w in _publishedWorkouts) {
      final activity = _activityLabel(_s(w['activity_type_id']));
      final duration = _n(w['planned_duration_sec']);
      totalDuration += duration;
      byActivity[activity] = (byActivity[activity] ?? 0) + 1;
    }

    return {
      'total': total,
      'total_duration_sec': totalDuration,
      'by_activity': byActivity,
    };
  }

  Widget _metricCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAthleteSection() {
    final name = _s(_summary?['athlete_name']).isEmpty
        ? widget.athleteName
        : _s(_summary?['athlete_name']);
    final email = _s(_summary?['athlete_email']);
    final birthDate = _dateText(_summary?['birth_date']);
    final gender = _s(_summary?['gender']);
    final height = _s(_summary?['height_cm']);
    final weight = _s(_summary?['weight_kg']);
    final experience = _s(_summary?['experience_level']);
    final fitness = _s(_summary?['fitness_level']);
    final vo2 = _s(_summary?['vo2_max']);
    final restingHr = _s(_summary?['resting_hr']);
    final maxHr = _s(_summary?['max_hr']);
    final phase = _s(_summary?['phase']);
    final dietaryRestrictions = _s(_summary?['dietary_restrictions']);
    final garmin = _summary?['garmin_connected'] == true ? 'Sim' : 'Não';

    return _sectionContainer(
      title: 'Resumo global do atleta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(email),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Nascimento',
                value: birthDate.isEmpty ? '-' : birthDate,
                icon: Icons.cake,
              ),
              _metricCard(
                title: 'Gênero',
                value: gender.isEmpty ? '-' : gender,
                icon: Icons.person,
              ),
              _metricCard(
                title: 'Altura',
                value: height.isEmpty ? '-' : '$height cm',
                icon: Icons.height,
              ),
              _metricCard(
                title: 'Peso',
                value: weight.isEmpty ? '-' : '$weight kg',
                icon: Icons.monitor_weight,
              ),
              _metricCard(
                title: 'Nível',
                value: experience.isEmpty ? '-' : experience,
                icon: Icons.speed,
              ),
              _metricCard(
                title: 'Fitness level',
                value: fitness.isEmpty ? '-' : fitness,
                icon: Icons.insights,
              ),
              _metricCard(
                title: 'VO2 máx',
                value: vo2.isEmpty ? '-' : vo2,
                icon: Icons.favorite,
              ),
              _metricCard(
                title: 'FC repouso',
                value: restingHr.isEmpty ? '-' : restingHr,
                icon: Icons.favorite_border,
              ),
              _metricCard(
                title: 'FC máxima',
                value: maxHr.isEmpty ? '-' : maxHr,
                icon: Icons.monitor_heart,
              ),
              _metricCard(
                title: 'Fase',
                value: phase.isEmpty ? '-' : phase,
                icon: Icons.timeline,
              ),
              _metricCard(
                title: 'Garmin conectado',
                value: garmin,
                icon: Icons.watch,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Restrições alimentares',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(dietaryRestrictions.isEmpty ? '-' : dietaryRestrictions),
        ],
      ),
    );
  }

  Widget _buildCareTeamSection() {
    if (_careTeam.isEmpty) {
      return _sectionContainer(
        title: 'Time de cuidado',
        child: const Text('Nenhum profissional ativo encontrado.'),
      );
    }

    return _sectionContainer(
      title: 'Time de cuidado',
      child: Column(
        children: _careTeam.map((row) {
          final name = _s(row['professional_name']).isEmpty
              ? 'Profissional'
              : _s(row['professional_name']);
          final email = _s(row['professional_email']);
          final phone = _s(row['phone_mobile']);
          final role = _roleLabel(_s(row['role_type']));

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F7F9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(role),
                if (email.isNotEmpty) Text('E-mail: $email'),
                if (phone.isNotEmpty) Text('Telefone: $phone'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInjuriesSection() {
    if (_injuries.isEmpty) {
      return _sectionContainer(
        title: 'Restrições físicas / lesões',
        child: const Text('Nenhuma restrição ou lesão cadastrada.'),
      );
    }

    return _sectionContainer(
      title: 'Restrições físicas / lesões',
      child: Column(
        children: _injuries.map((row) {
          final type = _s(row['restriction_type']);
          final title = _s(row['title']).isEmpty ? 'Registro' : _s(row['title']);
          final bodyRegion = _s(row['body_region']);
          final severity = _s(row['severity']);
          final status = _s(row['status']);
          final startDate = _dateText(row['start_date']);
          final expectedEndDate = _dateText(row['expected_end_date']);
          final notes = _s(row['notes']);
          final recommendations = _s(row['recommendations']);

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF7F7F9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (type.isNotEmpty) Text('Tipo: $type'),
                    if (bodyRegion.isNotEmpty) Text('Região: $bodyRegion'),
                    if (severity.isNotEmpty) Text('Severidade: $severity'),
                    if (status.isNotEmpty) Text('Status: $status'),
                    if (startDate.isNotEmpty) Text('Início: $startDate'),
                    if (expectedEndDate.isNotEmpty)
                      Text('Fim previsto: $expectedEndDate'),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Obs: $notes'),
                ],
                if (recommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Recomendações: $recommendations'),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkoutsSection() {
    final summary = _workoutSummary();
    final byActivity = (summary['by_activity'] as Map<String, int>);

    return _sectionContainer(
      title: 'Treinos publicados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                title: 'Total publicados',
                value: '${summary['total']}',
                icon: Icons.publish,
              ),
              _metricCard(
                title: 'Carga publicada',
                value: _formatHours(_n(summary['total_duration_sec'])),
                icon: Icons.timer,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Distribuição por atividade',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (byActivity.isEmpty)
            const Text('Sem treinos publicados.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byActivity.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE9EDF5),
                  ),
                  child: Text('${entry.key}: ${entry.value}'),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          if (_publishedWorkouts.isEmpty)
            const Text('Nenhum treino publicado encontrado.')
          else
            Column(
              children: _publishedWorkouts.take(12).map((w) {
                final title =
                    _s(w['title']).isEmpty ? 'Treino' : _s(w['title']);
                final date = _dateText(w['scheduled_date']);
                final activity = _activityLabel(_s(w['activity_type_id']));
                final professional = _s(w['professional_name']);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text('Data: $date'),
                          Text('Atividade: $activity'),
                          if (professional.isNotEmpty)
                            Text('Profissional: $professional'),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Resumo de ${widget.athleteName}'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAthleteSection(),
                _buildCareTeamSection(),
                _buildInjuriesSection(),
                _buildWorkoutsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
