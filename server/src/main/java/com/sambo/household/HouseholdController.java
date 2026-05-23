package com.sambo.household;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.UserSummaryDto;
import com.sambo.gcs.GcsStorageService;
import com.sambo.household.dto.AvatarOptionDto;
import com.sambo.household.dto.CreateHouseholdRequest;
import com.sambo.household.dto.HouseholdDto;
import com.sambo.household.dto.HouseholdMembershipDto;
import com.sambo.household.dto.HouseholdSessionResponse;
import com.sambo.household.dto.LeaveHouseholdRequest;
import com.sambo.household.dto.SwitchHouseholdRequest;
import com.sambo.household.dto.UpdateHouseholdAvatarRequest;
import com.sambo.household.dto.UpdateHouseholdRequest;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Household-scoped operations. Tenant id always taken from the principal —
 * never from path. Multi-tenancy is implicit; the principal can only ever
 * read or modify their own household here. Membership-changing endpoints
 * (switch, leave, create) mint a fresh JWT because the active household
 * (and possibly the role) changes.
 */
@RestController
@RequestMapping("/api/household")
@RequiredArgsConstructor
public class HouseholdController {

    private static final int AVATAR_KEY_MAX = 50;

    private final HouseholdRepository householdRepo;
    private final HouseholdMembershipRepository membershipRepo;
    private final HouseholdService householdService;
    private final GcsStorageService gcsService;

    @GetMapping
    public HouseholdDto get(@AuthenticationPrincipal SamboPrincipal principal) {
        Household h = householdRepo.findById(principal.householdId())
            .orElseThrow(() -> new EntityNotFoundException("Household not found"));
        return HouseholdDto.from(h, gcsService.avatarUrl(h.getAvatarKey()));
    }

    @PutMapping
    @Transactional
    public HouseholdDto rename(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody UpdateHouseholdRequest req
    ) {
        Household h = householdRepo.findById(principal.householdId())
            .orElseThrow(() -> new EntityNotFoundException("Household not found"));
        h.setName(req.name().trim());
        return HouseholdDto.from(h, gcsService.avatarUrl(h.getAvatarKey()));
    }

    @PatchMapping("/avatar")
    @Transactional
    public HouseholdDto updateAvatar(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody UpdateHouseholdAvatarRequest req
    ) {
        String key = req.avatarKey().trim();
        int num;
        try {
            num = Integer.parseInt(key);
        } catch (NumberFormatException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "avatarKey must be a number");
        }
        if (num < 1 || num > AVATAR_KEY_MAX) {
            throw new ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "avatarKey must be between 1 and " + AVATAR_KEY_MAX);
        }
        String paddedKey = String.format("%02d", num);

        Household h = householdRepo.findById(principal.householdId())
            .orElseThrow(() -> new EntityNotFoundException("Household not found"));
        h.setAvatarKey(paddedKey);
        return HouseholdDto.from(h, gcsService.avatarUrl(paddedKey));
    }

    /**
     * Returns all 50 avatar options with their signed URLs. Used by the
     * avatar picker screen on the client — generates all URLs in one round-trip.
     */
    @GetMapping("/avatar-options")
    public List<AvatarOptionDto> avatarOptions() {
        return java.util.stream.IntStream.rangeClosed(1, AVATAR_KEY_MAX)
            .mapToObj(i -> {
                String key = String.format("%02d", i);
                return new AvatarOptionDto(key, gcsService.avatarUrl(key));
            })
            .toList();
    }

    /** All users with a membership in the active household. */
    @GetMapping("/members")
    public List<UserSummaryDto> members(@AuthenticationPrincipal SamboPrincipal principal) {
        // JOIN FETCH variant — without it, m.getUser() returns a lazy proxy and
        // .getDisplayName() in the DTO mapper trips LazyInitializationException
        // (open-in-view is intentionally off — see application.yml).
        return membershipRepo
            .findByHouseholdIdFetchingUser(principal.householdId()).stream()
            .map(m -> UserSummaryDto.from(m.getUser()))
            .toList();
    }

    @GetMapping("/memberships")
    public List<HouseholdMembershipDto> memberships(@AuthenticationPrincipal SamboPrincipal principal) {
        return householdService.listMemberships(principal);
    }

    @PostMapping("/switch")
    public HouseholdSessionResponse switchActive(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody SwitchHouseholdRequest req
    ) {
        return householdService.switchActive(req.householdId(), principal);
    }

    @PostMapping("/leave")
    public HouseholdSessionResponse leave(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody LeaveHouseholdRequest req
    ) {
        return householdService.leave(req.householdId(), principal);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public HouseholdSessionResponse create(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateHouseholdRequest req
    ) {
        return householdService.create(req.name(), principal);
    }
}
