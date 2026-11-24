import 'package:flutter/material.dart';

import 'api_service.dart';
import 'models.dart';
import 'user.dart';

class AcademicGradesPage extends StatefulWidget {
  const AcademicGradesPage({super.key, required this.api, required this.user});
  final ApiService api;
  final User user;

  @override
  State<AcademicGradesPage> createState() => _AcademicGradesPageState();
}

class _AcademicGradesPageState extends State<AcademicGradesPage> {
  late final TextEditingController _year;
  final TextEditingController _search = TextEditingController();
  List<Classroom> _classes = [];
  List<Map<String, dynamic>> _teacherLinks = [];
  List<Map<String, dynamic>> _results = [];
  String? _classCode;
  int _semester = 1;
  bool _loading = true;
  bool _error = false;

  bool get _student => widget.user.role == 'STUDENT';
  bool get _admin => widget.user.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = now.month >= 9 ? now.year : now.year - 1;
    _year = TextEditingController(text: '$start-${start + 1}');
    _load();
  }

  @override
  void dispose() {
    _year.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_student) {
        _results = [
          await widget.api.tp7Get(
            '/tp7/mes-resultats?anneeUniversitaire=${Uri.encodeQueryComponent(_year.text)}&semestre=$_semester',
          ),
        ];
      } else if (_admin) {
        _classes = await widget.api.getClasses();
        _classCode ??= _classes.isEmpty ? null : _classes.first.code;
        await _loadClassResults();
      } else {
        _teacherLinks = await widget.api.tp7List(
          '/tp7/enseignants/moi/classes',
        );
        final codes = _teacherLinks
            .map((v) => v['codClass'].toString())
            .toSet();
        _classes = codes.map((code) {
          final row = _teacherLinks.firstWhere((v) => v['codClass'] == code);
          return Classroom(code: code, name: row['nomClass'].toString());
        }).toList();
        _classCode ??= _classes.isEmpty ? null : _classes.first.code;
        await _loadClassResults();
      }
    } catch (_) {
      _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClassResults() async {
    if (_classCode == null) {
      _results = [];
      return;
    }
    final query = _search.text.trim();
    final path =
        '/tp7/resultats?codClass=${Uri.encodeQueryComponent(_classCode!)}'
        '&anneeUniversitaire=${Uri.encodeQueryComponent(_year.text)}&semestre=$_semester'
        '${query.isEmpty ? '' : '&recherche=${Uri.encodeQueryComponent(query)}'}';
    _results = await widget.api.tp7List(path);
  }

  Future<void> _selectPeriod({
    String? codClass,
    String? year,
    int? semester,
  }) async {
    if (codClass != null || _classCode != null) {
      _classCode = codClass ?? _classCode;
    }
    if (year != null) _year.text = year;
    if (semester != null) _semester = semester;
    await _load();
  }

  Future<void> _edit(
    Map<String, dynamic> student,
    Map<String, dynamic> subject,
  ) async {
    final editor = await showDialog<_EvaluationDraft>(
      context: context,
      builder: (_) => _EvaluationDialog(
        student: student,
        subject: subject,
        year: _year.text,
        semester: _semester,
      ),
    );
    if (editor == null) return;
    final nce = student['nce'];
    final codMat = subject['codMat'].toString();
    final exists = subject['saisieExiste'] == true;
    final path = exists
        ? '/tp7/evaluations/$nce/${Uri.encodeComponent(codMat)}/${Uri.encodeComponent(_year.text)}/$_semester'
        : '/tp7/evaluations';
    try {
      await widget.api.tp7Save(path, {
        'nce': nce,
        'codMat': codMat,
        'anneeUniversitaire': _year.text,
        'semestre': _semester,
        'tp1': editor.tp1,
        'tp2': editor.tp2,
        'ds': editor.ds,
        'examen': editor.exam,
      }, method: exists ? 'PUT' : 'POST');
      _message('Notes enregistrées.');
      await _load();
    } catch (e) {
      _message('$e', error: true);
    }
  }

  Future<void> _delete(
    Map<String, dynamic> student,
    Map<String, dynamic> subject,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la saisie ?'),
        content: Text(
          'Les notes de ${subject['intMat']} pour cette période seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.tp7Delete(
        '/tp7/evaluations/${student['nce']}/${Uri.encodeComponent(subject['codMat'].toString())}/${Uri.encodeComponent(_year.text)}/$_semester',
      );
      await _load();
    } catch (e) {
      _message('$e', error: true);
    }
  }

  bool _canEdit(String codClass, String codMat) =>
      _admin ||
      _teacherLinks.any(
        (v) => v['codClass'] == codClass && v['codMat'] == codMat,
      );

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Impossible de charger les résultats.'),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_student && _results.isNotEmpty && _results.first['nce'] == null) {
      return const Center(
        child: Text('Ce compte n’est pas encore associé à un étudiant.'),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!_student)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: _classCode,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.code,
                            child: Text('${c.name} (${c.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => _selectPeriod(codClass: v),
                  ),
                ),
              SizedBox(
                width: 145,
                child: TextFormField(
                  controller: _year,
                  decoration: const InputDecoration(
                    labelText: 'Année universitaire',
                  ),
                  onFieldSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                width: 145,
                child: DropdownButtonFormField<int>(
                  initialValue: _semester,
                  decoration: const InputDecoration(labelText: 'Semestre'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Semestre 1')),
                    DropdownMenuItem(value: 2, child: Text('Semestre 2')),
                  ],
                  onChanged: (v) => _selectPeriod(semester: v),
                ),
              ),
              if (!_student)
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Rechercher',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchResults,
                      ),
                    ),
                    onSubmitted: (_) => _searchResults(),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Text('Aucun résultat pour cette sélection.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: _results.length,
                  itemBuilder: (context, index) =>
                      _studentCard(_results[index]),
                ),
        ),
      ],
    );
  }

  Future<void> _searchResults() async {
    setState(() => _loading = true);
    try {
      await _loadClassResults();
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _studentCard(Map<String, dynamic> summary) {
    final average = summary['moyenneGenerale'];
    final subjects = (summary['matieres'] as List? ?? const [])
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(
          '${summary['nce']} • ${summary['prenom']} ${summary['nom']}',
        ),
        subtitle: Text(
          'Classe ${summary['codClass']} • Moyenne générale : ${average == null ? 'En attente' : '$average / 20'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${summary['matieresCompletes']} matières complètes • ${summary['matieresIncompletes']} en attente • ${summary['matieresValidees']} validées • ${summary['matieresNonValidees']} non validées',
              ),
            ),
          ),
          ...subjects.map((subject) {
            final editable =
                !_student &&
                subject['hasTp'] != null &&
                _canEdit(
                  summary['codClass'].toString(),
                  subject['codMat'].toString(),
                );
            final exists = subject['saisieExiste'] == true;
            return ListTile(
              title: Text(
                '${subject['intMat']} (${subject['codMat']}) • Coef. ${subject['coef']}',
              ),
              subtitle: Text(
                subject['hasTp'] == null
                    ? 'Type de matière à configurer avant la saisie.'
                    : '${subject['hasTp'] == true ? 'TP1 ${subject['tp1'] ?? '—'} • TP2 ${subject['tp2'] ?? '—'} • ' : ''}DS ${subject['ds'] ?? '—'} • Examen ${subject['examen'] ?? '—'} • ${subject['etat'] == 'VALIDEE'
                          ? 'Validée'
                          : subject['etat'] == 'NON_VALIDEE'
                          ? 'Non validée'
                          : 'En attente'}',
              ),
              trailing: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    subject['moyenne'] == null
                        ? '—'
                        : '${subject['moyenne']} / 20',
                  ),
                  if (editable)
                    IconButton(
                      tooltip: exists ? 'Modifier' : 'Saisir',
                      icon: Icon(exists ? Icons.edit_outlined : Icons.add),
                      onPressed: () => _edit(summary, subject),
                    ),
                  if (editable && exists)
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(summary, subject),
                    ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Résultat final : ${summary['resultatFinal'] == 'VALIDE'
                    ? 'Validé'
                    : summary['resultatFinal'] == 'NON_VALIDE'
                    ? 'Non validé'
                    : 'En attente'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: summary['resultatFinal'] == 'VALIDE'
                      ? Colors.green.shade800
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManualGradeEntryPage extends StatefulWidget {
  const ManualGradeEntryPage({super.key, required this.api});
  final ApiService api;

  @override
  State<ManualGradeEntryPage> createState() => _ManualGradeEntryPageState();
}

class _ManualGradeEntryPageState extends State<ManualGradeEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _year;
  final _tp1 = TextEditingController();
  final _tp2 = TextEditingController();
  final _ds = TextEditingController();
  final _exam = TextEditingController();
  List<Classroom> _classes = [];
  List<Student> _students = [];
  List<Map<String, dynamic>> _subjects = [];
  String? _classCode;
  int? _studentId;
  String? _subjectCode;
  int _semester = 1;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _evaluation;
  bool _hasSavedEvaluation = false;
  bool _editing = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _requestId = 0;

  Student? get _student =>
      _students.where((s) => s.id == _studentId).firstOrNull;
  Map<String, dynamic>? get _subject => _subjects
      .where((s) => s['codMat']?.toString() == _subjectCode)
      .firstOrNull;
  bool get _hasTp => _subject?['hasTp'] == true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = today.month >= 9 ? today.year : today.year - 1;
    _year = TextEditingController(text: '$start-${start + 1}');
    _loadClasses();
  }

  @override
  void dispose() {
    _year.dispose();
    _tp1.dispose();
    _tp2.dispose();
    _ds.dispose();
    _exam.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _classes = await widget.api.getClasses();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectClass(String? code) async {
    final request = ++_requestId;
    setState(() {
      _classCode = code;
      _studentId = null;
      _subjectCode = null;
      _students = [];
      _subjects = [];
      _summary = null;
      _evaluation = null;
      _hasSavedEvaluation = false;
      _editing = true;
      _loading = true;
      _error = null;
    });
    if (code == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        widget.api.getStudents(),
        widget.api.tp7List(
          '/tp7/matieres?codClass=${Uri.encodeQueryComponent(code)}',
        ),
      ]);
      if (!mounted || request != _requestId) return;
      _students = (results[0] as List<Student>)
          .where((s) => s.classCode == code)
          .toList();
      _subjects = results[1] as List<Map<String, dynamic>>;
    } catch (e) {
      if (mounted && request == _requestId) _error = '$e';
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _selectStudent(int? id) async {
    _requestId++;
    setState(() {
      _studentId = id;
      _subjectCode = null;
      _summary = null;
      _evaluation = null;
      _hasSavedEvaluation = false;
      _editing = true;
    });
    _clearFields();
    if (id != null && _subjectCode != null) await _loadSelectedPeriod();
  }

  Future<void> _selectSubject(String? code) async {
    _requestId++;
    setState(() {
      _subjectCode = code;
      _evaluation = null;
      _hasSavedEvaluation = false;
      _editing = true;
      _summary = null;
    });
    _clearFields();
    if (_studentId != null && code != null) await _loadSelectedPeriod();
  }

  Future<void> _selectPeriod({String? year, int? semester}) async {
    _requestId++;
    if (year != null) _year.text = year.trim();
    if (semester != null) _semester = semester;
    setState(() {
      _summary = null;
      _evaluation = null;
      _hasSavedEvaluation = false;
      _editing = true;
    });
    _clearFields();
    if (_studentId != null && _subjectCode != null) {
      await _loadSelectedPeriod();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSelectedPeriod() async {
    final id = _studentId;
    final subjectCode = _subjectCode;
    final year = _year.text.trim();
    if (id == null || subjectCode == null) return;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.api.tp7Get(
        '/tp7/resultats/$id?anneeUniversitaire=${Uri.encodeQueryComponent(year)}&semestre=$_semester',
      );
      if (!mounted || request != _requestId) return;
      final rows = (value['matieres'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row));
      _summary = value;
      _evaluation = rows
          .where((row) => row['codMat']?.toString() == subjectCode)
          .firstOrNull;
      _hasSavedEvaluation = _evaluation?['saisieExiste'] == true;
      _editing = !_hasSavedEvaluation;
      _fillFields(_evaluation);
    } catch (e) {
      if (mounted && request == _requestId) _error = '$e';
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  void _fillFields(Map<String, dynamic>? row) {
    _tp1.text = row?['tp1']?.toString() ?? '';
    _tp2.text = row?['tp2']?.toString() ?? '';
    _ds.text = row?['ds']?.toString() ?? '';
    _exam.text = row?['examen']?.toString() ?? '';
  }

  void _clearFields() => _fillFields(null);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final student = _student;
    final subject = _subject;
    final studentId = student?.id;
    if (studentId == null || subject == null) return;
    final wasSaved = _hasSavedEvaluation;
    setState(() => _saving = true);
    final year = _year.text.trim();
    final uriCode = Uri.encodeComponent(_subjectCode!);
    final path = wasSaved
        ? '/tp7/evaluations/$studentId/$uriCode/${Uri.encodeComponent(year)}/$_semester'
        : '/tp7/evaluations';
    try {
      await widget.api.tp7Save(path, {
        'nce': studentId,
        'codMat': _subjectCode,
        'anneeUniversitaire': year,
        'semestre': _semester,
        'tp1': _hasTp ? _parseGrade(_tp1) : null,
        'tp2': _hasTp ? _parseGrade(_tp2) : null,
        'ds': _parseGrade(_ds),
        'examen': _parseGrade(_exam),
      }, method: wasSaved ? 'PUT' : 'POST');
      await _loadSelectedPeriod();
      if (mounted) {
        _message(
          wasSaved
              ? 'Notes modifiées et moyennes recalculées.'
              : 'Notes enregistrées et moyennes calculées.',
        );
      }
    } catch (e) {
      if (mounted) _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _parseGrade(TextEditingController controller) =>
      controller.text.trim().isEmpty
      ? null
      : double.parse(controller.text.trim().replaceAll(',', '.'));

  String? _validateGrade(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || value < 0 || value > 20
        ? 'Saisissez une note entre 0 et 20.'
        : null;
  }

  void _cancel() {
    if (_hasSavedEvaluation) {
      _fillFields(_evaluation);
      setState(() => _editing = false);
    } else {
      _clearFields();
      setState(() => _editing = true);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _loadClasses, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    final subject = _subject;
    final selectedStudent = _student;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Saisie manuelle des notes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 190,
              child: TextFormField(
                controller: _year,
                decoration: const InputDecoration(
                  labelText: 'Année universitaire',
                  hintText: '2026-2027',
                ),
                onFieldSubmitted: (value) => _selectPeriod(year: value),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int>(
                key: ValueKey('semester-$_semester'),
                initialValue: _semester,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semestre'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Semestre 1')),
                  DropdownMenuItem(value: 2, child: Text('Semestre 2')),
                ],
                onChanged: (value) {
                  if (value != null) _selectPeriod(semester: value);
                },
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                key: ValueKey('class-$_classCode'),
                initialValue: _classCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Classe'),
                hint: const Text('Choisir une classe'),
                items: _classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.code,
                        child: Text('${c.name} (${c.code})'),
                      ),
                    )
                    .toList(),
                onChanged: _selectClass,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                key: ValueKey('student-$_classCode-$_studentId'),
                initialValue: _studentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Étudiant'),
                hint: const Text('Choisir un étudiant'),
                items: _students
                    .where((s) => s.id != null)
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.firstName} ${s.name}'),
                      ),
                    )
                    .toList(),
                onChanged: _classCode == null ? null : _selectStudent,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: ValueKey('subject-$_classCode-$_subjectCode'),
                initialValue: _subjectCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Matière'),
                hint: const Text('Choisir une matière'),
                items: _subjects
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['codMat'].toString(),
                        child: Text('${s['intMat']} (${s['codMat']})'),
                      ),
                    )
                    .toList(),
                onChanged: _studentId == null ? null : _selectSubject,
              ),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        if (_classCode != null && _subjects.isEmpty && !_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Aucune matière associée à cette classe.'),
          ),
        if (selectedStudent != null && subject != null) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedStudent.firstName} ${selectedStudent.name} • ${subject['intMat']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Année ${_year.text} • Semestre $_semester • Coefficient ${subject['coef'] ?? '—'}',
                  ),
                  if (subject['hasTp'] == null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Configurez d’abord le type de cette matière dans Gestion des matières (Avec TP : Oui ou Non), puis revenez ici.',
                    ),
                  ] else if (_hasSavedEvaluation && !_editing)
                    _savedGradeView()
                  else
                    _gradeForm(),
                ],
              ),
            ),
          ),
        ],
        if (_summary != null) ...[
          const SizedBox(height: 20),
          Text(
            'Récapitulatif des matières',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ..._summaryRows(),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              title: const Text(
                'Moyenne générale pondérée',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                _summary!['moyenneGenerale'] == null
                    ? 'En attente'
                    : '${_summary!['moyenneGenerale']} / 20',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Résultat : ${_statusLabel(_summary!['resultatFinal'])}',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _gradeForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (_hasTp) ...[
          _gradeField(_tp1, 'TP1 / 20'),
          _gradeField(_tp2, 'TP2 / 20'),
        ],
        _gradeField(_ds, 'DS / 20'),
        _gradeField(_exam, 'Examen / 20'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Enregistrement…'
                    : _hasSavedEvaluation
                    ? 'Modifier'
                    : 'Enregistrer',
              ),
            ),
            OutlinedButton(
              onPressed: _saving ? null : _cancel,
              child: const Text('Annuler'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _gradeField(TextEditingController controller, String label) =>
      SizedBox(
        width: 220,
        child: TextFormField(
          controller: controller,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: _validateGrade,
        ),
      );

  Widget _savedGradeView() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            if (_hasTp)
              Text(
                'TP1 : ${_evaluation?['tp1'] ?? '—'} • TP2 : ${_evaluation?['tp2'] ?? '—'}',
              ),
            Text('DS : ${_evaluation?['ds'] ?? '—'}'),
            Text('Examen : ${_evaluation?['examen'] ?? '—'}'),
            Text('Moyenne : ${_evaluation?['moyenne'] ?? 'En attente'}'),
            Text('Statut : ${_statusLabel(_evaluation?['etat'])}'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Modifier'),
            ),
            TextButton(onPressed: _cancel, child: const Text('Annuler')),
          ],
        ),
      ],
    ),
  );

  List<Widget> _summaryRows() {
    final rows = (_summary?['matieres'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row));
    return [
      Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Matière')),
              DataColumn(label: Text('TP1')),
              DataColumn(label: Text('TP2')),
              DataColumn(label: Text('DS')),
              DataColumn(label: Text('Examen')),
              DataColumn(label: Text('Moyenne')),
              DataColumn(label: Text('Coefficient')),
              DataColumn(label: Text('Statut')),
            ],
            rows: rows.map((row) {
              final withTp = row['hasTp'] == true;
              String score(String key) =>
                  row[key] == null ? '—' : '${row[key]}';
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      row['intMat']?.toString() ??
                          row['codMat']?.toString() ??
                          '',
                    ),
                  ),
                  DataCell(Text(withTp ? score('tp1') : '—')),
                  DataCell(Text(withTp ? score('tp2') : '—')),
                  DataCell(Text(score('ds'))),
                  DataCell(Text(score('examen'))),
                  DataCell(
                    Text(
                      row['moyenne'] == null
                          ? 'En attente'
                          : '${row['moyenne']}',
                    ),
                  ),
                  DataCell(Text('${row['coef'] ?? '—'}')),
                  DataCell(Text(_statusLabel(row['etat']))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ];
  }

  String _statusLabel(dynamic value) => switch (value?.toString()) {
    'VALIDEE' || 'VALIDE' => 'Validée',
    'NON_VALIDEE' || 'NON_VALIDE' => 'Non validée',
    _ => 'En attente',
  };
}

class _EvaluationDraft {
  const _EvaluationDraft(this.tp1, this.tp2, this.ds, this.exam);
  final double? tp1, tp2, ds, exam;
}

class _EvaluationDialog extends StatefulWidget {
  const _EvaluationDialog({
    required this.student,
    required this.subject,
    required this.year,
    required this.semester,
  });
  final Map<String, dynamic> student, subject;
  final String year;
  final int semester;
  @override
  State<_EvaluationDialog> createState() => _EvaluationDialogState();
}

class _EvaluationDialogState extends State<_EvaluationDialog> {
  final _key = GlobalKey<FormState>();
  late final _tp1 = TextEditingController(
    text: widget.subject['tp1']?.toString(),
  );
  late final _tp2 = TextEditingController(
    text: widget.subject['tp2']?.toString(),
  );
  late final _ds = TextEditingController(
    text: widget.subject['ds']?.toString(),
  );
  late final _exam = TextEditingController(
    text: widget.subject['examen']?.toString(),
  );
  @override
  void dispose() {
    _tp1.dispose();
    _tp2.dispose();
    _ds.dispose();
    _exam.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.replaceAll(',', '.'));
    return n == null || n < 0 || n > 20
        ? 'Entrez une note entre 0 et 20.'
        : null;
  }

  double? _parse(TextEditingController c) => c.text.trim().isEmpty
      ? null
      : double.parse(c.text.trim().replaceAll(',', '.'));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.student['prenom']} ${widget.student['nom']} • ${widget.subject['intMat']}',
    ),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.year} • Semestre ${widget.semester}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.subject['hasTp'] == true) ...[
                TextFormField(
                  controller: _tp1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'TP1 / 20'),
                  validator: _validate,
                ),
                TextFormField(
                  controller: _tp2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'TP2 / 20'),
                  validator: _validate,
                ),
              ],
              TextFormField(
                controller: _ds,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'DS / 20'),
                validator: _validate,
              ),
              TextFormField(
                controller: _exam,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Examen / 20'),
                validator: _validate,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(
            context,
            _EvaluationDraft(
              widget.subject['hasTp'] == true ? _parse(_tp1) : null,
              widget.subject['hasTp'] == true ? _parse(_tp2) : null,
              _parse(_ds),
              _parse(_exam),
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}
