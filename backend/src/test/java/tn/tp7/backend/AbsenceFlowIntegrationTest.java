package tn.tp7.backend;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"spring.datasource.url=jdbc:h2:mem:tp7absence;DB_CLOSE_DELAY=-1", "spring.jpa.hibernate.ddl-auto=create-drop", "app.security.enabled=false"})
@AutoConfigureMockMvc
class AbsenceFlowIntegrationTest {
 @Autowired MockMvc http;
 @Autowired DepartmentRepository departments;
 @Autowired SchoolClassRepository classes;
 @Autowired StudentRepository students;
 @Autowired SubjectRepository subjects;
 @Autowired ClassSubjectRepository classSubjects;
 @Autowired AbsenceRepository absenceRepository;
 @Autowired AcademicGradeRepository academicGrades;
 @Autowired GradeRepository legacyGrades;
 Department department; SchoolClass schoolClass; Student student; Subject subject;
 @BeforeEach void seed(){
  absenceRepository.deleteAll(); academicGrades.deleteAll(); legacyGrades.deleteAll(); classSubjects.deleteAll(); students.deleteAll(); classes.deleteAll(); departments.deleteAll(); subjects.deleteAll();
  department=new Department();department.codDept="TI";department.nomDept="Informatique";departments.save(department);
  schoolClass=new SchoolClass();schoolClass.codClass="DSI33";schoolClass.nomClass="DSI33";schoolClass.departement=department;classes.save(schoolClass);
  student=new Student();student.nom="Ben Foulen1";student.prenom="Foulen1";student.classe=schoolClass;student=students.save(student);
  subject=new Subject();subject.codMat="AFCP";subject.intMat="AFCP";subject.hasTp=true;subjects.save(subject);
  ClassSubject link=new ClassSubject();link.classe=schoolClass;link.matiere=subject;link.coef=1.0;link.chsm=3;classSubjects.save(link);
 }
 @Test void cascadeAbsenceCrudAndSubjectTotals() throws Exception {
  http.perform(get("/tp7/departements")).andExpect(status().isOk()).andExpect(jsonPath("$[0].codDept").value("TI"));
  http.perform(get("/tp7/classes").param("codDept","TI")).andExpect(status().isOk()).andExpect(jsonPath("$[0].codClass").value("DSI33"));
  http.perform(get("/tp7/etudiants").param("codClass","DSI33")).andExpect(status().isOk()).andExpect(jsonPath("$[0].nce").value(student.id));
  http.perform(get("/tp7/matieres").param("codClass","DSI33")).andExpect(status().isOk()).andExpect(jsonPath("$[0].codMat").value("AFCP"));
  String body="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"dateA\":\"2025-11-11\",\"nha\":1.5}";
  String created=http.perform(post("/tp7/absences").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.nha").value(1.5)).andReturn().getResponse().getContentAsString();
  int id=Integer.parseInt(created.replaceAll(".*\\\"id\\\":([0-9]+).*", "$1"));
  http.perform(get("/tp7/totaux").param("nce",student.id.toString())).andExpect(status().isOk()).andExpect(jsonPath("$[0].totalNha").value(1.5));
  http.perform(put("/tp7/absences/"+id).contentType(MediaType.APPLICATION_JSON).content(body.replace("1.5","4.5"))).andExpect(status().isOk()).andExpect(jsonPath("$.nha").value(4.5));
  http.perform(get("/tp7/totaux").param("nce",student.id.toString())).andExpect(status().isOk()).andExpect(jsonPath("$[0].totalNha").value(4.5));
  http.perform(delete("/tp7/absences/"+id)).andExpect(status().isOk());
  http.perform(get("/tp7/absences").param("nce",student.id.toString())).andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
  http.perform(get("/tp7/totaux").param("nce",student.id.toString())).andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
 }

 @Test void classAbsenceForecastLoadsDetailsAndUpdatesExistingRows() throws Exception {
  http.perform(get("/tp7/absences/prevision").param("codClass", "DSI33")
          .param("codMat", "AFCP").param("dateA", "2025-11-12"))
          .andExpect(status().isOk())
          .andExpect(jsonPath("$.nomClass").value("DSI33"))
          .andExpect(jsonPath("$.nomDept").value("Informatique"))
          .andExpect(jsonPath("$.intMat").value("AFCP"))
          .andExpect(jsonPath("$.chsm").value(3))
          .andExpect(jsonPath("$.students[0].nce").value(student.id))
          .andExpect(jsonPath("$.students[0].nha").value(0.0));

  String first = "{\"codClass\":\"DSI33\",\"codMat\":\"AFCP\",\"dateA\":\"2025-11-12\",\"students\":[{\"nce\":" + student.id + ",\"nha\":1.5}]}";
  http.perform(post("/tp7/absences/prevision").contentType(MediaType.APPLICATION_JSON).content(first))
          .andExpect(status().isOk()).andExpect(jsonPath("$.enregistrees").value(1))
          .andExpect(jsonPath("$.absences[0].nha").value(1.5));
  String revised = first.replace("1.5", "4.5");
  http.perform(post("/tp7/absences/prevision").contentType(MediaType.APPLICATION_JSON).content(revised))
          .andExpect(status().isOk()).andExpect(jsonPath("$.absences[0].nha").value(4.5));
  org.assertj.core.api.Assertions.assertThat(absenceRepository.findAllByEtudiantId(student.id))
          .hasSize(1).first().extracting(a -> a.nha).isEqualTo(4.5);

  http.perform(post("/tp7/absences/prevision").contentType(MediaType.APPLICATION_JSON)
          .content(first.replace("1.5", "-1"))).andExpect(status().isBadRequest());
  http.perform(post("/tp7/absences/prevision").contentType(MediaType.APPLICATION_JSON)
          .content(first.replace("\"AFCP\"", "\"NOT-LINKED\""))).andExpect(status().isBadRequest());

  SchoolClass otherClass = new SchoolClass(); otherClass.codClass = "DSI34"; otherClass.nomClass = "DSI34"; otherClass.departement = department; classes.save(otherClass);
  http.perform(post("/tp7/absences/prevision").contentType(MediaType.APPLICATION_JSON)
          .content(first.replace("DSI33", "DSI34"))).andExpect(status().isBadRequest());
 }

 @Test void classSubjectHoursCanBeCorrectedWithoutChangingTheCoefficient() throws Exception {
  http.perform(get("/tp7/matieres/AFCP/classes"))
          .andExpect(status().isOk()).andExpect(jsonPath("$[0].codClass").value("DSI33"))
          .andExpect(jsonPath("$[0].chsm").value(3));
  http.perform(put("/tp7/classes-matieres/DSI33/AFCP")
          .contentType(MediaType.APPLICATION_JSON).content("{\"chsm\":45}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.chsm").value(45))
          .andExpect(jsonPath("$.coef").value(1.0));
  http.perform(get("/tp7/matieres").param("codClass", "DSI33"))
          .andExpect(status().isOk()).andExpect(jsonPath("$[0].chsm").value(45));
  org.assertj.core.api.Assertions.assertThat(classSubjects
          .findByClasseCodClassAndMatiereCodMat("DSI33", "AFCP").orElseThrow().chsm)
          .isEqualTo(45);
  http.perform(put("/tp7/classes-matieres/DSI33/AFCP")
          .contentType(MediaType.APPLICATION_JSON).content("{\"chsm\":0}"))
          .andExpect(status().isBadRequest());
 }

 @Test void maximumPopulationUsesStudentCountsAndUpdatesOnlyChosenTiedClass() throws Exception {
  schoolClass.nbrEtud = 99; classes.save(schoolClass);
  SchoolClass tiedClass = new SchoolClass(); tiedClass.codClass = "DSI34"; tiedClass.nomClass = "DSI34"; tiedClass.departement = department; classes.save(tiedClass);
  Student tiedStudent = new Student(); tiedStudent.nom = "Test"; tiedStudent.prenom = "Tie"; tiedStudent.classe = tiedClass; students.save(tiedStudent);

  http.perform(get("/tp7/effectifs/maximales"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.maxEffectif").value(1))
          .andExpect(jsonPath("$.classes", org.hamcrest.Matchers.hasSize(2)))
          .andExpect(jsonPath("$.classes[0].nombreEtudiants").value(1))
          .andExpect(jsonPath("$.classes[0].nbrEtud").value(99));

  http.perform(put("/tp7/effectifs/DSI34")).andExpect(status().isOk())
          .andExpect(jsonPath("$.nbrEtud").value(1));
  org.assertj.core.api.Assertions.assertThat(classes.findById("DSI33").orElseThrow().nbrEtud).isEqualTo(99);
  org.assertj.core.api.Assertions.assertThat(classes.findById("DSI34").orElseThrow().nbrEtud).isEqualTo(1);

  Student second = new Student(); second.nom = "Autre"; second.prenom = "Étudiant"; second.classe = schoolClass; students.save(second);
  http.perform(put("/tp7/effectifs/DSI34")).andExpect(status().isBadRequest());
  org.assertj.core.api.Assertions.assertThat(classes.findById("DSI34").orElseThrow().nbrEtud).isEqualTo(1);
 }

 @Test void departmentsSubjectsAndGradesSupportCrudAndProtectReferences() throws Exception {
  http.perform(put("/tp7/departements/TI").contentType(MediaType.APPLICATION_JSON)
          .content("{\"nomDept\":\"Informatique modifiée\"}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.nomDept").value("Informatique modifiée"));
  http.perform(get("/tp7/departements")).andExpect(status().isOk())
          .andExpect(jsonPath("$[0].nomDept").value("Informatique modifiée"));
  http.perform(delete("/tp7/departements/TI")).andExpect(status().isConflict());
  http.perform(put("/tp7/matieres/AFCP").contentType(MediaType.APPLICATION_JSON)
          .content("{\"intMat\":\"Architecture\",\"description\":\"Cours\"}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.intMat").value("Architecture"));
  http.perform(get("/tp7/admin/matieres")).andExpect(status().isOk())
          .andExpect(jsonPath("$[0].description").value("Cours"));
  http.perform(delete("/tp7/matieres/AFCP")).andExpect(status().isConflict());

  String grade="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"valeurNote\":14.5}";
  http.perform(post("/tp7/notes").contentType(MediaType.APPLICATION_JSON).content(grade))
          .andExpect(status().isOk()).andExpect(jsonPath("$.valeurNote").value(14.5));
  http.perform(get("/tp7/notes")).andExpect(status().isOk())
          .andExpect(jsonPath("$[0].nom").value("Ben Foulen1"));
  http.perform(put("/tp7/notes/{nce}/{code}",student.id,"AFCP").contentType(MediaType.APPLICATION_JSON)
          .content("{\"valeurNote\":16.0}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.valeurNote").value(16.0));
  http.perform(delete("/tp7/notes/{nce}/{code}",student.id,"AFCP")).andExpect(status().isOk());
  http.perform(get("/tp7/notes")).andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());

  http.perform(post("/tp7/departements").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codDept\":\"EMPTY\",\"nomDept\":\"Vide\"}"))
          .andExpect(status().isOk());
  http.perform(delete("/tp7/departements/EMPTY")).andExpect(status().isOk());
  http.perform(post("/tp7/matieres").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codMat\":\"LIBRE\",\"intMat\":\"Matière libre\",\"hasTp\":false}"))
          .andExpect(status().isOk());
  http.perform(delete("/tp7/matieres/LIBRE")).andExpect(status().isOk());
  http.perform(get("/tp7/admin/matieres")).andExpect(status().isOk())
          .andExpect(jsonPath("$[?(@.codMat=='LIBRE')]").isEmpty());
 }

 @Test void unusedSubjectIsRemovedFromClassAndCatalogWhileLinkedSubjectIsProtected() throws Exception {
  http.perform(post("/tp7/matieres").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codMat\":\"TSTDEL\",\"intMat\":\"Matière test suppression\",\"hasTp\":false}"))
          .andExpect(status().isOk());
  http.perform(post("/tp7/classes-matieres").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codClass\":\"DSI33\",\"codMat\":\"TSTDEL\",\"coef\":1.0,\"chsm\":2}"))
          .andExpect(status().isOk());
  http.perform(put("/tp7/matieres/TSTDEL").contentType(MediaType.APPLICATION_JSON)
          .content("{\"intMat\":\"Matière test modifiée\",\"description\":\"ok\",\"hasTp\":false}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.intMat").value("Matière test modifiée"));
  http.perform(post("/tp7/matieres").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codMat\":\"TSTDEL\",\"intMat\":\"Doublon\",\"hasTp\":false}"))
          .andExpect(status().isConflict())
          .andExpect(jsonPath("$.message").value("Une matière avec ce code existe déjà."));
  http.perform(delete("/tp7/matieres/TSTDEL"))
          .andExpect(status().isConflict())
          .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("encore associée")));
  http.perform(delete("/tp7/classes-matieres/DSI33/TSTDEL")).andExpect(status().isOk());
  org.assertj.core.api.Assertions.assertThat(subjects.existsById("TSTDEL")).isFalse();
  http.perform(get("/tp7/matieres").param("codClass","DSI33"))
          .andExpect(status().isOk())
          .andExpect(jsonPath("$[?(@.codMat=='TSTDEL')]").isEmpty());
  http.perform(get("/tp7/admin/matieres")).andExpect(status().isOk())
          .andExpect(jsonPath("$[?(@.codMat=='TSTDEL')]").isEmpty());

  http.perform(delete("/tp7/matieres/AFCP")).andExpect(status().isConflict())
          .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("encore associée")));
 }

 @Test void cannotUnlinkSubjectWhenAcademicGradeReferencesIt() throws Exception {
  AcademicGrade grade = new AcademicGrade();
  grade.id = new AcademicGradeId(student.id, "AFCP", "2026-2027", 1);
  grade.etudiant = student;
  grade.matiere = subject;
  grade.ds = 14.0;
  grade.examen = 15.0;
  academicGrades.saveAndFlush(grade);

  http.perform(delete("/tp7/classes-matieres/DSI33/AFCP"))
          .andExpect(status().isConflict())
          .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("notes enregistrées")));
  org.assertj.core.api.Assertions.assertThat(
          classSubjects.existsByClasseCodClassAndMatiereCodMat("DSI33", "AFCP")).isTrue();
  org.assertj.core.api.Assertions.assertThat(subjects.existsById("AFCP")).isTrue();
 }

 @Test void allSubjectsUseTheSameEvaluationSaveUpdateAndAverageFlow() throws Exception {
  subject.hasTp = true;
  subjects.save(subject);
  addSubjectAndLink("SOA", false, 1.0);
  addSubjectAndLink("CROSS PLATEFORM", true, 1.0);
  addSubjectAndLink("ENG", false, 1.0);
  addSubjectAndLink("FR", false, 1.0);

  saveEvaluation("AFCP", "\"tp1\":14,\"tp2\":16,\"ds\":12,\"examen\":15", 14.10);
  saveEvaluation("SOA", "\"ds\":14,\"examen\":16", 15.40);
  saveEvaluation("CROSS PLATEFORM", "\"tp1\":12,\"tp2\":14,\"ds\":15,\"examen\":17", 15.60);
  saveEvaluation("ENG", "\"ds\":10,\"examen\":12", 11.40);
  saveEvaluation("FR", "\"ds\":8,\"examen\":10", 9.40);

  http.perform(get("/tp7/resultats/{nce}", student.id)
          .param("anneeUniversitaire", "2026-2027").param("semestre", "1"))
          .andExpect(status().isOk())
          .andExpect(jsonPath("$.matieres", org.hamcrest.Matchers.hasSize(5)))
          .andExpect(jsonPath("$.moyenneGenerale").value(13.18))
          .andExpect(jsonPath("$.matieres[?(@.codMat=='SOA')].moyenne").value(org.hamcrest.Matchers.contains(15.4)))
          .andExpect(jsonPath("$.matieres[?(@.codMat=='CROSS PLATEFORM')].moyenne").value(org.hamcrest.Matchers.contains(15.6)));

  String revised = "{\"nce\":" + student.id + ",\"codMat\":\"SOA\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"ds\":18,\"examen\":16}";
  http.perform(put("/tp7/evaluations/{nce}/{code}/{year}/{semester}", student.id, "SOA", "2026-2027", 1)
          .contentType(MediaType.APPLICATION_JSON).content(revised))
          .andExpect(status().isOk()).andExpect(jsonPath("$.moyenne").value(16.60));
  http.perform(get("/tp7/resultats/{nce}", student.id)
          .param("anneeUniversitaire", "2026-2027").param("semestre", "1"))
          .andExpect(status().isOk())
          .andExpect(jsonPath("$.matieres[?(@.codMat=='SOA')].moyenne").value(org.hamcrest.Matchers.contains(16.6)));
 }

 private void addSubjectAndLink(String code, boolean hasTp, double coefficient) {
  Subject material = new Subject();
  material.codMat = code;
  material.intMat = code;
  material.hasTp = hasTp;
  subjects.save(material);
  ClassSubject link = new ClassSubject();
  link.classe = schoolClass;
  link.matiere = material;
  link.coef = coefficient;
  link.chsm = 2;
  classSubjects.save(link);
 }

 private void saveEvaluation(String code, String values, double average) throws Exception {
  String body = "{\"nce\":" + student.id + ",\"codMat\":\"" + code
          + "\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1," + values + "}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(body))
          .andExpect(status().isCreated())
          .andExpect(jsonPath("$.codMat").value(code))
          .andExpect(jsonPath("$.moyenne").value(average));
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(body))
          .andExpect(status().isConflict());
 }

 @Test void classesBelongToDepartmentsAndAbsenceEliminationIsPerSubject() throws Exception {
  http.perform(post("/classes").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codClass\":\"RSI\",\"nomClass\":\"RSI\",\"codDept\":\"TI\"}"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.codDept").value("TI"));
  http.perform(get("/tp7/classes").param("codDept","TI"))
          .andExpect(status().isOk()).andExpect(jsonPath("$[?(@.codClass=='RSI')]" ).exists());
  Subject other=new Subject();other.codMat="SOA";other.intMat="SOA";subjects.save(other);
  http.perform(post("/tp7/classes-matieres").contentType(MediaType.APPLICATION_JSON)
          .content("{\"codClass\":\"DSI33\",\"codMat\":\"SOA\",\"coef\":1.0,\"chsm\":3}"))
          .andExpect(status().isOk());
  http.perform(get("/tp7/matieres").param("codClass","DSI33"))
          .andExpect(status().isOk()).andExpect(jsonPath("$[?(@.codMat=='SOA')]" ).exists());
  http.perform(post("/tp7/absences").contentType(MediaType.APPLICATION_JSON)
          .content("{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"dateA\":\"2025-11-11\",\"nha\":10.5}"))
          .andExpect(status().isOk());
  http.perform(post("/tp7/absences").contentType(MediaType.APPLICATION_JSON)
          .content("{\"nce\":"+student.id+",\"codMat\":\"SOA\",\"dateA\":\"2025-11-11\",\"nha\":10.0}"))
          .andExpect(status().isOk());
  http.perform(get("/tp7/totaux").param("nce",student.id.toString()))
          .andExpect(status().isOk())
          .andExpect(jsonPath("$[?(@.codMat=='AFCP')].elimine").value(org.hamcrest.Matchers.contains(true)))
          .andExpect(jsonPath("$[?(@.codMat=='SOA')].elimine").value(org.hamcrest.Matchers.contains(false)));
  http.perform(post("/tp7/absences").contentType(MediaType.APPLICATION_JSON)
          .content("{\"nce\":"+student.id+",\"codMat\":\"ABSENT\",\"dateA\":\"2025-11-11\",\"nha\":1.0}"))
          .andExpect(status().isBadRequest());
  http.perform(delete("/tp7/classes-matieres/DSI33/SOA")).andExpect(status().isConflict());
 }

 @Test void academicGradesCalculateFormulasPendingZeroAndWeightedResultByPeriod() throws Exception {
  Grade historical=new Grade();historical.etudiant=student;historical.matiere=subject;historical.id=new GradeId(student.id,"AFCP");historical.valeurNote=13.25;legacyGrades.save(historical);
  Subject noTp=new Subject();noTp.codMat="ANG";noTp.intMat="Anglais";noTp.hasTp=false;subjects.save(noTp);
  ClassSubject afcpLink=classSubjects.findAllByClasseCodClass("DSI33").getFirst();
  afcpLink.coef=3.0;
  classSubjects.save(afcpLink);
  ClassSubject english=new ClassSubject();english.classe=schoolClass;english.matiere=noTp;english.coef=1.0;english.chsm=2;classSubjects.save(english);

  String tpGrade="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"tp1\":14,\"tp2\":16,\"ds\":12,\"examen\":15}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(tpGrade))
          .andExpect(status().isCreated()).andExpect(jsonPath("$.moyenne").value(14.10));
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(tpGrade))
          .andExpect(status().isConflict());

  String englishGrade="{\"nce\":"+student.id+",\"codMat\":\"ANG\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"ds\":14,\"examen\":16}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(englishGrade))
          .andExpect(status().isCreated()).andExpect(jsonPath("$.moyenne").value(15.40));
  http.perform(get("/tp7/resultats/{nce}",student.id).param("anneeUniversitaire","2026-2027").param("semestre","1"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.moyenneGenerale").value(14.43))
          .andExpect(jsonPath("$.matieresCompletes").value(2)).andExpect(jsonPath("$.resultatFinal").value("VALIDE"));
  http.perform(get("/tp7/notes")).andExpect(status().isOk()).andExpect(jsonPath("$[0].valeurNote").value(13.25));
  String revisedGrade="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"tp1\":18,\"tp2\":18,\"ds\":12,\"examen\":15}";
  http.perform(put("/tp7/evaluations/{nce}/{code}/{year}/{semester}",student.id,"AFCP","2026-2027",1)
          .contentType(MediaType.APPLICATION_JSON).content(revisedGrade)).andExpect(status().isOk())
          .andExpect(jsonPath("$.moyenne").value(14.70));
  http.perform(get("/tp7/resultats/{nce}",student.id).param("anneeUniversitaire","2026-2027").param("semestre","1"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.moyenneGenerale").value(14.88));
  http.perform(get("/tp7/evaluations").param("codClass","DSI33").param("anneeUniversitaire","2026-2027").param("semestre","1"))
          .andExpect(status().isOk()).andExpect(jsonPath("$[?(@.codMat=='AFCP')]").value(org.hamcrest.Matchers.hasSize(1)));
  http.perform(get("/tp7/notes")).andExpect(status().isOk()).andExpect(jsonPath("$[0].valeurNote").value(13.25));
  String invalidRange="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":2,\"tp1\":21,\"tp2\":10,\"ds\":12,\"examen\":15}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(invalidRange)).andExpect(status().isBadRequest());

  String zeroGrade="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":2,\"tp1\":0,\"tp2\":10,\"ds\":12,\"examen\":15}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(zeroGrade))
          .andExpect(status().isCreated()).andExpect(jsonPath("$.moyenne").value(12.10));
  String incomplete="{\"nce\":"+student.id+",\"codMat\":\"ANG\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":2,\"ds\":null,\"examen\":16}";
  http.perform(post("/tp7/evaluations").contentType(MediaType.APPLICATION_JSON).content(incomplete))
          .andExpect(status().isCreated()).andExpect(jsonPath("$.moyenne").value(org.hamcrest.Matchers.nullValue())).andExpect(jsonPath("$.etat").value("EN_ATTENTE"));
  http.perform(get("/tp7/resultats/{nce}",student.id).param("anneeUniversitaire","2026-2027").param("semestre","2"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.moyenneGenerale").value(org.hamcrest.Matchers.nullValue()))
          .andExpect(jsonPath("$.matieresIncompletes").value(1)).andExpect(jsonPath("$.resultatFinal").value("EN_ATTENTE"));

  String missingTp="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"tp1\":null,\"tp2\":16,\"ds\":12,\"examen\":15}";
  http.perform(put("/tp7/evaluations/{nce}/{code}/{year}/{semester}",student.id,"AFCP","2026-2027",1)
          .contentType(MediaType.APPLICATION_JSON).content(missingTp)).andExpect(status().isOk())
          .andExpect(jsonPath("$.moyenne").value(org.hamcrest.Matchers.nullValue())).andExpect(jsonPath("$.etat").value("EN_ATTENTE"));
  http.perform(get("/tp7/resultats/{nce}",student.id).param("anneeUniversitaire","2026-2027").param("semestre","1"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.matieresIncompletes").value(1))
          .andExpect(jsonPath("$.matieresValidees").value(1));
 }
}
