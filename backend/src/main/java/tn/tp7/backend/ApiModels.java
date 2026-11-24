package tn.tp7.backend;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

final class ApiModels {
    private ApiModels() {}

    record Credentials(@NotBlank @Email @Size(max = 100) String email,
                       @NotBlank @Size(min = 1, max = 200) String password) {}
    record UserResponse(Integer id, String email, String role, Integer studentId, Integer teacherId, String token) {}
    record ClassroomRequest(@NotBlank @Size(max = 30) String codClass,
                            @NotBlank @Size(max = 100) String nomClass,
                            Integer nbreEtud, String codDept) {}
    record ClassroomResponse(String codClass, String nomClass, long nbreEtud, String codDept) {}
    record TrainingRequest(@NotBlank @Size(max = 100) String nom, Integer duree) {}
    record TrainingResponse(Integer id, String nom, Integer duree) {}
    record RelationCode(String codClass) {}
    record RelationId(Integer id) {}
    record StudentRequest(@NotBlank @Size(max = 100) String nom,
                          @NotBlank @Size(max = 100) String prenom,
                          LocalDate dateNais, RelationCode classe, RelationId formation) {}
    record StudentResponse(Integer id, String nom, String prenom, LocalDate dateNais,
                           ClassroomResponse classe, TrainingResponse formation) {}
    record ErrorResponse(String message) {}
}
