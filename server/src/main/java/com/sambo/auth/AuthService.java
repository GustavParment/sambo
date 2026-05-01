package com.sambo.auth;

import com.sambo.auth.dto.AuthUserDto;
import com.sambo.auth.dto.LoginResponse;
import com.sambo.auth.google.GoogleIdTokenValidator;
import com.sambo.auth.google.GoogleUserInfo;
import com.sambo.auth.jwt.JwtService;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import com.sambo.household.Role;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final GoogleIdTokenValidator googleValidator;
    private final JwtService jwtService;
    private final AppUserRepository userRepo;
    private final HouseholdRepository householdRepo;

    /**
     * Validates a Google ID token from the Flutter client and returns a
     * server-issued JWT plus the resolved user. First-time logins bootstrap
     * a fresh household with this user as ADMIN — the invite-flow for joining
     * an existing household is a follow-up (see {@code Household} module).
     */
    @Transactional
    public LoginResponse loginWithGoogle(String googleIdToken) {
        GoogleUserInfo info = googleValidator.validate(googleIdToken);

        AppUser user = userRepo.findByEmail(info.email())
            .orElseGet(() -> bootstrap(info));

        String jwt = jwtService.issue(user);
        return new LoginResponse(jwt, AuthUserDto.from(user));
    }

    private AppUser bootstrap(GoogleUserInfo info) {
        log.info("Bootstrapping new user + household for {}", info.email());
        Household household = householdRepo.save(Household.builder()
            .name(info.email() + "'s household")
            .build());
        return userRepo.save(AppUser.builder()
            .household(household)
            .email(info.email())
            .displayName(info.name() != null ? info.name() : info.email())
            .role(Role.ADMIN)
            .build());
    }
}
