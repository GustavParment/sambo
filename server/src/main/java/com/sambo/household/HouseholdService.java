package com.sambo.household;

import com.sambo.auth.dto.AuthUserDto;
import com.sambo.auth.jwt.JwtService;
import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.household.dto.HouseholdMembershipDto;
import com.sambo.household.dto.HouseholdSessionResponse;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * Membership-level operations on households. Tenant scoping is enforced by
 * always reading the authenticated principal — callers cannot act on a
 * household they aren't a member of.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class HouseholdService {

    private final AppUserRepository userRepo;
    private final HouseholdRepository householdRepo;
    private final HouseholdMembershipRepository membershipRepo;
    private final JwtService jwtService;

    /** Every household the user belongs to, with role + active flag. */
    @Transactional(readOnly = true)
    public List<HouseholdMembershipDto> listMemberships(SamboPrincipal principal) {
        UUID activeId = principal.householdId();
        // JOIN FETCH avoids N+1 on the household side.
        return membershipRepo.findByUserIdFetchingHousehold(principal.userId()).stream()
            .map(m -> HouseholdMembershipDto.from(m,
                activeId != null && activeId.equals(m.getHousehold().getId())))
            .sorted(Comparator.comparing(HouseholdMembershipDto::joinedAt))
            .toList();
    }

    /**
     * Switch the user's active household. The target must already be one of
     * their memberships — there's no implicit join here. Returns a fresh JWT
     * scoped to the new active household + role.
     */
    @Transactional
    public HouseholdSessionResponse switchActive(UUID targetHouseholdId, SamboPrincipal principal) {
        AppUser user = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found"));

        HouseholdMembership membership = membershipRepo
            .findByUserIdAndHouseholdId(user.getId(), targetHouseholdId)
            .orElseThrow(() -> new AccessDeniedException(
                "Du är inte medlem i det hushållet"));

        user.setActiveHousehold(membership.getHousehold());
        userRepo.save(user);

        String jwt = jwtService.issue(user, membership);
        log.info("User {} switched active household to {}", user.getEmail(), targetHouseholdId);
        return new HouseholdSessionResponse(jwt, AuthUserDto.from(user, membership));
    }

    /**
     * Leave a household. If it was the active one, fall back to another
     * membership (oldest first) — or null if none remain. The household is
     * deleted (with everything that hangs off it) when the last member leaves.
     */
    @Transactional
    public HouseholdSessionResponse leave(UUID targetHouseholdId, SamboPrincipal principal) {
        AppUser user = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found"));

        HouseholdMembership membership = membershipRepo
            .findByUserIdAndHouseholdId(user.getId(), targetHouseholdId)
            .orElseThrow(() -> new AccessDeniedException(
                "Du är inte medlem i det hushållet"));

        membershipRepo.delete(membership);

        boolean wasActive = user.getActiveHousehold() != null
            && user.getActiveHousehold().getId().equals(targetHouseholdId);

        // If no members remain in the household, drop it (cascade purges chores,
        // budget rows, calendar events, etc).
        if (membershipRepo.countByHouseholdId(targetHouseholdId) == 0) {
            householdRepo.deleteById(targetHouseholdId);
        }

        HouseholdMembership fallback = null;
        if (wasActive) {
            fallback = membershipRepo.findByUserId(user.getId()).stream()
                .min(Comparator.comparing(HouseholdMembership::getJoinedAt))
                .orElse(null);
            user.setActiveHousehold(fallback == null ? null : fallback.getHousehold());
            userRepo.save(user);
        }

        log.info("User {} left household {}", user.getEmail(), targetHouseholdId);

        if (fallback == null && wasActive) {
            // No JWT to mint — caller has no active household. Front-end is
            // expected to redirect to a "create or accept invite" screen.
            return new HouseholdSessionResponse(null, AuthUserDto.from(user, null));
        }

        // Either active didn't change (we left a non-active household) — re-mint
        // a JWT for the still-current active membership; or active changed and
        // fallback holds the new one.
        HouseholdMembership active = wasActive
            ? fallback
            : membershipRepo
                .findByUserIdAndHouseholdId(user.getId(), user.getActiveHousehold().getId())
                .orElseThrow();
        String jwt = jwtService.issue(user, active);
        return new HouseholdSessionResponse(jwt, AuthUserDto.from(user, active));
    }

    /**
     * Create a new household with the caller as ADMIN, switch to it, mint a
     * fresh JWT. Subject to the per-user household cap.
     */
    @Transactional
    public HouseholdSessionResponse create(String rawName, SamboPrincipal principal) {
        AppUser user = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found"));

        if (membershipRepo.countByUserId(user.getId()) >= InviteService.MAX_HOUSEHOLDS_PER_USER) {
            throw new TooManyHouseholdsException(
                "Du kan max vara med i " + InviteService.MAX_HOUSEHOLDS_PER_USER + " hushåll. "
                    + "Lämna ett hushåll innan du skapar ett nytt.");
        }

        Household household = householdRepo.save(Household.builder()
            .name(rawName.trim())
            .build());

        HouseholdMembership membership = membershipRepo.save(HouseholdMembership.builder()
            .user(user)
            .household(household)
            .role(Role.ADMIN)
            .build());

        user.setActiveHousehold(household);
        userRepo.save(user);

        String jwt = jwtService.issue(user, membership);
        log.info("User {} created household {} ({})",
            user.getEmail(), household.getId(), household.getName());
        return new HouseholdSessionResponse(jwt, AuthUserDto.from(user, membership));
    }
}
