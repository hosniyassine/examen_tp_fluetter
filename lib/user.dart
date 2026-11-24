class User {
  const User(this.id, this.email, {this.role = 'ADMIN', this.studentId, this.teacherId});

  final int? id;
  final String email;
  final String role;
  final int? studentId;
  final int? teacherId;

  factory User.fromMap(Map<String, dynamic> map) => User(
    map['id'] as int?,
    map['email']?.toString() ?? '',
    role: map['role']?.toString() ?? 'ADMIN',
    studentId: map['studentId'] as int?,
    teacherId: map['teacherId'] as int?,
  );
}
