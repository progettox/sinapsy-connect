# API Contracts (logica applicativa)

> Se usi Supabase-only, questo file resta il contratto logico tra use-case e repository.

## Azioni principali (concept)
- POST /campaigns
- GET /campaigns?role=creator&city=Milano (city opzionale, non bloccante)
- POST /applications
- DELETE /applications/{id} (creator owner, solo se `pending`; fallback possibile: update status a `rejected`)
- POST /applications/{id}/accept
- POST /projects/{id}/deliver
- POST /projects/{id}/approve
- POST /projects/{id}/dispute
- POST /reviews

## Nota implementativa Supabase
- Le azioni possono essere implementate con:
  - query dirette su Postgres via Supabase client
  - RPC SQL
  - Edge Functions (quando serve logica server)

## Response standard
- success: bool
- data: object
- error: { code, message }

## Error codes
- AUTH_REQUIRED
- FORBIDDEN
- VALIDATION_ERROR
- NOT_FOUND
- CONFLICT_STATE
