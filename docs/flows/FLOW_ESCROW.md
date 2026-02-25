# Flow — Escrow (MVP)

Stati escrow (MVP):
- `not_started`
- `locked` (fondi bloccati)
- `released` (fondi trasferiti)
- `refunded` (rimborso)

Flusso:
1. Match
2. Brand: “Firma e Paga” → escrow = locked
3. Creator: lavora → “Lavoro concluso”
4. Brand: Approva → escrow = released, progetto completed
5. Se disputa → escrow resta locked fino a decisione admin (MVP: placeholder)