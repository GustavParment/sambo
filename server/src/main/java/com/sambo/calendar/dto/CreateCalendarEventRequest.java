package com.sambo.calendar.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record CreateCalendarEventRequest(
    @NotBlank @Size(max = 128) String title,
    @Size(max = 1024) String description,
    @NotNull Instant startsAt,
    @NotNull Instant endsAt,
    boolean allDay,
    @NotBlank @Pattern(regexp = "^#[0-9A-Fa-f]{6}$") String color
) {}
