-- =====================================================================
--  Upgrade a database created by the FIRST version of SoldNSU
--  (soldnsu_mysql.sql) to the current schema. Run once:
--     mysql -u root -p soldnsu < database/schema.sql
--     mysql -u root -p soldnsu < database/migrate_old_db.sql
--  schema.sql adds the new tables and views; this file changes the
--  existing posts table. Fresh installs do NOT need this file.
-- =====================================================================
USE `soldnsu`;

-- money should never be a floating-point number
ALTER TABLE posts MODIFY price DECIMAL(12, 2) NOT NULL;

-- any category/segment text that is not in the lookup tables becomes 'Other' / 'universal'
UPDATE posts SET category = 'Other'     WHERE category NOT IN (SELECT name FROM categories);
UPDATE posts SET segment  = 'universal' WHERE segment  NOT IN (SELECT code FROM segments);

ALTER TABLE posts
    ADD CONSTRAINT fk_posts_category FOREIGN KEY (category) REFERENCES categories(name) ON UPDATE CASCADE,
    ADD CONSTRAINT fk_posts_segment  FOREIGN KEY (segment)  REFERENCES segments(code)   ON UPDATE CASCADE,
    ADD CONSTRAINT chk_posts_price   CHECK (price >= 0),
    ADD CONSTRAINT chk_posts_status  CHECK (status IN ('pending', 'approved', 'rejected')),
    ADD INDEX idx_posts_browse (status, segment, category),
    ADD INDEX idx_posts_created (created_at);

ALTER TABLE messages       ADD INDEX idx_msg_thread (post_id, buyer_id, id);
ALTER TABLE universal_chat ADD INDEX idx_uchat_approved (approved, id);
