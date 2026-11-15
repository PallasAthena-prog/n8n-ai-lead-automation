#!/bin/sh
# One-time setup for a fresh n8n volume: imports the two credentials and the four
# workflows, then publishes the workflows so their webhooks and schedule are live.
# Runs in the short-lived "n8n-import" container before the main n8n container starts.
set -eu

MARKER=/home/node/.n8n/.lead-demo-imported

if [ -f "$MARKER" ]; then
  echo "Demo workflows were imported before. Nothing to do."
  echo "(Run 'docker compose down -v' to start again from a clean slate.)"
  exit 0
fi

echo "Importing credentials..."
sed "s|__CRM_DB_PASSWORD__|${CRM_DB_PASSWORD}|" /import/credentials.template.json > /tmp/credentials.json
n8n import:credentials --input=/tmp/credentials.json
rm -f /tmp/credentials.json

echo "Importing workflows..."
n8n import:workflow --separate --input=/import/workflows

echo "Publishing workflows..."
for id in leadIntakeFlow01 followUpFlow0002 leadReplyFlow003 crmBoardFlow0004; do
  n8n publish:workflow --id="$id"
done

touch "$MARKER"
echo "Done."
