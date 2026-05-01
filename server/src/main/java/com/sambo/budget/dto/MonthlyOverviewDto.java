package com.sambo.budget.dto;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

public record MonthlyOverviewDto(
    UUID householdId,
    YearMonth yearMonth,
    BigDecimal totalBudgeted,
    BigDecimal totalSpent,
    BigDecimal totalRemaining,
    List<CategoryStatusDto> categories
) {}
