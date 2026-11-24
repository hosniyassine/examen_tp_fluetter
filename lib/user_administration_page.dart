import 'package:flutter/material.dart';

import 'api_service.dart';
import 'models.dart';

class UserAdministrationPage extends StatefulWidget {
  const UserAdministrationPage({super.key, required this.api});
  final ApiService api;
  @override State<UserAdministrationPage> createState() => _UserAdministrationPageState();
}

class _UserAdministrationPageState extends State<UserAdministrationPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String,dynamic>> _accounts=[],_teachers=[],_assignments=[];
  List<Student> _students=[];
  List<Classroom> _classes=[];
  bool _loading=true;
  @override void initState(){super.initState();_load();}
  @override void dispose(){_tabs.dispose();super.dispose();}

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      _accounts=await widget.api.tp7List('/tp7/admin/users');
      _students=await widget.api.getStudents();
      _teachers=await widget.api.tp7List('/tp7/admin/enseignants');
      _assignments=await widget.api.tp7List('/tp7/admin/affectations');
      _classes=await widget.api.getClasses();
    } catch(e) { _message('$e',true); }
    finally { if(mounted)setState(()=>_loading=false); }
  }
  void _message(String s,[bool error=false]){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:error?Colors.red.shade700:null));}

  Future<void> _editAccount(Map<String,dynamic> account) async {
    String role=account['role']?.toString()??'STUDENT';
    int? studentId=account['studentId'] as int?;
    int? teacherId=account['teacherId'] as int?;
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setDialog)=>AlertDialog(
      title:Text('Rôle de ${account['email']}'),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:role,decoration:const InputDecoration(labelText:'Rôle'),items:const[
          DropdownMenuItem(value:'ADMIN',child:Text('Administrateur')),
          DropdownMenuItem(value:'TEACHER',child:Text('Enseignant')),
          DropdownMenuItem(value:'STUDENT',child:Text('Étudiant')),
        ],onChanged:(v)=>setDialog(()=>role=v??role)),
        if(role=='STUDENT')DropdownButtonFormField<int>(initialValue:studentId,decoration:const InputDecoration(labelText:'Étudiant lié'),items:_students.where((s)=>s.id!=null).map((s)=>DropdownMenuItem(value:s.id,child:Text('${s.id} • ${s.firstName} ${s.name}'))).toList(),onChanged:(v)=>setDialog(()=>studentId=v)),
        if(role=='TEACHER')DropdownButtonFormField<int>(initialValue:teacherId,decoration:const InputDecoration(labelText:'Enseignant lié'),items:_teachers.map((t)=>DropdownMenuItem(value:t['id'] as int,child:Text('${t['prenom']} ${t['nom']}'))).toList(),onChanged:(v)=>setDialog(()=>teacherId=v)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Enregistrer'))],
    )));
    if(ok!=true)return;
    try { await widget.api.tp7Save('/tp7/admin/users/${account['id']}/role',{'role':role,'studentId':role=='STUDENT'?studentId:null,'teacherId':role=='TEACHER'?teacherId:null},method:'PUT');await _load(); }
    catch(e){_message('$e',true);}
  }

  Future<void> _editTeacher([Map<String,dynamic>? teacher]) async {
    final first=TextEditingController(text:teacher?['prenom']?.toString());
    final last=TextEditingController(text:teacher?['nom']?.toString());
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:Text(teacher==null?'Ajouter un enseignant':'Modifier l’enseignant'),
      content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:first,decoration:const InputDecoration(labelText:'Prénom')),TextField(controller:last,decoration:const InputDecoration(labelText:'Nom'))])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Enregistrer'))],
    ));
    if(ok==true){try{await widget.api.tp7Save('/tp7/admin/enseignants${teacher==null?'':'/${teacher['id']}'}',{'prenom':first.text.trim(),'nom':last.text.trim()},method:teacher==null?'POST':'PUT');await _load();}catch(e){_message('$e',true);}}
    first.dispose();last.dispose();
  }

  Future<void> _addAssignment() async {
    if(_teachers.isEmpty||_classes.isEmpty){_message('Ajoutez d’abord un enseignant et une classe.',true);return;}
    int teacherId=_teachers.first['id'] as int;
    String classCode=_classes.first.code;
    List<Map<String,dynamic>> materials=[];
    String? subjectCode;
    Future<void> loadMaterials(StateSetter update)async{materials=await widget.api.tp7List('/tp7/matieres?codClass=${Uri.encodeQueryComponent(classCode)}');subjectCode=materials.isEmpty?null:materials.first['codMat'].toString();update((){});}
    final ok=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setDialog){
      if(materials.isEmpty&&classCode.isNotEmpty){loadMaterials(setDialog);}
      return AlertDialog(title:const Text('Affecter une matière'),content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(initialValue:teacherId,decoration:const InputDecoration(labelText:'Enseignant'),items:_teachers.map((t)=>DropdownMenuItem(value:t['id'] as int,child:Text('${t['prenom']} ${t['nom']}'))).toList(),onChanged:(v)=>setDialog(()=>teacherId=v??teacherId)),
        DropdownButtonFormField<String>(initialValue:classCode,decoration:const InputDecoration(labelText:'Classe'),items:_classes.map((c)=>DropdownMenuItem(value:c.code,child:Text('${c.name} (${c.code})'))).toList(),onChanged:(v)async{if(v==null)return;classCode=v;materials=[];await loadMaterials(setDialog);}),
        if(materials.isNotEmpty)DropdownButtonFormField<String>(initialValue:subjectCode,decoration:const InputDecoration(labelText:'Matière'),items:materials.map((m)=>DropdownMenuItem(value:m['codMat'].toString(),child:Text(m['intMat'].toString()))).toList(),onChanged:(v)=>setDialog(()=>subjectCode=v)),
        if(materials.isEmpty)const Padding(padding:EdgeInsets.all(8),child:Text('Aucune matière pour cette classe.')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:subjectCode==null?null:()=>Navigator.pop(context,true),child:const Text('Enregistrer'))]);
    }));
    if(ok==true&&subjectCode!=null){try{await widget.api.tp7Save('/tp7/admin/affectations',{'teacherId':teacherId,'codClass':classCode,'codMat':subjectCode});await _load();}catch(e){_message('$e',true);}}
  }

  Future<void> _deleteAssignment(Map<String,dynamic> row) async {
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Retirer l’affectation ?'),content:Text('${row['teacher']} • ${row['matiere']} (${row['codClass']})'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Retirer'))]));
    if(ok==true){try{await widget.api.tp7Delete('/tp7/admin/affectations/${row['id']}');await _load();}catch(e){_message('$e',true);}}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final accountCards = _accounts.map((u) => Card(
      child: ListTile(
        title: Text(u['email'].toString()),
        subtitle: Text('${u['role']} • ${u['student'] ?? u['teacher'] ?? 'aucune association'}'),
        trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editAccount(u)),
      ),
    )).toList();
    final teacherCards = _teachers.map((t) => Card(
      child: ListTile(
        title: Text('${t['prenom']} ${t['nom']}'),
        trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editTeacher(t)),
      ),
    )).toList();
    final assignmentRows = _assignments.map((a) => ListTile(
      title: Text('${a['teacher']} • ${a['matiere']}'),
      subtitle: Text('Classe ${a['codClass']}'),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteAssignment(a)),
    )).toList();
    return Column(children: [
      TabBar(controller: _tabs, tabs: const [Tab(text: 'Comptes'), Tab(text: 'Enseignants et affectations')]),
      Expanded(child: TabBarView(controller: _tabs, children: [
        accountCards.isEmpty ? const Center(child: Text('Aucun compte.')) : ListView(children: accountCards),
        Column(children: [
          Expanded(child: ListView(children: [...teacherCards, ...assignmentRows])),
          Padding(padding: const EdgeInsets.all(10), child: Wrap(spacing: 10, children: [
            OutlinedButton.icon(onPressed: () => _editTeacher(), icon: const Icon(Icons.person_add_alt_1), label: const Text('Ajouter enseignant')),
            FilledButton.icon(onPressed: _addAssignment, icon: const Icon(Icons.assignment_ind_outlined), label: const Text('Affecter matière')),
          ])),
        ]),
      ])),
    ]);
  }
}
