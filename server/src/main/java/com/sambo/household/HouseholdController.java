package com.sambo.household;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.UserSummaryDto;
import com.sambo.household.dto.HouseholdDto;
import com.sambo.household.dto.UpdateHouseholdRequest;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Household-scoped operations. Tenant id always taken from the principal —
 * never from path. Multi-tenancy is implicit; the principal can only ever
 * read or modify their own household here.
 */
@RestController
@RequestMapping("/api/household")
@RequiredArgsConstructor
public class HouseholdController {

    private final AppUserRepository userRepo;
    private final HouseholdRepository householdRepo;

    @GetMapping
    public HouseholdDto get(@AuthenticationPrincipal SamboPrincipal principal) {
        Household h = householdRepo.findById(principal.householdId())
            .orElseThrow(() -> new EntityNotFoundException("Household not found"));
        return HouseholdDto.from(h);
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
        return HouseholdDto.from(h);
    }

    @GetMapping("/members")
    public List<UserSummaryDto> members(@AuthenticationPrincipal SamboPrincipal principal) {
        return userRepo.findByHouseholdId(principal.householdId()).stream()
            .map(UserSummaryDto::from)
            .toList();
    }
}
