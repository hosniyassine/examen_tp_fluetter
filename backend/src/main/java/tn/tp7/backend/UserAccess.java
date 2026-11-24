package tn.tp7.backend;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Component
class UserSessionService {
    private final Map<String, AppUser> sessions = new ConcurrentHashMap<>();
    String create(AppUser user) {
        String token = UUID.randomUUID().toString();
        sessions.put(token, user);
        return token;
    }
    AppUser find(String token) { return sessions.get(token); }
    void remove(String token) { sessions.remove(token); }
}

@Component
class RoleAuthorizationInterceptor implements HandlerInterceptor {
    private final UserSessionService sessions;
    private final boolean enabled;
    RoleAuthorizationInterceptor(UserSessionService sessions,
            @org.springframework.beans.factory.annotation.Value("${app.security.enabled:true}") boolean enabled) { this.sessions = sessions; this.enabled=enabled; }

    @Override public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if (request.getMethod().equalsIgnoreCase("OPTIONS")) return true;
        String path = request.getRequestURI();
        if (!enabled) return true;
        if (path.equals("/login") || path.equals("/register")) return true;
        String header = request.getHeader("Authorization");
        String token = header != null && header.startsWith("Bearer ") ? header.substring(7) : "";
        AppUser user = sessions.find(token);
        if (user == null) {
            response.setStatus(HttpStatus.UNAUTHORIZED.value());
            response.setContentType("application/json");
            response.getWriter().write("{\"message\":\"Session expirée. Reconnectez-vous.\"}");
            return false;
        }
        request.setAttribute("authenticatedUser", user);
        String role = user.role == null ? "ADMIN" : user.role;
        if (path.equals("/logout")) return true;
        if (role.equals("ADMIN")) return true;
        if (request.getMethod().equals("GET") && role.equals("STUDENT") && path.equals("/tp7/mes-resultats")) return true;
        if (role.equals("TEACHER") && (path.startsWith("/tp7/evaluations") || path.startsWith("/tp7/resultats")
                || path.equals("/tp7/enseignants/moi/classes") || path.equals("/tp7/matieres"))) return true;
        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType("application/json");
        response.getWriter().write("{\"message\":\"Votre rôle ne permet pas cette opération.\"}");
        return false;
    }
}

@Configuration
class RoleAuthorizationConfiguration implements WebMvcConfigurer {
    private final RoleAuthorizationInterceptor interceptor;
    RoleAuthorizationConfiguration(RoleAuthorizationInterceptor interceptor) { this.interceptor = interceptor; }
    @Override public void addInterceptors(InterceptorRegistry registry) { registry.addInterceptor(interceptor); }

    @Override public void addCorsMappings(org.springframework.web.servlet.config.annotation.CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("http://localhost:*", "http://127.0.0.1:*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }

    @Bean ApplicationRunner upgradeLegacyAccountRoles(UserRepository users,
            @org.springframework.beans.factory.annotation.Value("${app.bootstrap-admin-email:}") String bootstrapAdminEmail) {
        return args -> {
            users.findAll().forEach(user -> {
                boolean changed = false;
                if (user.role == null || user.role.isBlank()) { user.role = "ADMIN"; changed = true; }
                if (!bootstrapAdminEmail.isBlank() && bootstrapAdminEmail.equalsIgnoreCase(user.email)
                        && !"ADMIN".equals(user.role)) { user.role = "ADMIN"; changed = true; }
                if (changed) users.save(user);
            });
        };
    }
}
