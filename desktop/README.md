# RezervisiMe — Desktop administrativna aplikacija (Flutter)

Admin/frizer panel. Seminarski RS II, IB220008.

## Pokretanje na Windowsu

Pokreni backend prema korijenskom README-u. Potrebni su Flutter SDK s podrškom za Windows i Visual Studio s komponentom Desktop development with C++.

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5126/api
```

## Moduli (7.1–7.8)
- Dashboard: KPI, bar chart (rezervacije/dan), donut (statusi), nedavne, popularne
- Rezervacije: tabela, filteri po statusu, paginacija, audit kolona, potvrdi/odbij/zavrsi
- Sedmicni kalendar: termini po danima/satima, filter po frizeru, boje po statusu
- Usluge: CRUD, kategorija iz padajuce liste, aktivna/neaktivna
- Frizeri: lista + radno vrijeme po danima
- Verifikacija: saloni i frizeri po statusu, odobri/odbij uz razlog
- Referentni podaci: gradovi, kategorije i oznake recenzija (pretraga, paginacija i CRUD)
- Izvjestaji: 2 PDF izvjestaja (prihodi, popularne usluge) — generisi, sacuvaj, otvori

## Prijava
`admin` / `Test1234!`  ·  `desktop` / `Test1234!`
