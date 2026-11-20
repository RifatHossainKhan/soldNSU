import hmac
import math
import os
import re
import secrets
import sys
import uuid
from functools import wraps

import pymysql
import pymysql.cursors
from flask import (Flask, abort, flash, g, redirect, render_template, request,
                   session, url_for)
from werkzeug.security import check_password_hash, generate_password_hash
from pymysql.constants import FIELD_TYPE
from pymysql.converters import conversions

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "static", "uploads")
ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}

# The two segments from the sketch
SEGMENTS = {
    "university": "University Educational Product",
    "universal": "Universal Product",
}
CATEGORIES = ["Books", "Electronics", "Stationery", "Furniture", "Clothing",
              "Lab Equipment", "Bikes & Transport", "Other"]

app = Flask(__name__)


def _secret_key():
    """Use SECRET_KEY from the environment, else a random key saved next to the app.
    (A fixed, public default key would let anyone forge a login cookie, even the admin's.)"""
    key = os.environ.get("SECRET_KEY")
    if key:
        return key
    path = os.path.join(BASE_DIR, ".secret_key")
    try:
        with open(path) as f:
            key = f.read().strip()
        if key:
            return key
    except OSError:
        pass
    key = secrets.token_hex(32)
    try:
        with open(path, "w") as f:
            f.write(key)
    except OSError:
        pass  # read-only folder: key lasts until restart
    return key


app.config["SECRET_KEY"] = _secret_key()
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024  # 5 MB uploads
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ---------------------------------------------------------------- database (MySQL)
# Connection settings. The defaults match XAMPP (user root, no password).
# MAMP: set MYSQL_PORT=8889 and MYSQL_PASSWORD=root.
MYSQL = {
    "host": os.environ.get("MYSQL_HOST", "127.0.0.1"),
    "port": int(os.environ.get("MYSQL_PORT", "3306")),
    "user": os.environ.get("MYSQL_USER", "root"),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
}
MYSQL_DB = os.environ.get("MYSQL_DB", "soldnsu")

# Return DATETIME columns as plain "YYYY-MM-DD HH:MM:SS" text (templates print and slice them).
_conv = conversions.copy()
_conv[FIELD_TYPE.DATETIME] = lambda value: value
_conv[FIELD_TYPE.TIMESTAMP] = lambda value: value


class Row(dict):
    """One result row: row["name"], row.name (in templates) and row[0] all work."""

    def __getitem__(self, key):
        if isinstance(key, int):
            return list(self.values())[key]
        return dict.__getitem__(self, key)


class RowCursor(pymysql.cursors.DictCursor):
    dict_type = Row


class DB:
    """Thin wrapper so the code can use db.execute(sql, args) with ? placeholders."""

    def __init__(self, conn):
        self.conn = conn

    def execute(self, sql, args=()):
        cur = self.conn.cursor()
        cur.execute(sql.replace("%", "%%").replace("?", "%s"), args)
        return cur

    def commit(self):
        self.conn.commit()

    def close(self):
        self.conn.close()


def open_db(with_database=True):
    conn = pymysql.connect(
        **MYSQL,
        database=MYSQL_DB if with_database else None,
        charset="utf8mb4",
        cursorclass=RowCursor,
        conv=_conv,
        autocommit=False,
    )
    return DB(conn)


def get_db():
    if "db" not in g:
        g.db = open_db()
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


TABLES = [
    """CREATE TABLE IF NOT EXISTS users(
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_admin TINYINT(1) NOT NULL DEFAULT 0,
    is_banned TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""",
    """CREATE TABLE IF NOT EXISTS posts(
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    price DOUBLE NOT NULL,
    category VARCHAR(60) NOT NULL,
    segment VARCHAR(20) NOT NULL,
    photo VARCHAR(255) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    sold TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""",
    """CREATE TABLE IF NOT EXISTS messages(
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    buyer_id INT NOT NULL,
    sender_id INT NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (buyer_id) REFERENCES users(id),
    FOREIGN KEY (sender_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""",
    """CREATE TABLE IF NOT EXISTS universal_chat(
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    body TEXT NOT NULL,
    approved TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""",
    """CREATE TABLE IF NOT EXISTS cards(
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(40) NOT NULL,
    url VARCHAR(500) NOT NULL,
    image VARCHAR(255) NULL,
    `position` INT NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4""",
]


def init_db():
    try:
        _init_db()
    except pymysql.err.OperationalError as e:
        sys.exit(
            f"\n[SoldNSU] Cannot connect to MySQL at {MYSQL['host']}:{MYSQL['port']} "
            f"as '{MYSQL['user']}': {e}\n"
            "  1) Start MySQL (XAMPP/MAMP control panel).\n"
            "  2) Check MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD "
            "(MAMP: MYSQL_PORT=8889 MYSQL_PASSWORD=root).\n")


def _init_db():
    # 1) create the database itself if it does not exist yet
    db = open_db(with_database=False)
    db.execute(f"CREATE DATABASE IF NOT EXISTS `{MYSQL_DB}` CHARACTER SET utf8mb4")
    db.close()
    # 2) create the tables (does nothing if they already exist)
    db = open_db()
    for ddl in TABLES:
        db.execute(ddl)
    admin_email = os.environ.get("ADMIN_EMAIL", "admin@soldnsu.local")
    admin_pass = os.environ.get("ADMIN_PASSWORD", "admin123")
    if not db.execute("SELECT 1 FROM users WHERE is_admin=1").fetchone():
        db.execute(
            "INSERT INTO users(name,email,password_hash,is_admin) VALUES(?,?,?,1)",
            ("Admin", admin_email, generate_password_hash(admin_pass)))
        db.commit()
        print(f"[SoldNSU] Admin created: {admin_email} / {admin_pass}  (change it!)")
    db.close()


# ---------------------------------------------------------------- auth
@app.before_request
def load_user():
    g.user = None
    if request.endpoint == "static":
        return
    uid = session.get("uid")
    if uid:
        user = get_db().execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
        if user and not user["is_banned"]:
            g.user = user
        else:
            session.clear()


def login_required(view):
    @wraps(view)
    def wrapped(*a, **kw):
        if g.user is None:
            flash("Please log in first.", "warn")
            return redirect(url_for("login", next=request.path))
        return view(*a, **kw)
    return wrapped


def admin_required(view):
    @wraps(view)
    def wrapped(*a, **kw):
        if g.user is None or not g.user["is_admin"]:
            abort(403)
        return view(*a, **kw)
    return wrapped


def csrf_token():
    if "csrf" not in session:
        session["csrf"] = uuid.uuid4().hex
    return session["csrf"]


app.jinja_env.globals["csrf_token"] = csrf_token
app.jinja_env.globals["SEGMENTS"] = SEGMENTS


@app.before_request
def check_csrf():
    if request.method == "POST":
        sent = request.form.get("csrf", "")
        good = session.get("csrf", "")
        # both must exist: two missing tokens must NOT count as "equal"
        if not sent or not good or not hmac.compare_digest(sent, good):
            abort(400, "Invalid form token. Reload the page and try again.")


def allowed_file(name):
    return "." in name and name.rsplit(".", 1)[1].lower() in ALLOWED_EXT


def sniff_image(head):
    """Return the real image type from the first bytes, or None if it is not an image."""
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if head.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "gif"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    return None


def save_photo(file):
    if not file or not file.filename:
        return None
    if not allowed_file(file.filename):
        raise ValueError("Photo must be png, jpg, jpeg, gif or webp.")
    head = file.stream.read(16)
    file.stream.seek(0)
    kind = sniff_image(head)
    if kind is None:
        raise ValueError("That file is not a real image.")
    name = f"{uuid.uuid4().hex}.{kind}"   # extension comes from the content, not the user
    file.save(os.path.join(UPLOAD_DIR, name))
    return name


def parse_price(raw):
    """Valid price or -1. Rejects nan/inf (they crash MySQL) and absurd values."""
    try:
        price = float(raw)
    except (TypeError, ValueError):
        return -1
    return price if math.isfinite(price) and 0 <= price <= 100_000_000 else -1


def like_escape(text):
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


@app.errorhandler(400)
@app.errorhandler(403)
@app.errorhandler(404)
@app.errorhandler(413)
def friendly_error(e):
    msg = {413: "That upload is too large (max 5 MB).",
           404: "We could not find that page.",
           403: "You are not allowed to open this page."}.get(e.code, e.description)
    return render_template("error.html", code=e.code, message=msg), e.code


def delete_photo(name):
    if name:
        try:
            os.remove(os.path.join(UPLOAD_DIR, name))
        except OSError:
            pass


# ---------------------------------------------------------------- public pages
@app.route("/")
def home():
    segment = request.args.get("segment", "")
    category = request.args.get("category", "")
    q = request.args.get("q", "").strip()
    sql = ("SELECT p.*, u.name AS owner_name FROM posts p JOIN users u ON u.id=p.owner_id "
           "WHERE p.status='approved'")
    args = []
    if segment in SEGMENTS:
        sql += " AND p.segment=?"
        args.append(segment)
    if category in CATEGORIES:
        sql += " AND p.category=?"
        args.append(category)
    if q:
        sql += " AND (p.title LIKE ? OR p.description LIKE ?)"
        like = f"%{like_escape(q)}%"
        args += [like, like]
    sql += " ORDER BY p.id DESC"
    db = get_db()
    posts = db.execute(sql, args).fetchall()
    cards = db.execute("SELECT * FROM cards WHERE active=1 ORDER BY `position`, id").fetchall()
    return render_template("home.html", posts=posts, segment=segment,
                           category=category, q=q, categories=CATEGORIES, cards=cards)


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name = request.form["name"].strip()[:255]
        email = request.form["email"].strip().lower()[:190]
        pw = request.form["password"]
        if not name or not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email) or len(pw) < 6:
            flash("Fill all fields with a valid email; password needs 6+ characters.", "error")
        else:
            try:
                db = get_db()
                db.execute("INSERT INTO users(name,email,password_hash) VALUES(?,?,?)",
                           (name, email, generate_password_hash(pw)))
                db.commit()
                flash("Account created. Please log in.", "ok")
                return redirect(url_for("login"))
            except pymysql.IntegrityError:
                flash("That email is already registered.", "error")
    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form["email"].strip().lower()[:190]
        user = get_db().execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
        if user and check_password_hash(user["password_hash"], request.form["password"]):
            if user["is_banned"]:
                flash("This account has been suspended.", "error")
            else:
                session.clear()
                session["uid"] = user["id"]
                nxt = request.args.get("next", "")
                if not nxt.startswith("/") or nxt.startswith("//") or "\\" in nxt:
                    nxt = url_for("admin_dashboard" if user["is_admin"] else "home")
                return redirect(nxt)
        else:
            flash("Wrong email or password.", "error")
    return render_template("login.html")


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return redirect(url_for("home"))


# ---------------------------------------------------------------- sell / buy
@app.route("/sell", methods=["GET", "POST"])
@login_required
def sell():
    if request.method == "POST":
        title = request.form["title"].strip()[:255]
        desc = request.form["description"].strip()
        category = request.form["category"]
        segment = request.form["segment"]
        price = parse_price(request.form["price"])
        if not title or price < 0 or category not in CATEGORIES or segment not in SEGMENTS:
            flash("Please enter a title, a valid price, category and segment.", "error")
            return render_template("sell.html", categories=CATEGORIES, form=request.form)
        try:
            photo = save_photo(request.files.get("photo"))
        except ValueError as e:
            flash(str(e), "error")
            return render_template("sell.html", categories=CATEGORIES, form=request.form)
        db = get_db()
        db.execute("INSERT INTO posts(owner_id,title,description,price,category,segment,photo) "
                   "VALUES(?,?,?,?,?,?,?)",
                   (g.user["id"], title, desc, price, category, segment, photo))
        db.commit()
        flash("Post submitted! It will appear once an admin approves it.", "ok")
        return redirect(url_for("my_posts"))
    return render_template("sell.html", categories=CATEGORIES, form={})


@app.route("/my-posts")
@login_required
def my_posts():
    posts = get_db().execute("SELECT * FROM posts WHERE owner_id=? ORDER BY id DESC",
                             (g.user["id"],)).fetchall()
    return render_template("my_posts.html", posts=posts)


@app.route("/post/<int:post_id>/sold", methods=["POST"])
@login_required
def toggle_sold(post_id):
    db = get_db()
    post = db.execute("SELECT * FROM posts WHERE id=?", (post_id,)).fetchone()
    if not post or post["owner_id"] != g.user["id"]:
        abort(403)
    db.execute("UPDATE posts SET sold=1-sold WHERE id=?", (post_id,))
    db.commit()
    return redirect(url_for("my_posts"))


@app.route("/post/<int:post_id>")
def post_detail(post_id):
    post = get_db().execute(
        "SELECT p.*, u.name AS owner_name FROM posts p JOIN users u ON u.id=p.owner_id "
        "WHERE p.id=?", (post_id,)).fetchone()
    if not post:
        abort(404)
    is_owner = g.user and g.user["id"] == post["owner_id"]
    is_admin = g.user and g.user["is_admin"]
    if post["status"] != "approved" and not (is_owner or is_admin):
        abort(404)
    return render_template("post.html", post=post, categories=CATEGORIES)


# ---------------------------------------------------------------- chat with owner
def _thread(post_id, buyer_id):
    return get_db().execute(
        "SELECT m.*, u.name AS sender_name FROM messages m JOIN users u ON u.id=m.sender_id "
        "WHERE m.post_id=? AND m.buyer_id=? ORDER BY m.id", (post_id, buyer_id)).fetchall()


@app.route("/chat/<int:post_id>", methods=["GET", "POST"])
@app.route("/chat/<int:post_id>/<int:buyer_id>", methods=["GET", "POST"])
@login_required
def chat(post_id, buyer_id=None):
    db = get_db()
    post = db.execute("SELECT p.*, u.name AS owner_name FROM posts p "
                      "JOIN users u ON u.id=p.owner_id WHERE p.id=?", (post_id,)).fetchone()
    if not post or post["status"] != "approved":
        abort(404)
    is_owner = g.user["id"] == post["owner_id"]
    if is_owner:
        if buyer_id is None:  # owner sees the list of buyers who wrote
            buyers = db.execute(
                "SELECT DISTINCT u.id, u.name FROM messages m JOIN users u ON u.id=m.buyer_id "
                "WHERE m.post_id=?", (post_id,)).fetchall()
            return render_template("chat_list.html", post=post, buyers=buyers)
    else:
        buyer_id = g.user["id"]
    buyer = db.execute("SELECT * FROM users WHERE id=?", (buyer_id,)).fetchone()
    if not buyer:
        abort(404)
    if request.method == "POST":
        body = request.form["body"].strip()
        if body:
            db.execute("INSERT INTO messages(post_id,buyer_id,sender_id,body) VALUES(?,?,?,?)",
                       (post_id, buyer_id, g.user["id"], body[:1000]))
            db.commit()
        return redirect(request.path)
    return render_template("chat.html", post=post, buyer=buyer, messages=_thread(post_id, buyer_id),
                           is_owner=is_owner)


@app.route("/inbox")
@login_required
def inbox():
    db = get_db()
    as_buyer = db.execute(
        "SELECT DISTINCT p.id, p.title, u.name AS owner_name FROM messages m "
        "JOIN posts p ON p.id=m.post_id JOIN users u ON u.id=p.owner_id "
        "WHERE m.buyer_id=? AND p.owner_id!=?", (g.user["id"], g.user["id"])).fetchall()
    as_owner = db.execute(
        "SELECT p.id, p.title, COUNT(DISTINCT m.buyer_id) AS buyers FROM posts p "
        "JOIN messages m ON m.post_id=p.id WHERE p.owner_id=? GROUP BY p.id, p.title", (g.user["id"],)).fetchall()
    return render_template("inbox.html", as_buyer=as_buyer, as_owner=as_owner)


# ---------------------------------------------------------------- universal chatbox
@app.route("/universal-chat", methods=["GET", "POST"])
@login_required
def universal_chat():
    db = get_db()
    if request.method == "POST":
        body = request.form["body"].strip()
        if body:
            db.execute("INSERT INTO universal_chat(user_id,body) VALUES(?,?)",
                       (g.user["id"], body[:500]))
            db.commit()
            flash("Message sent. It shows to everyone after admin approval.", "ok")
        return redirect(url_for("universal_chat"))
    msgs = db.execute(
        "SELECT c.*, u.name FROM universal_chat c JOIN users u ON u.id=c.user_id "
        "WHERE c.approved=1 OR c.user_id=? ORDER BY c.id DESC LIMIT 100", (g.user["id"],)).fetchall()
    return render_template("universal_chat.html", msgs=reversed(msgs))


# ---------------------------------------------------------------- admin
@app.route("/admin")
@admin_required
def admin_dashboard():
    db = get_db()
    stats = {
        "users": db.execute("SELECT COUNT(*) FROM users WHERE is_admin=0").fetchone()[0],
        "posts": db.execute("SELECT COUNT(*) FROM posts").fetchone()[0],
        "pending": db.execute("SELECT COUNT(*) FROM posts WHERE status='pending'").fetchone()[0],
        "approved": db.execute("SELECT COUNT(*) FROM posts WHERE status='approved'").fetchone()[0],
        "university": db.execute("SELECT COUNT(*) FROM posts WHERE segment='university'").fetchone()[0],
        "universal": db.execute("SELECT COUNT(*) FROM posts WHERE segment='universal'").fetchone()[0],
        "chat_pending": db.execute("SELECT COUNT(*) FROM universal_chat WHERE approved=0").fetchone()[0],
    }
    return render_template("admin/dashboard.html", stats=stats)


@app.route("/admin/posts")
@admin_required
def admin_posts():
    posts = get_db().execute(
        "SELECT p.*, u.name AS owner_name FROM posts p JOIN users u ON u.id=p.owner_id "
        "ORDER BY (p.status='pending') DESC, p.id DESC").fetchall()
    return render_template("admin/posts.html", posts=posts)


@app.route("/admin/posts/<int:post_id>/approve", methods=["POST"])
@admin_required
def admin_approve_post(post_id):
    db = get_db()
    db.execute("UPDATE posts SET status='approved' WHERE id=?", (post_id,))
    db.commit()
    flash("Post approved.", "ok")
    return redirect(url_for("admin_posts"))


@app.route("/admin/posts/<int:post_id>/segment", methods=["POST"])
@admin_required
def admin_edit_segment(post_id):
    segment = request.form["segment"]
    if segment not in SEGMENTS:
        abort(400)
    db = get_db()
    db.execute("UPDATE posts SET segment=? WHERE id=?", (segment, post_id))
    db.commit()
    flash("Segment updated.", "ok")
    return redirect(url_for("admin_posts"))


@app.route("/admin/posts/<int:post_id>/delete", methods=["POST"])
@admin_required
def admin_delete_post(post_id):
    db = get_db()
    post = db.execute("SELECT photo FROM posts WHERE id=?", (post_id,)).fetchone()
    if post:
        delete_photo(post["photo"])
        db.execute("DELETE FROM messages WHERE post_id=?", (post_id,))
        db.execute("DELETE FROM posts WHERE id=?", (post_id,))
        db.commit()
        flash("Post deleted.", "ok")
    return redirect(url_for("admin_posts"))


@app.route("/admin/posts/<int:post_id>/edit", methods=["GET", "POST"])
@admin_required
def admin_edit_post(post_id):
    db = get_db()
    post = db.execute("SELECT * FROM posts WHERE id=?", (post_id,)).fetchone()
    if not post:
        abort(404)
    if request.method == "POST":
        price = parse_price(request.form["price"])
        category, segment = request.form["category"], request.form["segment"]
        title = request.form["title"].strip()[:255]
        if not title or price < 0 or category not in CATEGORIES or segment not in SEGMENTS:
            flash("Invalid values.", "error")
        else:
            db.execute("UPDATE posts SET title=?, description=?, price=?, category=?, segment=? "
                       "WHERE id=?", (title, request.form["description"].strip(), price,
                                      category, segment, post_id))
            db.commit()
            flash("Post updated.", "ok")
            return redirect(url_for("admin_posts"))
    return render_template("admin/edit_post.html", post=post, categories=CATEGORIES)


@app.route("/admin/users")
@admin_required
def admin_users():
    users = get_db().execute(
        "SELECT u.*, (SELECT COUNT(*) FROM posts WHERE owner_id=u.id) AS post_count "
        "FROM users u ORDER BY u.id").fetchall()
    return render_template("admin/users.html", users=users)


@app.route("/admin/users/<int:user_id>/ban", methods=["POST"])
@admin_required
def admin_ban_user(user_id):
    if user_id == g.user["id"]:
        flash("You cannot suspend yourself.", "error")
    else:
        db = get_db()
        db.execute("UPDATE users SET is_banned=1-is_banned WHERE id=? AND is_admin=0", (user_id,))
        db.commit()
    return redirect(url_for("admin_users"))


@app.route("/admin/chat")
@admin_required
def admin_chat():
    msgs = get_db().execute(
        "SELECT c.*, u.name FROM universal_chat c JOIN users u ON u.id=c.user_id "
        "ORDER BY c.approved ASC, c.id DESC").fetchall()
    return render_template("admin/chat.html", msgs=msgs)


@app.route("/admin/chat/<int:msg_id>/approve", methods=["POST"])
@admin_required
def admin_chat_approve(msg_id):
    db = get_db()
    db.execute("UPDATE universal_chat SET approved=1 WHERE id=?", (msg_id,))
    db.commit()
    return redirect(url_for("admin_chat"))


@app.route("/admin/chat/<int:msg_id>/delete", methods=["POST"])
@admin_required
def admin_chat_delete(msg_id):
    db = get_db()
    db.execute("DELETE FROM universal_chat WHERE id=?", (msg_id,))
    db.commit()
    return redirect(url_for("admin_chat"))


# ---------------------------------------------------------------- admin: play cards
def clean_url(raw):
    """Accept https://..., http://..., /internal/path or bare domain. Reject other schemes."""
    u = (raw or "").strip()
    if not u or len(u) > 500:
        return None
    if u.startswith("/") and not u.startswith("//"):
        return u
    low = u.lower()
    if low.startswith(("http://", "https://")):
        return u
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", u):  # javascript:, data:, mailto: ...
        return None
    return "https://" + u


@app.route("/admin/cards", methods=["GET", "POST"])
@admin_required
def admin_cards():
    db = get_db()
    if request.method == "POST":
        title = request.form["title"].strip()[:40]
        url = clean_url(request.form["url"])
        if not title or not url:
            flash("Enter a short title and a valid link (https://...).", "error")
            return redirect(url_for("admin_cards"))
        try:
            image = save_photo(request.files.get("image"))
        except ValueError as e:
            flash(str(e), "error")
            return redirect(url_for("admin_cards"))
        pos = db.execute("SELECT COALESCE(MAX(`position`),0)+1 FROM cards").fetchone()[0]
        db.execute("INSERT INTO cards(title,url,image,`position`) VALUES(?,?,?,?)",
                   (title, url, image, pos))
        db.commit()
        flash("Play card added.", "ok")
        return redirect(url_for("admin_cards"))
    cards = db.execute("SELECT * FROM cards ORDER BY `position`, id").fetchall()
    return render_template("admin/cards.html", cards=cards)


@app.route("/admin/cards/<int:card_id>/edit", methods=["GET", "POST"])
@admin_required
def admin_edit_card(card_id):
    db = get_db()
    card = db.execute("SELECT * FROM cards WHERE id=?", (card_id,)).fetchone()
    if not card:
        abort(404)
    if request.method == "POST":
        title = request.form["title"].strip()[:40]
        url = clean_url(request.form["url"])
        try:
            position = int(request.form.get("position", card["position"]))
        except ValueError:
            position = card["position"]
        if not title or not url:
            flash("Enter a short title and a valid link (https://...).", "error")
            return render_template("admin/edit_card.html", card=card)
        try:
            new_image = save_photo(request.files.get("image"))
        except ValueError as e:
            flash(str(e), "error")
            return render_template("admin/edit_card.html", card=card)
        image = card["image"]
        if new_image:                       # replaced with a new picture
            delete_photo(image)
            image = new_image
        elif request.form.get("remove_image"):   # picture removed
            delete_photo(image)
            image = None
        db.execute("UPDATE cards SET title=?, url=?, image=?, `position`=?, active=? WHERE id=?",
                   (title, url, image, position, 1 if request.form.get("active") else 0, card_id))
        db.commit()
        flash("Play card updated.", "ok")
        return redirect(url_for("admin_cards"))
    return render_template("admin/edit_card.html", card=card)


@app.route("/admin/cards/<int:card_id>/toggle", methods=["POST"])
@admin_required
def admin_toggle_card(card_id):
    db = get_db()
    db.execute("UPDATE cards SET active=1-active WHERE id=?", (card_id,))
    db.commit()
    return redirect(url_for("admin_cards"))


@app.route("/admin/cards/<int:card_id>/delete", methods=["POST"])
@admin_required
def admin_delete_card(card_id):
    db = get_db()
    card = db.execute("SELECT image FROM cards WHERE id=?", (card_id,)).fetchone()
    if card:
        delete_photo(card["image"])
        db.execute("DELETE FROM cards WHERE id=?", (card_id,))
        db.commit()
        flash("Play card deleted.", "ok")
    return redirect(url_for("admin_cards"))

init_db()

if __name__ == "__main__":
    app.run(debug=os.environ.get("FLASK_DEBUG") == "1", port=5000)
