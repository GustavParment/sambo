package com.sambo.overview;

import com.sambo.budget.BudgetService;
import com.sambo.budget.dto.MonthlyOverviewDto;
import com.sambo.chore.ChoreAggregate;
import com.sambo.chore.ChoreCompletionRepository;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.overview.dto.ChoreParticipantDto;
import com.sambo.overview.dto.ChoreSummaryDto;
import com.sambo.overview.dto.OverviewDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Aggregates household activity for the dashboard tab. Combines
 * chore-completion counts (this service) with the existing budget
 * monthly-overview (delegated to {@link BudgetService}).
 *
 * <p>Month boundaries are interpreted in {@code Europe/Stockholm} and then
 * converted to UTC {@link Instant}s before hitting the DB. Easy to
 * parameterise on a {@code ?tz=} query param later if we need it.
 */
@Service
@RequiredArgsConstructor
public class OverviewService {

    private static final ZoneId TZ = ZoneId.of("Europe/Stockholm");

    private final ChoreCompletionRepository completionRepo;
    private final AppUserRepository userRepo;
    private final BudgetService budgetService;

    @Transactional(readOnly = true)
    public OverviewDto getMonthly(UUID householdId, YearMonth yearMonth) {
        Instant from = yearMonth.atDay(1).atStartOfDay(TZ).toInstant();
        Instant to   = yearMonth.plusMonths(1).atDay(1).atStartOfDay(TZ).toInstant();

        ChoreAggregate agg = completionRepo
            .aggregateForHouseholdInWindow(householdId, from, to);

        List<UUID> participantIds = completionRepo
            .participantUserIdsForHouseholdInWindow(householdId, from, to);

        List<ChoreParticipantDto> participants = participantIds.isEmpty()
            ? List.of()
            : namesFor(participantIds);

        ChoreSummaryDto chores = new ChoreSummaryDto(
            agg.totalCompletions(),
            agg.distinctChoresDone(),
            participants
        );

        MonthlyOverviewDto budget = budgetService.getMonthlyOverview(householdId, yearMonth);

        return new OverviewDto(yearMonth, chores, budget);
    }

    /**
     * Resolve display names for the user IDs we got out of the DB. Returned
     * order is unspecified (and the DTO docs say so) — frontend renders the
     * list neutrally without ranking.
     */
    private List<ChoreParticipantDto> namesFor(List<UUID> ids) {
        Map<UUID, String> byId = userRepo.findAllById(ids).stream()
            .collect(Collectors.toMap(AppUser::getId, AppUser::getDisplayName));
        return ids.stream()
            .map(id -> new ChoreParticipantDto(id, byId.getOrDefault(id, "Okänd")))
            .toList();
    }
}
