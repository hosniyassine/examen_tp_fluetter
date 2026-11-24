import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api_service.dart';
import 'models.dart';
import 'user.dart';
import 'academic_grades_page.dart';
import 'user_administration_page.dart';
import 'absence_forecast_page.dart';
import 'class_population_page.dart';

void main() => runApp(const Tp7App());

class Tp7App extends StatelessWidget {
  const Tp7App({super.key, this.api});

  final ApiService? api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gestion scolaire',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff3d795f),
        primary: const Color(0xff3d795f),
      ),
      scaffoldBackgroundColor: const Color(0xfff6f8f6),
      textTheme: GoogleFonts.robotoTextTheme(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffdce5df)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffdce5df)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff3d795f), width: 1.5),
        ),
      ),
    ),
    home: LoginPage(api: api ?? ApiService()),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api});
  final ApiService api;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final user = await widget.api.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardPage(api: widget.api, user: user),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red.shade700 : null,
          ),
        );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 54,
                    color: Color(0xff3d795f),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gestion scolaire',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connectez-vous à votre espace',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 28),
                  _AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Connexion',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _emailValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Saisissez votre mot de passe.'
                              : null,
                          onFieldSubmitted: (_) => _signIn(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterPage(api: widget.api),
                              ),
                            ),
                            child: const Text('Créer un compte'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _busy ? null : _signIn,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(_busy ? 'Connexion…' : 'Se connecter'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Service : ${widget.api.baseUrl}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.api});
  final ApiService api;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.api.register(_email.text.trim(), _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé. Vous pouvez vous connecter.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Créer un compte')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Inscription',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value == null || value.length < 4
                          ? 'Utilisez au moins 4 caractères.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Les mots de passe ne correspondent pas.'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _register,
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Text('Créer mon compte'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('J’ai déjà un compte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, required this.user});
  final ApiService api;
  final User user;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _Section _section = _Section.home;
  @override
  void initState() {
    super.initState();
    if (widget.user.role != 'ADMIN') _section = _Section.grades;
  }

  void _select(_Section section) {
    setState(() => _section = section);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_section) {
      _Section.home => 'Tableau de bord',
      _Section.students => 'Gestion des étudiants',
      _Section.classes => 'Gestion des classes',
      _Section.trainings => 'Gestion des formations',
      _Section.absences => 'Gestion des absences',
      _Section.absenceForecast => 'Prévision des absences',
      _Section.classPopulation => 'Effectif des classes',
      _Section.subjects => 'Gestion des matières',
      _Section.departments => 'Gestion des départements',
      _Section.grades => 'Gestion des notes',
      _Section.users => 'Comptes et enseignants',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                color: const Color(0xffd9f0df),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(height: 12),
                    Text(
                      widget.user.email,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      widget.user.role == 'ADMIN'
                          ? 'Espace administration'
                          : widget.user.role == 'TEACHER'
                          ? 'Espace enseignant'
                          : 'Espace étudiant',
                    ),
                  ],
                ),
              ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Accueil',
                  selected: _section == _Section.home,
                  onTap: () => _select(_Section.home),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.people_outline,
                  label: 'Étudiants',
                  selected: _section == _Section.students,
                  onTap: () => _select(_Section.students),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.class_outlined,
                  label: 'Classes',
                  selected: _section == _Section.classes,
                  onTap: () => _select(_Section.classes),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Formations',
                  selected: _section == _Section.trainings,
                  onTap: () => _select(_Section.trainings),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.event_busy_outlined,
                  label: 'Absences',
                  selected: _section == _Section.absences,
                  onTap: () => _select(_Section.absences),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.event_available_outlined,
                  label: 'Prévision des absences',
                  selected: _section == _Section.absenceForecast,
                  onTap: () => _select(_Section.absenceForecast),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.groups_outlined,
                  label: 'Effectif des classes',
                  selected: _section == _Section.classPopulation,
                  onTap: () => _select(_Section.classPopulation),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Matières',
                  selected: _section == _Section.subjects,
                  onTap: () => _select(_Section.subjects),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.account_tree_outlined,
                  label: 'Départements',
                  selected: _section == _Section.departments,
                  onTap: () => _select(_Section.departments),
                ),
              if (widget.user.role == 'ADMIN')
                _DrawerItem(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Comptes et enseignants',
                  selected: _section == _Section.users,
                  onTap: () => _select(_Section.users),
                ),
              _DrawerItem(
                icon: Icons.grade_outlined,
                label: widget.user.role == 'STUDENT'
                    ? 'Mes résultats'
                    : widget.user.role == 'ADMIN'
                    ? 'Gestion des notes'
                    : 'Notes et résultats',
                selected: _section == _Section.grades,
                onTap: () => _select(_Section.grades),
              ),
              _DrawerItem(
                icon: Icons.logout,
                label: 'Déconnexion',
                onTap: () async {
                  await widget.api.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => LoginPage(api: widget.api),
                    ),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: _section == _Section.absences
          ? AbsencePage(api: widget.api)
          : _section == _Section.absenceForecast
          ? AbsenceForecastPage(api: widget.api)
          : _section == _Section.classPopulation
          ? ClassPopulationPage(api: widget.api)
          : _section == _Section.grades
          ? _GradeCenterPage(api: widget.api, user: widget.user)
          : _section == _Section.users
          ? UserAdministrationPage(api: widget.api)
          : {_Section.subjects, _Section.departments}.contains(_section)
          ? _AdminCatalogPage(api: widget.api, section: _section)
          : _section == _Section.home
          ? _DashboardHome(
              user: widget.user,
              onStudents: () => setState(() => _section = _Section.students),
              onClasses: () => setState(() => _section = _Section.classes),
              onTrainings: () => setState(() => _section = _Section.trainings),
            )
          : _ManagementPage(
              key: ValueKey(_section),
              api: widget.api,
              section: _section,
            ),
    );
  }
}

enum _Section {
  home,
  students,
  classes,
  trainings,
  absences,
  absenceForecast,
  classPopulation,
  subjects,
  departments,
  grades,
  users,
}

class _GradeCenterPage extends StatelessWidget {
  const _GradeCenterPage({required this.api, required this.user});
  final ApiService api;
  final User user;
  @override
  Widget build(BuildContext context) {
    if (user.role != 'ADMIN') return AcademicGradesPage(api: api, user: user);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Saisie des notes'),
              Tab(text: 'Résultats'),
              Tab(text: 'Notes historiques'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ManualGradeEntryPage(api: api),
                AcademicGradesPage(api: api, user: user),
                _AdminCatalogPage(api: api, section: _Section.grades),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.user,
    required this.onStudents,
    required this.onClasses,
    required this.onTrainings,
  });
  final User user;
  final VoidCallback onStudents;
  final VoidCallback onClasses;
  final VoidCallback onTrainings;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xffe7f5e9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bienvenue', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              user.email,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gérez les étudiants, les classes et les formations depuis le menu.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.people_outline)),
          title: const Text('Gestion des étudiants'),
          subtitle: const Text('Choisir une classe et gérer ses étudiants'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onStudents,
        ),
      ),
      Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.class_outlined)),
          title: Text('Classes'),
          subtitle: Text('Consulter et modifier les classes'),
          onTap: onClasses,
        ),
      ),
      Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.menu_book_outlined)),
          title: Text('Formations'),
          subtitle: Text('Consulter et modifier les formations'),
          onTap: onTrainings,
        ),
      ),
    ],
  );
}

class _ManagementPage extends StatefulWidget {
  const _ManagementPage({super.key, required this.api, required this.section});
  final ApiService api;
  final _Section section;
  @override
  State<_ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<_ManagementPage> {
  late Future<_ManagementData> _data;
  String? _selectedClass;
  String? _selectedDepartment;
  bool _classSelectionInitialized = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    late final Future<_ManagementData> request;
    switch (widget.section) {
      case _Section.students:
        request =
            Future.wait([
              widget.api.getClasses(),
              widget.api.getTrainings(),
              widget.api.getStudents(),
            ]).then(
              (values) => _ManagementData(
                values[0] as List<Classroom>,
                values[1] as List<Training>,
                values[2] as List<Student>,
              ),
            );
      case _Section.classes:
        request =
            Future.wait([widget.api.getClasses(), widget.api.getDepartments()])
                .then(
                  (values) => _ManagementData(
                    values[0] as List<Classroom>,
                    [],
                    [],
                    values[1] as List<Map<String, dynamic>>,
                  ),
                );
      case _Section.trainings:
        request = widget.api.getTrainings().then(
          (trainings) => _ManagementData([], trainings, []),
        );
      case _Section.home:
      case _Section.absences:
      case _Section.absenceForecast:
      case _Section.classPopulation:
      case _Section.subjects:
      case _Section.departments:
      case _Section.grades:
      case _Section.users:
        request = Future.value(const _ManagementData([], [], []));
    }
    _data = request.then((data) {
      if (widget.section == _Section.students) {
        final classes = data.classes;
        if (!_classSelectionInitialized) {
          _selectedClass = classes.isEmpty ? null : classes.first.code;
          _classSelectionInitialized = true;
        }
      }
      return data;
    });
    setState(() {});
  }

  Future<void> _edit(
    _ManagementData data, {
    Classroom? classroom,
    Training? training,
    Student? student,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        api: widget.api,
        section: widget.section,
        data: data,
        classroom: classroom,
        training: training,
        student: student,
        selectedClass: _selectedClass,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(
    _ManagementData data, {
    Classroom? classroom,
    Training? training,
    Student? student,
  }) async {
    final label =
        classroom?.name ??
        training?.name ??
        '${student?.firstName} ${student?.name}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer « $label » ?'),
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
      if (classroom != null) {
        await widget.api.deleteClass(classroom.code);
      } else if (training != null) {
        final id = training.id;
        if (id == null) {
          throw const ApiException(
            'La formation reçue du serveur ne contient pas son identifiant.',
          );
        }
        await widget.api.deleteTraining(id);
      } else if (student != null) {
        final id = student.id;
        if (id == null) {
          throw const ApiException(
            'L’étudiant reçu du serveur ne contient pas son identifiant.',
          );
        }
        await widget.api.deleteStudent(id);
      }
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ManagementData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          message: snapshot.error.toString(),
          onRetry: _refresh,
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final students = data.students
          .where(
            (item) =>
                _selectedClass == null || item.classCode == _selectedClass,
          )
          .toList();
      final shownClasses = data.classes
          .where(
            (c) =>
                _selectedDepartment == null ||
                c.departmentCode == _selectedDepartment,
          )
          .toList();
      return Column(
        children: [
          if (widget.section == _Section.classes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Département'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tous les départements'),
                  ),
                  ...data.departments.map(
                    (d) => DropdownMenuItem(
                      value: d['codDept'].toString(),
                      child: Text('${d['nomDept']} (${d['codDept']})'),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedDepartment = value),
              ),
            ),
          if (widget.section == _Section.students)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedClass,
                decoration: const InputDecoration(
                  labelText: 'Classe',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Toutes les classes'),
                  ),
                  ...data.classes.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.code,
                      child: Text('${item.name} (${item.code})'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedClass = value),
              ),
            ),
          Expanded(child: _buildList(context, data, students, shownClasses)),
        ],
      );
    },
  );

  Widget _buildList(
    BuildContext context,
    _ManagementData data,
    List<Student> students,
    List<Classroom> shownClasses,
  ) {
    final Widget empty;
    final List<Widget> rows = [];
    switch (widget.section) {
      case _Section.students:
        empty = const _EmptyState(
          icon: Icons.people_outline,
          text: 'Aucun étudiant pour cette classe.',
        );
        for (final item in students) {
          rows.add(
            _RecordCard(
              title: '${item.firstName} ${item.name}',
              subtitle:
                  '${item.classCode ?? 'Sans classe'}${item.birthDate == null ? '' : ' • ${item.birthDate!.day}/${item.birthDate!.month}/${item.birthDate!.year}'}',
              onEdit: () => _edit(data, student: item),
              onDelete: () => _delete(data, student: item),
            ),
          );
        }
      case _Section.classes:
        empty = const _EmptyState(
          icon: Icons.class_outlined,
          text: 'Aucune classe enregistrée.',
        );
        for (final item in shownClasses) {
          rows.add(
            _RecordCard(
              title: item.name,
              subtitle:
                  '${item.code} • ${data.departments.where((d) => d['codDept'] == item.departmentCode).map((d) => d['nomDept']).firstOrNull ?? item.departmentCode ?? 'Sans département'} • ${item.studentCount ?? 0} étudiants',
              onEdit: () => _edit(data, classroom: item),
              onDelete: () => _delete(data, classroom: item),
            ),
          );
        }
      case _Section.trainings:
        empty = const _EmptyState(
          icon: Icons.menu_book_outlined,
          text: 'Aucune formation enregistrée.',
        );
        for (final item in data.trainings) {
          rows.add(
            _RecordCard(
              title: item.name,
              subtitle: item.duration == null
                  ? 'Durée non précisée'
                  : '${item.duration} mois',
              onEdit: () => _edit(data, training: item),
              onDelete: () => _delete(data, training: item),
            ),
          );
        }
      case _Section.home:
      case _Section.absences:
      case _Section.absenceForecast:
      case _Section.classPopulation:
      case _Section.subjects:
      case _Section.departments:
      case _Section.grades:
      case _Section.users:
        empty = const SizedBox.shrink();
    }
    return Stack(
      children: [
        rows.isEmpty
            ? empty
            : RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: rows,
                ),
              ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _edit(data),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
      ],
    );
  }
}

class _ManagementData {
  const _ManagementData(
    this.classes,
    this.trainings,
    this.students, [
    this.departments = const [],
  ]);
  final List<Classroom> classes;
  final List<Training> trainings;
  final List<Student> students;
  final List<Map<String, dynamic>> departments;
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.api,
    required this.section,
    required this.data,
    this.classroom,
    this.training,
    this.student,
    this.selectedClass,
  });
  final ApiService api;
  final _Section section;
  final _ManagementData data;
  final Classroom? classroom;
  final Training? training;
  final Student? student;
  final String? selectedClass;
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.classroom?.code,
  );
  late final TextEditingController _className = TextEditingController(
    text: widget.classroom?.name,
  );
  late final TextEditingController _trainingName = TextEditingController(
    text: widget.training?.name,
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.training?.duration?.toString(),
  );
  late final TextEditingController _studentName = TextEditingController(
    text: widget.student?.name,
  );
  late final TextEditingController _firstName = TextEditingController(
    text: widget.student?.firstName,
  );
  String? _classCode;
  String? _departmentCode;
  int? _trainingId;
  DateTime? _birthDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _classCode =
        widget.student?.classCode ??
        widget.selectedClass ??
        (widget.data.classes.isEmpty ? null : widget.data.classes.first.code);
    _departmentCode =
        widget.classroom?.departmentCode ??
        (widget.data.departments.isEmpty
            ? null
            : widget.data.departments.first['codDept']?.toString());
    _trainingId =
        widget.student?.trainingId ??
        (widget.data.trainings.isEmpty ? null : widget.data.trainings.first.id);
    _birthDate = widget.student?.birthDate;
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _className,
      _trainingName,
      _duration,
      _studentName,
      _firstName,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.section == _Section.classes) {
        await widget.api.saveClass(
          Classroom(
            code: _code.text.trim(),
            name: _className.text.trim(),
            departmentCode: _departmentCode,
          ),
          oldCode: widget.classroom?.code,
        );
      }
      if (widget.section == _Section.trainings) {
        await widget.api.saveTraining(
          Training(
            id: widget.training?.id,
            name: _trainingName.text.trim(),
            duration: int.tryParse(_duration.text),
          ),
          id: widget.training?.id,
        );
      }
      if (widget.section == _Section.students) {
        if (_classCode == null) {
          throw const ApiException(
            'Créez une classe avant d’ajouter un étudiant.',
          );
        }
        await widget.api.saveStudent(
          Student(
            id: widget.student?.id,
            name: _studentName.text.trim(),
            firstName: _firstName.text.trim(),
            birthDate: _birthDate,
            classCode: _classCode,
            trainingId: _trainingId,
          ),
          id: widget.student?.id,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing =
        widget.classroom != null ||
        widget.training != null ||
        widget.student != null;
    return AlertDialog(
      title: Text(
        '${editing ? 'Modifier' : 'Ajouter'} ${switch (widget.section) {
          _Section.students => 'un étudiant',
          _Section.classes => 'une classe',
          _Section.trainings => 'une formation',
          _Section.absences => 'une absence',
          _Section.subjects => 'une matière',
          _Section.departments => 'un département',
          _Section.grades => 'une note',
          _ => 'un élément',
        }}',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.section == _Section.classes) ...[
                  TextFormField(
                    controller: _code,
                    enabled: widget.classroom == null,
                    decoration: const InputDecoration(
                      labelText: 'Code de la classe',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _className,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la classe',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _departmentCode,
                    decoration: const InputDecoration(labelText: 'Département'),
                    items: widget.data.departments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['codDept'].toString(),
                            child: Text('${d['nomDept']} (${d['codDept']})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _departmentCode = v),
                    validator: (v) =>
                        v == null ? 'Sélectionnez un département.' : null,
                  ),
                ],
                if (widget.section == _Section.trainings) ...[
                  TextFormField(
                    controller: _trainingName,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la formation',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois)',
                    ),
                    validator: (value) =>
                        value == null || int.tryParse(value) == null
                        ? 'Saisissez une durée en mois.'
                        : null,
                  ),
                ],
                if (widget.section == _Section.students) ...[
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _studentName,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _classCode,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: widget.data.classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.code,
                            child: Text('${c.name} (${c.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _classCode = v),
                    validator: (value) =>
                        value == null ? 'Sélectionnez une classe.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _trainingId,
                    decoration: const InputDecoration(labelText: 'Formation'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucune'),
                      ),
                      ...widget.data.trainings
                          .where((t) => t.id != null)
                          .map(
                            (t) => DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          ),
                    ],
                    onChanged: (v) => setState(() => _trainingId = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _birthDate ?? DateTime(2005),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _birthDate = date);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _birthDate == null
                          ? 'Date de naissance (facultative)'
                          : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });
  final String title, subtitle;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Modifier')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    selected: selected,
    onTap: onTap,
  );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xffd9f0df),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .09),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text('Impossible de charger les données'),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text(text),
      ],
    ),
  );
}

String? _emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Saisissez votre adresse e-mail.';
  }
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est obligatoire.' : null;

class AbsencePage extends StatefulWidget {
  const AbsencePage({super.key, required this.api});
  final ApiService api;
  @override
  State<AbsencePage> createState() => _AbsencePageState();
}

class _AbsencePageState extends State<AbsencePage> {
  List<Map<String, dynamic>> departments = [],
      classes = [],
      students = [],
      absences = [],
      totals = [];
  String? dept, classCode;
  int? nce;
  bool loading = true;
  bool showChart = false;

  double get allAbsenceHours => totals.fold<double>(
    0,
    (sum, item) => sum + (item['totalNha'] as num).toDouble(),
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      departments = await widget.api.tp7List('/tp7/departements');
      if (dept == null && departments.isNotEmpty) {
        dept = departments.first['codDept'] as String;
      }
      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadClasses() async {
    classes = dept == null
        ? []
        : await widget.api.tp7List(
            '/tp7/classes?codDept=${Uri.encodeQueryComponent(dept!)}',
          );
    classCode = classes.any((x) => x['codClass'] == classCode)
        ? classCode
        : (classes.isEmpty ? null : classes.first['codClass'] as String);
    await _loadStudents();
  }

  Future<void> _loadStudents() async {
    students = classCode == null
        ? []
        : await widget.api.tp7List(
            '/tp7/etudiants?codClass=${Uri.encodeQueryComponent(classCode!)}',
          );
    nce = students.any((x) => x['nce'] == nce)
        ? nce
        : (students.isEmpty ? null : students.first['nce'] as int);
    await _loadAbsences();
  }

  Future<void> _loadAbsences() async {
    showChart = false;
    if (nce == null) {
      absences = [];
      totals = [];
    } else {
      absences = await widget.api.tp7List('/tp7/absences?nce=$nce');
      totals = await widget.api.tp7List('/tp7/totaux?nce=$nce');
    }
    if (mounted) setState(() {});
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final subjects = await widget.api.tp7List(
      '/tp7/matieres?codClass=${Uri.encodeQueryComponent(classCode!)}',
    );
    if (!mounted) return;
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune matière associée à cette classe.'),
        ),
      );
      return;
    }
    String code = (row?['codMat'] ?? subjects.first['codMat']).toString();
    final date = TextEditingController(
      text: (row?['dateA'] ?? DateTime.now().toIso8601String().substring(0, 10))
          .toString(),
    );
    final hours = TextEditingController(text: (row?['nha'] ?? '1').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          row == null ? 'Ajouter une absence' : 'Modifier une absence',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: code,
              items: subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['codMat'].toString(),
                      child: Text('${s['intMat']} (${s['codMat']})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  code = v;
                }
              },
            ),
            TextField(
              controller: date,
              decoration: const InputDecoration(
                labelText: 'DateA (AAAA-MM-JJ)',
              ),
            ),
            TextField(
              controller: hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'NHA'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.tp7Save(
        row == null ? '/tp7/absences' : '/tp7/absences/${row['id']}',
        {
          'nce': nce,
          'codMat': code,
          'dateA': date.text,
          'nha': double.parse(hours.text),
        },
        method: row == null ? 'POST' : 'PUT',
      );
      await _loadAbsences();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final student = students.where((s) => s['nce'] == nce).firstOrNull;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('absence-dept-$dept'),
              initialValue: dept,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Département'),
              items: departments
                  .map(
                    (d) => DropdownMenuItem(
                      value: d['codDept'].toString(),
                      child: Text('${d['nomDept']} (${d['codDept']})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                dept = v;
                classCode = null;
                nce = null;
                await _loadClasses();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey('absence-class-$classCode'),
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
              onChanged: (v) async {
                classCode = v;
                nce = null;
                await _loadStudents();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: ValueKey('absence-student-$nce'),
              initialValue: nce,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Étudiant'),
              items: students
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['nce'] as int,
                      child: Text('${s['nce']} - ${s['nom']} ${s['prenom']}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                nce = v;
                await _loadAbsences();
              },
            ),
            if (student != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _absenceInfoField('Classe', classCode ?? ''),
                    _absenceInfoField('Département', dept ?? ''),
                    _absenceInfoField('Étudiant', '${student['nce']}'),
                    _absenceInfoField('Nom', '${student['nom']}'),
                    _absenceInfoField('Prénom', '${student['prenom']}'),
                  ],
                ),
              ),
            const Text(
              'Absences',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (absences.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucune absence enregistrée.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('DateA')),
                    DataColumn(label: Text('CodMat')),
                    DataColumn(label: Text('NHA')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: absences
                      .map(
                        (a) => DataRow(
                          cells: [
                            DataCell(Text('${a['dateA']}')),
                            DataCell(Text('${a['codMat']}')),
                            DataCell(Text('${a['nha']}')),
                            DataCell(
                              Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _edit(a),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      await widget.api.tp7Delete(
                                        '/tp7/absences/${a['id']}',
                                      );
                                      await _loadAbsences();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            const Text(
              'Total des absences par matière (seuil : 10 heures)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (totals.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('CodMat')),
                    DataColumn(label: Text('Total NHA')),
                    DataColumn(label: Text('Statut')),
                  ],
                  rows: totals
                      .map(
                        (t) => DataRow(
                          cells: [
                            DataCell(Text('${t['codMat']}')),
                            DataCell(Text('${t['totalNha']}')),
                            DataCell(
                              Text(t['elimine'] == true ? 'Éliminé' : '—'),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              )
            else if (nce != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun total à afficher.'),
              ),
            if (nce != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilledButton.icon(
                  onPressed: totals.isEmpty
                      ? null
                      : () => setState(() => showChart = true),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calculer'),
                ),
              ),
            if (showChart) ...[
              Text(
                'Total des absences / semestre : ${allAbsenceHours.toStringAsFixed(1)} h',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (totals.length > 1)
                SizedBox(
                  height: 230,
                  child: CustomPaint(painter: _AbsenceChart(totals)),
                )
              else
                const Text(
                  'Ajoutez des absences dans au moins deux matières pour tracer la courbe.',
                ),
            ],
          ],
        ),
        if (nce != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              tooltip: 'Ajouter une absence',
              onPressed: () => _edit(),
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  Widget _absenceInfoField(String label, String value) => SizedBox(
    width: 175,
    child: TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _AbsenceChart extends CustomPainter {
  _AbsenceChart(this.values);
  final List<Map<String, dynamic>> values;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const left = 38.0;
    const right = 12.0;
    const top = 18.0;
    const bottom = 34.0;
    final max = values
        .map((v) => (v['totalNha'] as num).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (max <= 0) {
      return;
    }
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    final step = plotWidth / (values.length - 1);
    final path = Path();
    final axisPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(left, top),
      Offset(left, size.height - bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, size.height - bottom),
      Offset(size.width - right, size.height - bottom),
      axisPaint,
    );
    for (var i = 0; i < values.length; i++) {
      final x = left + i * step;
      final hours = (values[i]['totalNha'] as num).toDouble();
      final y = top + plotHeight - hours / max * plotHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.deepPurple);
      _drawChartLabel(
        canvas,
        '${values[i]['codMat']}',
        Offset(x, size.height - bottom + 5),
        maxWidth: step,
      );
      _drawChartLabel(
        canvas,
        hours.toStringAsFixed(1),
        Offset(x, y - 18),
        maxWidth: 48,
      );
    }
    canvas.drawPath(path, p);
  }

  void _drawChartLabel(
    Canvas canvas,
    String text,
    Offset center, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth > 4 ? maxWidth - 4 : maxWidth);
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _AbsenceChart old) => old.values != values;
}

class _AdminCatalogPage extends StatefulWidget {
  const _AdminCatalogPage({required this.api, required this.section});
  final ApiService api;
  final _Section section;
  @override
  State<_AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends State<_AdminCatalogPage> {
  List<Map<String, dynamic>> items = [], students = [], subjects = [];
  List<Classroom> classes = [];
  String? selectedClass;
  bool classSelectionInitialized = false;
  bool loading = true;
  bool get isDepartment => widget.section == _Section.departments;
  bool get isSubject => widget.section == _Section.subjects;
  String get base => isDepartment
      ? '/tp7/departements'
      : isSubject
      ? '/tp7/admin/matieres'
      : '/tp7/notes';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      if (isSubject) {
        classes = await widget.api.getClasses();
        if (!classSelectionInitialized) {
          selectedClass = classes.isEmpty ? null : classes.first.code;
          classSelectionInitialized = true;
        }
        items = selectedClass == null
            ? await widget.api.tp7List(base)
            : await widget.api.tp7List(
                '/tp7/matieres?codClass=${Uri.encodeQueryComponent(selectedClass!)}',
              );
        subjects = await widget.api.tp7List('/tp7/admin/matieres');
      } else {
        items = await widget.api.tp7List(base);
      }
      if (widget.section == _Section.grades) {
        students = (await widget.api.getStudents())
            .map(
              (s) => {
                'id': s.id,
                'nom': s.name,
                'prenom': s.firstName,
                'codClass': s.classCode,
              },
            )
            .toList();
        subjects = await widget.api.tp7List('/tp7/admin/matieres');
      }
    } catch (e) {
      _message('$e', true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String s, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final label = isDepartment
        ? 'le département ${item['codDept']}'
        : isSubject
        ? 'la matière ${item['codMat']}'
        : 'la note de ${item['nom']} ${item['prenom']} (${item['codMat']})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer $label ?'),
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
    if (ok != true) return;
    try {
      if (isSubject) {
        final code = item['codMat']?.toString().trim() ?? '';
        if (code.isEmpty) {
          throw const ApiException(
            'La matière sélectionnée ne contient pas son identifiant.',
          );
        }
        final encoded = Uri.encodeComponent(code);
        if (selectedClass != null) {
          await widget.api.tp7Delete(
            '/tp7/classes-matieres/${Uri.encodeComponent(selectedClass!)}/$encoded',
          );
        } else {
          await widget.api.tp7Delete('/tp7/matieres/$encoded');
        }
      } else {
        final path = isDepartment
            ? '$base/${Uri.encodeComponent(item['codDept'].toString())}'
            : '/tp7/notes/${item['nce']}/${Uri.encodeComponent(item['codMat'].toString())}';
        await widget.api.tp7Delete(path);
      }
      await _load();
    } catch (e) {
      _message('$e', true);
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    if (widget.section == _Section.grades && students.isEmpty) {
      _message('Aucun étudiant disponible.', true);
      return;
    }
    if (widget.section == _Section.grades && subjects.isEmpty) {
      _message('Aucune matière disponible.', true);
      return;
    }
    if (isSubject && item == null && selectedClass == null) {
      _message('Créez une classe avant d’ajouter une matière.', true);
      return;
    }
    var editItem = item;
    var editClass = selectedClass;
    if (isSubject && item != null && editClass == null) {
      try {
        final code = Uri.encodeComponent(item['codMat'].toString());
        final associations = await widget.api.tp7List(
          '/tp7/matieres/$code/classes',
        );
        if (!mounted) return;
        if (associations.isNotEmpty) {
          Map<String, dynamic>? selectedAssociation;
          if (associations.length == 1) {
            selectedAssociation = associations.first;
          } else {
            selectedAssociation = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => SimpleDialog(
                title: const Text('Choisir la classe du CHSM à modifier'),
                children: associations
                    .map(
                      (association) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, association),
                        child: Text(
                          '${association['nomClass']} (${association['codClass']}) • ${association['chsm']} h',
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }
          if (!mounted || selectedAssociation == null) return;
          editClass = selectedAssociation['codClass'].toString();
          editItem = {...item, ...selectedAssociation};
        }
      } catch (e) {
        _message('$e', true);
        return;
      }
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CatalogEditDialog(
        api: widget.api,
        section: widget.section,
        existing: editItem,
        students: students,
        subjects: subjects,
        classes: classes,
        selectedClass: editClass,
      ),
    );
    if (!mounted) return;
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final empty = isDepartment
        ? 'Aucun département enregistré.'
        : isSubject
        ? 'Aucune matière associée à cette classe.'
        : 'Aucune note enregistrée.';
    final rows = items.map((item) {
      final title = isDepartment
          ? '${item['nomDept']}'
          : isSubject
          ? '${item['intMat']}'
          : '${item['nom']} ${item['prenom']}';
      final subtitle = isDepartment
          ? 'Code : ${item['codDept']}'
          : isSubject
          ? '${item['codMat']} • ${item['chsm'] == null ? 'CHSM selon la classe' : 'CHSM : ${item['chsm']} h'}${(item['description'] ?? '').toString().isEmpty ? '' : ' • ${item['description']}'}'
          : '${item['codClass']} • ${item['codMat']} • ${item['intMat']} • ${item['valeurNote']}';
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _edit(item) : _delete(item),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ),
      );
    }).toList();
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            if (isSubject)
              DropdownButtonFormField<String>(
                initialValue: selectedClass,
                decoration: const InputDecoration(labelText: 'Classe'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Toutes les matières'),
                  ),
                  ...classes.map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text('${c.name} (${c.code})'),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  selectedClass = v;
                  await _load();
                },
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text(empty)),
              ),
            ...rows,
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
      ],
    );
  }
}

class _CatalogEditDialog extends StatefulWidget {
  const _CatalogEditDialog({
    required this.api,
    required this.section,
    required this.students,
    required this.subjects,
    required this.classes,
    required this.selectedClass,
    this.existing,
  });
  final ApiService api;
  final _Section section;
  final List<Map<String, dynamic>> students, subjects;
  final List<Classroom> classes;
  final String? selectedClass;
  final Map<String, dynamic>? existing;
  @override
  State<_CatalogEditDialog> createState() => _CatalogEditDialogState();
}

class _CatalogEditDialogState extends State<_CatalogEditDialog> {
  final keyForm = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: widget
        .existing?[widget.section == _Section.departments
            ? 'codDept'
            : 'codMat']
        ?.toString(),
  );
  late final name = TextEditingController(
    text: widget
        .existing?[widget.section == _Section.departments
            ? 'nomDept'
            : 'intMat']
        ?.toString(),
  );
  late final details = TextEditingController(
    text: widget.existing?['description']?.toString(),
  );
  late final value = TextEditingController(
    text: widget.existing?['valeurNote']?.toString(),
  );
  final coef = TextEditingController(text: '1');
  late final chsm = TextEditingController(
    text: widget.existing?['chsm']?.toString() ?? '',
  );
  int? selectedStudent;
  String? selectedSubject;
  String? selectedClass;
  bool? selectedHasTp;
  bool busy = false;
  List<Map<String, dynamic>> gradeSubjects = [];
  @override
  void initState() {
    super.initState();
    selectedStudent =
        widget.existing?['nce'] as int? ??
        (widget.students.isEmpty ? null : widget.students.first['id'] as int?);
    selectedSubject =
        widget.existing?['codMat']?.toString() ??
        (widget.subjects.isEmpty
            ? null
            : widget.subjects.first['codMat'].toString());
    selectedClass =
        widget.selectedClass ??
        (widget.classes.isEmpty ? null : widget.classes.first.code);
    selectedHasTp = widget.existing?['hasTp'] as bool?;
    if (widget.section == _Section.grades) _loadGradeSubjects();
  }

  Future<void> _loadGradeSubjects() async {
    final student = widget.students
        .where((s) => s['id'] == selectedStudent)
        .firstOrNull;
    final classCode =
        widget.existing?['codClass']?.toString() ??
        student?['codClass']?.toString();
    if (classCode == null) return;
    try {
      final fetched = await widget.api.tp7List(
        '/tp7/matieres?codClass=${Uri.encodeQueryComponent(classCode)}',
      );
      if (mounted) {
        setState(() {
          gradeSubjects = fetched;
          if (!gradeSubjects.any((s) => s['codMat'] == selectedSubject)) {
            selectedSubject = gradeSubjects.isEmpty
                ? null
                : gradeSubjects.first['codMat'].toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    details.dispose();
    value.dispose();
    coef.dispose();
    chsm.dispose();
    super.dispose();
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Ce champ est obligatoire.' : null;
  Future<void> save() async {
    if (!(keyForm.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      final edit = widget.existing != null;
      if (widget.section == _Section.departments) {
        await widget.api.tp7Save(
          '/tp7/departements${edit ? '/${Uri.encodeComponent(code.text)}' : ''}',
          {'codDept': code.text.trim(), 'nomDept': name.text.trim()},
          method: edit ? 'PUT' : 'POST',
        );
      } else if (widget.section == _Section.subjects) {
        if (!edit && selectedClass == null) {
          throw const ApiException('Sélectionnez une classe.');
        }
        await widget.api.tp7Save(
          '/tp7/matieres${edit ? '/${Uri.encodeComponent(code.text)}' : ''}',
          {
            'codMat': code.text.trim(),
            'intMat': name.text.trim(),
            'description': details.text.trim(),
            'hasTp': selectedHasTp,
          },
          method: edit ? 'PUT' : 'POST',
        );
        if (!edit) {
          try {
            await widget.api.tp7Save('/tp7/classes-matieres', {
              'codClass': selectedClass,
              'codMat': code.text.trim(),
              'coef': double.parse(coef.text),
              'chsm': int.parse(chsm.text),
            });
          } catch (error) {
            await widget.api.tp7Delete(
              '/tp7/matieres/${Uri.encodeComponent(code.text.trim())}',
            );
            rethrow;
          }
        } else if (widget.selectedClass != null &&
            widget.existing?.containsKey('chsm') == true) {
          await widget.api.tp7Save(
            '/tp7/classes-matieres/${Uri.encodeComponent(widget.selectedClass!)}/${Uri.encodeComponent(code.text.trim())}',
            {'chsm': int.parse(chsm.text)},
            method: 'PUT',
          );
        }
      } else {
        if (selectedStudent == null || selectedSubject == null) {
          throw const ApiException('Sélectionnez un étudiant et une matière.');
        }
        final grade = double.parse(value.text);
        final path = edit
            ? '/tp7/notes/$selectedStudent/${Uri.encodeComponent(selectedSubject!)}'
            : '/tp7/notes';
        await widget.api.tp7Save(
          path,
          edit
              ? {'valeurNote': grade}
              : {
                  'nce': selectedStudent,
                  'codMat': selectedSubject,
                  'valeurNote': grade,
                },
          method: edit ? 'PUT' : 'POST',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.existing != null;
    final dept = widget.section == _Section.departments;
    final subject = widget.section == _Section.subjects;
    final title = dept
        ? 'département'
        : subject
        ? 'matière'
        : 'note';
    final fields = <Widget>[];
    if (dept || subject) {
      fields.addAll([
        TextFormField(
          controller: code,
          readOnly: edit,
          decoration: InputDecoration(
            labelText: dept ? 'Code du département' : 'Code de la matière',
          ),
          validator: requiredText,
        ),
        TextFormField(
          controller: name,
          decoration: InputDecoration(
            labelText: dept ? 'Nom du département' : 'Intitulé',
          ),
          validator: requiredText,
        ),
      ]);
      if (subject) {
        fields.add(
          TextFormField(
            controller: details,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        );
        fields.add(
          DropdownButtonFormField<bool>(
            initialValue: selectedHasTp,
            decoration: const InputDecoration(
              labelText: 'Cette matière comporte des TP ?',
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('Oui')),
              DropdownMenuItem(value: false, child: Text('Non')),
            ],
            onChanged: (v) => setState(() => selectedHasTp = v),
            validator: (v) =>
                v == null ? 'Indiquez si la matière comporte des TP.' : null,
          ),
        );
        if (!edit) {
          fields.addAll([
            DropdownButtonFormField<String>(
              initialValue: selectedClass,
              decoration: const InputDecoration(labelText: 'Classe'),
              items: widget.classes
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text('${c.name} (${c.code})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selectedClass = v),
              validator: (v) => v == null ? 'Sélectionnez une classe.' : null,
            ),
            TextFormField(
              controller: coef,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Coefficient'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n <= 0 ? 'Coefficient invalide.' : null;
              },
            ),
          ]);
        }
        if (!edit ||
            (widget.selectedClass != null &&
                widget.existing?.containsKey('chsm') == true)) {
          fields.add(
            TextFormField(
              controller: chsm,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CHSM (heures)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n <= 0 ? 'CHSM invalide.' : null;
              },
            ),
          );
        }
      }
    } else {
      fields.addAll([
        DropdownButtonFormField<int>(
          initialValue: selectedStudent,
          decoration: const InputDecoration(labelText: 'Étudiant'),
          items: widget.students
              .map(
                (s) => DropdownMenuItem(
                  value: s['id'] as int?,
                  child: Text('${s['nom']} ${s['prenom']} (${s['id']})'),
                ),
              )
              .toList(),
          onChanged: edit
              ? null
              : (v) async {
                  setState(() => selectedStudent = v);
                  await _loadGradeSubjects();
                },
        ),
        DropdownButtonFormField<String>(
          initialValue: gradeSubjects.any((s) => s['codMat'] == selectedSubject)
              ? selectedSubject
              : null,
          decoration: const InputDecoration(labelText: 'Matière'),
          items: gradeSubjects
              .map(
                (s) => DropdownMenuItem(
                  value: s['codMat'].toString(),
                  child: Text('${s['intMat']} (${s['codMat']})'),
                ),
              )
              .toList(),
          onChanged: edit ? null : (v) => setState(() => selectedSubject = v),
        ),
        TextFormField(
          controller: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Note'),
          validator: (v) => v == null || double.tryParse(v.trim()) == null
              ? 'Saisissez une note valide.'
              : null,
        ),
      ]);
    }
    return AlertDialog(
      title: Text('${edit ? 'Modifier' : 'Ajouter'} $title'),
      content: Form(
        key: keyForm,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: fields),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
