package com.sambo.budget;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.budget.dto.CategoryDto;
import com.sambo.budget.dto.CreateCategoryRequest;
import com.sambo.budget.dto.MonthlyOverviewDto;
import com.sambo.budget.dto.UpsertAllocationRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

/**
 * Budget endpoints. Tenant scoping comes from {@link SamboPrincipal} — the
 * household id is NEVER taken from path or body.
 */
@RestController
@RequestMapping("/api/budget")
@RequiredArgsConstructor
public class BudgetController {

    private final BudgetService budgetService;

    /* ---- monthly overview ---------------------------------------------- */

    /** Example: GET /api/budget/2026-05 */
    @GetMapping("/{yearMonth}")
    public MonthlyOverviewDto overview(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable @DateTimeFormat(pattern = "yyyy-MM") YearMonth yearMonth
    ) {
        return budgetService.getMonthlyOverview(principal.householdId(), yearMonth);
    }

    /* ---- category CRUD ------------------------------------------------- */

    @GetMapping("/categories")
    public List<CategoryDto> listCategories(@AuthenticationPrincipal SamboPrincipal principal) {
        return budgetService.listCategories(principal.householdId());
    }

    @PostMapping("/categories")
    @ResponseStatus(HttpStatus.CREATED)
    public CategoryDto createCategory(
        @AuthenticationPrincipal SamboPrincipal principal,
        @Valid @RequestBody CreateCategoryRequest req
    ) {
        return budgetService.createCategory(principal.householdId(), req.name());
    }

    @DeleteMapping("/categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable UUID id
    ) {
        budgetService.deleteCategory(id, principal.householdId());
    }

    /* ---- allocation upsert --------------------------------------------- */

    /** PUT /api/budget/2026-05/categories/{id} { "amount": 4000 } */
    @PutMapping("/{yearMonth}/categories/{categoryId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void setAllocation(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable @DateTimeFormat(pattern = "yyyy-MM") YearMonth yearMonth,
        @PathVariable UUID categoryId,
        @Valid @RequestBody UpsertAllocationRequest req
    ) {
        budgetService.upsertAllocation(
            principal.householdId(), categoryId, yearMonth, req.amount());
    }
}
