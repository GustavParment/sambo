package com.sambo.overview;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.overview.dto.OverviewDto;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.YearMonth;

/**
 * Dashboard payload. Tenant scope is taken from the JWT principal — the path
 * carries only the year-month, never the household id.
 */
@RestController
@RequestMapping("/api/overview")
@RequiredArgsConstructor
public class OverviewController {

    private final OverviewService overviewService;

    @GetMapping("/{yearMonth}")
    public OverviewDto get(
        @AuthenticationPrincipal SamboPrincipal principal,
        @PathVariable @DateTimeFormat(pattern = "yyyy-MM") YearMonth yearMonth
    ) {
        return overviewService.getMonthly(principal.householdId(), yearMonth);
    }
}
