# Acceptance Criteria (MVP)

## Swipe feed
- Dato un creator loggato
- Quando carico Home
- Allora vedo 1 card alla volta con info essenziali
- Swipe dx = crea application se requisiti ok
- Swipe sx = scarta e passa alla successiva

## Match
- Dato che un brand accetta una application
- Allora viene creata una chat/workspace
- Entrambi vedono lo stato "matched"

## Project status
- Dato un match
- Quando il creator invia la prima consegna e preme "Lavoro concluso"
- Allora lo stato diventa `delivered`

## Delivery
- Creator puo inviare almeno 1 consegna (file o link)
- Brand puo Approva o Richiedi revisione

## Dispute
- Se uno apre contestazione
- Allora stato progetto = `disputed`
- Chat diventa read-only (MVP)

## Review
- Se progetto = completed
- Allora entrambi possono lasciare rating 1-5 una sola volta
