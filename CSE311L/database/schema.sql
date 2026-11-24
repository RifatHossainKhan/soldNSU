-- =====================================================================
--  SoldNSU — database schema (MySQL 8 / MariaDB 10.4+ / TiDB)
--  CSE311 / CSE311L  Database Management Systems — team project
--
--  Run:   mysql -u root -p < database/schema.sql
--  The app also runs this file automatically on start-up, so every
--  statement here must be safe to run more than once (IF NOT EXISTS,
--  INSERT IGNORE, CREATE OR REPLACE).
--
--  Tables (3NF):
--    segments        lookup: the two market segments
--    categories      lookup: product categories
--    users           members and admins
--    posts           product listings (FK -> users, categories, segments)
--    messages        private buyer <-> seller chat about one post
--    universal_chat  public chat room, moderated by admins
--    cards           "play cards" (quick links) on the home page
--    post_status_log audit trail filled by a trigger (procedures_triggers.sql)
-- =====================================================================
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS `soldnsu` CHARACTER SET utf8mb4;
USE `soldnsu`;

-- ---------------------------------------------------------------- lookups
CREATE TABLE IF NOT EXISTS segments(
    code  VARCHAR(20)  NOT NULL PRIMARY KEY,
    label VARCHAR(80)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categories(
    id   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(60)  NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO segments(code, label) VALUES
    ('university', 'University Educational Product'),
    ('universal',  'Universal Product');

INSERT IGNORE INTO categories(id, name) VALUES
    (1, 'Books'), (2, 'Electronics'), (3, 'Stationery'), (4, 'Furniture'),
    (5, 'Clothing'), (6, 'Lab Equipment'), (7, 'Bikes & Transport'), (8, 'Other');

-- ---------------------------------------------------------------- users
CREATE TABLE IF NOT EXISTS users(
    id            INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    email         VARCHAR(190) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_admin      TINYINT(1)   NOT NULL DEFAULT 0,
    is_banned     TINYINT(1)   NOT NULL DEFAULT 0,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_users_admin  CHECK (is_admin  IN (0, 1)),
    CONSTRAINT chk_users_banned CHECK (is_banned IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- posts
-- category and segment reference the lookup tables by their unique
-- natural key, so the application can keep reading plain text values.
CREATE TABLE IF NOT EXISTS posts(
    id          INT            NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_id    INT            NOT NULL,
    title       VARCHAR(255)   NOT NULL,
    description TEXT           NOT NULL,
    price       DECIMAL(12, 2) NOT NULL,
    category    VARCHAR(60)    NOT NULL,
    segment     VARCHAR(20)    NOT NULL,
    photo       VARCHAR(255)   NULL,
    status      VARCHAR(20)    NOT NULL DEFAULT 'pending',
    sold        TINYINT(1)     NOT NULL DEFAULT 0,
    created_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_owner    FOREIGN KEY (owner_id) REFERENCES users(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_posts_category FOREIGN KEY (category) REFERENCES categories(name)
        ON UPDATE CASCADE,
    CONSTRAINT fk_posts_segment  FOREIGN KEY (segment)  REFERENCES segments(code)
        ON UPDATE CASCADE,
    CONSTRAINT chk_posts_price   CHECK (price >= 0),
    CONSTRAINT chk_posts_status  CHECK (status IN ('pending', 'approved', 'rejected')),
    CONSTRAINT chk_posts_sold    CHECK (sold IN (0, 1)),
    INDEX idx_posts_browse (status, segment, category),
    INDEX idx_posts_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- private chat
-- One conversation = (post_id, buyer_id). sender_id is either the buyer
-- or the owner of the post.
CREATE TABLE IF NOT EXISTS messages(
    id         INT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    post_id    INT      NOT NULL,
    buyer_id   INT      NOT NULL,
    sender_id  INT      NOT NULL,
    body       TEXT     NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_post   FOREIGN KEY (post_id)   REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_buyer  FOREIGN KEY (buyer_id)  REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_msg_thread (post_id, buyer_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- public chat
CREATE TABLE IF NOT EXISTS universal_chat(
    id         INT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id    INT        NOT NULL,
    body       TEXT       NOT NULL,
    approved   TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_uchat_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_uchat_approved CHECK (approved IN (0, 1)),
    INDEX idx_uchat_approved (approved, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- home-page cards
CREATE TABLE IF NOT EXISTS cards(
    id         INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title      VARCHAR(40)  NOT NULL,
    url        VARCHAR(500) NOT NULL,
    image      VARCHAR(255) NULL,
    `position` INT          NOT NULL DEFAULT 0,
    active     TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT chk_cards_active CHECK (active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- audit log
CREATE TABLE IF NOT EXISTS post_status_log(
    id         INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
    post_id    INT         NOT NULL,
    old_status VARCHAR(20) NULL,
    new_status VARCHAR(20) NOT NULL,
    old_sold   TINYINT(1)  NULL,
    new_sold   TINYINT(1)  NOT NULL,
    changed_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    INDEX idx_log_post (post_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
--  Views (used by the admin "Reports" page)
-- =====================================================================

-- Everything a visitor can buy right now.
CREATE OR REPLACE VIEW v_active_listings AS
SELECT p.id, p.title, p.price, p.category, s.label AS segment_label,
       p.segment, u.name AS seller, p.created_at
FROM posts p
JOIN users u    ON u.id = p.owner_id
JOIN segments s ON s.code = p.segment
WHERE p.status = 'approved' AND p.sold = 0;

-- Listings per category (LEFT JOIN keeps empty categories at 0).
CREATE OR REPLACE VIEW v_category_summary AS
SELECT c.name AS category,
       COUNT(p.id)                                         AS total_posts,
       COALESCE(SUM(p.status = 'approved'), 0)             AS approved_posts,
       COALESCE(SUM(p.sold = 1), 0)                        AS sold_posts,
       ROUND(AVG(CASE WHEN p.status = 'approved' THEN p.price END), 2) AS avg_price,
       MIN(CASE WHEN p.status = 'approved' THEN p.price END) AS min_price,
       MAX(CASE WHEN p.status = 'approved' THEN p.price END) AS max_price
FROM categories c
LEFT JOIN posts p ON p.category = c.name
GROUP BY c.id, c.name;

-- Activity of every non-admin member.
CREATE OR REPLACE VIEW v_seller_stats AS
SELECT u.id AS user_id, u.name, u.email,
       COUNT(p.id)                                                  AS total_posts,
       COALESCE(SUM(p.status = 'approved'), 0)                      AS approved_posts,
       COALESCE(SUM(p.sold = 1), 0)                                 AS sold_posts,
       COALESCE(SUM(CASE WHEN p.sold = 1 THEN p.price ELSE 0 END), 0) AS sold_value,
       (SELECT COUNT(DISTINCT m.post_id, m.buyer_id)
          FROM messages m JOIN posts p2 ON p2.id = m.post_id
         WHERE p2.owner_id = u.id)                                  AS buyer_threads
FROM users u
LEFT JOIN posts p ON p.owner_id = u.id
WHERE u.is_admin = 0
GROUP BY u.id, u.name, u.email;

-- Posts in each segment, split by status.
CREATE OR REPLACE VIEW v_segment_summary AS
SELECT s.code, s.label,
       COUNT(p.id)                              AS total_posts,
       COALESCE(SUM(p.status = 'pending'), 0)   AS pending_posts,
       COALESCE(SUM(p.status = 'approved'), 0)  AS approved_posts,
       COALESCE(SUM(p.status = 'rejected'), 0)  AS rejected_posts
FROM segments s
LEFT JOIN posts p ON p.segment = s.code
GROUP BY s.code, s.label;
