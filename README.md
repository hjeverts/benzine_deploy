# benzine_deploy

Gecombineerde Docker Compose-stack (PostgreSQL + benzine_backend API +
benzine_frontend) en een `update.sh`-script om alles in één keer bij te
werken. Dit is bedoeld voor de Ubuntu-server; voor losse ontwikkeling kun je
nog steeds de `docker-compose.yml` in `benzine_backend` of `benzine_frontend`
los gebruiken.

## Verwachte layout

Clone alle drie de repo's naast elkaar in dezelfde map, bijvoorbeeld:

```
/opt/benzine/
  benzine_backend/
  benzine_frontend/
  benzine_deploy/   <- deze repo
```

(`benzine_android` hoort hier niet bij; die app draait niet in Docker.)

## Eerste keer opzetten

```bash
cd /opt/benzine
git clone git@github.com:hjeverts/benzine_backend.git
git clone git@github.com:hjeverts/benzine_frontend.git
git clone git@github.com:hjeverts/benzine_deploy.git
cd benzine_deploy
cp .env.example .env
# vul POSTGRES_PASSWORD en JWT_KEY in .env in (bv. openssl rand -base64 48)
./update.sh
```

Na de eerste keer opstarten:
- Frontend: http://<server>:8081 (poort instelbaar via `FRONTEND_PORT` in `.env`)
- API: http://<server>:5080/api (poort instelbaar via `API_PORT`)
- Maak via de frontend (`/register`) je eerste account aan.
- Wil je de oude Dash/parquet-data migreren? Zie
  `benzine_backend/scripts/README.md` (draai dat script pas **nadat** je een
  account hebt aangemaakt via de frontend, zodat de voertuigen aan het juiste
  account gekoppeld kunnen worden).

## Bijwerken naar de laatste versie

```bash
cd /opt/benzine/benzine_deploy
./update.sh
```

Dit script:
1. Haalt de laatste commits op voor `benzine_backend` en `benzine_frontend`
   (`git pull --ff-only` op de huidige branch).
2. Bouwt de Docker-images opnieuw.
3. Herstart de stack (`docker compose up -d`); de API past bij het opstarten
   automatisch eventuele nieuwe EF Core-migraties toe.
4. Ruimt oude, ongebruikte images op.
5. Controleert of de API bereikbaar is via `/api/health`.

Opties:
- `./update.sh --no-pull` — bouw/herstart opnieuw zonder eerst te pullen
  (handig als je lokaal net iets hebt aangepast).
- `./update.sh --logs` — toon na afloop de laatste logregels van alle services.

## Database rechtstreeks benaderen

PostgreSQL is alleen lokaal bereikbaar op poort 5433 (`127.0.0.1:5433`), bv.
voor het migratiescript of `psql`:

```bash
psql "postgresql://benzine:<wachtwoord>@localhost:5433/benzine"
```
