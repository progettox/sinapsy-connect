# Architecture Overview (MVP)

## App Flutter
- presentation (UI)
- application (use-cases)
- domain (entities)
- data (repositories + datasources)

## Services
- Auth
- Campaigns
- Applications
- Chat/Projects
- Media upload
- Reviews

## Key rule
Ogni feature deve rispettare le state machines definite in `docs/flows/STATE_MACHINES.md`.