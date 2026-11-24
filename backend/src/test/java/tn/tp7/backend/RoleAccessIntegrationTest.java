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

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:tp7roles;DB_CLOSE_DELAY=-1","spring.jpa.hibernate.ddl-auto=create-drop","app.bootstrap-admin-email=admin@example.test","app.security.enabled=true"})
@AutoConfigureMockMvc
class RoleAccessIntegrationTest {
    @Autowired MockMvc http;
    @Autowired UserRepository users;
    @Autowired StudentRepository students;
    @Autowired TeacherRepository teachers;
    @Autowired DepartmentRepository departments;
    @Autowired SchoolClassRepository classes;
    @Autowired SubjectRepository subjects;
    @Autowired ClassSubjectRepository classSubjects;
    @Autowired TeacherAssignmentRepository assignments;
    @Autowired AcademicGradeRepository academicGrades;
    @Autowired GradeRepository legacyGrades;
    @Autowired AbsenceRepository absences;

    Department department;
    SchoolClass schoolClass;
    Student student;
    Subject afcp,soa;
    String adminToken;

    @BeforeEach void seed() throws Exception {
        assignments.deleteAll();absences.deleteAll();academicGrades.deleteAll();legacyGrades.deleteAll();users.deleteAll();classSubjects.deleteAll();students.deleteAll();classes.deleteAll();departments.deleteAll();subjects.deleteAll();teachers.deleteAll();
        department=new Department();department.codDept="TI";department.nomDept="Informatique";departments.save(department);
        schoolClass=new SchoolClass();schoolClass.codClass="DSI";schoolClass.nomClass="DSI";schoolClass.departement=department;classes.save(schoolClass);
        student=new Student();student.nom="Foulen";student.prenom="A";student.classe=schoolClass;student=students.save(student);
        afcp=subject("AFCP",true);soa=subject("SOA",false);
        link(afcp);link(soa);
        adminToken=registerAndLogin("admin@example.test","admin-password");
    }

    @Test void studentCanOnlyReadOwnResultsAndAdminCanReadSchoolData() throws Exception {
        http.perform(get("/classes").header("Authorization",bearer(adminToken))).andExpect(status().isOk());
        String studentToken=registerAndLogin("student@example.test","student-password");
        AppUser account=users.findByEmail("student@example.test").orElseThrow();
        account.student=student;users.save(account);
        studentToken=login("student@example.test","student-password");
        http.perform(get("/tp7/mes-resultats").header("Authorization",bearer(studentToken))
                .param("anneeUniversitaire","2026-2027").param("semestre","1"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.nce").value(student.id));
        http.perform(get("/classes").header("Authorization",bearer(studentToken))).andExpect(status().isForbidden());
        http.perform(get("/tp7/resultats/{nce}",student.id).header("Authorization",bearer(studentToken))
                .param("anneeUniversitaire","2026-2027").param("semestre","1")).andExpect(status().isForbidden());
    }

    @Test void teacherCanOnlySeeAndEnterGradesForAssignedSubjects() throws Exception {
        Teacher teacher=new Teacher();teacher.nom="Prof";teacher.prenom="Test";teacher=teachers.save(teacher);
        AppUser account=new AppUser();account.email="teacher@example.test";account.passwordHash=new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder().encode("teacher-password");account.role="TEACHER";account.teacher=teacher;users.save(account);
        ClassSubject assigned=classSubjects.findByClasseCodClassAndMatiereCodMat("DSI","AFCP").orElseThrow();
        TeacherAssignment assignment=new TeacherAssignment();assignment.teacher=teacher;assignment.classSubject=assigned;assignments.save(assignment);
        String token=login("teacher@example.test","teacher-password");
        http.perform(get("/tp7/enseignants/moi/classes").header("Authorization",bearer(token)))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].codMat").value("AFCP"));
        http.perform(get("/tp7/matieres").header("Authorization",bearer(token)).param("codClass","DSI"))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].codMat").value("AFCP"))
                .andExpect(jsonPath("$[1]").doesNotExist());
        String allowed="{\"nce\":"+student.id+",\"codMat\":\"AFCP\",\"anneeUniversitaire\":\"2026-2027\",\"semestre\":1,\"tp1\":12,\"tp2\":12,\"ds\":12,\"examen\":12}";
        http.perform(post("/tp7/evaluations").header("Authorization",bearer(token)).contentType(MediaType.APPLICATION_JSON).content(allowed)).andExpect(status().isCreated());
        String denied=allowed.replace("AFCP","SOA");
        http.perform(post("/tp7/evaluations").header("Authorization",bearer(token)).contentType(MediaType.APPLICATION_JSON).content(denied)).andExpect(status().isForbidden());
    }

    private Subject subject(String code,boolean hasTp){Subject s=new Subject();s.codMat=code;s.intMat=code;s.hasTp=hasTp;return subjects.save(s);}
    private void link(Subject subject){ClassSubject l=new ClassSubject();l.classe=schoolClass;l.matiere=subject;l.coef=1.0;l.chsm=2;classSubjects.save(l);}
    private String registerAndLogin(String email,String password)throws Exception{
        http.perform(post("/register").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\""+email+"\",\"password\":\""+password+"\"}"))
                .andExpect(status().isCreated());
        return login(email,password);
    }
    private String login(String email,String password)throws Exception{
        String response=http.perform(post("/login").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\""+email+"\",\"password\":\""+password+"\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return response.replaceAll(".*\\\"token\\\":\\\"([^\\\"]+)\\\".*","$1");
    }
    private String bearer(String token){return "Bearer "+token;}
}
