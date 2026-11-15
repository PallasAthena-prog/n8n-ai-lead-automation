#!/usr/bin/env bash
# Sends a set of realistic test leads to the intake webhook, one of each kind.
# Usage: bash scripts/send-sample-leads.sh          (uses http://localhost:5678)
#        LEAD_WEBHOOK_URL=https://... bash scripts/send-sample-leads.sh
set -euo pipefail

cd "$(dirname "$0")/.."

URL="${LEAD_WEBHOOK_URL:-http://localhost:5678/webhook/lead}"
SECRET="${LEAD_WEBHOOK_SECRET:-}"
# fall back to the value in .env, so the samples still work when the secret is switched on
if [ -z "$SECRET" ] && [ -f .env ]; then
  SECRET="$(grep -E '^LEAD_WEBHOOK_SECRET=' .env | tail -n 1 | cut -d= -f2- | tr -d '\r')"
fi

headers=(-H "Content-Type: application/json")
if [ -n "$SECRET" ]; then
  headers+=(-H "X-Webhook-Secret: $SECRET")
fi

post() {
  echo "== $1"
  curl -sS -X POST "$URL" "${headers[@]}" -d "$2"
  echo
  echo
}

post "Hot: demo request with a timeline" '{
  "name": "Dana Whitfield",
  "email": "dana.whitfield@brightside-logistics.com",
  "company": "Brightside Logistics",
  "job_title": "Head of Operations",
  "phone": "+44 20 7946 0123",
  "source": "pricing-page",
  "utm_source": "google",
  "utm_campaign": "reporting-automation",
  "message": "We are a team of 40 and still build our weekly ops reports by hand in Excel. Could we get a demo and pricing this week? We want to replace the current process before the end of the quarter."
}'

post "Warm: relevant problem, no buying signal yet" '{
  "name": "Marco Bellini",
  "email": "marco@studio-bellini.it",
  "company": "Studio Bellini",
  "message": "Hi, we are looking into ways to automate some of our client reporting. How does your tool connect to Google Sheets?"
}'

post "Cold: early research" '{
  "name": "Priya Raman",
  "email": "priya.raman@gmail.com",
  "message": "I am a student writing my thesis on workflow automation and was just curious how your product works."
}'

post "Spam: SEO pitch" '{
  "name": "Rank Experts",
  "email": "offers@rank-experts-seo.biz",
  "message": "We offer SEO services and link building to rank your website on page 1. Guest post packages from $49. Reply for our price list!"
}'

post "Bot: hidden honeypot field filled" '{
  "name": "John",
  "email": "john.smith1987@mail.com",
  "message": "Great site",
  "_hp": "http://cheap-pills.example"
}'

post "Invalid: missing email (expect HTTP 422)" '{
  "name": "No Email",
  "message": "Forgot my address"
}'

post "Duplicate: Dana sends the form again" '{
  "name": "Dana Whitfield",
  "email": "Dana.Whitfield@brightside-logistics.com",
  "message": "Just checking you got my earlier request."
}'

echo "Done. Open http://localhost:8025 for the emails and http://localhost:5678/webhook/crm for the CRM board."
