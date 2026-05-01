package com.sambo.chore;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.chore.dto.ChoreDto;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChoreService {

    private final ChoreRepository choreRepo;
    private final ChoreCompletionRepository completionRepo;
    private final HouseholdRepository householdRepo;
    private final AppUserRepository userRepo;

    @Transactional(readOnly = true)
    public List<ChoreDto> listForHousehold(UUID householdId) {
        return toDtos(choreRepo
            .findByHouseholdIdAndArchivedAtIsNullOrderByNameAsc(householdId));
    }

    @Transactional(readOnly = true)
    public List<ChoreDto> listArchived(UUID householdId) {
        return toDtos(choreRepo
            .findByHouseholdIdAndArchivedAtIsNotNullOrderByArchivedAtDesc(householdId));
    }

    private List<ChoreDto> toDtos(List<Chore> chores) {
        return chores.stream()
            .map(c -> ChoreDto.from(
                c,
                completionRepo.findFirstByChoreIdOrderByCompletedAtDesc(c.getId()).orElse(null)))
            .toList();
    }

    @Transactional
    public ChoreDto create(UUID householdId, String name,
                           Instant lastCompletedAt, Instant scheduledFor) {
        Household household = householdRepo.getReferenceById(householdId);
        Chore saved = choreRepo.save(Chore.builder()
            .household(household)
            .name(name.trim())
            .scheduledFor(scheduledFor)
            .build());

        ChoreCompletion completion = null;
        if (lastCompletedAt != null) {
            completion = completionRepo.save(ChoreCompletion.builder()
                .chore(saved)
                .completedAt(lastCompletedAt)
                .users(new HashSet<>())
                .build());
            saved.setLastCompletedAt(lastCompletedAt);
        }
        log.info("Created chore '{}' household={} baseline={} scheduledFor={}",
            saved.getName(), householdId, lastCompletedAt, scheduledFor);
        return ChoreDto.from(saved, completion);
    }

    /**
     * Records a new completion event with the given participants. If
     * {@code participantIds} is null/empty the caller is the sole completer
     * (single-user fallback). Every participant id must belong to the same
     * household as the caller — otherwise 403.
     */
    @Transactional
    public ChoreDto complete(UUID choreId, List<UUID> participantIds, SamboPrincipal principal) {
        Chore chore = loadOwned(choreId, principal.householdId());

        Set<UUID> ids = new HashSet<>();
        if (participantIds == null || participantIds.isEmpty()) {
            ids.add(principal.userId());
        } else {
            ids.addAll(participantIds);
        }

        Set<AppUser> participants = new HashSet<>();
        for (UUID id : ids) {
            AppUser u = userRepo.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("User not found: " + id));
            if (!u.getHousehold().getId().equals(principal.householdId())) {
                throw new AccessDeniedException(
                    "Participant does not belong to your household: " + id);
            }
            participants.add(u);
        }

        Instant now = Instant.now();
        ChoreCompletion completion = completionRepo.save(ChoreCompletion.builder()
            .chore(chore)
            .completedAt(now)
            .users(participants)
            .build());
        chore.setLastCompletedAt(now);

        log.info("Chore {} completed by {} user(s) at {}",
            choreId, participants.size(), now);
        return ChoreDto.from(chore, completion);
    }

    /** Soft archive: preserves completion history, just hides from active list. */
    @Transactional
    public ChoreDto archive(UUID choreId, UUID householdId) {
        Chore chore = loadOwned(choreId, householdId);
        if (chore.getArchivedAt() == null) {
            chore.setArchivedAt(Instant.now());
        }
        log.info("Archived chore {} in household {}", choreId, householdId);
        return ChoreDto.from(
            chore,
            completionRepo.findFirstByChoreIdOrderByCompletedAtDesc(chore.getId()).orElse(null));
    }

    @Transactional
    public ChoreDto unarchive(UUID choreId, UUID householdId) {
        Chore chore = loadOwned(choreId, householdId);
        chore.setArchivedAt(null);
        log.info("Unarchived chore {} in household {}", choreId, householdId);
        return ChoreDto.from(
            chore,
            completionRepo.findFirstByChoreIdOrderByCompletedAtDesc(chore.getId()).orElse(null));
    }

    @Transactional
    public void delete(UUID choreId, UUID householdId) {
        Chore chore = loadOwned(choreId, householdId);
        choreRepo.delete(chore);
        log.info("Deleted chore {} from household {}", choreId, householdId);
    }

    private Chore loadOwned(UUID choreId, UUID householdId) {
        Chore chore = choreRepo.findById(choreId)
            .orElseThrow(() -> new EntityNotFoundException("Chore not found: " + choreId));
        if (!chore.getHousehold().getId().equals(householdId)) {
            throw new AccessDeniedException("Chore does not belong to your household");
        }
        return chore;
    }
}
