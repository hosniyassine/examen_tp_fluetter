package tn.tp7.backend;

import jakarta.validation.Valid;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
class AuthController {
    private final UserRepository users;
    private final UserSessionService sessions;
    private final String bootstrapAdminEmail;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    AuthController(UserRepository users, UserSessionService sessions,
                   @org.springframework.beans.factory.annotation.Value("${app.bootstrap-admin-email:}") String bootstrapAdminEmail) {
        this.users = users; this.sessions = sessions; this.bootstrapAdminEmail = bootstrapAdminEmail;
    }

    @PostMapping("/register")
    org.springframework.http.ResponseEntity<ApiModels.UserResponse> register(
            @Valid @RequestBody ApiModels.Credentials input) {
        if (users.existsByEmail(input.email())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cette adresse e-mail existe déjà.");
        }
        AppUser user = new AppUser();
        user.email = input.email().trim().toLowerCase(java.util.Locale.ROOT);
        user.passwordHash = encoder.encode(input.password());
        user.role = !bootstrapAdminEmail.isBlank() && bootstrapAdminEmail.equalsIgnoreCase(user.email) ? "ADMIN" : "STUDENT";
        try {
            user = users.saveAndFlush(user);
        } catch (DataIntegrityViolationException ex) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cette adresse e-mail existe déjà.");
        }
        return org.springframework.http.ResponseEntity.status(HttpStatus.CREATED)
                .body(response(user, null));
    }

    @PostMapping("/login")
    ApiModels.UserResponse login(@Valid @RequestBody ApiModels.Credentials input) {
        AppUser user = users.findByEmail(input.email().trim().toLowerCase(java.util.Locale.ROOT))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Identifiants invalides."));
        if (!encoder.matches(input.password(), user.passwordHash)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Identifiants invalides.");
        }
        if (user.role == null) user.role = "ADMIN";
        return response(user, sessions.create(user));
    }

    @org.springframework.web.bind.annotation.PostMapping("/logout")
    @org.springframework.web.bind.annotation.ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(@org.springframework.web.bind.annotation.RequestHeader("Authorization") String authorization) {
        if (authorization.startsWith("Bearer ")) sessions.remove(authorization.substring(7));
    }

    private ApiModels.UserResponse response(AppUser user, String token) {
        return new ApiModels.UserResponse(user.id, user.email, user.role,
                user.student == null ? null : user.student.id,
                user.teacher == null ? null : user.teacher.id, token);
    }
}

