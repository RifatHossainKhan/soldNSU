# SoldNSU — Campus Marketplace

**CSE311 / CSE311L — Database Management Systems · Team project**

SoldNSU is a buy-and-sell marketplace for NSU students. Members post things they no longer need (books, lab equipment, electronics, furniture…), chat privately with buyers, and talk in a moderated public chat room. Admins approve or reject posts, manage users and see reports built from SQL views.

Built with **Flask (Python)** and **MySQL / MariaDB**.

## Team

| Name | Student ID |
|---|---|
| H M Imrul Kayes Emon | 2232979642 |
| Rebecca Sultana Asha | 2312640642 |
| Marsia Tabassum Zidni | 2513804042 |
| MD Rifat Hossain Khan | 2233150642 |

## Features

**Members**
- Register / log in (passwords hashed with scrypt)
- Post a product with photo, price, category and segment (*University Educational* or *Universal*)
- Browse by segment and category, keyword search
- Private chat with the seller of a post; inbox for buyers and sellers
- Mark own posts as sold
- Public "universal chat" (messages appear after admin approval)

**Admins**
- Dashboard with live counts
- Approve, reject, edit, re-segment or delete posts
- Suspend / restore users
- Moderate the universal chat
- Manage the home-page link cards
- **Reports** page: per-segment, per-category and per-seller statistics, and the post status history

## Database

Everything about the database is in [`database/`](database) and [`docs/database-design.md`](docs/database-design.md) (ER diagram, relational schema, normalization, constraints, indexes).

| File | Contents |
|---|---|
| `database/schema.sql` | 8 tables (3NF), lookup data, foreign keys, CHECK constraints, indexes, 4 views |
| `database/procedures_triggers.sql` | 4 triggers and 3 stored procedures |
| `database/seed.sql` | sample users, 25 products, chats, cards |
| `database/queries.sql` | 18 example queries: joins, GROUP BY / HAVING, subqueries, NOT EXISTS, window functions, UNION, views, procedures, a transaction, and constraint violations |
| `database/migrate_old_db.sql` | upgrades a database made by the first version (`soldnsu_mysql.sql`) |

## Run it locally (XAMPP / MySQL)

1. Start MySQL (XAMPP or MAMP control panel).
2. Import the database, either in phpMyAdmin (**Import** tab, files in this order) or with the command line:
   ```bash
   mysql -u root -p < database/schema.sql
   mysql -u root -p < database/procedures_triggers.sql
   mysql -u root -p < database/seed.sql
   ```
   Skipping this step is fine too: the app creates the tables, views, triggers and an admin account by itself on first start. Only the sample data needs `seed.sql`.
3. Install and run:
   ```bash
   python3 -m pip install -r requirements.txt
   python3 app.py
   ```
4. Open http://127.0.0.1:5000

Default connection: host `127.0.0.1`, port `3306`, user `root`, no password, database `soldnsu`. Change it with environment variables (MAMP: `MYSQL_PORT=8889`, `MYSQL_PASSWORD=root`).

**Demo logins (from `seed.sql`):**

| Role | E-mail | Password |
|---|---|---|
| Admin | admin@soldnsu.local | admin123 |
| Seller | seller@soldnsu.local | demo1234 |
| Buyer | buyer@soldnsu.local | demo1234 |

Change these before putting the site online.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `MYSQL_HOST` | 127.0.0.1 | database host |
| `MYSQL_PORT` | 3306 | database port (TiDB Cloud uses 4000) |
| `MYSQL_USER` | root | database user |
| `MYSQL_PASSWORD` | *(empty)* | database password |
| `MYSQL_DB` | soldnsu | database name |
| `MYSQL_SSL` | false | `true` for hosted databases such as TiDB Cloud |
| `SECRET_KEY` | random, saved in `.secret_key` | signs the login cookie |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` |  | admin created when no admin exists |
| `FLASK_DEBUG` | 0 | `1` for debug mode (local only) |

## Deploy online (Render + TiDB Cloud)

GitHub Pages can only host static files, so it cannot run this Flask + MySQL app. Use a Python host:

1. Create a MySQL-compatible database (e.g. TiDB Cloud) and import `database/schema.sql`, then `database/seed.sql` if you want sample data. TiDB does not support triggers or stored procedures; skip `procedures_triggers.sql` there. The app keeps working, only the status history on the Reports page stays empty.
2. On Render create a **Web Service** from this repository.
   - Build command: `pip install -r requirements.txt`
   - Start command: `gunicorn app:app`
3. Add the environment variables above (with `MYSQL_SSL=true`, a long random `SECRET_KEY` and a strong `ADMIN_PASSWORD`).

Uploaded photos are stored in `static/uploads/`; on Render's free plan they are lost on restart, so add a persistent disk or object storage before relying on uploads.

## Project structure

```
app.py                     Flask app: routes, auth, CSRF, DB access
database/                  schema, triggers & procedures, seed data, example queries, migration
docs/database-design.md    ER diagram, relational schema, normalization
templates/                 Jinja2 pages (templates/admin/ for the admin panel)
static/style.css           styles
static/uploads/            product photos
requirements.txt, Procfile deployment
```

## Security notes

- Passwords are hashed (scrypt), never stored in plain text
- Every form carries a CSRF token
- All SQL uses parameterised queries; LIKE wildcards in searches are escaped
- Uploaded files are checked by their content, renamed, and limited to 5 MB
- Login redirects only go to local paths
- Banned users are logged out on their next request
