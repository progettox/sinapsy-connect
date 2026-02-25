# Security Rules (MVP concepts)

## Principi
- Un user può leggere/modificare solo il proprio profilo.
- Un brand può leggere applications solo delle proprie campaigns.
- Una chat è visibile solo a brandId e creatorId.
- Se project è `disputed`, invio messaggi bloccato (read-only).

## Storage media
- Upload consentito solo a membri della chat
- Accesso ai file tramite URL signed o regole per path.

> Implementazione concreta dipende da Firebase/Backend.