package com.sambo.household;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.household.dto.AcceptInviteRequest;
import com.sambo.household.dto.AcceptInviteResponse;
import com.sambo.household.dto.InviteDto;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/invites")
@RequiredArgsConstructor
public class InviteController {

    private final InviteService inviteService;

    /** ADMIN of the current household generates a new shareable code. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    public InviteDto generate(@AuthenticationPrincipal SamboPrincipal principal) {
        return inviteService.generate(principal);
    }

    /**
     * Any authenticated user may accept — server enforces "no other members in
     * your current household" so partners aren't accidentally orphaned.
     * Returns a fresh JWT carrying the new householdId / role.
     */
    @PostMapping("/accept")
    public AcceptInviteResponse accept(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody AcceptInviteRequest req
    ) {
        return inviteService.accept(req.code(), principal);
    }
}
