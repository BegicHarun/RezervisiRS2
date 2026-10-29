# RezervisiMe

Online platforma za rezervaciju frizerskih i beauty usluga.
Seminarski rad iz predmeta **Razvoj softvera II** (FIT) — student **Harun Begić, IB220008**.

Sistem se sastoji od tri dijela:
- **Backend REST API** (.NET 10, ASP.NET Core, EF Core, SQL Server) + **Worker** mikroservis (RabbitMQ, email notifikacije)
- **Desktop** aplikacija (Flutter) — administrativni panel
- **Mobilna** aplikacija (Flutter) — klijentska aplikacija

---

## Tehnologije

- .NET 10, ASP.NET Core, Entity Framework Core, SQL Server 2022
- JWT autentifikacija + role-based autorizacija (Administrator, Frizer, Klijent)
- RabbitMQ (mikroservis za notifikacije), MailKit (SMTP)
- Flutter (desktop + mobilni klijent)
- PayPal (sandbox) — plaćanje rezervacija
- Docker Compose — svi servisi u kontejnerima

---

## Pokretanje backenda (Docker)

Preduslov: instaliran Docker Desktop.

1. U root folderu projekta (gdje je `docker-compose.yml`) treba postojati `.env` fajl.
   Za pregled rada, otpakuj priloženi `.env-tajne.zip` (šifra je dostavljena na DLWMS)
   u isti folder i preimenuj u `.env`.

2. Pokreni sve servise jednom komandom:

   ```
   docker compose up --build
   ```

3. Nakon pokretanja:
   - API / Swagger: `http://localhost:5126/swagger`
   - RabbitMQ UI: `http://localhost:15672` (guest/guest)

   Baza se automatski kreira i puni početnim podacima (migracije + seed) pri pokretanju API-ja.
   SQL Server-u treba ~20-30 s da se digne; API ima retry pa sačeka bazu.

Za čist start iz nule (briše bazu):

```
docker compose down -v && docker compose up --build
```

---

## Pokretanje mobilne aplikacije (Android)

API adresa za Android emulator je `10.0.2.2` (standardna AVD adresa za host).

```
cd <mobilni-folder>
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5126/api
```

## Pokretanje desktop aplikacije (Windows)

API adresa za desktop je `localhost`.

```
cd <desktop-folder>
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5126/api
```

> API adresa je konfigurabilna preko `--dart-define=API_BASE_URL` (upute 3.3).
> Ako se ne zada, koristi se podrazumijevana vrijednost za lokalni razvoj.

---

## Korisnički podaci za pristup

| Kontekst | Korisničko ime | Lozinka |
|---|---|---|
| Administrator (desktop) | `admin` | `Test1234!` |
| Frizer (desktop) | `desktop` | `Test1234!` |
| Klijent (mobilni) | `mobile` | `Test1234!` |

Dodatni frizerski nalozi (za demo podatke): `frizer2` … `frizer6`, lozinka `Test1234!`.

---

## Dokumentacija sistema preporuke

Opis recommender sistema (content-based + popularity-based) nalazi se u fajlu
[`recommender-dokumentacija.md`](./recommender-dokumentacija.md).

---

## Napomene

- Konfiguracija (connection string, JWT, PayPal, SMTP) čita se iz `.env` fajla; ništa nije hardkodirano.
- Plaćanje koristi stvarno PayPal sandbox okruženje (nije simulirano), sa refund logikom.
- Email notifikacije: dok je `SMTP_HOST=smtp.example.com`, Worker radi u DEV režimu i samo logira email
  (vidljivo u `docker compose logs worker`). Za pravi email upiši stvarne SMTP podatke u `.env`.
