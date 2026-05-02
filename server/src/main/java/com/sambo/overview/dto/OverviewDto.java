package com.sambo.overview.dto;

import com.sambo.budget.dto.MonthlyOverviewDto;

import java.time.YearMonth;

/**
 * Single-payload monthly overview for the dashboard tab — chore activity +
 * budget progress for the current household, in one round trip.
 */
public record OverviewDto(
    YearMonth yearMonth,
    ChoreSummaryDto chores,
    MonthlyOverviewDto budget
) {}
