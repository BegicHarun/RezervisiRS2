# RezervisiMe — Mobilna aplikacija (Flutter, klijent)

Klijentski dio platforme RezervisiMe. Seminarski rad RS II, IB220008.

## Preduslovi
- Flutter SDK (3.5+), Xcode + iOS Simulator (macOS)
- Pokrenut backend (RezervisiMe.API) na `http://localhost:5001`

## Povezivanje na backend
Vidi `lib/services/config.dart`. Za iOS simulator `localhost` radi direktno.
Bitno: backend mora slusati HTTP (ne samo HTTPS) — provjeri port u konzoli
backenda i po potrebi ga uskladi u `config.dart`.

## Pokretanje
```bash
flutter pub get
open -a Simulator            # pokreni iOS simulator
flutter run
```

## Ekrani (prate prijedlog iz dokumentacije)
- Prijava / registracija
- Pocetna: preporuke (recommender), kategorije, lista salona
- Pretraga sa filterom po gradu
- Profil salona: usluge po kategorijama, recenzije, ocjena
- Rezervacija u koracima: frizer + datum + color-coded termini + sazetak
- Moje rezervacije (master-detail) + otkazivanje uz potvrdu i razlog
- Historija: statistika + zavrseni termini po mjesecima
- Recenzija: rating, brze oznake, komentar
- Obavijesti: grupisano po danima, procitano/neprocitano, auto-refresh (polling)
- Profil + odjava

## Test nalog
`mobile` / `Test1234!` (vec upisano na login ekranu)
