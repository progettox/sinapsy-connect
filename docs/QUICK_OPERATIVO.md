# Quick Operativo

Questa guida contiene solo quello che serve per lavorare subito sul progetto.

## Stato attuale app
- Login e onboarding profilo attivi.
- Dashboard Brand personalizzata attiva.
- Card "Campagne Attive" e "Candidature" cliccabili.
- Sezione creator consigliati con scroll/swipe attiva.
- Follow/Unfollow attivo da dashboard e discover.
- Username univoco in fase di salvataggio profilo.

## Requisiti minimi Supabase
Per i contatori follower globali servono:
1. Tabella `profile_followers` con chiave unica (`follower_id`, `followed_id`).
2. Colonne su `profiles`: `followers_count`, `following_count`.
3. RLS/policy per consentire:
- `select` su follow.
- `insert/delete` solo per `auth.uid() = follower_id`.

Senza questa parte DB, il numero follower non resta coerente tra account diversi.

## Dove toccare il codice (follow)
- Repo dati follow: `app/lib/features/brand/data/brand_creator_feed_repository.dart`
- UI dashboard: `app/lib/features/brand/presentation/pages/brand_dashboard_page.dart`
- UI discover: `app/lib/features/brand/presentation/pages/brand_discover_creators_page.dart`

## Comandi utili
Da cartella `app`:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter run`
4. `flutter build apk --release`

APK release output:
- `app/build/app/outputs/flutter-apk/app-release.apk`

## Cosa puoi ignorare per ora
- Documenti legali/compliance se stai lavorando solo su feature.
- Documenti su webhook/notifiche se non stai toccando backend eventi.
- Wireframe estesi se la UI e gia stata implementata.
