package com.sambo.calendar;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.calendar.dto.CalendarEventDto;
import com.sambo.calendar.dto.CreateCalendarEventRequest;
import com.sambo.calendar.dto.UpdateCalendarEventRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/calendar")
@RequiredArgsConstructor
public class CalendarController {

    private final CalendarService calendarService;

    /**
     * GET /api/calendar?from=2026-05-01T00:00:00Z&to=2026-06-01T00:00:00Z
     * — half-open window. Client computes the local-month boundaries and
     * sends them as ISO instants; server doesn't need to know the household
     * timezone.
     */
    @GetMapping
    public List<CalendarEventDto> list(
        @AuthenticationPrincipal SamboPrincipal principal,
        @RequestParam Instant from,
        @RequestParam Instant to
    ) {
        return calendarService.listInWindow(principal.householdId(), from, to);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CalendarEventDto create(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateCalendarEventRequest req
    ) {
        return calendarService.create(principal, req);
    }

    @PutMapping("/{id}")
    public CalendarEventDto update(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id,
        @Valid @RequestBody UpdateCalendarEventRequest req
    ) {
        return calendarService.update(id, principal.householdId(), req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        calendarService.delete(id, principal.householdId());
    }
}
