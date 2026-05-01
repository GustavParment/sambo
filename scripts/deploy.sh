#!/usr/bin/env bash
# Manual deploy of the Sambo backend to Cloud Run.
#
# Prereqs (one-time, see DEPLOY.md):
#   - gcloud CLI authed: `gcloud auth login`
#   - project set:       `gcloud config set project <PROJECT_ID>`
#   - APIs enabled:      run, sql, sqladmin, cloudbuild, artifactregistry,
#                        secretmanager
#   - Artifact Registry repo created in REGION (`sambo`)
#   - Cloud SQL Postgres instance + database + user created
#   - Secrets uploaded to Secret Manager (see DEPLOY.md)
#
# Usage:
#   ./scripts/deploy.sh
#
# Tweak the variables below for your project, then commit. They're not
# secrets — actual secrets are read from Secret Manager.

set -euo pipefail

# ---- Per-project configuration --------------------------------------------

PROJECT_ID="${PROJECT_ID:-sambo-app-495010}"
REGION="${REGION:-europe-north1}"            # Helsinki — closest to Sweden
SERVICE="${SERVICE:-sambo-api}"
REPO="${REPO:-sambo}"
INSTANCE="${INSTANCE:-sambo-db}"             # Cloud SQL instance id
DB_NAME="${DB_NAME:-sambo}"
DB_USER="${DB_USER:-sambo}"

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${SERVICE}:latest"
CONNECTION_NAME="${PROJECT_ID}:${REGION}:${INSTANCE}"

# ---- Build + push image via Cloud Build -----------------------------------

cd "$(dirname "$0")/../server"

echo "▶ building image $IMAGE"
gcloud builds submit \
  --tag "$IMAGE" \
  --project "$PROJECT_ID" \
  .

# ---- Deploy ---------------------------------------------------------------

echo "▶ deploying $SERVICE to Cloud Run ($REGION)"
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --platform managed \
  --allow-unauthenticated \
  --add-cloudsql-instances "$CONNECTION_NAME" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 5 \
  --port 8080 \
  --timeout 60 \
  --set-env-vars "DB_URL=jdbc:postgresql:///${DB_NAME}?cloudSqlInstance=${CONNECTION_NAME}&socketFactory=com.google.cloud.sql.postgres.SocketFactory" \
  --set-env-vars "DB_USER=${DB_USER}" \
  --set-secrets "DB_PASSWORD=sambo-db-password:latest" \
  --set-secrets "SAMBO_JWT_SECRET=sambo-jwt-secret:latest" \
  --set-secrets "SAMBO_GOOGLE_AUDIENCES=sambo-google-audiences:latest"

URL=$(gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --format='value(status.url)')

echo
echo "✓ deployed: $URL"
echo "  smoke-test:  curl -fsS $URL/actuator/health"
echo "  Flutter URL: --dart-define=BACKEND_BASE_URL=$URL"
