package tn.tp7.backend;

import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/tp7/effectifs")
class ClassPopulationController {
    private final SchoolClassRepository classes;
    private final StudentRepository students;

    ClassPopulationController(SchoolClassRepository classes, StudentRepository students) {
        this.classes = classes;
        this.students = students;
    }

    @GetMapping("/maximales")
    @Transactional(readOnly = true)
    Map<String, Object> maximumClasses() {
        List<SchoolClass> allClasses = classes.findAll();
        long maximum = allClasses.stream()
                .mapToLong(schoolClass -> students.countByClasseCodClass(schoolClass.codClass))
                .max().orElse(0);
        List<Map<String, Object>> results = new ArrayList<>();
        for (SchoolClass schoolClass : allClasses) {
            long count = students.countByClasseCodClass(schoolClass.codClass);
            if (count == maximum) results.add(classInfo(schoolClass, count));
        }
        results.sort((a, b) -> a.get("codClass").toString().compareTo(b.get("codClass").toString()));
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("maxEffectif", allClasses.isEmpty() ? null : maximum);
        response.put("classes", results);
        return response;
    }

    @PutMapping("/{codClass}")
    @Transactional
    Map<String, Object> updateMaximumClass(@PathVariable String codClass) {
        SchoolClass selected = classes.findById(codClass)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Classe introuvable."));
        List<SchoolClass> allClasses = classes.findAll();
        long maximum = allClasses.stream()
                .mapToLong(schoolClass -> students.countByClasseCodClass(schoolClass.codClass))
                .max().orElse(0);
        long selectedCount = students.countByClasseCodClass(selected.codClass);
        if (selectedCount != maximum) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Seule une classe ayant l'effectif maximal peut être mise à jour.");
        }
        selected.nbrEtud = Math.toIntExact(selectedCount);
        classes.save(selected);
        return classInfo(selected, selectedCount);
    }

    private Map<String, Object> classInfo(SchoolClass schoolClass, long count) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("codClass", schoolClass.codClass);
        result.put("nomClass", schoolClass.nomClass);
        result.put("codDept", schoolClass.departement == null ? null : schoolClass.departement.codDept);
        result.put("nomDept", schoolClass.departement == null ? null : schoolClass.departement.nomDept);
        result.put("nombreEtudiants", count);
        result.put("nbrEtud", schoolClass.nbrEtud);
        return result;

    }
}
