-- CRM schema for the lead automation demo.
-- Postgres runs this once, the first time the data volume is created.

create table leads (
    id                     bigint generated always as identity primary key,
    email                  text not null unique,
    full_name              text not null,
    company                text,
    job_title              text,
    phone                  text,
    message                text,
    source                 text not null default 'website',
    utm                    jsonb not null default '{}'::jsonb,

    -- filled in by the qualification step
    category               text check (category in ('hot', 'warm', 'cold', 'spam')),
    score                  integer check (score between 0 and 100),
    intent                 text,
    urgency                text check (urgency in ('high', 'medium', 'low')),
    summary                text,
    classification_reasons jsonb not null default '[]'::jsonb,
    classified_by          text check (classified_by in ('llm', 'rules')),
    -- first sentences of the reply, written by the model (kept so a retried email reads the same)
    opening                text,

    -- pipeline state
    status                 text not null default 'new' check (status in (
                               'new', 'contacted', 'nurturing', 'meeting_requested',
                               'no_response', 'unsubscribed', 'undeliverable', 'disqualified')),
    owner_email            text,
    follow_up_step         integer not null default 0,
    next_follow_up_at      timestamptz,
    last_contacted_at      timestamptz,
    submission_count       integer not null default 1,
    -- secret used in the "book a call" and "unsubscribe" links
    response_token         uuid not null default gen_random_uuid(),

    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

create index leads_due_follow_ups on leads (next_follow_up_at)
    where next_follow_up_at is not null;

-- Everything that happens to a lead, newest last. Handy for debugging and for a timeline view.
create table lead_activities (
    id         bigint generated always as identity primary key,
    lead_id    bigint not null references leads (id) on delete cascade,
    type       text not null,
    detail     jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index lead_activities_by_lead on lead_activities (lead_id, created_at);

-- Email sequences live in the database, so copy and timing can change without touching the workflows.
-- Step 0 is the first reply, sent right away. Each later step is sent delay_days after the previous email.
-- Placeholders: {{first_name}} {{lead_company}} {{our_company}} {{sender_name}} {{opening}} {{booking_link}}
create table sequence_steps (
    category   text not null check (category in ('hot', 'warm', 'cold')),
    step       integer not null check (step >= 0),
    delay_days numeric not null check (delay_days >= 0),
    subject    text not null,
    body       text not null,
    primary key (category, step)
);

insert into sequence_steps (category, step, delay_days, subject, body) values
('hot', 0, 0, 'Your {{our_company}} demo: pick a time',
'Hi {{first_name}},

{{opening}}

The quickest next step is a 30 minute call where we look at your setup together and I show you the parts that matter for {{lead_company}}. Here is my calendar:

{{booking_link}}

Talk soon,
{{sender_name}}'),

('hot', 1, 1, 'Re: your {{our_company}} demo',
'Hi {{first_name}},

Just checking my last email did not get buried. If none of the slots work, reply with two times that suit you and I will send an invite.

{{booking_link}}

{{sender_name}}'),

('hot', 2, 3, 'Should I close your demo request?',
'Hi {{first_name}},

I have not heard back, so I will assume the timing is not right and close your request for now. If things change, the calendar link below still works.

{{booking_link}}

All the best,
{{sender_name}}'),

('warm', 0, 0, 'Thanks for getting in touch, {{first_name}}',
'Hi {{first_name}},

{{opening}}

Most teams in a similar spot start with a short walkthrough, so they can see whether {{our_company}} fits before spending more time on it. If that sounds useful, grab a slot here:

{{booking_link}}

Best,
{{sender_name}}'),

('warm', 1, 3, 'A few ideas for {{lead_company}}',
'Hi {{first_name}},

I had another look at what you wrote. The teams that get the most out of {{our_company}} usually start by automating one weekly report and build from there. Happy to walk you through how that would look for {{lead_company}}.

{{booking_link}}

{{sender_name}}'),

('warm', 2, 7, 'Last check-in from {{our_company}}',
'Hi {{first_name}},

I will stop following up after this one. If you want to pick the conversation back up later, just reply to this email or use the link below.

{{booking_link}}

{{sender_name}}'),

('cold', 0, 0, 'Thanks for your interest in {{our_company}}',
'Hi {{first_name}},

{{opening}}

No pressure at all. Whenever you want to see how it works, you can book a short call here:

{{booking_link}}

Cheers,
{{sender_name}}'),

('cold', 1, 7, 'How other teams use {{our_company}}',
'Hi {{first_name}},

A quick note in case it helps: most of our customers start by replacing one spreadsheet that someone updates by hand every week. That alone usually saves a few hours.

If you would like to see an example, here is my calendar:

{{booking_link}}

{{sender_name}}'),

('cold', 2, 21, 'Still exploring?',
'Hi {{first_name}},

This is my last email for now. If {{our_company}} becomes relevant later, you can always reach me here.

{{booking_link}}

{{sender_name}}');

-- Quick overview of the pipeline: psql -c "select * from pipeline_overview"
create view pipeline_overview as
select category,
       status,
       count(*)           as leads,
       round(avg(score))  as avg_score
  from leads
 group by category, status
 order by category, status;
