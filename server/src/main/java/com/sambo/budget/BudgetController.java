package com.sambo.budget;

import com.sambo.budget.dto.MonthlyOverviewDto;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.UUID;

@RestController
@RequestMapping("/api/households/{householdId}/budget")
@RequiredArgsConstructor
public class BudgetController {

    private final BudgetService budgetService;

    /**
     * GET /api/households/{householdId}/budget/{yearMonth}
     * Example: /api/households/.../budget/2026-05
     *
     * TODO: replace path-based householdId with the authenticated user's
     * household once Spring Security is wired up — never trust path tenancy.
     */
    @GetMapping("/{yearMonth}")
    public MonthlyOverviewDto getMonthlyOverview(
        @PathVariable UUID householdId,
        @PathVariable @DateTimeFormat(pattern = "yyyy-MM") YearMonth yearMonth
    ) {
        return budgetService.getMonthlyOverview(householdId, yearMonth);
    }
}
