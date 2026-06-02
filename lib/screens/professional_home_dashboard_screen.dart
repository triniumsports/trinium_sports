import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_athlete_summary_screen.dart';
import 'coach_athlete_workouts_review_screen.dart';
import 'coach_create_workout_screen.dart';

class ProfessionalHomeDashboardScreen extends StatefulWidget {
  final String fullName;

  const ProfessionalHomeDashboardScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<ProfessionalHomeDashboardScreen> createState() =>
      _ProfessionalHomeDashboardScreenState();
}

class _ProfessionalHomeDashboardScreenState
    extends State<ProfessionalHomeDashboardScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _msg;

  List<Map<String, dynamic>> _activeRelations = [];
  Map<String, Map<String, dynamic>> _athleteProfiles = {};
  Map<String, Map<String, dynamic>> _athleteSummaries = {};
  Map<String, List<Map<String, dynamic>>> _athleteWorkouts = {};
  Map<String, List<Map<String, dynamic>>> _athleteRaces = {};
  Map<String, List<Map<String, dynamic>>> _athleteInjuries = {};

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
    if (v.contains('swimrun')) return 'Swimrun';
    return raw.isEmpty ? 'Geral' : raw;
  }

  String _feedbackLabel(String raw) {
    switch (raw) {
      case 'weak':
        return 'Fraco';
      case 'normal':
        return 'Normal';
      case 'strong':
        return 'Forte';
      case 'very_strong':
        return 'Muito Forte';
      default:
        return raw;
    }
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _msg = 'Usuário não autenticado.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final links = await _client
          .from('v_athlete_professional_links')
          .select()
          .eq('professional_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      _activeRelations = (links as List).cast<Map<String, dynamic>>();

      final athleteIds = _activeRelations
          .map((e) => _s(e['athlete_id']))
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      _athleteProfiles = {};
      _athleteSummaries = {};
      _athleteWorkouts = {};
      _athleteRaces = {};
      _athleteInjuries = {};

      if (athleteIds.isNotEmpty) {
        final quotedIds = '(${athleteIds.map((e) => '"$e"').join(',')})';

        final profilesRes = await _client
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .filter('id', 'in', quotedIds);

        for (final row in (profilesRes as List).cast<Map<String, dynamic>>()) {
          final id = _s(row['id']);
          if (id.isNotEmpty) _athleteProfiles[id] = row;
        }

        final summariesRes = await _client
            .from('v_athlete_global_summary')
            .select()
            .filter('athlete_id', 'in', quotedIds);

        for (final row in (summariesRes as List).cast<Map<String, dynamic>>()) {
          final id = _s(row['athlete_id']);
          if (id.isNotEmpty) _athleteSummaries[id] = row;
        }

        final workoutsRes = await _client
            .from('v_prescribed_workouts_mvp')
            .select()
            .filter('athlete_id', 'in', quotedIds)
            .order('scheduled_date', ascending: true);

        for (final row in (workoutsRes as List).cast<Map<String, dynamic>>()) {
          final athleteId = _s(row['athlete_id']);
          _athleteWorkouts.putIfAbsent(athleteId, () => []);
          _athleteWorkouts[athleteId]!.add(row);
        }

        final racesRes = await _client
            .from('target_races')
            .select()
            .filter('athlete_id', 'in', quotedIds)
            .order('race_date', ascending: true);

        for (final row in (racesRes as List).cast<Map<String, dynamic>>()) {
          final athleteId = _s(row['athlete_id']);
          _athleteRaces.putIfAbsent(athleteId, () => []);
          _athleteRaces[athleteId]!.add(row);
        }

        final injuriesRes = await _client
            .from('athlete_injuries_restrictions')
            .select()
            .filter('athlete_id', 'in', quotedIds)
            .order('created_at', ascending: false);

        for (final row in (injuriesRes as List).cast<Map<String, dynamic>>()) {
          final athleteId = _s(row['athlete_id']);
          _athleteInjuries.putIfAbsent(athleteId, () => []);
          _athleteInjuries[athleteId]!.add(row);
        }
      }
    } catch (e) {
      _msg = 'Erro ao carregar home do profissional: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _summaryCards() {
    int activeAthletes = _activeRelations.length;
    int upcomingRaces = 0;
    int weakFeedbacks = 0;
    int activeRestrictions = 0;

    final now = DateTime.now();

    for (final entry in _athleteRaces.entries) {
      for (final race in entry.value) {
        final date = DateTime.tryParse(_s(race['race_date']));
        if (date != null && !date.isBefore(DateTime(now.year, now.month, now.day))) {
          upcomingRaces++;
        }
      }
    }

    for (final entry in _athleteWorkouts.entries) {
      for (final w in entry.value) {
        final feedback = _s(w['athlete_feedback']);
        if (feedback == 'weak') weakFeedbacks++;
      }
    }

    for (final entry in _athleteInjuries.entries) {
      for (final injury in entry.value) {
        final status = _s(injury['status']);
        if (status == 'active' || status == 'monitoring') {
          activeRestrictions++;
        }
      }
    }

    return {
      'active_athletes': activeAthletes,
      'upcoming_races': upcomingRaces,
      'weak_feedbacks': weakFeedbacks,
      'active_restrictions': activeRestrictions,
    };
  }

  List<Map<String, dynamic>> _upcomingRacesFlat() {
    final items = <Map<String, dynamic>>[];
    for (final relation in _activeRelations) {
      final athleteId = _s(relation['athlete_id']);
      final athleteName =
          _s(_athleteProfiles[athleteId]?['full_name']).isEmpty
              ? 'Atleta'
              : _s(_athleteProfiles[athleteId]?['full_name']);
      for (final race in (_athleteRaces[athleteId] ?? [])) {
        items.add({
          'athlete_id': athleteId,
          'athlete_name': athleteName,
          ...race,
        });
      }
    }

    items.sort((a, b) => _s(a['race_date']).compareTo(_s(b['race_date'])));
    return items.take(8).toList();
  }

  List<Map<String, dynamic>> _feedbacksFlat() {
    final items = <Map<String, dynamic>>[];
    for (final relation in _activeRelations) {
      final athleteId = _s(relation['athlete_id']);
      final athleteName =
          _s(_athleteProfiles[athleteId]?['full_name']).isEmpty
              ? 'Atleta'
              : _s(_athleteProfiles[athleteId]?['full_name']);
      for (final w in (_athleteWorkouts[athleteId] ?? [])) {
        final feedback = _s(w['athlete_feedback']);
        if (feedback.isNotEmpty) {
          items.add({
            'athlete_id': athleteId,
            'athlete_name': athleteName,
            ...w,
          });
        }
      }
    }

    items.sort((a, b) => _dateText(b['scheduled_date']).compareTo(_dateText(a['scheduled_date'])));
    return items.take(8).toList();
  }

  List<Map<String, dynamic>> _restrictionsFlat() {
    final items = <Map<String, dynamic>>[];
    for (final relation in _activeRelations) {
      final athleteId = _s(relation['athlete_id']);
      final athleteName =
          _s(_athleteProfiles[athleteId]?['full_name']).isEmpty
              ? 'Atleta'
              : _s(_athleteProfiles[athleteId]?['full_name']);
      for (final item in (_athleteInjuries[athleteId] ?? [])) {
        final status = _s(item['status']);
        if (status == 'active' || status == 'monitoring') {
          items.add({
            'athlete_id': athleteId,
            'athlete_name': athleteName,
            ...item,
          });
        }
      }
    }
    return items.take(8).toList();
  }

  Widget _section({
    required String title,
    required Widget child,
    List<Widget>? actions,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7F7F9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
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

  void _openAthleteSummary(String athleteId, String athleteName) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CoachAthleteSummaryScreen(
          athleteId: athleteId,
          athleteName: athleteName,
        ),
      ),
    )
        .then((_) => _load());
  }

  void _openCreateWorkout(String athleteId, String athleteName) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CoachCreateWorkoutScreen(
          initialAthleteId: athleteId,
          initialAthleteName: athleteName,
        ),
      ),
    )
        .then((_) => _load());
  }

  void _openWorkoutReview(String athleteId, String athleteName) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CoachAthleteWorkoutsReviewScreen(
          athleteId: athleteId,
          athleteName: athleteName,
        ),
      ),
    )
        .then((_) => _load());
  }

  Widget _buildHeader() {
    return _section(
      title: 'Bem-vindo, ${widget.fullName}',
      child: const Text(
        'Acompanhe sua carteira de atletas, feedbacks, provas próximas e restrições relevantes em um único dashboard.',
      ),
    );
  }

  Widget _buildSummaryCards() {
    final s = _summaryCards();

    return _section(
      title: 'Visão geral',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricCard(
            'Atletas ativos',
            '${s['active_athletes']}',
            Icons.groups,
          ),
          _metricCard(
            'Provas próximas',
            '${s['upcoming_races']}',
            Icons.flag,
          ),
          _metricCard(
            'Feedbacks fracos',
            '${s['weak_feedbacks']}',
            Icons.warning_amber,
          ),
          _metricCard(
            'Restrições ativas',
            '${s['active_restrictions']}',
            Icons.health_and_safety,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAthletesSection() {
    return _section(
      title: 'Atletas ativos',
      actions: [
        FilledButton.tonal(
          onPressed: _load,
          child: const Text('Atualizar'),
        ),
      ],
      child: _activeRelations.isEmpty
          ? const Text('Nenhum atleta ativo encontrado.')
          : Column(
              children: _activeRelations.map((relation) {
                final athleteId = _s(relation['athlete_id']);
                final athleteName =
                    _s(_athleteProfiles[athleteId]?['full_name']).isEmpty
                        ? 'Atleta'
                        : _s(_athleteProfiles[athleteId]?['full_name']);
                final athleteEmail = _s(_athleteProfiles[athleteId]?['email']);
                final avatar = _s(_athleteProfiles[athleteId]?['avatar_url']);
                final role = _roleLabel(_s(relation['role_type']));
                final workoutCount = (_athleteWorkouts[athleteId] ?? []).length;
                final racesCount = (_athleteRaces[athleteId] ?? []).length;
                final injuriesCount = (_athleteInjuries[athleteId] ?? []).length;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  athleteName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(role),
                                if (athleteEmail.isNotEmpty) Text(athleteEmail),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tinyChip('Treinos: $workoutCount'),
                          _tinyChip('Provas: $racesCount'),
                          _tinyChip('Restrições: $injuriesCount'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                _openAthleteSummary(athleteId, athleteName),
                            child: const Text('Resumo'),
                          ),
                          FilledButton.tonal(
                            onPressed: () =>
                                _openCreateWorkout(athleteId, athleteName),
                            child: const Text('Criar treino'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                _openWorkoutReview(athleteId, athleteName),
                            child: const Text('Ver treinos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _tinyChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFE9EDF5),
      ),
      child: Text(text),
    );
  }

  Widget _buildUpcomingRacesSection() {
    final races = _upcomingRacesFlat();

    return _section(
      title: 'Provas próximas',
      child: races.isEmpty
          ? const Text('Nenhuma prova próxima encontrada.')
          : Column(
              children: races.map((race) {
                final athleteId = _s(race['athlete_id']);
                final athleteName = _s(race['athlete_name']);
                final raceName =
                    _s(race['name']).isEmpty ? 'Prova' : _s(race['name']);
                final raceDate = _dateText(race['race_date']);
                final activity = _activityLabel(_s(race['activity_type_id']));

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              raceName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Atleta: $athleteName'),
                            Text('Data: $raceDate'),
                            Text('Modalidade: $activity'),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            _openAthleteSummary(athleteId, athleteName),
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFeedbacksSection() {
    final feedbacks = _feedbacksFlat();

    return _section(
      title: 'Feedbacks recentes',
      child: feedbacks.isEmpty
          ? const Text('Nenhum feedback recente encontrado.')
          : Column(
              children: feedbacks.map((item) {
                final athleteId = _s(item['athlete_id']);
                final athleteName = _s(item['athlete_name']);
                final title =
                    _s(item['title']).isEmpty ? 'Treino' : _s(item['title']);
                final feedback = _feedbackLabel(_s(item['athlete_feedback']));
                final feedbackNotes = _s(item['athlete_feedback_notes']);
                final date = _dateText(item['scheduled_date']);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Atleta: $athleteName'),
                            Text('Data: $date'),
                            Text('Feedback: $feedback'),
                            if (feedbackNotes.isNotEmpty)
                              Text('Obs: $feedbackNotes'),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            _openWorkoutReview(athleteId, athleteName),
                        child: const Text('Ver'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRestrictionsSection() {
    final items = _restrictionsFlat();

    return _section(
      title: 'Restrições / lesões relevantes',
      child: items.isEmpty
          ? const Text('Nenhuma restrição relevante encontrada.')
          : Column(
              children: items.map((item) {
                final athleteId = _s(item['athlete_id']);
                final athleteName = _s(item['athlete_name']);
                final title =
                    _s(item['title']).isEmpty ? 'Registro' : _s(item['title']);
                final region = _s(item['body_region']);
                final status = _s(item['status']);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF7F7F9),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('Atleta: $athleteName'),
                            if (region.isNotEmpty) Text('Região: $region'),
                            if (status.isNotEmpty) Text('Status: $status'),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            _openAthleteSummary(athleteId, athleteName),
                        child: const Text('Abrir'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    Widget content;
    if (isDesktop) {
      content = Column(
        children: [
          _buildHeader(),
          _buildSummaryCards(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildActiveAthletesSection(),
                    _buildFeedbacksSection(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildUpcomingRacesSection(),
                    _buildRestrictionsSection(),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = Column(
        children: [
          _buildHeader(),
          _buildSummaryCards(),
          _buildActiveAthletesSection(),
          _buildUpcomingRacesSection(),
          _buildFeedbacksSection(),
          _buildRestrictionsSection(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Home do Profissional'),
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
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    content,
                    _section(
                      title: 'Próxima evolução do dashboard',
                      child: const Text(
                        'Próximo passo: consolidar indicadores de carga, alertas automáticos, documentos/exames e visão por profissional/modalidade.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
