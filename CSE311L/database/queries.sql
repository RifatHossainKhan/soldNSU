-- =====================================================================
--  SoldNSU — example queries for the report / viva
--  Every query here runs against schema.sql + seed.sql.
--  The ones marked [app] are the same queries the Flask app runs.
-- =====================================================================
USE `soldnsu`;

-- 1. [app] Home page: approved posts in one segment, newest first (JOIN + filter)
SELECT p.id, p.title, p.price, p.category, u.name AS owner_name
FROM posts p
JOIN users u ON u.id = p.owner_id
WHERE p.status = 'approved' AND p.segment = 'university'
ORDER BY p.id DESC;

-- 2. [app] Keyword search with LIKE
SELECT id, title, price
FROM posts
WHERE status = 'approved'
  AND (title LIKE '%calculator%' OR description LIKE '%calculator%');

-- 3. Number of posts and average price per category (GROUP BY + aggregate)
SELECT category, COUNT(*) AS posts, ROUND(AVG(price), 2) AS avg_price
FROM posts
WHERE status = 'approved'
GROUP BY category
ORDER BY posts DESC;

-- 4. Categories whose average price is above 1000 Tk (HAVING)
SELECT category, ROUND(AVG(price), 2) AS avg_price
FROM posts
WHERE status = 'approved'
GROUP BY category
HAVING AVG(price) > 1000;

-- 5. Posts more expensive than the average of their own category (correlated subquery)
SELECT p.title, p.category, p.price
FROM posts p
WHERE p.status = 'approved'
  AND p.price > (SELECT AVG(p2.price) FROM posts p2
                  WHERE p2.category = p.category AND p2.status = 'approved')
ORDER BY p.category, p.price DESC;

-- 6. Members who have never posted anything (LEFT JOIN ... IS NULL)
SELECT u.id, u.name
FROM users u
LEFT JOIN posts p ON p.owner_id = u.id
WHERE p.id IS NULL;

-- 7. Same question with NOT EXISTS
SELECT u.id, u.name
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.owner_id = u.id);

-- 8. [app] Seller inbox: each of my posts with the number of buyers who wrote
SELECT p.id, p.title, COUNT(DISTINCT m.buyer_id) AS buyers
FROM posts p
JOIN messages m ON m.post_id = p.id
WHERE p.owner_id = 2
GROUP BY p.id, p.title;

-- 9. [app] One conversation (post 3, buyer 3), oldest message first
SELECT m.created_at, u.name AS sender, m.body
FROM messages m
JOIN users u ON u.id = m.sender_id
WHERE m.post_id = 3 AND m.buyer_id = 3
ORDER BY m.id;

-- 10. [app] Admin dashboard in ONE query (conditional aggregation)
SELECT
    (SELECT COUNT(*) FROM users WHERE is_admin = 0)            AS users,
    COUNT(*)                                                    AS posts,
    SUM(status = 'pending')                                     AS pending,
    SUM(status = 'approved')                                    AS approved,
    SUM(segment = 'university')                                 AS university,
    SUM(segment = 'universal')                                  AS universal,
    (SELECT COUNT(*) FROM universal_chat WHERE approved = 0)    AS chat_pending
FROM posts;

-- 11. Most contacted posts (multi-table JOIN + ORDER BY + LIMIT)
SELECT p.title, u.name AS seller, COUNT(DISTINCT m.buyer_id) AS interested_buyers
FROM posts p
JOIN users u    ON u.id = p.owner_id
JOIN messages m ON m.post_id = p.id
GROUP BY p.id, p.title, u.name
ORDER BY interested_buyers DESC
LIMIT 5;

-- 12. Posts added per day (date functions)
SELECT DATE(created_at) AS day, COUNT(*) AS new_posts
FROM posts
GROUP BY DATE(created_at)
ORDER BY day;

-- 13. Price rank inside each category (window function, MySQL 8 / MariaDB 10.2+)
SELECT category, title, price,
       RANK() OVER (PARTITION BY category ORDER BY price DESC) AS price_rank
FROM posts
WHERE status = 'approved';

-- 14. University vs universal posts side by side (UNION ALL)
SELECT 'university' AS segment, COUNT(*) AS posts FROM posts WHERE segment = 'university'
UNION ALL
SELECT 'universal', COUNT(*) FROM posts WHERE segment = 'universal';

-- 15. Using the views
SELECT * FROM v_active_listings ORDER BY price LIMIT 10;
SELECT * FROM v_category_summary;
SELECT * FROM v_seller_stats;
SELECT * FROM v_segment_summary;

-- 16. Using the stored procedures (not available on TiDB)
CALL sp_seller_report(2);
CALL sp_search_posts('book', 'university', 1000);
CALL sp_approve_post(24);
SELECT * FROM post_status_log WHERE post_id = 24;

-- 17. Transaction: mark a post sold and leave a note to the buyer atomically
START TRANSACTION;
UPDATE posts SET sold = 1 WHERE id = 11 AND sold = 0;
INSERT INTO messages(post_id, buyer_id, sender_id, body)
VALUES (11, 3, 1, 'Marked as sold to you. Thanks!');
COMMIT;

-- 18. Constraints at work (each of these is REJECTED by the database)
-- INSERT INTO posts(owner_id,title,description,price,category,segment)
--   VALUES (2,'Bad price','x',-5,'Books','university');        -- chk_posts_price / trigger
-- INSERT INTO posts(owner_id,title,description,price,category,segment)
--   VALUES (2,'Bad category','x',10,'Cars','university');      -- fk_posts_category
-- INSERT INTO posts(owner_id,title,description,price,category,segment)
--   VALUES (999,'No owner','x',10,'Books','university');       -- fk_posts_owner
-- INSERT INTO users(name,email,password_hash) VALUES ('Dup','admin@soldnsu.local','x'); -- UNIQUE email
