# Storage & Media

## Obiettivo
- evitare perdita qualità
- gestire file pesanti

## MVP
- Supporta:
  - immagini (jpg/png)
  - video (mp4) opzionale
  - link (wetransfer/drive)

## Strategia
- In app: upload su Storage e salva URL in `messages.mediaUrl`
- Per qualità: non comprimere lato app (o compressione controllata)
- Per sicurezza: accesso limitato a chat members