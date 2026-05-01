package com.sambo.chore;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.ChoreDto;
import com.sambo.chore.dto.CompleteChoreRequest;
import com.sambo.chore.dto.CreateChoreRequest;
import com.sambo.household.Role;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Chore endpoints. Tenant scoping is enforced by reading {@link SamboPrincipal}
 * from the security context — the household id is NEVER taken from path or
 * body. Role-based gates use Spring's {@code hasRole(...)} which reads from
 * the same authority list the JWT filter populates.
 */
@RestController
@RequestMapping("/api/chores")
@RequiredArgsConstructor
public class ChoreController {

    private final ChoreService choreService;

    /** Default = active chores only. {@code ?archived=true} returns archived ones. */
    @GetMapping
    public List<ChoreDto> list(
        @AuthenticationPrincipal SamboPrincipal principal,
        @RequestParam(defaultValue = "false") boolean archived
    ) {
        UUID hid = principal.householdId();
        return archived ? choreService.listArchived(hid) : choreService.listForHousehold(hid);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ChoreDto create(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateChoreRequest req
    ) {
        return choreService.create(
            principal.householdId(), req.name(),
            req.lastCompletedAt(), req.scheduledFor());
    }

    /**
     * Body is optional. Empty/missing → caller is the only participant. Pass
     * a list of household member ids to record "we did it together".
     */
    @PostMapping("/{id}/complete")
    public ChoreDto complete(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id,
        @RequestBody(required = false) CompleteChoreRequest req
    ) {
        return choreService.complete(id, req == null ? null : req.userIds(), principal);
    }

    @PostMapping("/{id}/archive")
    public ChoreDto archive(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        return choreService.archive(id, principal.householdId());
    }

    @PostMapping("/{id}/unarchive")
    public ChoreDto unarchive(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        return choreService.unarchive(id, principal.householdId());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('" + "ADMIN" + "')")
    public void delete(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        choreService.delete(id, principal.householdId());
    }

    /** Also expose ADMIN as a string constant in case other modules need it. */
    @SuppressWarnings("unused")
    private static final String ROLE_ADMIN = Role.ADMIN.name();
}
