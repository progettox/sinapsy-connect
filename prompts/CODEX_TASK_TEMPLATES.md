# Codex Task Templates

## Template 1 — Create feature skeleton
Obiettivo: creare la feature X con cartelle data/domain/application/ui.
Input:
- feature name
- screens
- state machine events
Output:
- struttura file
- provider Riverpod
- repository interface + fake impl

## Template 2 — Implement a screen
Obiettivo: implementare UI della screen X.
Vincoli:
- nessuna logica nel widget
- usare state/provider
- stati: loading/empty/error

## Template 3 — Implement repository with Firebase
Obiettivo: collegare repository X a Firestore.
Vincoli:
- mapping model ↔ entity
- error handling