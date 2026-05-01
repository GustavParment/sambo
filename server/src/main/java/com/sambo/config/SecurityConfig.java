package com.sambo.config;

import com.sambo.auth.jwt.JwtAuthenticationFilter;
import com.sambo.household.Role;
import jakarta.servlet.DispatcherType;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .formLogin(AbstractHttpConfigurer::disable)
            .httpBasic(AbstractHttpConfigurer::disable)

            .authorizeHttpRequests(auth -> auth
                // Let internal error dispatch (e.g. MethodArgumentNotValid → /error)
                // through, otherwise validation 400s get rewritten to 401.
                .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()

                // Public — anyone can call.
                .requestMatchers("/api/auth/**", "/actuator/health").permitAll()

                // Admin-only surface (placeholder; add concrete endpoints under
                // /api/admin/** as we build them).
                .requestMatchers("/api/admin/**").hasRole(Role.ADMIN.name())

                // Everything else under /api/** requires a valid JWT.
                .requestMatchers("/api/**").authenticated()

                // Lock down by default.
                .anyRequest().denyAll()
            )

            // Return JSON-friendly 401 instead of a login redirect.
            .exceptionHandling(ex -> ex.authenticationEntryPoint(jsonAuthEntryPoint()))

            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    /** Sends 401 with an empty body — Flutter can branch on status alone. */
    private static AuthenticationEntryPoint jsonAuthEntryPoint() {
        return (req, res, ex) -> res.sendError(HttpServletResponse.SC_UNAUTHORIZED);
    }
}
