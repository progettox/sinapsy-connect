# API Contracts (se usi backend custom)

> Se usi Firebase-only, questo file serve come “contratto logico” per servizi e repository.

## Endpoints (concept)
- POST /campaigns
- GET /campaigns?role=creator&city=Milano
- POST /applications
- POST /applications/{id}/accept
- POST /projects/{id}/lock-escrow
- POST /projects/{id}/deliver
- POST /projects/{id}/approve
- POST /projects/{id}/dispute
- POST /reviews

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