package com.sambo.chore.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateChoreRequest(
    @NotBlank @Size(max = 100) String name
) {}
