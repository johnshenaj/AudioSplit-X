# AudioSplit X 0.1

App standalone Swift/SwiftUI per macOS 15 o successivo, compilata per Apple Silicon.

## Download

[Scarica la versione 0.1.0 per Apple Silicon](https://github.com/johnshenaj/AudioSplit-X/releases/tag/v0.1.0).
Build sperimentale locale, non notarizzata. Richiede macOS 15 o successivo.

## Test eseguito

Chrome sugli altoparlanti MacBook Pro e ChatGPT nelle cuffie jack contemporaneamente:
verificato su un Mac Apple Silicon con macOS 26.6.2 e confermato all’ascolto dall’utente.
Verificati anche mute, attenuazione al 90%, sospensione/ripresa e caricamento preferenze.
Sette test automatici superati. Non equivale a supporto universale per app e dispositivi.

## Uso

Apri `AudioSplit X.app`. L’icona a diramazione nella barra menu apre il pannello anche dopo aver chiuso la finestra iniziale.
Avvia una riproduzione nelle app desiderate. Scegli l’uscita nella loro riga.
La prima cattura può far comparire il permesso macOS di registrazione audio di sistema. Va consentito per instradare l’audio; non occorrono Accessibilità, microfono o driver aggiuntivi per questa build non sandboxed.

- Chrome: Altoparlanti MacBook Pro.
- ChatGPT: Cuffie esterne.
- Volume: attenuazione software 0–100% del percorso catturato.
- Mute: silenzia il percorso catturato.
- Reset: ripristina volume 100%, toglie il mute e lascia l’uscita all’app/sistema.
- Sospendi tutto: ferma i tap e ripristina le uscite originali; conserva le scelte.
- Esci: arresta percorsi, dispositivi aggregati privati e tap prima di chiudere.
- Riprova: ritenta percorsi falliti dopo aver corretto permessi o riproduzione.

Il pallino “Audio attivo” indica lo stato di uscita riportato da Core Audio, che può restare attivo anche durante il silenzio. “Segnale ricevuto” significa che il tap ha ricevuto campioni non nulli durante questa sessione; non è una misura acustica. Il piccolo indicatore mostra il picco di uscita campionato ogni secondo e può perdere suoni brevi.

## Preferenze e diagnostica

Preferenze locali per bundle ID: `~/Library/Application Support/AudioSplit X/routes.json`.
Diagnostica aggiornata: `~/Library/Logs/AudioSplit X/status.txt`.
Nessuna registrazione audio viene salvata o inviata. Le preferenze ricordano anche le app non attive e l’UID del dispositivo. Un dispositivo scollegato interrompe il percorso e ripristina l’audio originale, che può quindi uscire dall’uscita di sistema. Ricollegandolo, la preferenza viene nuovamente applicata.

Il controllo delle variazioni avviene ogni secondo. Il sistema raggruppa helper e processi nelle app proprietarie; il routing del browser vale per l’app, non per la singola scheda. Un nuovo processo audio può richiedere un breve riavvio del percorso.

## Limiti di questa versione

Motore sperimentale stereo/mono Float32, senza un convertitore di frequenza proprio: se tap e uscita presentano frequenze diverse, il percorso viene rifiutato invece di reinterpretare i campioni. Non modifica frequenze o uscita predefinita del sistema.

Se una riproduzione attiva non produce alcun segnale rilevato per 15 secondi iniziali, il percorso viene fermato. Il silenzio non dimostra da solo un problema di permesso: controllare contenuto, app e permessi prima di Riprova. Il controllo non garantisce il recupero da ogni blocco del driver dopo che il segnale è già stato ricevuto.

Non verificati: DAW con driver esclusivi/hog mode, contenuti protetti, Bluetooth/AirPlay, sleep/wake, riconnessioni fisiche, molteplici uscite hardware multicanale e sincronizzazione labiale. Nessuna promessa di compatibilità universale. Una DAW può scegliere direttamente il proprio dispositivo e non passare dal percorso di sistema.

Build locale con firma ad hoc, non notarizzata per distribuzione su altri Mac. Una ricompilazione con firma ad hoc può richiedere nuovamente il permesso audio. Per sviluppo continuativo è preferibile una firma stabile Apple Development autorizzata dall’utente.

## Compilazione

Aprire Package.swift in Xcode oppure eseguire:

```
swift test
./build.sh /percorso/destinazione
```

Il pacchetto non scarica dipendenze. `build.sh` usa firma ad hoc per default; `AUDIOSPLIT_SIGN_IDENTITY` permette una diversa identità già presente nel portachiavi. Una build Intel richiede compilazione sul relativo target; quella consegnata è arm64.

## Origine del motore

Quattro file del motore e i test di raggruppamento derivano da [SoundRouter](https://github.com/dws741119/SoundRouter), commit `ae42d470a28ea864a5420f4c8917f19007dca7f3`, licenza MIT, copyright Daniel Tien. La licenza integrale è inclusa in Packaging e nelle risorse dell’app.

AudioSplit X aggiunge interfaccia, gestione e salvataggio dei percorsi, sospensione/uscita, diagnostica e controllo del segnale. Il motore derivato usa un namespace proprio, mute solo durante la lettura del tap, accesso serializzato ai parametri del callback, controlli sui formati e sui buffer corti. Non riutilizza la configurazione SoundRouter.

## Licenza

MIT. Vedi LICENSE e THIRD_PARTY_NOTICES.md per le attribuzioni del codice derivato.
