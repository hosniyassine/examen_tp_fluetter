package tn.tp7.backend;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/tp7")
class AbsenceController {
 private final DepartmentRepository departments; private final SchoolClassRepository classes;
 private final StudentRepository students; private final SubjectRepository subjects;
 private final AbsenceRepository absences; private final ClassSubjectRepository links; private final GradeRepository grades; private final TeacherAssignmentRepository assignments; private final AcademicGradeRepository academicGrades;
 AbsenceController(DepartmentRepository d, SchoolClassRepository c, StudentRepository s, SubjectRepository m, AbsenceRepository a, ClassSubjectRepository l, GradeRepository g, TeacherAssignmentRepository t, AcademicGradeRepository ag) { departments=d; classes=c; students=s; subjects=m; absences=a; links=l; grades=g; assignments=t; academicGrades=ag; }
 record DeptIn(@NotBlank String codDept,@NotBlank String nomDept) {}
 record DeptRef(@NotBlank String codDept) {}
 record ClassIn(@NotBlank String codClass,@NotBlank String nomClass,@NotBlank String codDept) {}
 record SubjectIn(@NotBlank String codMat,@NotBlank String intMat,String description,@NotNull Boolean hasTp) {}
 record SubjectEdit(@NotBlank String intMat,String description,Boolean hasTp) {}
 record DepartmentEdit(@NotBlank String nomDept) {}
 record GradeIn(@NotNull Integer nce,@NotBlank String codMat,@NotNull Double valeurNote) {}
 record GradeEdit(@NotNull Double valeurNote) {}
 record AbsenceIn(@NotNull Integer nce,@NotBlank String codMat,@NotNull LocalDate dateA,@NotNull @PositiveOrZero Double nha) {}
 record ForecastStudent(@NotNull Integer nce,@NotNull @PositiveOrZero Double nha) {}
 record ForecastIn(@NotBlank String codClass,@NotBlank String codMat,@NotNull LocalDate dateA,@NotEmpty List<@Valid ForecastStudent> students) {}
 @GetMapping("/departements") List<Map<String,Object>> departments(){return departments.findAll().stream().map(d->Map.<String,Object>of("codDept",d.codDept,"nomDept",d.nomDept)).toList();}
 @PostMapping("/departements") Map<String,Object> addDepartment(@Valid @RequestBody DeptIn in){ Department d=new Department();d.codDept=in.codDept().trim();d.nomDept=in.nomDept().trim();departments.save(d);return Map.of("codDept",d.codDept,"nomDept",d.nomDept); }
 @PutMapping("/departements/{code}") Map<String,Object> updateDepartment(@PathVariable String code,@Valid @RequestBody DepartmentEdit in){Department d=departments.findById(code).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Département introuvable."));d.nomDept=in.nomDept().trim();departments.save(d);return Map.of("codDept",d.codDept,"nomDept",d.nomDept);}
 @DeleteMapping("/departements/{code}") void deleteDepartment(@PathVariable String code){Department d=departments.findById(code).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Département introuvable."));if(classes.existsByDepartementCodDept(code))throw new ResponseStatusException(HttpStatus.CONFLICT,"Le département contient encore des classes.");departments.delete(d);}
 @GetMapping("/classes") List<Map<String,Object>> classes(@RequestParam(required=false) String codDept){return classes.findAll().stream().filter(c->codDept==null||(c.departement!=null&&codDept.equals(c.departement.codDept))).map(c->Map.<String,Object>of("codClass",c.codClass,"nomClass",c.nomClass,"codDept",c.departement==null?"":c.departement.codDept)).toList();}
 @PostMapping("/classes") Map<String,Object> addClass(@Valid @RequestBody ClassIn in){SchoolClass c=new SchoolClass();c.codClass=in.codClass().trim();c.nomClass=in.nomClass().trim();c.departement=departments.findById(in.codDept()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Département introuvable."));classes.save(c);return Map.of("codClass",c.codClass,"nomClass",c.nomClass,"codDept",c.departement.codDept);}
 @PutMapping("/classes/{codClass}/departement") Map<String,Object> assignDepartment(@PathVariable String codClass,@Valid @RequestBody DeptRef in){SchoolClass c=classes.findById(codClass).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Classe introuvable."));c.departement=departments.findById(in.codDept()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Département introuvable."));classes.save(c);return Map.of("codClass",c.codClass,"nomClass",c.nomClass,"codDept",c.departement.codDept);}
 @GetMapping("/etudiants") List<Map<String,Object>> students(@RequestParam String codClass){return students.findAllByClasseCodClass(codClass).stream().map(s->Map.<String,Object>of("nce",s.id,"nom",s.nom,"prenom",s.prenom,"codClass",s.classe.codClass)).toList();}
 record LinkIn(@NotBlank String codClass,@NotBlank String codMat,@NotNull @Positive Double coef,@NotNull @Positive Integer chsm) {}
 record LinkHoursIn(@NotNull @Positive Integer chsm) {}
 @PostMapping("/classes-matieres") Map<String,Object> link(@Valid @RequestBody LinkIn in){SchoolClass c=classes.findById(in.codClass()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Classe introuvable."));Subject m=subjects.findById(in.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Matière introuvable."));if(links.existsByClasseCodClassAndMatiereCodMat(c.codClass,m.codMat))throw new ResponseStatusException(HttpStatus.CONFLICT,"Cette matière est déjà associée à la classe.");ClassSubject l=new ClassSubject();l.classe=c;l.matiere=m;l.coef=in.coef();l.chsm=in.chsm();links.save(l);return Map.of("codClass",l.classe.codClass,"codMat",l.matiere.codMat,"coef",l.coef,"chsm",l.chsm);}
 @GetMapping("/matieres") List<Map<String,Object>> subjects(@RequestParam String codClass,@RequestAttribute(value="authenticatedUser",required=false) AppUser actor){return links.findAllByClasseCodClass(codClass).stream().filter(l->actor==null||!"TEACHER".equals(actor.role)||actor.teacher!=null&&assignments.existsByTeacherIdAndClassSubjectId(actor.teacher.id,l.id)).map(l->{Map<String,Object> m=subjectMap(l.matiere);m.put("coef",l.coef);m.put("chsm",l.chsm);m.put("codClass",l.classe.codClass);return m;}).toList();}
 @GetMapping("/matieres/{codMat}/classes") List<Map<String,Object>> subjectClassLinks(@PathVariable String codMat){
  if(!subjects.existsById(codMat))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Matière introuvable.");
  return links.findAllByMatiereCodMat(codMat).stream().map(link->Map.<String,Object>of("codClass",link.classe.codClass,"nomClass",link.classe.nomClass,"chsm",link.chsm,"coef",link.coef)).toList();
 }
 @PutMapping("/classes-matieres/{codClass}/{codMat}") @Transactional
 Map<String,Object> updateClassSubjectHours(@PathVariable String codClass,@PathVariable String codMat,@Valid @RequestBody LinkHoursIn in){
  ClassSubject link=links.findByClasseCodClassAndMatiereCodMat(codClass,codMat).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Association classe-matière introuvable."));
  link.chsm=in.chsm();links.save(link);return Map.of("codClass",codClass,"codMat",codMat,"coef",link.coef,"chsm",link.chsm);
 }
 @DeleteMapping("/classes-matieres/{codClass}/{codMat}") @Transactional
 void unlink(@PathVariable String codClass,@PathVariable String codMat){
  ClassSubject link=links.findByClasseCodClassAndMatiereCodMat(codClass,codMat)
          .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Association classe-matière introuvable."));
  assertSubjectCanLeaveClass(codClass,codMat,link.id);
  links.delete(link);
  links.flush();
  deleteSubjectIfOrphan(codMat);
 }
 @PostMapping("/matieres") Map<String,Object> addSubject(@Valid @RequestBody SubjectIn in){
  String code=in.codMat().trim();
  if(subjects.existsById(code)) throw new ResponseStatusException(HttpStatus.CONFLICT,"Une matière avec ce code existe déjà.");
  Subject m=new Subject();m.codMat=code;m.intMat=in.intMat().trim();m.description=in.description();m.hasTp=in.hasTp();subjects.save(m);return subjectMap(m);
 }
 @GetMapping("/admin/matieres") List<Map<String,Object>> allSubjects(){return subjects.findAll().stream().map(this::subjectMap).toList();}
 @PutMapping("/matieres/{code}") Map<String,Object> updateSubject(@PathVariable String code,@Valid @RequestBody SubjectEdit in){Subject m=subjects.findById(code).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Matière introuvable."));m.intMat=in.intMat().trim();m.description=in.description();if(in.hasTp()!=null)m.hasTp=in.hasTp();return subjectMap(subjects.save(m));}
 @DeleteMapping("/matieres/{code}") @Transactional
 void deleteSubject(@PathVariable String code){
  if(!subjects.existsById(code)) throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Matière introuvable.");
  if(subjectStillReferenced(code))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Impossible de supprimer cette matière : elle est encore associée à une classe, une absence, une note ou un enseignant.");
  subjects.deleteById(code);
 }
 @GetMapping("/absences") List<Map<String,Object>> absences(@RequestParam Integer nce){return absences.findAllByEtudiantId(nce).stream().map(this::absenceMap).toList();}
 @GetMapping("/absences/prevision") Map<String,Object> absenceForecast(@RequestParam String codClass,@RequestParam String codMat,@RequestParam LocalDate dateA){
  SchoolClass c=classes.findById(codClass).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Classe introuvable."));
  ClassSubject link=links.findByClasseCodClassAndMatiereCodMat(codClass,codMat).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cette matière n'appartient pas à la classe sélectionnée."));
  List<Map<String,Object>> rows=students.findAllByClasseCodClass(codClass).stream().map(s->{Map<String,Object> row=new LinkedHashMap<>();row.put("nce",s.id);row.put("nom",s.nom);row.put("prenom",s.prenom);row.put("nha",absences.findByEtudiantIdAndMatiereCodMatAndDateA(s.id,codMat,dateA).map(a->a.nha).orElse(0.0));return row;}).toList();
  Map<String,Object> result=new LinkedHashMap<>();result.put("codClass",c.codClass);result.put("nomClass",c.nomClass);result.put("codDept",c.departement==null?null:c.departement.codDept);result.put("nomDept",c.departement==null?null:c.departement.nomDept);result.put("codMat",link.matiere.codMat);result.put("intMat",link.matiere.intMat);result.put("chsm",link.chsm);result.put("dateA",dateA);result.put("students",rows);return result;
 }
 @PostMapping("/absences/prevision") @Transactional
 Map<String,Object> saveForecast(@Valid @RequestBody ForecastIn in){
  if(!classes.existsById(in.codClass()))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Classe introuvable.");
  if(!links.existsByClasseCodClassAndMatiereCodMat(in.codClass(),in.codMat()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cette matière n'appartient pas à la classe sélectionnée.");
  Subject subject=subjects.findById(in.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Matière introuvable."));
  Set<Integer> ids=new HashSet<>();List<Absence> rows=new ArrayList<>();
  for(ForecastStudent item:in.students()){
   if(!ids.add(item.nce()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Un étudiant apparaît plusieurs fois dans la prévision.");
   Student student=students.findById(item.nce()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));
   if(student.classe==null||!in.codClass().equals(student.classe.codClass))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Un étudiant ne fait pas partie de la classe sélectionnée.");
   Absence absence=absences.findByEtudiantIdAndMatiereCodMatAndDateA(item.nce(),in.codMat(),in.dateA()).orElseGet(Absence::new);
   absence.etudiant=student;absence.matiere=subject;absence.dateA=in.dateA();absence.nha=item.nha();rows.add(absence);
  }
  List<Absence> saved=absences.saveAll(rows);Map<String,Object> result=new LinkedHashMap<>();result.put("enregistrees",saved.size());result.put("absences",saved.stream().map(this::absenceMap).toList());return result;
 }
 @PostMapping("/absences") Map<String,Object> addAbsence(@Valid @RequestBody AbsenceIn in){
  Student student=students.findById(in.nce()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));
  Subject subject=subjects.findById(in.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Matière introuvable."));
  if(!links.existsByClasseCodClassAndMatiereCodMat(student.classe.codClass,subject.codMat))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cette matière n'appartient pas à la classe de l'étudiant.");
  Absence a=absences.findByEtudiantIdAndMatiereCodMatAndDateA(in.nce(),in.codMat(),in.dateA()).orElseGet(Absence::new);a.etudiant=student;a.matiere=subject;a.dateA=in.dateA();a.nha=in.nha();return absenceMap(absences.save(a));
 }
 @PutMapping("/absences/{id}") Map<String,Object> updateAbsence(@PathVariable Integer id,@Valid @RequestBody AbsenceIn in){Absence a=absences.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Absence introuvable."));apply(a,in);return absenceMap(absences.save(a));}
 @DeleteMapping("/absences/{id}") void deleteAbsence(@PathVariable Integer id){absences.deleteById(id);}
 @GetMapping("/totaux") List<Map<String,Object>> totals(@RequestParam Integer nce){Map<String,Double> totals=absences.findAllByEtudiantId(nce).stream().collect(Collectors.groupingBy(a->a.matiere.codMat,Collectors.summingDouble(a->a.nha)));return totals.entrySet().stream().map(e->{Subject m=subjects.findById(e.getKey()).orElseThrow();double total=e.getValue();return Map.<String,Object>of("codMat",e.getKey(),"intMat",m.intMat,"totalNha",total,"elimine",total>10.0);}).toList();}
 private void apply(Absence a,AbsenceIn in){a.etudiant=students.findById(in.nce()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));a.matiere=subjects.findById(in.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Matière introuvable."));if(!links.existsByClasseCodClassAndMatiereCodMat(a.etudiant.classe.codClass,a.matiere.codMat))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cette matière n'appartient pas à la classe de l'étudiant.");a.dateA=in.dateA();a.nha=in.nha();}
 private Map<String,Object> absenceMap(Absence a){return Map.of("id",a.id,"nce",a.etudiant.id,"codMat",a.matiere.codMat,"intMat",a.matiere.intMat,"dateA",a.dateA,"nha",a.nha);}
 @GetMapping("/notes") List<Map<String,Object>> notes(){return grades.findAll().stream().map(this::gradeMap).toList();}
 @PostMapping("/notes") Map<String,Object> addGrade(@Valid @RequestBody GradeIn in){Grade g=new Grade();setGradeReferences(g,in);g.valeurNote=in.valeurNote();g.id=new GradeId(g.etudiant.id,g.matiere.codMat);return gradeMap(grades.save(g));}
 @PutMapping("/notes/{nce}/{codMat}") Map<String,Object> updateGrade(@PathVariable Integer nce,@PathVariable String codMat,@Valid @RequestBody GradeEdit in){GradeId id=new GradeId(nce,codMat);Grade g=grades.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Note introuvable."));g.valeurNote=in.valeurNote();return gradeMap(grades.save(g));}
 @DeleteMapping("/notes/{nce}/{codMat}") void deleteGrade(@PathVariable Integer nce,@PathVariable String codMat){GradeId id=new GradeId(nce,codMat);if(!grades.existsById(id))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Note introuvable.");grades.deleteById(id);}
 private void setGradeReferences(Grade g,GradeIn in){g.etudiant=students.findById(in.nce()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));g.matiere=subjects.findById(in.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Matière introuvable."));if(!links.existsByClasseCodClassAndMatiereCodMat(g.etudiant.classe.codClass,g.matiere.codMat))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cette matière n'appartient pas à la classe de l'étudiant.");}
 private Map<String,Object> gradeMap(Grade g){return Map.of("nce",g.etudiant.id,"nom",g.etudiant.nom,"prenom",g.etudiant.prenom,"codClass",g.etudiant.classe.codClass,"codMat",g.matiere.codMat,"intMat",g.matiere.intMat,"valeurNote",g.valeurNote);}
 private Map<String,Object> subjectMap(Subject s){Map<String,Object> map=new HashMap<>();map.put("codMat",s.codMat);map.put("intMat",s.intMat);map.put("description",s.description==null?"":s.description);map.put("hasTp",s.hasTp);return map;}
 private void assertSubjectCanLeaveClass(String codClass,String codMat,Integer linkId){
  if(absences.existsByEtudiantClasseCodClassAndMatiereCodMat(codClass,codMat)
          ||grades.existsByEtudiantClasseCodClassAndMatiereCodMat(codClass,codMat)
          ||academicGrades.existsByEtudiantClasseCodClassAndMatiereCodMat(codClass,codMat))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Impossible de retirer cette matière : elle possède des absences ou des notes enregistrées pour cette classe.");
  if(assignments.existsByClassSubjectId(linkId))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Impossible de retirer cette matière : elle est affectée à un enseignant dans cette classe.");
 }
 private void deleteSubjectIfOrphan(String code){
  if(!subjectStillReferenced(code)) subjects.deleteById(code);
 }
 private boolean subjectStillReferenced(String code){
  return links.existsByMatiereCodMat(code)||absences.existsByMatiereCodMat(code)
          ||grades.existsByMatiereCodMat(code)||academicGrades.existsByMatiereCodMat(code)
          ||assignments.existsByClassSubjectMatiereCodMat(code);
 }
}


