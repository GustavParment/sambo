package com.sambo.overview.dto;

import java.util.List;

public record ChoreSummaryDto(
    long totalCompletions,
    long distinctChoresDone,
    List<ChoreParticipantDto> participants
) {}
