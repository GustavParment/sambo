# Multi-stage build:
#   1. JDK 25 builds the Spring Boot fat jar with Maven
#   2. Slim JRE 25 image runs it
#
# Image stays small (~ 250 MB compressed), pulls go-offline once per pom
# change, and the runtime is happy on Cloud Run's 512 MB tier.

# ---- Build ------------------------------------------------------------------

FROM eclipse-temurin:25-jdk AS build

WORKDIR /workspace

# Maven wrapper + pom first → the dependency cache layer survives src changes.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

# Now the source.
COPY src ./src
RUN ./mvnw -B -q -DskipTests package \
 && cp target/sambo-*.jar /workspace/app.jar

# ---- Runtime ---------------------------------------------------------------

FROM eclipse-temurin:25-jre

WORKDIR /app

# Run as non-root.
RUN groupadd --system sambo && useradd --system --gid sambo sambo
USER sambo:sambo

COPY --from=build --chown=sambo:sambo /workspace/app.jar /app/app.jar

# Cloud Run injects PORT; Spring Boot honours server.port via SERVER_PORT env.
ENV PORT=8080 \
    TZ=UTC \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080

ENTRYPOINT ["java","-jar","/app/app.jar"]
