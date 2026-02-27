# Acceptance Criteria (MVP)

## Swipe feed
- Dato un creator loggato
- Quando carico Home
- Allora vedo 1 card alla volta con info essenziali
- Swipe dx = crea application se requisiti ok
- Swipe sx = scarta e passa alla successiva
- La location della campagna e opzionale e non blocca la candidatura

## My Applications
- Dato un creator con una candidatura `pending`
- Quando preme "Abbandona richiesta" e conferma
- Allora la candidatura viene rimossa dalla lista My Applications
- E non risulta piu come candidatura `pending` lato brand
- E il creator puo inviare nuovamente una candidatura per la stessa campagna

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
