package com.sambo.auth;

import com.sambo.auth.dto.GoogleLoginRequest;
import com.sambo.auth.dto.LoginResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/google")
    public LoginResponse google(@Valid @RequestBody GoogleLoginRequest req) {
        return authService.loginWithGoogle(req.idToken());
    }
}
