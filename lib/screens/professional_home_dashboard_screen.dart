import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_athlete_summary_screen.dart';
import 'coach_athlete_workouts_review_screen.dart';
import 'coach_create_workout_screen.dart';
import 'coach_requests_screen.dart';

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
  List<Map<String, dynamic>> _pendingRelations = [];
  Map<String, Map<String, dynamic>> _athleteProfiles = {};
  Map<String, List<Map<String, dynamic>>> _athleteWorkouts = {};
  Map<String, List<Map<String, dynamic>>> _athleteRaces = {};
  Map<String, List<Map<String, dynamic>>> _athleteInjuries = {};
  Map<String, List<Map<String, dynamic>>> _athleteWeeklyLoad = {};

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
      final allLinks = await _client
          .from('v_athlete_professional_links')
          .select()
          .eq('professional_id', user.id)
          .order('created_at', ascending: false);

      final all = (allLinks as List).cast<Map<String, dynamic>>();
      _activeRelations = all.where((e) => _s(e['status']) == 'active').toList();
      _pendingRelations =
          all.where((e) => _s(e['status']) == 'pending').toList();

      final athleteIds = _activeRelations
          .map((e) => _s(e['athlete_id']))
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      _athleteProfiles = {};
      _athleteWorkouts = {};
      _athleteRaces = {};
      _athleteInjuries = {};
      _athleteWeeklyLoad = {};

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

        final weeklyLoadRes = await _client
            .from('v_athlete_training_load_weekly')
            .select()
            .filter('athlete_id', 'in', quotedIds)
            .order('week_start', ascending: false);

        for (final row in (weeklyLoadRes as List).cast<Map<String, dynamic>>()) {
          final athleteId = _s(row['athlete_id']);
          _athleteWeeklyLoad.putIfAbsent(athleteId, () => []);
          _athleteWeeklyLoad[athleteId]!.add(row);
        }
      }
    } catch (e) {
      _msg = 'Erro ao carregar home do profissional: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        return raw.isEmpty ? '-' : raw;
    }
  }

  Map<String, dynamic> _loadSummaryForAthlete(String athleteId) {
    final rows = _athleteWeeklyLoad[athleteId] ?? [];
    int planned = 0;
    int executed = 0;
    int weak = 0;
    num plannedSec = 0;
    num executedSec = 0;

    for (final row in rows) {
      planned += _n(row['planned_sessions']).toInt();
      executed += _n(row['executed_sessions']).toInt();
      weak += _n(row['weak_feedback_count']).toInt();
      plannedSec += _n(row['planned_duration_sec']);
      executedSec += _n(row['executed_duration_sec']);
    }

    final adherence = planned == 0 ? 0.0 : (executed / planned) * 100;

    return {
      'planned_sessions': planned,
      'executed_sessions': executed,
      'weak_feedback': weak,
      'planned_duration_sec': plannedSec,
      'executed_duration_sec': executedSec,
      'adherence_pct': adherence,
    };
  }

  String _priorityLabel(String athleteId) {
    final load = _loadSummaryForAthlete(athleteId);
    final injuries = _athleteInjuries[athleteId] ?? [];
    final races = _athleteRaces[athleteId] ?? [];

    final hasWeakFeedback = (load['weak_feedback'] as int) > 0;
    final hasActiveInjury = injuries.any((i) {
      final status = _s(i['status']);
      return status == 'active' || status == 'monitoring';
    });

    final now = DateTime.now();
    final hasUpcomingRaceSoon = races.any((r) {
      final d = DateTime.tryParse(_s(r['race_date']));
      if (d == null) return false;
      final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
      return diff >= 0 && diff <= 21;
    });

    final adherence = load['adherence_pct'] as double;

    if (hasWeakFeedback || (hasUpcomingRaceSoon && hasActiveInjury) || adherence < 50) {
      return 'Perigo';
    }
    if (hasActiveInjury || hasUpcomingRaceSoon || adherence < 80) {
      return 'Atenção';
    }
    return 'OK';
  }

  Color _priorityColor(String label) {
    switch (label) {
      case 'Perigo':
        return Colors.red;
      case 'Atenção':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _latestFeedback(String athleteId) {
    final workouts = _athleteWorkouts[athleteId] ?? [];
    final withFeedback = workouts.where((w) => _s(w['athlete_feedback']).isNotEmpty).toList();
    if (withFeedback.isEmpty) return '-';
    withFeedback.sort(
      (a, b) => _dateText(b['scheduled_date']).compareTo(_dateText(a['scheduled_date'])),
    );
    return _feedbackLabel(_s(withFeedback.first['athlete_feedback']));
  }

  String _nextRace(String athleteId) {
    final races = _athleteRaces[athleteId] ?? [];
    final now = DateTime.now();
    final future = races.where((r) {
      final d = DateTime.tryParse(_s(r['race_date']));
      if (d == null) return false;
      return !d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    if (future.isEmpty) return '-';
    future.sort((a, b) => _s(a['race_date']).compareTo(_s(b['race_date'])));
    return '${_s(future.first['name']).isEmpty ? 'Prova' : _s(future.first['name'])} • ${_dateText(future.first['race_date'])}';
  }

  String _restrictionsSummary(String athleteId) {
    final items = _athleteInjuries[athleteId] ?? [];
    final active = items.where((i) {
      final status = _s(i['status']);
      return status == 'active' || status == 'monitoring';
    }).toList();

    if (active.isEmpty) return '-';
    final first = active.first;
    final title = _s(first['title']).isEmpty ? 'Restrição' : _s(first['title']);
    final region = _s(first['body_region']);
    return region.isEmpty ? title : '$title • $region';
  }

  Map<String, dynamic> _summaryCards() {
    int activeAthletes = _activeRelations.length;
    int pendingRequests = _pendingRelations.length;
    int danger = 0;
    int attention = 0;

    for (final relation in _activeRelations) {
      final athleteId = _s(relation['athlete_id']);
      final priority = _priorityLabel(athleteId);
      if (priority == 'Perigo') {
        danger++;
      } else if (priority == 'Atenção') {
        attention++;
      }
    }

    return {
      'active_athletes': activeAthletes,
      'pending_requests': pendingRequests,
      'danger': danger,
      'attention': attention,
    };
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
      width: 220,
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

  Widget _buildHeader() {
    return _section(
      title: 'Bem-vindo, ${widget.fullName}',
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoachRequestsScreen()),
            );
          },
          child: const Text('Solicitações e atletas'),
        ),
      ],
      child: const Text(
        'Faça a gestão geral do seu portfólio de atletas, priorizando quem precisa de acompanhamento imediato.',
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
          _metricCard('Atletas ativos', '${s['active_athletes']}', Icons.groups),
          _metricCard('Solicitações pendentes', '${s['pending_requests']}', Icons.mail_outline),
          _metricCard('Em perigo', '${s['danger']}', Icons.warning_amber),
          _metricCard('Em atenção', '${s['attention']}', Icons.visibility),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    if (_activeRelations.isEmpty) {
      return _section(
        title: 'Gestão do portfólio',
        child: const Text('Nenhum atleta ativo encontrado.'),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(_activeRelations)
      ..sort((a, b) {
        final ap = _priorityLabel(_s(a['athlete_id']));
        final bp = _priorityLabel(_s(b['athlete_id']));
        const weight = {'Perigo': 0, 'Atenção': 1, 'OK': 2};
        final aw = weight[ap] ?? 99;
        final bw = weight[bp] ?? 99;
        if (aw != bw) return aw.compareTo(bw);

        final an = _s(_athleteProfiles[_s(a['athlete_id'])]?['full_name']);
        final bn = _s(_athleteProfiles[_s(b['athlete_id'])]?['full_name']);
        return an.compareTo(bn);
      });

    return _section(
      title: 'Gestão do portfólio',
      child: Column(
        children: sorted.map((relation) {
          final athleteId = _s(relation['athlete_id']);
          final athleteName =
              _s(_athleteProfiles[athleteId]?['full_name']).isEmpty
                  ? 'Atleta'
                  : _s(_athleteProfiles[athleteId]?['full_name']);
          final athleteEmail = _s(_athleteProfiles[athleteId]?['email']);
          final priority = _priorityLabel(athleteId);
          final priorityColor = _priorityColor(priority);
          final feedback = _latestFeedback(athleteId);
          final nextRace = _nextRace(athleteId);
          final restriction = _restrictionsSummary(athleteId);
          final load = _loadSummaryForAthlete(athleteId);
          final planned = load['planned_sessions'] as int;
          final executed = load['executed_sessions'] as int;
          final adherence = load['adherence_pct'] as double;

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
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            athleteName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (athleteEmail.isNotEmpty) Text(athleteEmail),
                        ],
                      ),
                    ),
                    Expanded(child: Text('Feedback: $feedback')),
                    Expanded(flex: 2, child: Text('Prova próxima: $nextRace')),
                    Expanded(flex: 2, child: Text('Restrição/lesão: $restriction')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: priorityColor.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          color: priorityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text('Planejado: $planned'),
                    Text('Executado: $executed'),
                    Text('Aderência: ${adherence.toStringAsFixed(0)}%'),
                    Text('Horas plan.: ${(_n(load['planned_duration_sec']) / 3600).toStringAsFixed(1)}h'),
                    Text('Horas exec.: ${(_n(load['executed_duration_sec']) / 3600).toStringAsFixed(1)}h'),
                    Text('Feedback fraco: ${load['weak_feedback']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _openAthleteSummary(athleteId, athleteName),
                      child: const Text('Resumo do atleta'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _openCreateWorkout(athleteId, athleteName),
                      child: const Text('Criar treino'),
                    ),
                    FilledButton(
                      onPressed: () => _openWorkoutReview(athleteId, athleteName),
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

  @override
  Widget build(BuildContext context) {
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
                constraints: const BoxConstraints(maxWidth: 1400),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(),
                    _buildSummaryCards(),
                    _buildPortfolioSection(),
                    _section(
                      title: 'Próxima evolução do dashboard',
                      child: const Text(
                        'Próximo passo: indicadores musculares, alertas automáticos, exames/documentos e score de risco por prova.',
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
