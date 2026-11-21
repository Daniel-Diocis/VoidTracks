# VoidTracks

Applicazione mobile sviluppata in Flutter per la riproduzione e gestione di brani musicali con integrazione cloud per database e storage dei contenuti multimediali.

## Demo

https://github.com/user-attachments/assets/3dc3289c-b2b9-4687-8449-bbae64815a55

## Funzionalità

- Riproduzione di brani musicali con controlli play/pausa e navigazione tra tracce
- Gestione della libreria musicale locale
- Download dei brani da storage cloud
- Integrazione con database remoto per i metadati dei brani

## Tecnologie utilizzate

- Flutter
- Dart
- Supabase
- Cloudflare

## Architettura

- **App mobile:** Flutter  
- **Database:** Supabase  
- **Storage:** Cloudflare

Il Catalogo legge i metadati da Supabase e riproduce i brani in streaming da Cloudflare R2. Con **Scarica** si salvano audio e copertina sul dispositivo. La scheda **Download** usa Isar e funziona offline. Le due schede condividono il player e i controlli di sistema.

## Avvio del progetto


Clonare il repository:

```bash
git clone https://github.com/Daniel-Diocis/VoidTracks.git
```

Configurare in `assets/.env` i valori client `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MUSIC_URL` e `COVER_URL`. Gli ultimi due sono gli URL di lettura dei rispettivi bucket R2.

Installare le dipendenze:

```bash
flutter pub get
```

Eseguire l'app:

```bash
flutter run
```
