# Tech Stack (MVP)

## Frontend
- Flutter
- Riverpod (state management)
- go_router (navigation)

## Backend (scelta attuale)
- Supabase Auth (Email)
- Supabase Postgres (database principale)
- Supabase Storage (media delivery)
- Supabase Realtime (chat e aggiornamenti stato)
- Supabase Edge Functions (opzionale: logica server)
- Row Level Security (RLS) per controllo accessi

## Note
- Per questo progetto MVP usiamo Supabase come default.
- Evitare mix di provider backend nello stesso codice.
