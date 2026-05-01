package com.sambo.budget;

import com.sambo.budget.dto.CategoryDto;
import com.sambo.budget.dto.CategoryStatusDto;
import com.sambo.budget.dto.MonthlyOverviewDto;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class BudgetService {

    private static final int UTIL_SCALE = 4;

    private final BudgetCategoryStatusRepository statusRepo;
    private final HouseholdCategoryRepository categoryRepo;
    private final BudgetPeriodRepository periodRepo;
    private final BudgetAllocationRepository allocationRepo;
    private final HouseholdRepository householdRepo;

    /* ---- monthly overview ---------------------------------------------- */

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

    /* ---- category CRUD ------------------------------------------------- */

    @Transactional(readOnly = true)
    public List<CategoryDto> listCategories(UUID householdId) {
        return categoryRepo.findByHouseholdIdOrderBySortOrderAsc(householdId).stream()
            .map(CategoryDto::from)
            .toList();
    }

    @Transactional
    public CategoryDto createCategory(UUID householdId, String name) {
        Household household = householdRepo.getReferenceById(householdId);
        int nextSortOrder = categoryRepo.findByHouseholdIdOrderBySortOrderAsc(householdId).stream()
            .mapToInt(HouseholdCategory::getSortOrder)
            .max()
            .orElse(-1) + 1;

        try {
            HouseholdCategory saved = categoryRepo.save(HouseholdCategory.builder()
                .household(household)
                .name(name.trim())
                .sortOrder(nextSortOrder)
                .build());
            return CategoryDto.from(saved);
        } catch (DataIntegrityViolationException e) {
            // Unique (household_id, name) — surface as a clean 409-ish error.
            throw new IllegalArgumentException(
                "En kategori med namnet \"" + name.trim() + "\" finns redan.");
        }
    }

    @Transactional
    public void deleteCategory(UUID categoryId, UUID householdId) {
        HouseholdCategory cat = loadOwnedCategory(categoryId, householdId);
        // FK from bank_transaction.category_id has ON DELETE SET NULL, and
        // budget_allocation.category_id has ON DELETE CASCADE — so deleting
        // the category cleans up its allocations and orphans its transactions.
        categoryRepo.delete(cat);
    }

    /* ---- allocation upsert --------------------------------------------- */

    /**
     * Sets the budgeted amount for a category in a given month. Creates the
     * period row if it doesn't exist yet. Idempotent — call again to update.
     */
    @Transactional
    public void upsertAllocation(
        UUID householdId, UUID categoryId, YearMonth yearMonth, BigDecimal amount
    ) {
        HouseholdCategory cat = loadOwnedCategory(categoryId, householdId);
        BudgetPeriod period = periodRepo
            .findByHouseholdIdAndYearAndMonth(householdId, yearMonth.getYear(), yearMonth.getMonthValue())
            .orElseGet(() -> periodRepo.save(BudgetPeriod.builder()
                .household(householdRepo.getReferenceById(householdId))
                .year(yearMonth.getYear())
                .month(yearMonth.getMonthValue())
                .build()));

        Optional<BudgetAllocation> existing = allocationRepo
            .findByPeriodIdAndCategoryId(period.getId(), cat.getId());

        if (existing.isPresent()) {
            existing.get().setBudgetedAmount(amount);
        } else {
            allocationRepo.save(BudgetAllocation.builder()
                .period(period)
                .category(cat)
                .budgetedAmount(amount)
                .build());
        }
    }

    /* ---- helpers ------------------------------------------------------- */

    private HouseholdCategory loadOwnedCategory(UUID categoryId, UUID householdId) {
        HouseholdCategory cat = categoryRepo.findById(categoryId)
            .orElseThrow(() -> new EntityNotFoundException("Category not found: " + categoryId));
        if (!cat.getHousehold().getId().equals(householdId)) {
            throw new AccessDeniedException("Category does not belong to your household");
        }
        return cat;
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
