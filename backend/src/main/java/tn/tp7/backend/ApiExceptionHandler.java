package tn.tp7.backend;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
class ApiExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiModels.ErrorResponse> invalid(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + " : " + error.getDefaultMessage())
                .findFirst().orElse("Données invalides.");
        return ResponseEntity.badRequest().body(new ApiModels.ErrorResponse(message));
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ApiModels.ErrorResponse> status(ResponseStatusException ex) {
        return ResponseEntity.status(ex.getStatusCode())
                .body(new ApiModels.ErrorResponse(ex.getReason() == null ? "Requête refusée." : ex.getReason()));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ApiModels.ErrorResponse> conflict(DataIntegrityViolationException ex) {
        Throwable cause = org.springframework.core.NestedExceptionUtils.getMostSpecificCause(ex);
        if (cause instanceof java.sql.SQLException sqlException) {
            if ("23503".equals(sqlException.getSQLState())) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(new ApiModels.ErrorResponse("Suppression impossible : cette donnée est encore utilisée par d'autres enregistrements."));
            }
            if ("23505".equals(sqlException.getSQLState())) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(new ApiModels.ErrorResponse("Une donnée avec ces mêmes identifiants existe déjà."));
            }
        }
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ApiModels.ErrorResponse("L'opération est refusée par une contrainte de la base de données."));
    }
}
