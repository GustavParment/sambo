package com.sambo.household;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.BAD_REQUEST)
public class TooManyHouseholdsException extends RuntimeException {
    public TooManyHouseholdsException(String message) {
        super(message);
    }
}
