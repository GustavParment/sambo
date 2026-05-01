package com.sambo.calendar;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface CalendarEventRepository extends JpaRepository<CalendarEvent, UUID> {

    /**
     * Events overlapping the half-open window {@code [from, to)}. An event
     * spanning the window edge counts (e.g. a 5-day trip starting before the
     * month begins still shows up if any of its days fall within the month).
     */
    List<CalendarEvent> findByHouseholdIdAndStartsAtLessThanAndEndsAtGreaterThanEqualOrderByStartsAtAsc(
        UUID householdId, Instant to, Instant from
    );
}
