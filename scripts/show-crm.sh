#!/usr/bin/env bash
# Prints the leads and their latest activity straight from the CRM database.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose exec -T postgres psql -U crm -d crm -P pager=off <<'SQL'
\echo '--- leads ---'
select id, full_name, category, score, classified_by, status, owner_email,
       follow_up_step as step, to_char(next_follow_up_at, 'HH24:MI:SS') as next_at
  from leads
 order by id;

\echo '--- pipeline ---'
select * from pipeline_overview;

\echo '--- last 15 activities ---'
select a.id, a.lead_id, l.full_name, a.type, a.detail, to_char(a.created_at, 'HH24:MI:SS') as at
  from lead_activities a
  join leads l on l.id = a.lead_id
 order by a.id desc
 limit 15;
SQL
