package tn.tp7.backend;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RestController
@RequestMapping("/classes")
class SchoolClassController {
    private final SchoolClassRepository classes;
    private final StudentRepository students;
    private final DepartmentRepository departments;
    private final ClassSubjectRepository classSubjects;
    SchoolClassController(SchoolClassRepository classes, StudentRepository students, DepartmentRepository departments, ClassSubjectRepository classSubjects) {
        this.classes = classes; this.students = students; this.departments = departments; this.classSubjects = classSubjects;
    }
    @GetMapping List<ApiModels.ClassroomResponse> list() {
        return classes.findAll().stream().map(this::response).toList();
    }
    @PostMapping ApiModels.ClassroomResponse create(@Valid @RequestBody ApiModels.ClassroomRequest in) {
        if (classes.existsById(in.codClass())) throw new ResponseStatusException(HttpStatus.CONFLICT, "Cette classe existe déjà.");
        SchoolClass entity = new SchoolClass(); entity.codClass = in.codClass().trim(); entity.nomClass = in.nomClass().trim();
        entity.departement = department(in.codDept());
        return response(classes.save(entity));
    }
    @PutMapping("/{codClass}") @Transactional
    ApiModels.ClassroomResponse update(@PathVariable String codClass, @Valid @RequestBody ApiModels.ClassroomRequest in) {
        SchoolClass entity = classes.findById(codClass).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Classe introuvable."));
        if (!codClass.equals(in.codClass()) && classes.existsById(in.codClass())) throw new ResponseStatusException(HttpStatus.CONFLICT, "Cette classe existe déjà.");
        if (!codClass.equals(in.codClass().trim())) {
            SchoolClass replacement = new SchoolClass();
            replacement.codClass = in.codClass().trim();
            replacement.nomClass = in.nomClass().trim();
            replacement.departement = department(in.codDept());
            classes.saveAndFlush(replacement);
            List<Student> enrolled = students.findAllByClasseCodClass(codClass);
            enrolled.forEach(student -> student.classe = replacement);
            students.saveAllAndFlush(enrolled);
            classes.delete(entity);
            return response(replacement);
        }
        entity.nomClass = in.nomClass().trim();
        entity.departement = department(in.codDept());
        return response(classes.save(entity));
    }
    @DeleteMapping("/{codClass}") void delete(@PathVariable String codClass) {
        if (!classes.existsById(codClass)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Classe introuvable.");
        if (students.countByClasseCodClass(codClass) > 0) throw new ResponseStatusException(HttpStatus.CONFLICT, "La classe contient encore des étudiants.");
        if (classSubjects.existsByClasseCodClass(codClass)) throw new ResponseStatusException(HttpStatus.CONFLICT, "La classe contient encore des matières associées.");
        classes.deleteById(codClass);
    }
    private ApiModels.ClassroomResponse response(SchoolClass e) {
        return new ApiModels.ClassroomResponse(e.codClass, e.nomClass, students.countByClasseCodClass(e.codClass), e.departement == null ? null : e.departement.codDept);
    }
    private Department department(String code) {
        if (code == null || code.isBlank()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Un département est requis pour la classe.");
        return departments.findById(code).orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Département introuvable."));
    }
}

@RestController
@RequestMapping("/formations")
class TrainingController {
    private final TrainingRepository trainings;
    TrainingController(TrainingRepository trainings) { this.trainings = trainings; }
    @GetMapping List<ApiModels.TrainingResponse> list() { return trainings.findAll().stream().map(this::response).toList(); }
    @PostMapping ApiModels.TrainingResponse create(@Valid @RequestBody ApiModels.TrainingRequest in) {
        Training e = new Training(); apply(e, in); return response(trainings.save(e));
    }
    @PutMapping("/{id}") ApiModels.TrainingResponse update(@PathVariable Integer id, @Valid @RequestBody ApiModels.TrainingRequest in) {
        Training e = trainings.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Formation introuvable."));
        apply(e, in); return response(trainings.save(e));
    }
    @DeleteMapping("/{id}") void delete(@PathVariable Integer id) {
        if (!trainings.existsById(id)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Formation introuvable.");
        trainings.deleteById(id);
    }
    private void apply(Training e, ApiModels.TrainingRequest in) {
        if (in.duree() != null && in.duree() < 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La durée doit être positive.");
        e.nom = in.nom().trim(); e.duree = in.duree();
    }
    private ApiModels.TrainingResponse response(Training e) { return new ApiModels.TrainingResponse(e.id, e.nom, e.duree); }
}

@RestController
@RequestMapping("/etudiants")
class StudentController {
    private final StudentRepository students;
    private final SchoolClassRepository classes;
    private final TrainingRepository trainings;
    StudentController(StudentRepository students, SchoolClassRepository classes, TrainingRepository trainings) {
        this.students = students; this.classes = classes; this.trainings = trainings;
    }
    @GetMapping List<ApiModels.StudentResponse> list() { return students.findAll().stream().map(this::response).toList(); }
    @PostMapping ApiModels.StudentResponse create(@Valid @RequestBody ApiModels.StudentRequest in) {
        Student e = new Student(); apply(e, in); return response(students.save(e));
    }
    @PutMapping("/{id}") ApiModels.StudentResponse update(@PathVariable Integer id, @Valid @RequestBody ApiModels.StudentRequest in) {
        Student e = students.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Étudiant introuvable."));
        apply(e, in); return response(students.save(e));
    }
    @DeleteMapping("/{id}") void delete(@PathVariable Integer id) {
        if (!students.existsById(id)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Étudiant introuvable.");
        students.deleteById(id);
    }
    private void apply(Student e, ApiModels.StudentRequest in) {
        e.nom = in.nom().trim(); e.prenom = in.prenom().trim(); e.dateNais = in.dateNais();
        if (in.classe() == null || in.classe().codClass() == null || in.classe().codClass().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Une classe est requise.");
        }
        e.classe = classes.findById(in.classe().codClass()).orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Classe introuvable."));
        e.formation = in.formation() == null || in.formation().id() == null ? null : trainings.findById(in.formation().id()).orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Formation introuvable."));
    }
    private ApiModels.StudentResponse response(Student e) {
        ApiModels.ClassroomResponse c = new ApiModels.ClassroomResponse(e.classe.codClass, e.classe.nomClass, students.countByClasseCodClass(e.classe.codClass), e.classe.departement == null ? null : e.classe.departement.codDept);
        ApiModels.TrainingResponse f = e.formation == null ? null : new ApiModels.TrainingResponse(e.formation.id, e.formation.nom, e.formation.duree);
        return new ApiModels.StudentResponse(e.id, e.nom, e.prenom, e.dateNais, c, f);
    }
}
