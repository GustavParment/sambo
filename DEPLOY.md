# DEPLOY.md — Sambo backend on Cloud Run + Cloud SQL

Goes from "works on my Mac" to "TestFlight can reach it over HTTPS."

You'll click through GCP Console for the resources that only happen once
(Cloud SQL instance, Artifact Registry repo, Secret Manager entries). After
that, every deploy is one command: `./scripts/deploy.sh`.

Estimated first-run effort: **45–60 min** of clicking, then 3-minute deploys.
Estimated cost: **~10 USD/month** (Cloud SQL `db-f1-micro` shared-core, the
rest stays in Cloud Run's free tier for an MVP).

---

## 1. Prereqs on your laptop

```bash
brew install --cask google-cloud-sdk      # gcloud CLI
gcloud auth login
gcloud auth application-default login     # used by some local tools
gcloud config set project sambo-app-495010       # use your real project id
```

---

## 2. Enable APIs (once per project)

```bash
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```

(Or click each one through Console → APIs & Services → Library — same effect.)

---

## 3. Cloud SQL Postgres instance

GCP Console → **SQL** → **Create instance** → **PostgreSQL**:

| Field | Value |
|---|---|
| Instance ID | `sambo-db` |
| Password | *generate a strong one and store it — you'll add to Secret Manager in step 5* |
| Database version | PostgreSQL 16 |
| Region | `europe-north1` (Helsinki — closest to Sweden) |
| Zonal availability | Single zone (cheaper; multi-zone for prod later) |
| Machine type | **Shared core → 1 vCPU, 0.614 GB** (the `db-f1-micro` tier — ~10 USD/mo) |
| Storage | 10 GB SSD, auto-increase on |
| Connections | **Public IP**: enable. **Private IP**: optional. Authorized networks: leave empty (we use Cloud SQL Auth Proxy via `--add-cloudsql-instances`, not direct IP). |

Click **Create instance** and wait ~10 min while it provisions.

When it's ready, in the instance overview:

- **Databases** tab → **+ Create database** → name `sambo`, click Create.
- **Users** tab → **+ Add user account** → username `sambo`, paste the password
  from above. Authentication: built-in.

Note the **Connection name** at the top of the instance overview — looks like
`sambo-app-495010:europe-north1:sambo-db`. You'll reuse it.

---

## 4. Artifact Registry repository

```bash
gcloud artifacts repositories create sambo \
  --repository-format=docker \
  --location=europe-north1 \
  --description="Sambo container images"
```

This is where built images live before Cloud Run pulls them.

---

## 5. Secret Manager — the three secrets

We never put real secrets in env-vars in the deploy script — Cloud Run
mounts them from Secret Manager at runtime. Three to create:

```bash
# 1) DB password (the one you typed in step 3)
echo -n 'YOUR_DB_PASSWORD' | gcloud secrets create sambo-db-password \
  --replication-policy=automatic --data-file=-

# 2) JWT signing secret — generate fresh, do NOT reuse the dev one
openssl rand -base64 48 | tr -d '\n' | gcloud secrets create sambo-jwt-secret \
  --replication-policy=automatic --data-file=-

# 3) Google audiences — comma-separated Web + iOS client IDs
echo -n '422660998581-lop49vn54npfri2o5asjcqlt6elt5si0.apps.googleusercontent.com,422660998581-3a1hrfun2o79qrdis005lfljueqk0uqd.apps.googleusercontent.com' \
  | gcloud secrets create sambo-google-audiences \
  --replication-policy=automatic --data-file=-
```

**Grant the Cloud Run runtime service account access** (it's the default
compute SA):

```bash
PROJECT_NUMBER=$(gcloud projects describe sambo-app-495010 --format='value(projectNumber)')
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for secret in sambo-db-password sambo-jwt-secret sambo-google-audiences; do
  gcloud secrets add-iam-policy-binding "$secret" \
    --member="serviceAccount:${SA}" \
    --role=roles/secretmanager.secretAccessor
done
```

Same SA also needs the Cloud SQL client role:

```bash
gcloud projects add-iam-policy-binding sambo-app-495010 \
  --member="serviceAccount:${SA}" \
  --role=roles/cloudsql.client
```

---

## 6. First deploy

Edit `scripts/deploy.sh` if your project / region / instance names differ
from the defaults (`sambo-app-495010` / `europe-north1` / `sambo-db`), then:

```bash
./scripts/deploy.sh
```

The script does three things:
1. `gcloud builds submit` — Cloud Build runs the multi-stage Dockerfile,
   pushes the image to Artifact Registry. ~3–5 min the first time.
2. `gcloud run deploy` — creates the Cloud Run service, wires Cloud SQL,
   injects the secrets. ~30 s.
3. Prints the public HTTPS URL.

On success the URL is something like:
```
https://sambo-api-abc123-lz.a.run.app
```

Smoke-test it:
```bash
curl https://sambo-api-abc123-lz.a.run.app/actuator/health
# {"status":"UP"}
```

The Flyway migrations (V1 → V6) run automatically on first container start
against the empty `sambo` database — schema appears in Cloud SQL after the
first request. Verify in Cloud SQL Studio (Console → SQL → sambo-db →
Cloud SQL Studio → query `\dt`).

---

## 7. Point the Flutter client at production

Override `BACKEND_BASE_URL` per build:

```bash
# Either edit client/.vscode/launch.json:
{
  "name": "Sambo (debug, prod backend)",
  "request": "launch",
  "type": "dart",
  "program": "lib/main.dart",
  "args": [
    "--dart-define=GOOGLE_SERVER_CLIENT_ID=422660998581-lop4....apps.googleusercontent.com",
    "--dart-define=BACKEND_BASE_URL=https://sambo-api-abc123-lz.a.run.app"
  ]
}

# Or as a fastlane env when building IPA for TestFlight:
flutter build ipa --release \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com \
  --dart-define=BACKEND_BASE_URL=https://sambo-api-abc123-lz.a.run.app
```

The IPA carries the Cloud Run URL baked in, so TestFlight users hit it
directly — no localhost dependency.

---

## 8. Subsequent deploys

After the first run, every code change is one command:

```bash
./scripts/deploy.sh
```

Cloud Build's Maven layer cache makes incremental builds ~90 s.

To redeploy without rebuilding (e.g. just bumped a secret):
```bash
gcloud run services update sambo-api --region europe-north1
```

---

## 9. Logs & debugging

```bash
# Tail logs in real-time
gcloud run services logs tail sambo-api --region europe-north1

# Or in Console: Cloud Run → sambo-api → LOGS tab
```

Common first-deploy issues:

| Symptom | Fix |
|---|---|
| Container exits immediately | Check logs — usually a missing secret. Verify all 3 secrets exist + IAM granted. |
| `Connection refused` on JDBC | `--add-cloudsql-instances` flag not passed, or Cloud SQL client role missing. |
| `aud not in audiences` | The Web/iOS client ID in `sambo-google-audiences` doesn't match what the app sends. Update secret with: `echo -n 'NEW_VALUE' \| gcloud secrets versions add sambo-google-audiences --data-file=-`. |
| First request takes 5–10 s | Cold start. Set `--min-instances=1` if you want always-warm — costs ~5 USD/mo. |

---

## 10. Wiring up CI later (optional)

`scripts/cloudbuild.yaml` is ready to be triggered from GitHub. In Console →
Cloud Build → Triggers → **Create trigger**:

- Source: connect GitHub, pick your `sambo` repo
- Event: push to branch `main`
- Configuration: Cloud Build configuration file
- Location: `scripts/cloudbuild.yaml`

Grant the Cloud Build SA the same roles as the runtime SA (run.admin +
iam.serviceAccountUser + cloudsql.client + secretmanager.secretAccessor).
After that, every push to main auto-builds and auto-deploys.
