class Classroom {
  const Classroom({required this.code, required this.name, this.studentCount, this.departmentCode});

  final String code;
  final String name;
  final int? studentCount;
  final String? departmentCode;

  factory Classroom.fromMap(Map<String, dynamic> map) => Classroom(
    code: (map['codClass'] ?? map['code'] ?? '').toString(),
    name: (map['nomClass'] ?? map['name'] ?? map['codClass'] ?? '').toString(),
    studentCount: _asInt(map['nbreEtud'] ?? map['studentCount']),
    departmentCode: (map['codDept'] ?? (map['departement'] is Map ? map['departement']['codDept'] : null))?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'codClass': code,
    'nomClass': name,
    if (studentCount != null) 'nbreEtud': studentCount,
    if (departmentCode != null) 'codDept': departmentCode,
  };
}

class Training {
  const Training({required this.id, required this.name, this.duration});

  final int? id;
  final String name;
  final int? duration;

  factory Training.fromMap(Map<String, dynamic> map) => Training(
    id: _asInt(map['id']),
    name: (map['nom'] ?? map['name'] ?? '').toString(),
    duration: _asInt(map['duree'] ?? map['duration']),
  );

  Map<String, dynamic> toMap() => {
    'nom': name,
    if (duration != null) 'duree': duration,
  };
}

class Student {
  const Student({
    this.id,
    required this.name,
    required this.firstName,
    this.birthDate,
    this.classCode,
    this.trainingId,
  });

  final int? id;
  final String name;
  final String firstName;
  final DateTime? birthDate;
  final String? classCode;
  final int? trainingId;

  factory Student.fromMap(Map<String, dynamic> map) {
    final classroom = map['classe'] is Map ? map['classe'] as Map : const {};
    final training = map['formation'] is Map
        ? map['formation'] as Map
        : const {};
    final dateValue =
        map['dateNais'] ?? map['dateNaissance'] ?? map['birthDate'];
    return Student(
      id: _asInt(map['id']),
      name: (map['nom'] ?? map['name'] ?? '').toString(),
      firstName: (map['prenom'] ?? map['firstName'] ?? '').toString(),
      birthDate: dateValue == null
          ? null
          : DateTime.tryParse(dateValue.toString()),
      classCode:
          (classroom['codClass'] ??
                  classroom['code'] ??
                  map['classe_cod_class'] ??
                  map['classCode'])
              ?.toString(),
      trainingId: _asInt(
        training['id'] ?? map['formation_id'] ?? map['trainingId'],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'nom': name,
    'prenom': firstName,
    if (birthDate != null) 'dateNais': _dateOnly(birthDate!),
    if (classCode != null) 'classe': {'codClass': classCode},
    if (trainingId != null) 'formation': {'id': trainingId},
  };
}

int? _asInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');
String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
