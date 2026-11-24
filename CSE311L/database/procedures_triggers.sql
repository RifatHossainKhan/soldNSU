-- =====================================================================
--  SoldNSU — stored procedures and triggers
--  Run AFTER schema.sql:   mysql -u root -p soldnsu < database/procedures_triggers.sql
--  (phpMyAdmin: Import tab works as-is because of the DELIMITER lines.)
--
--  The app also tries to install these on start-up. TiDB Cloud does not
--  support triggers or stored procedures; there the app just skips them
--  and everything else keeps working.
-- =====================================================================
USE `soldnsu`;

-- ---------------------------------------------------------------- triggers
DROP TRIGGER IF EXISTS trg_users_before_insert;
DELIMITER $$
-- Store e-mail addresses in one canonical form.
CREATE TRIGGER trg_users_before_insert
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    SET NEW.email = LOWER(TRIM(NEW.email));
    SET NEW.name  = TRIM(NEW.name);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_posts_before_insert;
DELIMITER $$
-- Business rules enforced in the database itself (also on servers that
-- ignore CHECK constraints): no negative price, every new post is pending.
CREATE TRIGGER trg_posts_before_insert
BEFORE INSERT ON posts
FOR EACH ROW
BEGIN
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    SET NEW.title = TRIM(NEW.title);
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_posts_status_audit;
DELIMITER $$
-- Every time a post is approved, rejected, or marked sold/unsold,
-- write one row to post_status_log.
CREATE TRIGGER trg_posts_status_audit
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) OR NOT (OLD.sold <=> NEW.sold) THEN
        INSERT INTO post_status_log(post_id, old_status, new_status, old_sold, new_sold)
        VALUES (NEW.id, OLD.status, NEW.status, OLD.sold, NEW.sold);
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_posts_insert_audit;
DELIMITER $$
CREATE TRIGGER trg_posts_insert_audit
AFTER INSERT ON posts
FOR EACH ROW
BEGIN
    INSERT INTO post_status_log(post_id, old_status, new_status, old_sold, new_sold)
    VALUES (NEW.id, NULL, NEW.status, NULL, NEW.sold);
END$$
DELIMITER ;

-- ---------------------------------------------------------------- procedures
DROP PROCEDURE IF EXISTS sp_approve_post;
DELIMITER $$
-- Approve a pending post. Returns the number of rows changed (0 or 1).
CREATE PROCEDURE sp_approve_post(IN p_post_id INT)
BEGIN
    UPDATE posts SET status = 'approved'
     WHERE id = p_post_id AND status <> 'approved';
    SELECT ROW_COUNT() AS changed;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_seller_report;
DELIMITER $$
-- All posts of one seller plus how many buyers wrote about each.
CREATE PROCEDURE sp_seller_report(IN p_user_id INT)
BEGIN
    SELECT p.id, p.title, p.price, p.status, p.sold,
           COUNT(DISTINCT m.buyer_id) AS interested_buyers,
           MAX(m.created_at)          AS last_message_at
      FROM posts p
      LEFT JOIN messages m ON m.post_id = p.id
     WHERE p.owner_id = p_user_id
     GROUP BY p.id, p.title, p.price, p.status, p.sold
     ORDER BY p.id DESC;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_search_posts;
DELIMITER $$
-- Keyword search over approved, unsold posts, optionally in one segment
-- (pass NULL or '' for all segments) and under a maximum price (NULL = any).
CREATE PROCEDURE sp_search_posts(IN p_keyword VARCHAR(100),
                                 IN p_segment VARCHAR(20),
                                 IN p_max_price DECIMAL(12, 2))
BEGIN
    SELECT id, title, price, category, segment_label, seller
      FROM v_active_listings
     WHERE (p_keyword IS NULL OR title LIKE CONCAT('%', p_keyword, '%'))
       AND (p_segment IS NULL OR p_segment = '' OR segment = p_segment)
       AND (p_max_price IS NULL OR price <= p_max_price)
     ORDER BY price;
END$$
DELIMITER ;
