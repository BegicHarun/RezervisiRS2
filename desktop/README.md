# RezervisiMe — Desktop administrativna aplikacija (Flutter)

Admin/frizer panel. Seminarski RS II, IB220008.

## Preduslovi
- Flutter SDK (3.5+) sa desktop podrskom
  - macOS: `flutter config --enable-macos-desktop`
  - Windows: `flutter config --enable-windows-desktop`
- Pokrenut backend na `http://localhost:5000` (sa fazom A: dashboard, reports, verify, working-hours)

## Povezivanje
Vidi `lib/services/config.dart`. Desktop vidi `localhost` direktno.
Provjeri HTTP port u konzoli backenda i po potrebi ga promijeni.

## Pokretanje
```bash
flutter pub get
flutter run -d macos      # ili: flutter run -d windows
```

## Moduli (7.1–7.8)
- Dashboard: KPI, bar chart (rezervacije/dan), donut (statusi), nedavne, popularne
- Rezervacije: tabela, filteri po statusu, paginacija, audit kolona, potvrdi/odbij/zavrsi
- Sedmicni kalendar: termini po danima/satima, filter po frizeru, boje po statusu
- Usluge: CRUD, kategorija iz padajuce liste, aktivna/neaktivna
- Frizeri: lista + radno vrijeme po danima
- Verifikacija: saloni i frizeri po statusu, odobri/odbij uz razlog
- Referentni podaci: gradovi i kategorije (CRUD, zasticeno brisanje u upotrebi)
- Izvjestaji: 2 PDF izvjestaja (prihodi, popularne usluge) — generisi, sacuvaj, otvori

## Prijava
`admin` / `Test1234!`  ·  `desktop` / `Test1234!`
