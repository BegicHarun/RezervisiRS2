# RezervisiMe — Mobilna aplikacija (Flutter, klijent)

Klijentski dio platforme RezervisiMe. Seminarski rad RS II, IB220008.

## Pokretanje na Android emulatoru

Pokreni backend prema uputama u korijenskom README-u. API treba biti dostupan na hostu na portu 5126. Pokreni Android emulator, pa iz foldera mobilne aplikacije izvrši:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5126/api
```

Adresa '10.0.2.2' je pristup hostu iz Android emulatora. Za fizički uređaj koristi dostupnu HTTPS adresu API-ja. Za iOS simulator na istom računaru API adresu zadaj prema lokalnoj konfiguraciji.

## Ekrani (prate prijedlog iz dokumentacije)
- Prijava / registracija / reset lozinke putem e-maila
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
`mobile` / `Test1234!`
