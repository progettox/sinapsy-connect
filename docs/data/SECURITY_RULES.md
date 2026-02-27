# Security Rules (MVP concepts)

## Principi
- Un user puo leggere/modificare solo il proprio profilo.
- Un brand puo leggere applications solo delle proprie campaigns.
- Un creator puo cancellare solo le proprie applications `pending`.
- Un creator puo aggiornare a `rejected` solo le proprie applications `pending` (fallback withdraw).
- Una chat e visibile solo a brandId e creatorId.
- Se project e `disputed`, invio messaggi bloccato (read-only).

## Supabase policy model
- Applicare Row Level Security (RLS) su tutte le tabelle sensibili.
- Policy per `select/insert/update/delete` basate su `auth.uid()`.
- Bloccare `insert` su `messages` quando project = `disputed`.

## Storage media
- Upload consentito solo a membri della chat.
- Accesso ai file tramite URL signed o policy Storage per path.

> Implementazione concreta: policy SQL + Storage policies in Supabase.
