package com.sambo.chore;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.ChoreDto;
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

    @GetMapping
    public List<ChoreDto> list(@AuthenticationPrincipal SamboPrincipal principal) {
        return choreService.listForHousehold(principal.householdId());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('" + "ADMIN" + "')")
    public ChoreDto create(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateChoreRequest req
    ) {
        return choreService.create(principal.householdId(), req.name());
    }

    @PostMapping("/{id}/complete")
    public ChoreDto complete(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        return choreService.complete(id, principal);
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
