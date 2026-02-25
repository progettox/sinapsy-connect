# State Machines

## Campaign (collab)
- `draft` → `active` → `matched` → `completed` (oppure `cancelled`)

## Application
- `pending` → `accepted` | `rejected`

## Project / Workspace
- `matched` → `escrow_locked` → `in_progress` → `delivered` → `completed`
- eccezioni:
  - `disputed`

## Message / Delivery
- message types:
  - `text`
  - `media` (file)
  - `link`
  - `system` (status changes)

Regola: cambi stato solo tramite eventi definiti (no aggiornamenti “a caso”).