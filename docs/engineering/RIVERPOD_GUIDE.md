# Riverpod guide (MVP)

## Pattern
- `StateNotifier` / `Notifier`
- state classes immutabili
- provider per repository

## Stati
Per ogni screen:
- loading
- data
- empty
- error

## Esempio state
- `SwipeFeedState` { status, cards, errorMessage }