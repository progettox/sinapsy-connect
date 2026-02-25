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
- Entrambi vedono lo stato “matched”

## Escrow status
- Dato un match
- Quando il brand preme “Firma e Paga”
- Allora lo stato diventa `in_progress` e banner escrow in chat diventa “locked”

## Delivery
- Creator può inviare almeno 1 consegna (file o link)
- Brand può Approva o Richiedi revisione

## Dispute
- Se uno apre contestazione
- Allora stato progetto = `disputed`
- Chat diventa read-only (MVP)

## Review
- Se progetto = completed
- Allora entrambi possono lasciare rating 1-5 una sola volta