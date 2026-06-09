# Local PostgreSQL Development Database

This project uses Docker Compose to run PostgreSQL locally for `parkirboss-api`.
The Flutter app should continue calling the API, not the database directly.

## Start Database

Run from the repo root:

```bash
docker compose up -d
```

Check the database status:

```bash
docker compose ps
```

The `db` service should become `healthy`.

## API Configuration

`parkirboss-api/.env` points the FastAPI app to the local PostgreSQL container:

```env
DATABASE_URL=postgresql+psycopg2://parkirboss:parkirboss_dev_password@localhost:5432/parkirboss
```

Run the API from `parkirboss-api`:

```bash
python -m uvicorn main:app --reload
```

On startup, the API creates tables with SQLAlchemy and inserts baseline seed data.

## Stop Database

```bash
docker compose stop
```

## Reset Database Data

This deletes the PostgreSQL volume and all local database data:

```bash
docker compose down -v
docker compose up -d
```

## Connect With psql

```bash
docker compose exec db psql -U parkirboss -d parkirboss
```
