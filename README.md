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

L'applicazione recupera i metadati dei brani dal database remoto e scarica i contenuti multimediali dallo storage cloud per la riproduzione all'interno dell'app.

## Avvio del progetto


Clonare il repository:

```bash
git clone https://github.com/Daniel-Diocis/VoidTracks.git
```

Installare le dipendenze:

```bash
flutter pub get
```

Eseguire l'app:

```bash
flutter run
```
