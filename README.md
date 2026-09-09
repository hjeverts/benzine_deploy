# vehictory_deploy

Gecombineerde Docker Compose-stack (PostgreSQL + vehictory_backend API +
vehictory_frontend) en een `update.sh`-script om alles in één keer bij te
werken. Dit is bedoeld voor de Ubuntu-server; voor losse ontwikkeling kun je
nog steeds de `docker-compose.yml` in `vehictory_backend` of `vehictory_frontend`
los gebruiken.

## Verwachte layout

Clone alle drie de repo's naast elkaar in dezelfde map, bijvoorbeeld:

```
/opt/vehictory/
  vehictory_backend/
  vehictory_frontend/
  vehictory_deploy/   <- deze repo
```

(`vehictory_android` hoort hier niet bij; die app draait niet in Docker.)

## Bestaande server migreren (benzine_deploy → vehictory_deploy)

Dit is geen greenfield-install: de app draaide al onder de naam `benzine_deploy`.
Docker Compose prefixt named volumes standaard met de mapnaam ("project name"),
dus je bestaande Postgres-data staat vermoedelijk in een volume genaamd
`benzine_deploy_postgres_data_benzine_pg18`. Als je de map zomaar hernoemt en
opnieuw `docker compose up` draait, maakt Compose een **nieuw, leeg** volume
(`vehictory_deploy_postgres_data_benzine_pg18`) — je data raakt niet kwijt,
maar de app lijkt leeg omdat de containers naar het verkeerde volume wijzen.

Doe dit in deze volgorde:

1. **Voordat je iets hernoemt**, controleer het echte volume-adres:
   ```bash
   docker volume ls | grep postgres_data_benzine_pg18
   ```
2. Zet in je (nieuwe) `.env` `COMPOSE_PROJECT_NAME` op precies het prefix dat
   je in stap 1 zag vóór `_postgres_data_benzine_pg18` (waarschijnlijk
   `benzine_deploy`, al staat dat al als default in `.env.example`).
3. Hernoem daarna pas de server-mappen (`benzine_backend` → `vehictory_backend`,
   enzovoort) en clone/pull de hernoemde repo's.
4. Draai `./update.sh` en controleer met `docker volume ls` dat er geen nieuw
   `vehictory_deploy_...`-volume is bijgekomen — je zou nog steeds hetzelfde
   `benzine_deploy_...`-volume moeten zien gekoppeld aan de `postgres`-container.
5. Bestaande ingelogde sessies worden ongeldig na deze update (de JWT-issuer/
   -audience zijn hernoemd); gebruikers moeten opnieuw inloggen. Dit is geen
   dataverlies.

## Eerste keer opzetten

```bash
cd /opt/vehictory
git clone git@github.com:hjeverts/vehictory_backend.git
git clone git@github.com:hjeverts/vehictory_frontend.git
git clone git@github.com:hjeverts/vehictory_deploy.git
cd vehictory_deploy
cp .env.example .env
# vul POSTGRES_PASSWORD en JWT_KEY in .env in (bv. openssl rand -base64 48)
./update.sh
```

Na de eerste keer opstarten:
- Frontend: http://<server>:8081 (poort instelbaar via `FRONTEND_PORT` in `.env`)
- API: http://<server>:5080/api (poort instelbaar via `API_PORT`)
- Maak via de frontend (`/register`) je eerste account aan.
- Wil je de oude Dash/parquet-data migreren? Zie
  `vehictory_backend/scripts/README.md` (draai dat script pas **nadat** je een
  account hebt aangemaakt via de frontend, zodat de voertuigen aan het juiste
  account gekoppeld kunnen worden).

## Bijwerken naar de laatste versie

```bash
cd /opt/vehictory/vehictory_deploy
./update.sh
```

Dit script:
1. Haalt de laatste commits op voor `vehictory_backend` en `vehictory_frontend`
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
