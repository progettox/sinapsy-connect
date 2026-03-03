
# Sinapsy Connect

App mobile Flutter (iOS/Android) per connessione tra Brand e Creator.

## Start rapido
1. Apri la cartella `app`.
2. Esegui `flutter pub get`.
3. Configura le variabili Supabase (`url` + `anon key`).
4. Avvia con `flutter run`.

## Build APK release
Da cartella `app`:
- `flutter build apk --release`
- APK output: `app/build/app/outputs/flutter-apk/app-release.apk`

## Documentazione essenziale
- Indice pratico: `docs/00_INDEX.md`
- Guida operativa aggiornata: `docs/QUICK_OPERATIVO.md`

## Note
- La dashboard brand e la logica follow/unfollow sono gia integrate lato app.
- Per i contatori follower globali servono tabelle/policy Supabase coerenti.
