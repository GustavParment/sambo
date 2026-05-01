package com.sambo.budget;

import com.sambo.budget.dto.CategoryStatusDto;
import com.sambo.budget.dto.MonthlyOverviewDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class BudgetService {

    private static final int UTIL_SCALE = 4;

    private final BudgetCategoryStatusRepository statusRepo;

    /**
     * Aggregated monthly overview for one household.
     * <p>
     * All heavy lifting (sum of transactions per category, remaining amount)
     * is done in {@code v_budget_category_status} so this method is essentially
     * a single indexed read + a small in-memory totals pass.
     */
    @Transactional(readOnly = true)
    public MonthlyOverviewDto getMonthlyOverview(UUID householdId, YearMonth yearMonth) {
        List<BudgetCategoryStatusView> rows = statusRepo
            .findByHouseholdIdAndYearAndMonthOrderBySortOrderAsc(
                householdId, yearMonth.getYear(), yearMonth.getMonthValue()
            );

        List<CategoryStatusDto> categories = rows.stream()
            .map(this::toDto)
            .toList();

        BigDecimal totalBudgeted = sum(categories, CategoryStatusDto::budgeted);
        BigDecimal totalSpent    = sum(categories, CategoryStatusDto::spent);
        BigDecimal totalRemaining = totalBudgeted.subtract(totalSpent);

        return new MonthlyOverviewDto(
            householdId, yearMonth,
            totalBudgeted, totalSpent, totalRemaining,
            categories
        );
    }

    private CategoryStatusDto toDto(BudgetCategoryStatusView v) {
        return new CategoryStatusDto(
            v.getCategoryId(),
            v.getCategoryName(),
            v.getBudgetedAmount(),
            v.getSpentAmount(),
            v.getRemainingAmount(),
            utilization(v.getSpentAmount(), v.getBudgetedAmount())
        );
    }

    /** spent / budgeted, with budgeted=0 short-circuited to 0 to avoid div-by-zero. */
    private static BigDecimal utilization(BigDecimal spent, BigDecimal budgeted) {
        if (budgeted.signum() == 0) return BigDecimal.ZERO;
        return spent.divide(budgeted, UTIL_SCALE, RoundingMode.HALF_UP);
    }

    private static BigDecimal sum(
        List<CategoryStatusDto> xs,
        java.util.function.Function<CategoryStatusDto, BigDecimal> f
    ) {
        return xs.stream().map(f).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
