package com.sambo.calendar;

import com.sambo.auth.jwt.SamboPrincipal;
import com.sambo.calendar.dto.CalendarEventDto;
import com.sambo.calendar.dto.CreateCalendarEventRequest;
import com.sambo.calendar.dto.UpdateCalendarEventRequest;
import com.sambo.household.AppUser;
import com.sambo.household.AppUserRepository;
import com.sambo.household.Household;
import com.sambo.household.HouseholdRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CalendarService {

    private final CalendarEventRepository eventRepo;
    private final HouseholdRepository householdRepo;
    private final AppUserRepository userRepo;

    @Transactional(readOnly = true)
    public List<CalendarEventDto> listInWindow(UUID householdId, Instant from, Instant to) {
        return eventRepo
            .findByHouseholdIdAndStartsAtLessThanAndEndsAtGreaterThanEqualOrderByStartsAtAsc(
                householdId, to, from)
            .stream()
            .map(CalendarEventDto::from)
            .toList();
    }

    @Transactional
    public CalendarEventDto create(SamboPrincipal principal, CreateCalendarEventRequest req) {
        validateRange(req.startsAt(), req.endsAt());
        Household household = householdRepo.getReferenceById(principal.householdId());
        AppUser creator = userRepo.findById(principal.userId())
            .orElseThrow(() -> new EntityNotFoundException("User not found: " + principal.userId()));

        CalendarEvent saved = eventRepo.save(CalendarEvent.builder()
            .household(household)
            .createdBy(creator)
            .title(req.title().trim())
            .description(req.description() == null ? null : req.description().trim())
            .startsAt(req.startsAt())
            .endsAt(req.endsAt())
            .allDay(req.allDay())
            .color(req.color())
            .build());
        return CalendarEventDto.from(saved);
    }

    @Transactional
    public CalendarEventDto update(UUID eventId, UUID householdId, UpdateCalendarEventRequest req) {
        validateRange(req.startsAt(), req.endsAt());
        CalendarEvent event = loadOwned(eventId, householdId);
        event.setTitle(req.title().trim());
        event.setDescription(req.description() == null ? null : req.description().trim());
        event.setStartsAt(req.startsAt());
        event.setEndsAt(req.endsAt());
        event.setAllDay(req.allDay());
        event.setColor(req.color());
        return CalendarEventDto.from(event);
    }

    @Transactional
    public void delete(UUID eventId, UUID householdId) {
        CalendarEvent event = loadOwned(eventId, householdId);
        eventRepo.delete(event);
    }

    private CalendarEvent loadOwned(UUID eventId, UUID householdId) {
        CalendarEvent event = eventRepo.findById(eventId)
            .orElseThrow(() -> new EntityNotFoundException("Event not found: " + eventId));
        if (!event.getHousehold().getId().equals(householdId)) {
            throw new AccessDeniedException("Event does not belong to your household");
        }
        return event;
    }

    private static void validateRange(Instant startsAt, Instant endsAt) {
        if (endsAt.isBefore(startsAt)) {
            throw new IllegalArgumentException("ends_at måste vara samma som eller efter starts_at");
        }
    }
}
