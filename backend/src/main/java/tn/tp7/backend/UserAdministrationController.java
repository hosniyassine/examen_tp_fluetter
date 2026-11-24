package tn.tp7.backend;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/tp7/admin")
class UserAdministrationController {
    private final UserRepository users;
    private final TeacherRepository teachers;
    private final TeacherAssignmentRepository assignments;
    private final ClassSubjectRepository classSubjects;
    private final StudentRepository students;

    UserAdministrationController(UserRepository users, TeacherRepository teachers,
                                 TeacherAssignmentRepository assignments, ClassSubjectRepository classSubjects,
                                 StudentRepository students) {
        this.users = users; this.teachers = teachers; this.assignments = assignments; this.classSubjects = classSubjects; this.students=students;
    }

    record UserRoleInput(@NotBlank String role, Integer studentId, Integer teacherId) {}
    record TeacherInput(@NotBlank String nom, @NotBlank String prenom) {}
    record AssignmentInput(@NotNull Integer teacherId, @NotBlank String codClass, @NotBlank String codMat) {}

    @GetMapping("/users") List<Map<String,Object>> users() { return users.findAll().stream().map(this::userMap).toList(); }

    @PutMapping("/users/{id}/role") @Transactional Map<String,Object> updateRole(@PathVariable Integer id, @Valid @RequestBody UserRoleInput input) {
        AppUser user=users.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Compte introuvable."));
        String role=input.role().trim().toUpperCase(java.util.Locale.ROOT);
        if(!List.of("ADMIN","TEACHER","STUDENT").contains(role))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Rôle invalide.");
        if(role.equals("STUDENT")){
            if(input.studentId()==null||input.teacherId()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Associez le compte à un étudiant uniquement.");
        }
        user.role=role;
        if(role.equals("STUDENT")){user.student=studentReference(input.studentId());user.teacher=null;}
        else if(role.equals("TEACHER")){if(input.teacherId()==null||input.studentId()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Associez le compte à un enseignant uniquement.");user.teacher=teacherReference(input.teacherId());user.student=null;}
        else {if(input.studentId()!=null||input.teacherId()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Un administrateur n'est pas lié à un étudiant ou enseignant.");user.student=null;user.teacher=null;}
        users.save(user);return userMap(user);
    }

    @GetMapping("/enseignants") List<Map<String,Object>> teachers(){return teachers.findAll().stream().map(this::teacherMap).toList();}
    @PostMapping("/enseignants") @ResponseStatus(HttpStatus.CREATED) Map<String,Object> addTeacher(@Valid @RequestBody TeacherInput input){Teacher teacher=new Teacher();teacher.nom=input.nom().trim();teacher.prenom=input.prenom().trim();return teacherMap(teachers.save(teacher));}
    @PutMapping("/enseignants/{id}") Map<String,Object> updateTeacher(@PathVariable Integer id,@Valid @RequestBody TeacherInput input){Teacher teacher=teacherReference(id);teacher.nom=input.nom().trim();teacher.prenom=input.prenom().trim();return teacherMap(teachers.save(teacher));}
    @DeleteMapping("/enseignants/{id}") @Transactional void deleteTeacher(@PathVariable Integer id){Teacher teacher=teacherReference(id);if(users.existsByTeacherId(id)||assignments.existsByTeacherId(id))throw new ResponseStatusException(HttpStatus.CONFLICT,"L'enseignant est associé à un compte ou à des matières.");teachers.delete(teacher);}

    @GetMapping("/affectations") List<Map<String,Object>> assignments(){return assignments.findAll().stream().map(this::assignmentMap).toList();}
    @PostMapping("/affectations") @ResponseStatus(HttpStatus.CREATED) Map<String,Object> addAssignment(@Valid @RequestBody AssignmentInput input){Teacher teacher=teacherReference(input.teacherId());ClassSubject link=classSubjects.findByClasseCodClassAndMatiereCodMat(input.codClass(),input.codMat()).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"La matière n'est pas affectée à cette classe."));if(assignments.existsByTeacherIdAndClassSubjectId(teacher.id,link.id))throw new ResponseStatusException(HttpStatus.CONFLICT,"Cette affectation existe déjà.");TeacherAssignment assignment=new TeacherAssignment();assignment.teacher=teacher;assignment.classSubject=link;return assignmentMap(assignments.save(assignment));}
    @DeleteMapping("/affectations/{id}") void deleteAssignment(@PathVariable Integer id){if(!assignments.existsById(id))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Affectation introuvable.");assignments.deleteById(id);}

    private Student studentReference(Integer id){return students.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));}
    private Teacher teacherReference(Integer id){return teachers.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enseignant introuvable."));}
    private Map<String,Object> teacherMap(Teacher t){return Map.of("id",t.id,"nom",t.nom,"prenom",t.prenom);}
    private Map<String,Object> assignmentMap(TeacherAssignment a){return Map.of("id",a.id,"teacherId",a.teacher.id,"teacher",a.teacher.prenom+" "+a.teacher.nom,"codClass",a.classSubject.classe.codClass,"codMat",a.classSubject.matiere.codMat,"matiere",a.classSubject.matiere.intMat);}
    private Map<String,Object> userMap(AppUser user){Map<String,Object> data=new java.util.LinkedHashMap<>();data.put("id",user.id);data.put("email",user.email);data.put("role",user.role);data.put("studentId",user.student==null?null:user.student.id);data.put("student",user.student==null?null:user.student.prenom+" "+user.student.nom);data.put("teacherId",user.teacher==null?null:user.teacher.id);data.put("teacher",user.teacher==null?null:user.teacher.prenom+" "+user.teacher.nom);return data;}
}
