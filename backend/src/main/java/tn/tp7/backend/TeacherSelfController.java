package tn.tp7.backend;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/tp7/enseignants/moi")
class TeacherSelfController {
    private final TeacherAssignmentRepository assignments;
    TeacherSelfController(TeacherAssignmentRepository assignments){this.assignments=assignments;}

    @GetMapping("/classes")
    List<Map<String,Object>> classes(@RequestAttribute("authenticatedUser") AppUser user){
        if(user.teacher==null)throw new ResponseStatusException(HttpStatus.CONFLICT,"Ce compte n'est pas associé à un enseignant.");
        return assignments.findAllByTeacherId(user.teacher.id).stream().map(a->Map.<String,Object>of(
                "codClass",a.classSubject.classe.codClass,
                "nomClass",a.classSubject.classe.nomClass,
                "codMat",a.classSubject.matiere.codMat,
                "intMat",a.classSubject.matiere.intMat)).toList();
    }
}
