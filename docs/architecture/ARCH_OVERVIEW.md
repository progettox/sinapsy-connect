# Architecture Overview (MVP)

## App Flutter
- presentation (UI)
- application (use-cases)
- domain (entities)
- data (repositories + datasources)

## Backend platform
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Supabase Realtime
- Supabase Edge Functions (opzionale)

## Services
- Auth
- Campaigns
- Applications
- Chat/Projects
- Media upload
- Reviews

## Key rule
Ogni feature deve rispettare le state machines definite in `docs/flows/STATE_MACHINES.md`.
