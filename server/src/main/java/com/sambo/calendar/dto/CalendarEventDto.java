package com.sambo.calendar.dto;

import com.sambo.calendar.CalendarEvent;

import java.time.Instant;
import java.util.UUID;

public record CalendarEventDto(
    UUID id,
    String title,
    String description,
    Instant startsAt,
    Instant endsAt,
    boolean allDay,
    String color,
    UUID createdByUserId,
    String createdByName,
    Instant createdAt,
    Instant updatedAt
) {
    public static CalendarEventDto from(CalendarEvent e) {
        return new CalendarEventDto(
            e.getId(),
            e.getTitle(),
            e.getDescription(),
            e.getStartsAt(),
            e.getEndsAt(),
            e.isAllDay(),
            e.getColor(),
            e.getCreatedBy().getId(),
            e.getCreatedBy().getDisplayName(),
            e.getCreatedAt(),
            e.getUpdatedAt()
        );
    }
}
