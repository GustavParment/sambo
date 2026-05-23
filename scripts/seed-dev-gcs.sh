#!/usr/bin/env bash
# Seed the local fake-gcs-server with the 50 household avatar PNGs.
# Run once after `docker compose up -d` in server/.
# Requires: curl, docker compose running (server/docker-compose.yml).

set -euo pipefail

EMULATOR="http://localhost:4443"
BUCKET="sambo-assets"
REMOTE_BUCKET="gs://sambo-assets"
PREFIX="household-avatars"
TMPDIR="$(mktemp -d)"

echo "→ Creating bucket $BUCKET in emulator..."
curl -s -X POST "$EMULATOR/storage/v1/b?project=dev" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$BUCKET\"}" > /dev/null

echo "→ Downloading avatars from $REMOTE_BUCKET/$PREFIX/ ..."
gcloud storage cp "$REMOTE_BUCKET/$PREFIX/*.png" "$TMPDIR/" --quiet

echo "→ Uploading to emulator..."
for f in "$TMPDIR"/*.png; do
  name="$(basename "$f")"
  curl -s -X POST \
    "$EMULATOR/upload/storage/v1/b/$BUCKET/o?uploadType=media&name=$PREFIX/$name" \
    -H "Content-Type: image/png" \
    --data-binary @"$f" > /dev/null
  printf "  uploaded %s\n" "$name"
done

rm -rf "$TMPDIR"
echo "✓ Done — 50 avatars seeded into $EMULATOR/$BUCKET/$PREFIX/"
