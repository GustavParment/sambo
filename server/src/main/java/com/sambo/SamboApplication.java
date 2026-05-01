package com.sambo;

import com.sambo.auth.config.GoogleAuthProperties;
import com.sambo.auth.config.JwtProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan(basePackageClasses = {JwtProperties.class, GoogleAuthProperties.class})
public class SamboApplication {

	public static void main(String[] args) {
		SpringApplication.run(SamboApplication.class, args);
	}

}
