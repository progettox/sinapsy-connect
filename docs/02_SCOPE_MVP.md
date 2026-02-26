# Scope MVP (v1)

## In scope (MVP)
1. Auth + onboarding
   - Login: solo Email
   - scelta ruolo: Brand vs Creator
   - setup profilo base

2. Brand
   - crea campagna (collab post)
   - lista campagne e stato
   - vede candidature (applications)
   - accetta/rifiuta -> match

3. Creator
   - feed a card con swipe
   - candidatura (application)
   - chat/workspace dopo match

4. Workspace
   - chat 1:1
   - consegna lavoro: upload media **oppure** link
   - bottone "Lavoro concluso"
   - brand: Approva / Richiedi revisione / Apri contestazione

5. Reviews
   - rating 1-5 dopo completamento

## Out of scope (v2)
- abbonamenti premium
- stanze multi-utente (brand + modella + fotografo)
- API YouTube/Twitch
- algoritmo match avanzato con AI

## Non-functional
- swipe fluido
- immagini caricate async
- data model consistente

## Decisioni MVP (per velocita)
- Social API: in MVP puoi usare "manual input" + flag `verified=false` (poi sostituibile)
