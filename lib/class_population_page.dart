import 'package:flutter/material.dart';

import 'api_service.dart';

class ClassPopulationPage extends StatefulWidget {
  const ClassPopulationPage({super.key, required this.api});
  final ApiService api;

  @override
  State<ClassPopulationPage> createState() => _ClassPopulationPageState();
}

class _ClassPopulationPageState extends State<ClassPopulationPage> {
  List<Map<String, dynamic>> classes = [];
  int? maximum;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.tp7Get('/tp7/effectifs/maximales');
      classes = (data['classes'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      maximum = (data['maxEffectif'] as num?)?.toInt();
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _update(Map<String, dynamic> item) async {
    setState(() => loading = true);
    try {
      final result = await widget.api.tp7Save(
        '/tp7/effectifs/${Uri.encodeComponent(item['codClass'].toString())}',
        const {},
        method: 'PUT',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Effectif mis à jour pour ${result['codClass']} : ${result['nbrEtud']} étudiants.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (classes.isEmpty) {
      return const Center(child: Text('Aucune classe n’est enregistrée.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Effectif maximal réel : $maximum étudiant${maximum == 1 ? '' : 's'}. Le calcul utilise les étudiants enregistrés, et non la valeur stockée dans la classe.',
            ),
          ),
        ),
        for (final item in classes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['nomClass']} (${item['codClass']})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Département : ${item['nomDept'] ?? item['codDept'] ?? '—'}',
                  ),
                  Text(
                    'Nombre réel d’étudiants (COUNT) : ${item['nombreEtudiants']}',
                  ),
                  Text(
                    'Valeur enregistrée dans NbrEtud : ${item['nbrEtud'] ?? 'non renseignée'}',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _update(item),
                      icon: const Icon(Icons.sync),
                      label: const Text('Mettre à jour l’effectif'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
