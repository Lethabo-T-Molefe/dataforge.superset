# DataForge Superset

Apache Superset 6.1, configured as DataForge's dashboard, Explore and SQL Lab surface. It is deployed on its
own and connected to the DataForge API ([`dataforge.backend`](https://github.com/Lethabo-T-Molefe/dataforge.backend))
through settings: nothing here imports the API's code.

What this repo adds to stock Superset:

- **Single sign-on from DataForge** (`dataforge_superset/sso.py`). Members never get a Superset password. The
  API issues a two-minute, single-use token signed with `SSO_SHARED_SECRET`; Superset signs them in with roles
  mapped from their DataForge role. Auditors are refused.
- **The DataForge look** (`dataforge_superset/theme.py`): colours, fonts, logo, chart palettes. Dark mode and
  theme switching are off.
- **Locked-down defaults** (`superset_config.py`): no self-registration, no SQL templating, no uploads,
  read-only SQL Lab with row and time caps, embedding allowed only from the DataForge web app.
- **`bootstrap.py`**: migrates Superset's database and creates the service account and roles DataForge uses.
  It is safe to run on every start, and the container does.

Superset reads the warehouse through `dataforge_bi`, a read-only database login that only sees approved
tables. The DataForge API creates that login and registers the warehouse, datasets, shared metrics and row
policies in Superset (`dataforge superset-sync`); you do not add the database by hand.

## Settings

Copy `.env.example` to `.env` for local runs; on a host, set the same names as environment variables.

| Setting | What it is |
| --- | --- |
| `SUPERSET_METADATA_URL` | Superset's own database (users, dashboards, charts). Use a separate database, not DataForge's. On Supabase, create a database named `superset` rather than using `postgres`, whose `public` schema the Supabase data API can read. |
| `SUPERSET_SECRET_KEY` | Signs Superset's sessions and encrypts stored connections. Keep it: changing it makes stored connections unreadable. |
| `SUPERSET_GUEST_TOKEN_SECRET` | Signs guest tokens for embedded dashboards. |
| `SUPERSET_ADMIN_USER`, `SUPERSET_ADMIN_PASSWORD` | The service account the API uses. **Must equal the API's settings of the same names.** |
| `SSO_SHARED_SECRET` | **Must equal the API's `SSO_SHARED_SECRET`.** |
| `DATAFORGE_JWT_ISSUER` | Must equal the API's `JWT_ISSUER` (`dataforge` by default). |
| `DATAFORGE_FRONTEND_ORIGINS` | The web app's address(es), comma-separated. Only these may embed Superset. |
| `SUPERSET_FORCE_HTTPS` | `true` when served over HTTPS behind a proxy (any real deployment). |
| `GUNICORN_WORKERS` | Container only. Each worker holds about 400 MB; the default is 2. |
| `PORT` | Container only. The port to listen on (default 8088; Render sets it). |

## Connecting it to the DataForge API

In the **API's** settings:

| API setting | Value |
| --- | --- |
| `SUPERSET_URL` | Where the API reaches Superset. On Render, the service's internal address. |
| `SUPERSET_PUBLIC_URL` | Where browsers reach Superset, if different from `SUPERSET_URL`. |
| `SUPERSET_ADMIN_USER`, `SUPERSET_ADMIN_PASSWORD` | The same values as here. |
| `SSO_SHARED_SECRET` | The same value as here. |
| `BI_DB_PASSWORD` | The password of the read-only warehouse login the API creates. |

Then run `dataforge superset-sync` once on the API. After that the API keeps Superset in step whenever a
dataset is approved, cleaned, rejected or erased, and when a metric or row policy changes.

## Running locally

Python 3.11 and [uv](https://docs.astral.sh/uv/). On Linux and macOS use `.venv/bin/python`.

```bash
uv venv --python 3.11 .venv
uv pip install --python .venv/Scripts/python.exe -r requirements.txt -c constraints-6.1.0.txt
cp .env.example .env                    # fill in the secrets
.venv/Scripts/python bootstrap.py       # database, service account, roles
.venv/Scripts/python run.py             # http://localhost:8088
```

## Deploying on Render

`render.yaml` describes the service: a Docker web service in Frankfurt on the 2 GB plan, with a health check
at `/health`. In Render choose **New > Blueprint**, pick this repo, and fill in the four values it asks for
(`SUPERSET_METADATA_URL`, `SUPERSET_ADMIN_PASSWORD`, `SSO_SHARED_SECRET`, `DATAFORGE_FRONTEND_ORIGINS`).
The two Superset secrets are generated for you.

The container runs `bootstrap.py` and then gunicorn. The first start takes several minutes while Superset's
database is created and its permissions are synced. Later starts, including each time a sleeping service
wakes, skip that work unless a migration ran (set `SUPERSET_BOOTSTRAP=full` to force it). Deploys wait for
this repo's GitHub checks to pass. On an instance with 512 MB of memory, set `GUNICORN_WORKERS=1`.

Give the service a subdomain of the same domain as the web app (for example `superset.yourdomain.com`), so
sign-in and embedded dashboards work without third-party cookies.

## Checks

```bash
uvx ruff check . && uvx ruff format --check .
docker build -t dataforge-superset .
```

GitHub Actions runs both on every push (`.github/workflows/ci.yml`).
