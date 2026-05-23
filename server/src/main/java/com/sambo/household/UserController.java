package com.sambo.household;

import com.sambo.auth.dto.AuthUserDto;
import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.household.dto.UpdateAvatarColorRequest;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final AppUserRepository userRepo;
    private final HouseholdMembershipRepository membershipRepo;

    /** Update the caller's avatar colour. Returns updated user profile. */
    @PatchMapping("/me")
    @Transactional
    public AuthUserDto updateMe(
        @AuthenticationPrincipal SamboPrincipal principal,
        @RequestBody UpdateAvatarColorRequest req
    ) {
        AppUser user = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found"));
        user.setAvatarColor(req.avatarColor());

        HouseholdMembership active = principal.householdId() == null ? null
            : membershipRepo.findByUserIdAndHouseholdId(principal.userId(), principal.householdId())
                .orElse(null);

        return AuthUserDto.from(user, active);
    }
}
