package com.sambo.auth;

import com.sambo.auth.dto.AuthUserDto;
import com.sambo.auth.dto.LoginResponse;
import com.sambo.auth.google.GoogleIdTokenValidator;
import com.sambo.auth.google.GoogleUserInfo;
import com.sambo.auth.jwt.JwtService;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdMembership;
import com.sambo.household.HouseholdMembershipRepository;
import com.sambo.household.HouseholdRepository;
import com.sambo.household.Role;
import jakarta.persistence.EntityNotFoundException;
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
    private final HouseholdMembershipRepository membershipRepo;

    /**
     * Validates a Google ID token from the Flutter client and returns a
     * server-issued JWT plus the resolved user. First-time logins bootstrap
     * a fresh household with this user as ADMIN. The JWT is scoped to the
     * user's currently-active household (per AppUser.activeHousehold).
     */
    @Transactional
    public LoginResponse loginWithGoogle(String googleIdToken) {
        GoogleUserInfo info = googleValidator.validate(googleIdToken);

        AppUser user = userRepo.findByEmail(info.email())
            .orElseGet(() -> bootstrap(info));

        Household active = user.getActiveHousehold();
        if (active == null) {
            throw new EntityNotFoundException(
                "User has no active household — login flow not yet supported");
        }
        HouseholdMembership membership = membershipRepo
            .findByUserIdAndHouseholdId(user.getId(), active.getId())
            .orElseThrow(() -> new EntityNotFoundException(
                "Active household has no membership — data inconsistency"));

        String jwt = jwtService.issue(user, membership);
        return new LoginResponse(jwt, AuthUserDto.from(user, membership));
    }

    private AppUser bootstrap(GoogleUserInfo info) {
        log.info("Bootstrapping new user + household for {}", info.email());
        Household household = householdRepo.save(Household.builder()
            .name(info.email() + "'s household")
            .build());
        AppUser user = userRepo.save(AppUser.builder()
            .activeHousehold(household)
            .email(info.email())
            .displayName(info.name() != null ? info.name() : info.email())
            .build());
        membershipRepo.save(HouseholdMembership.builder()
            .user(user)
            .household(household)
            .role(Role.ADMIN)
            .build());
        return user;
    }
}
