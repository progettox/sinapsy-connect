# Decisione Backend e Schema (MVP)

## Decisione presa
- Usiamo **Supabase** come backend unico per MVP.
- Database: **PostgreSQL**.
- Autenticazione: Supabase Auth.
- Media: Supabase Storage.

## Regola di progetto
- Non mischiare provider diversi nel runtime.

## Scelta default suggerita (MVP)
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Supabase Realtime (chat/stati)
- Supabase Edge Functions (solo se serve)

## Motivo
- Stack coerente, SQL nativo, RLS integrata, meno complessita operativa.
