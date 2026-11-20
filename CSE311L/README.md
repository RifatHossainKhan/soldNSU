# SoldNSU

A campus marketplace built with Flask (Python), HTML and CSS. Data is stored in **MySQL**.

## 1. Start MySQL
Start MySQL from XAMPP or MAMP (or any MySQL / MariaDB server).

## 2. Import your data (first time only)
Open phpMyAdmin, choose **Import**, select `soldnsu_mysql.sql` and click **Go**.
This creates the `soldnsu` database with all tables and your existing data.
The file uses `INSERT IGNORE`, so it is safe to import even if the app already ran once
(no more "Duplicate entry" error) and safe to import twice.

Already imported an older copy and only want the 20 new sample products?
Import `products_20.sql` into the `soldnsu` database instead.

## 3. Run the site
```bash
python3 -m pip install -r requirements.txt
python3 app.py
```
Open http://127.0.0.1:5000

## MySQL connection settings
Defaults match XAMPP: host `127.0.0.1`, port `3306`, user `root`, empty password, database `soldnsu`.
Change them with environment variables:

```bash
# MAMP example
MYSQL_PORT=8889 MYSQL_PASSWORD=root python3 app.py
```
Available: `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB`.

## Admin login
Your imported admin account keeps its password. On an empty database the app creates
`admin@soldnsu.local` / `admin123` on first run. Change it. `SECRET_KEY` is optional: if you do not set one, the app creates a random one
in a `.secret_key` file next to `app.py` (keep that file private). To set your own:

```bash
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=strong-password SECRET_KEY=long-random-text python3 app.py
```

## Photos
Uploaded photos are files in `static/uploads/`. The database only stores their names, so keep that folder.

## Troubleshooting
- **"Cannot connect to MySQL"**: start MySQL in XAMPP/MAMP, then check the connection variables above.
- **`ModuleNotFoundError: pymysql`**: run `python3 -m pip install -r requirements.txt`.
- **Port 5000 busy on macOS**: AirPlay uses it; turn off AirPlay Receiver or change the port in `app.py`.

## Features
**Any user (one account to buy and sell)**: sell post with photo, price and category; buy and chat with the owner; two segments (University Educational Product, Universal Product).

**Admin**: approve, edit, delete posts and change their segment; dashboard; manage users (suspend / reinstate); approve or delete universal chat messages; manage the sliding play cards (title, link, picture, order, show/hide).

**Universal chatbox** for all users (messages go live after admin approval).
