import 'package:flutter/material.dart';

import 'api_service.dart';

class AbsenceForecastPage extends StatefulWidget {
  const AbsenceForecastPage({super.key, required this.api});
  final ApiService api;

  @override
  State<AbsenceForecastPage> createState() => _AbsenceForecastPageState();
}

class _AbsenceForecastPageState extends State<AbsenceForecastPage> {
  List<Map<String, dynamic>> classes = [], subjects = [], students = [];
  final Map<int, TextEditingController> hours = {};
  String? classCode, subjectCode, error;
  DateTime date = DateTime.now();
  Map<String, dynamic>? details;
  bool loading = true, loadingRows = false, saving = false;

  String get dateValue =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    for (final controller in hours.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      classes = await widget.api.tp7List('/tp7/classes');
      classCode = classes.isEmpty ? null : classes.first['codClass'].toString();
      await _loadSubjects();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadSubjects() async {
    if (classCode == null) {
      subjects = [];
      subjectCode = null;
      students = [];
      details = null;
      return;
    }
    try {
      subjects = await widget.api.tp7List(
        '/tp7/matieres?codClass=${Uri.encodeQueryComponent(classCode!)}',
      );
      subjectCode = subjects.isEmpty
          ? null
          : subjects.first['codMat'].toString();
      await _loadForecast();
    } catch (e) {
      error = '$e';
      subjects = [];
      subjectCode = null;
      students = [];
      details = null;
    }
  }

  Future<void> _loadForecast() async {
    if (classCode == null || subjectCode == null) {
      students = [];
      details = null;
      _replaceHours(const []);
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      loadingRows = true;
      error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          'codClass': classCode!,
          'codMat': subjectCode!,
          'dateA': dateValue,
        },
      ).query;
      details = await widget.api.tp7Get('/tp7/absences/prevision?$query');
      students = (details!['students'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _replaceHours(students);
    } catch (e) {
      error = '$e';
      students = [];
      details = null;
      _replaceHours(const []);
    } finally {
      if (mounted) setState(() => loadingRows = false);
    }
  }

  void _replaceHours(List<Map<String, dynamic>> rows) {
    for (final controller in hours.values) {
      controller.dispose();
    }
    hours
      ..clear()
      ..addEntries(
        rows.map((row) {
          final id = row['nce'] as int;
          return MapEntry(
            id,
            TextEditingController(text: (row['nha'] ?? 0).toString()),
          );
        }),
      );
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => date = selected);
    await _loadForecast();
  }

  Future<void> _save() async {
    final values = <Map<String, dynamic>>[];
    for (final student in students) {
      final id = student['nce'] as int;
      final value = double.tryParse(hours[id]!.text.replaceAll(',', '.'));
      if (value == null || !value.isFinite || value < 0) {
        _message(
          'Saisissez un nombre d’heures positif ou nul pour chaque étudiant.',
          true,
        );
        return;
      }
      values.add({'nce': id, 'nha': value});
    }
    if (classCode == null || subjectCode == null || values.isEmpty) {
      _message(
        'Sélectionnez une classe avec au moins un étudiant et une matière.',
        true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final result = await widget.api.tp7Save('/tp7/absences/prevision', {
        'codClass': classCode,
        'codMat': subjectCode,
        'dateA': dateValue,
        'students': values,
      });
      if (!mounted) return;
      _message('${result['enregistrees']} absence(s) enregistrée(s).');
      await _loadForecast();
    } catch (e) {
      _message('$e', true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String message, [bool isError = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('forecast-class-$classCode'),
          initialValue: classCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Classe'),
          items: classes
              .map(
                (c) => DropdownMenuItem(
                  value: c['codClass'].toString(),
                  child: Text('${c['nomClass']} (${c['codClass']})'),
                ),
              )
              .toList(),
          onChanged: (value) async {
            setState(() {
              classCode = value;
              subjectCode = null;
              details = null;
              error = null;
            });
            await _loadSubjects();
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('forecast-subject-$subjectCode'),
          initialValue: subjectCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Matière'),
          items: subjects
              .map(
                (s) => DropdownMenuItem(
                  value: s['codMat'].toString(),
                  child: Text('${s['intMat']} (${s['codMat']})'),
                ),
              )
              .toList(),
          onChanged: (value) async {
            setState(() => subjectCode = value);
            await _loadForecast();
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _detail('Classe', details?['nomClass'] ?? classCode ?? '—'),
                _detail(
                  'Département',
                  details?['nomDept'] ?? details?['codDept'] ?? '—',
                ),
                _detail('Matière', details?['intMat'] ?? '—'),
                _detail(
                  'CHSM',
                  details == null ? '—' : '${details!['chsm']} heures',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Date de la séance'),
            subtitle: Text(dateLabel),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _chooseDate,
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        if (loadingRows)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucun étudiant à afficher pour cette sélection.'),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Prévision des absences',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nom')),
                  DataColumn(label: Text('Prénom')),
                  DataColumn(label: Text('NHA')),
                ],
                rows: students.map((student) {
                  final id = student['nce'] as int;
                  return DataRow(
                    cells: [
                      DataCell(Text('${student['nom']}')),
                      DataCell(Text('${student['prenom']}')),
                      DataCell(
                        SizedBox(
                          width: 88,
                          child: TextField(
                            controller: hours[id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              saving ? 'Enregistrement…' : 'Enregistrer les absences',
            ),
          ),
        ],
      ],
    );
  }

  Widget _detail(String label, String value) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
