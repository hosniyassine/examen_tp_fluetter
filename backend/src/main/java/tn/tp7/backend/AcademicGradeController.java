package tn.tp7.backend;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/tp7")
class AcademicGradeController {
    private final AcademicGradeRepository grades;
    private final AcademicGradeService service;
    private final StudentRepository students;
    private final TeacherAssignmentRepository assignments;

    AcademicGradeController(AcademicGradeRepository grades, AcademicGradeService service, StudentRepository students,
                            TeacherAssignmentRepository assignments) {
        this.grades = grades;
        this.service = service;
        this.students = students;
        this.assignments = assignments;
    }

    @GetMapping("/evaluations")
    List<Map<String, Object>> evaluations(@RequestParam @NotBlank String codClass,
                                         @RequestParam @NotBlank String anneeUniversitaire,
                                         @RequestParam @NotNull @Min(1) @Max(2) Integer semestre,
                                         @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        List<Map<String,Object>> rows=service.evaluationsForClass(codClass, anneeUniversitaire, semestre);
        if(actor!=null&&"TEACHER".equals(actor.role)) rows=rows.stream().filter(r->teacherHas(actor,(String)r.get("codClass"),(String)r.get("codMat"))).toList();
        return rows;
    }

    @PostMapping("/evaluations")
    @ResponseStatus(HttpStatus.CREATED)
    Map<String, Object> create(@Valid @RequestBody EvaluationInput input,
                               @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        requireTeacherAssignment(actor,input.nce(),input.codMat());
        return service.evaluationMap(service.save(input, null, null, null, null, true));
    }

    @PutMapping("/evaluations/{nce}/{codMat}/{year}/{semester}")
    Map<String, Object> update(@PathVariable Integer nce, @PathVariable String codMat,
                               @PathVariable String year, @PathVariable Integer semester,
                               @Valid @RequestBody EvaluationInput input,
                               @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        requireTeacherAssignment(actor,nce,codMat);
        return service.evaluationMap(service.save(input, nce, codMat, year, semester, false));
    }

    @DeleteMapping("/evaluations/{nce}/{codMat}/{year}/{semester}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(@PathVariable Integer nce, @PathVariable String codMat,
                @PathVariable String year, @PathVariable Integer semester,
                @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        requireTeacherAssignment(actor,nce,codMat);
        service.delete(nce, codMat, year, semester);
    }

    @GetMapping("/resultats/{nce}")
    Map<String, Object> studentResults(@PathVariable Integer nce,
                                       @RequestParam @NotBlank String anneeUniversitaire,
                                       @RequestParam @NotNull @Min(1) @Max(2) Integer semestre,
                                       @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        if(actor!=null&&"TEACHER".equals(actor.role)) requireTeacherClass(actor,students.findById(nce).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Étudiant introuvable.")).classe.codClass);
        return service.studentResults(nce, anneeUniversitaire, semestre).getFirst();
    }

    @GetMapping("/resultats")
    List<Map<String, Object>> classResults(@RequestParam @NotBlank String codClass,
                                           @RequestParam @NotBlank String anneeUniversitaire,
                                           @RequestParam @NotNull @Min(1) @Max(2) Integer semestre,
                                           @RequestParam(required = false) String recherche,
                                           @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        if(actor!=null&&"TEACHER".equals(actor.role)) requireTeacherClass(actor,codClass);
        String query = recherche == null ? "" : recherche.trim().toLowerCase(java.util.Locale.ROOT);
        return students.findAllByClasseCodClass(codClass).stream()
                .filter(student -> query.isEmpty()
                        || String.valueOf(student.id).contains(query)
                        || student.nom.toLowerCase(java.util.Locale.ROOT).contains(query)
                        || student.prenom.toLowerCase(java.util.Locale.ROOT).contains(query))
                .map(student -> service.studentResults(student.id, anneeUniversitaire, semestre).getFirst())
                .toList();
    }

    @GetMapping("/mes-resultats")
    Map<String,Object> ownResults(@RequestParam @NotBlank String anneeUniversitaire,
                                  @RequestParam @NotNull @Min(1) @Max(2) Integer semestre,
                                  @RequestAttribute(value="authenticatedUser",required=false) AppUser actor) {
        if(actor==null||actor.student==null) throw new ResponseStatusException(HttpStatus.CONFLICT,"Ce compte n'est pas associé à un étudiant.");
        return service.studentResults(actor.student.id,anneeUniversitaire,semestre).getFirst();
    }

    private void requireTeacherAssignment(AppUser actor,Integer studentId,String codMat){
        if(actor==null||!"TEACHER".equals(actor.role))return;
        Student student=students.findById(studentId).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"Étudiant introuvable."));
        if(!teacherHas(actor,student.classe.codClass,codMat))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Cette matière ne fait pas partie de vos affectations.");
    }
    private boolean teacherHas(AppUser actor,String codClass,String codMat){
        if(actor==null||actor.teacher==null)return false;
        return assignments.findAllByTeacherId(actor.teacher.id).stream().anyMatch(a->a.classSubject.classe.codClass.equals(codClass)&&a.classSubject.matiere.codMat.equals(codMat));
    }
    private void requireTeacherClass(AppUser actor,String codClass){
        if(actor==null||actor.teacher==null||assignments.findAllByTeacherId(actor.teacher.id).stream().noneMatch(a->a.classSubject.classe.codClass.equals(codClass)))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Cette classe ne fait pas partie de vos affectations.");
    }
}
