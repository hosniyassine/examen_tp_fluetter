package tn.tp7.backend;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
class AcademicGradeService {
    private final AcademicGradeRepository grades;
    private final StudentRepository students;
    private final SubjectRepository subjects;
    private final ClassSubjectRepository classSubjects;

    AcademicGradeService(AcademicGradeRepository grades, StudentRepository students,
                         SubjectRepository subjects, ClassSubjectRepository classSubjects) {
        this.grades = grades;
        this.students = students;
        this.subjects = subjects;
        this.classSubjects = classSubjects;
    }

    @Transactional
    AcademicGrade save(EvaluationInput input, Integer pathStudentId, String pathSubjectCode,
                       String pathYear, Integer pathSemester, boolean create) {
        validateYear(input.anneeUniversitaire());
        Integer studentId = create ? input.nce() : pathStudentId;
        String subjectCode = create ? input.codMat() : pathSubjectCode;
        String year = create ? input.anneeUniversitaire() : pathYear;
        Integer semester = create ? input.semestre() : pathSemester;
        if (!create && (!year.equals(input.anneeUniversitaire()) || !semester.equals(input.semestre()))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La période d'une note existante ne peut pas être modifiée.");
        }
        Student student = students.findById(studentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Étudiant introuvable."));
        Subject subject = subjects.findById(subjectCode)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Matière introuvable."));
        if (subject.hasTp == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Configurez d'abord si cette matière comporte des TP.");
        }
        if (!classSubjects.existsByClasseCodClassAndMatiereCodMat(student.classe.codClass, subjectCode)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cette matière n'appartient pas à la classe de l'étudiant.");
        }
        AcademicGradeId id = new AcademicGradeId(studentId, subjectCode, year, semester);
        AcademicGrade grade = grades.findById(id).orElse(null);
        if (create && grade != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Les notes existent déjà pour cet étudiant, cette matière et cette période.");
        }
        if (!create && grade == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Saisie de notes introuvable.");
        }
        if (grade == null) grade = new AcademicGrade();
        grade.id = id;
        grade.etudiant = student;
        grade.matiere = subject;
        grade.tp1 = subject.hasTp ? input.tp1() : null;
        grade.tp2 = subject.hasTp ? input.tp2() : null;
        grade.ds = input.ds();
        grade.examen = input.examen();
        return grades.save(grade);
    }

    Map<String, Object> evaluationMap(AcademicGrade grade) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("nce", grade.etudiant.id);
        result.put("nom", grade.etudiant.nom);
        result.put("prenom", grade.etudiant.prenom);
        result.put("codClass", grade.etudiant.classe.codClass);
        result.put("codMat", grade.matiere.codMat);
        result.put("intMat", grade.matiere.intMat);
        result.put("hasTp", grade.matiere.hasTp);
        result.put("anneeUniversitaire", grade.id.academicYear);
        result.put("semestre", grade.id.semester);
        result.put("tp1", grade.tp1);
        result.put("tp2", grade.tp2);
        result.put("ds", grade.ds);
        result.put("examen", grade.examen);
        result.put("saisieExiste", true);
        result.put("moyenne", calculate(grade.matiere.hasTp, grade.tp1, grade.tp2, grade.ds, grade.examen));
        result.put("etat", complete(grade.matiere.hasTp, grade.tp1, grade.tp2, grade.ds, grade.examen)
                ? (calculate(grade.matiere.hasTp, grade.tp1, grade.tp2, grade.ds, grade.examen) >= 10 ? "VALIDEE" : "NON_VALIDEE")
                : "EN_ATTENTE");
        return result;
    }

    List<Map<String, Object>> evaluationsForClass(String codClass, String year, Integer semester) {
        validateYear(year);
        return grades.findAllByEtudiantClasseCodClassAndIdAcademicYearAndIdSemester(codClass, year, semester)
                .stream().map(this::evaluationMap).toList();
    }

    void delete(Integer studentId, String subjectCode, String year, Integer semester) {
        AcademicGradeId id = new AcademicGradeId(studentId, subjectCode, year, semester);
        if (!grades.existsById(id)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Saisie de notes introuvable.");
        grades.deleteById(id);
    }

    List<Map<String, Object>> studentResults(Integer studentId, String year, Integer semester) {
        validateYear(year);
        Student student = students.findById(studentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Étudiant introuvable."));
        List<Map<String, Object>> materialResults = new ArrayList<>();
        BigDecimal weighted = BigDecimal.ZERO;
        BigDecimal coefficientSum = BigDecimal.ZERO;
        int completeCount = 0;
        int validatedCount = 0;
        int failedCount = 0;
        List<ClassSubject> materials = classSubjects.findAllByClasseCodClass(student.classe.codClass);
        for (ClassSubject link : materials) {
            AcademicGrade grade = grades.findByEtudiantIdAndMatiereCodMatAndIdAcademicYearAndIdSemester(
                    studentId, link.matiere.codMat, year, semester).orElse(null);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("nce", student.id);
            row.put("nom", student.nom);
            row.put("prenom", student.prenom);
            row.put("codClass", student.classe.codClass);
            row.put("codMat", link.matiere.codMat);
            row.put("intMat", link.matiere.intMat);
            row.put("coef", link.coef);
            row.put("hasTp", link.matiere.hasTp);
            row.put("anneeUniversitaire", year);
            row.put("semestre", semester);
            Double tp1 = grade == null ? null : grade.tp1;
            Double tp2 = grade == null ? null : grade.tp2;
            Double ds = grade == null ? null : grade.ds;
            Double exam = grade == null ? null : grade.examen;
            boolean complete = complete(link.matiere.hasTp, tp1, tp2, ds, exam);
            Double average = calculate(link.matiere.hasTp, tp1, tp2, ds, exam);
            row.put("tp1", tp1);
            row.put("tp2", tp2);
            row.put("ds", ds);
            row.put("examen", exam);
            row.put("saisieExiste", grade != null);
            row.put("moyenne", average);
            row.put("etat", complete ? average >= 10 ? "VALIDEE" : "NON_VALIDEE" : "EN_ATTENTE");
            if (complete) {
                completeCount++;
                BigDecimal coefficient = BigDecimal.valueOf(link.coef);
                weighted = weighted.add(BigDecimal.valueOf(average).multiply(coefficient));
                coefficientSum = coefficientSum.add(coefficient);
                if (average >= 10) validatedCount++; else failedCount++;
            }
            materialResults.add(row);
        }
        boolean allComplete = !materials.isEmpty() && completeCount == materials.size();
        Double generalAverage = allComplete && coefficientSum.signum() > 0
                ? weighted.divide(coefficientSum, 2, RoundingMode.HALF_UP).doubleValue() : null;
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("nce", student.id);
        summary.put("nom", student.nom);
        summary.put("prenom", student.prenom);
        summary.put("codClass", student.classe.codClass);
        summary.put("anneeUniversitaire", year);
        summary.put("semestre", semester);
        summary.put("nombreMatieres", materials.size());
        summary.put("matieresCompletes", completeCount);
        summary.put("matieresIncompletes", materials.size() - completeCount);
        summary.put("matieresValidees", validatedCount);
        summary.put("matieresNonValidees", failedCount);
        summary.put("moyenneGenerale", generalAverage);
        summary.put("resultatFinal", generalAverage == null ? "EN_ATTENTE" : generalAverage >= 10 ? "VALIDE" : "NON_VALIDE");
        summary.put("matieres", materialResults);
        return List.of(summary);
    }

    static boolean complete(Boolean hasTp, Double tp1, Double tp2, Double ds, Double exam) {
        if (hasTp == null || ds == null || exam == null) return false;
        return !hasTp || (tp1 != null && tp2 != null);
    }

    static Double calculate(Boolean hasTp, Double tp1, Double tp2, Double ds, Double exam) {
        if (!complete(hasTp, tp1, tp2, ds, exam)) return null;
        double result = hasTp
                ? ((tp1 + tp2) / 2.0 * 0.20) + (ds * 0.30) + (exam * 0.50)
                : (ds * 0.30) + (exam * 0.70);
        return rounded(result);
    }

    private static double rounded(double number) {
        return BigDecimal.valueOf(number).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    private static void validateYear(String year) {
        if (year == null || !year.matches("\\d{4}-\\d{4}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "L'année doit être au format AAAA-AAAA.");
        }
        int start = Integer.parseInt(year.substring(0, 4));
        int end = Integer.parseInt(year.substring(5));
        if (end != start + 1) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "L'année universitaire doit couvrir deux années consécutives.");
    }
}

record EvaluationInput(
        @jakarta.validation.constraints.NotNull Integer nce,
        @jakarta.validation.constraints.NotBlank String codMat,
        @jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Pattern(regexp="\\d{4}-\\d{4}") String anneeUniversitaire,
        @jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Min(1) @jakarta.validation.constraints.Max(2) Integer semestre,
        @jakarta.validation.constraints.DecimalMin("0.0") @jakarta.validation.constraints.DecimalMax("20.0") Double tp1,
        @jakarta.validation.constraints.DecimalMin("0.0") @jakarta.validation.constraints.DecimalMax("20.0") Double tp2,
        @jakarta.validation.constraints.DecimalMin("0.0") @jakarta.validation.constraints.DecimalMax("20.0") Double ds,
        @jakarta.validation.constraints.DecimalMin("0.0") @jakarta.validation.constraints.DecimalMax("20.0") Double examen) {}
