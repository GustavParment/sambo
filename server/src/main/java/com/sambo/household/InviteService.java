package com.sambo.household;

import com.sambo.auth.dto.AuthUserDto;
import com.sambo.auth.jwt.JwtService;
import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.household.dto.AcceptInviteResponse;
import com.sambo.household.dto.InviteDto;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;

@Slf4j
@Service
@RequiredArgsConstructor
public class InviteService {

    /** Codes use only unambiguous characters — no 0/O/1/I/L. */
    private static final char[] CODE_CHARS =
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();
    private static final int CODE_LENGTH = 6;
    private static final Duration TTL = Duration.ofHours(24);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final InviteRepository inviteRepo;
    private final HouseholdRepository householdRepo;
    private final AppUserRepository userRepo;
    private final JwtService jwtService;

    @Transactional
    public InviteDto generate(SamboPrincipal principal) {
        Invite invite = inviteRepo.save(Invite.builder()
            .household(householdRepo.getReferenceById(principal.householdId()))
            .createdBy(userRepo.getReferenceById(principal.userId()))
            .code(generateUniqueCode())
            .expiresAt(Instant.now().plus(TTL))
            .build());
        log.info("Invite {} created in household {}", invite.getCode(), principal.householdId());
        return InviteDto.from(invite);
    }

    @Transactional
    public AcceptInviteResponse accept(String rawCode, SamboPrincipal principal) {
        String code = rawCode == null ? "" : rawCode.toUpperCase().trim();
        Invite invite = inviteRepo.findByCodeAndUsedAtIsNull(code)
            .orElseThrow(() -> new InvalidInviteException("Ogiltig eller redan använd kod"));
        if (invite.isExpired()) {
            throw new InvalidInviteException("Koden har gått ut");
        }

        AppUser user = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found"));
        Household oldHousehold = user.getHousehold();
        Household newHousehold = invite.getHousehold();

        if (oldHousehold.getId().equals(newHousehold.getId())) {
            throw new InvalidInviteException("Du är redan med i det här hushållet");
        }
        long otherUsersInOld = userRepo.countByHouseholdIdAndIdNot(
            oldHousehold.getId(), user.getId());
        if (otherUsersInOld > 0) {
            // Refusing to orphan someone in their existing household.
            throw new InvalidInviteException(
                "Du har andra medlemmar i ditt hushåll och kan inte byta utan att lämna dem.");
        }

        // Move the user.
        user.setHousehold(newHousehold);
        user.setRole(Role.USER);
        userRepo.save(user);

        // Mark invite consumed.
        invite.setUsedAt(Instant.now());
        invite.setUsedBy(user);

        // Old household has no users left → drop it (and its empty children
        // via ON DELETE CASCADE on every FK pointing at household_id).
        householdRepo.delete(oldHousehold);

        // Issue a fresh JWT — the old one carries the wrong householdId + role.
        String jwt = jwtService.issue(user);
        log.info("User {} joined household {} via invite {}",
            user.getEmail(), newHousehold.getId(), invite.getCode());
        return new AcceptInviteResponse(jwt, AuthUserDto.from(user));
    }

    private String generateUniqueCode() {
        for (int attempt = 0; attempt < 5; attempt++) {
            String candidate = randomCode();
            if (inviteRepo.findByCode(candidate).isEmpty()) return candidate;
        }
        throw new IllegalStateException("Could not generate a unique invite code after 5 attempts");
    }

    private static String randomCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(CODE_CHARS[RANDOM.nextInt(CODE_CHARS.length)]);
        }
        return sb.toString();
    }
}
