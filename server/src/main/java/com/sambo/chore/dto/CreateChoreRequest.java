package com.sambo.chore.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/**
 * @param lastCompletedAt optional baseline — "we already did this on this date,
 *                        track from here". Creates a synthetic completion event
 *                        with no participants attributed.
 * @param scheduledFor    optional forward-looking — when this chore should be
 *                        done next. Stored on the chore row, not a completion.
 */
public record CreateChoreRequest(
    @NotBlank @Size(max = 100) String name,
    @PastOrPresent Instant lastCompletedAt,
    @Future Instant scheduledFor
) {}
