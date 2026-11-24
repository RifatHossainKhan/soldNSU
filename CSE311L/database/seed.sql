-- =====================================================================
--  SoldNSU — sample data for demos and testing
--  Run AFTER schema.sql:   mysql -u root -p soldnsu < database/seed.sql
--  Safe to run twice (INSERT IGNORE).
--
--  Demo logins (change or delete these before going live):
--    admin@soldnsu.local  / admin123   (administrator)
--    seller@soldnsu.local / demo1234
--    buyer@soldnsu.local  / demo1234
--  Photos live in static/uploads/sample_*.
-- =====================================================================
SET NAMES utf8mb4;
USE `soldnsu`;

INSERT IGNORE INTO users (id, name, email, password_hash, is_admin, is_banned, created_at) VALUES
(1, 'Admin',       'admin@soldnsu.local',  'scrypt:32768:8:1$ZjmcSah10nTD0de1$96c663e9a07149095fd00798bd16e8c59c34f2a48dbcf4e4d06e8c948d60e9d624a578fb371dfce03627a64582de81e912e8c57a5485c1d6e91dd4d08fe9044f', 1, 0, '2026-11-15 20:24:09'),
(2, 'Demo Seller', 'seller@soldnsu.local', 'scrypt:32768:8:1$IH3M6bUOstykZvLD$c6f2458b2a9e6e63b94931b2a6b663e49ddc970d0101536bb59a3a1466e47d05f79178a4d804931f6e04353743d73f38ab57a38b64d2491a62c334e5e35d8fd4', 0, 0, '2026-11-15 21:00:18'),
(3, 'Demo Buyer',  'buyer@soldnsu.local',  'scrypt:32768:8:1$IH3M6bUOstykZvLD$c6f2458b2a9e6e63b94931b2a6b663e49ddc970d0101536bb59a3a1466e47d05f79178a4d804931f6e04353743d73f38ab57a38b64d2491a62c334e5e35d8fd4', 0, 0, '2026-11-16 08:30:00');

INSERT IGNORE INTO posts (id, owner_id, title, description, price, category, segment, photo, status, sold, created_at) VALUES
(1, 1, 'Desktop computer (Core i7, 10th gen)', 'A new computer with a Core i7 10th gen processor.', 50000, 'Electronics', 'universal', 'sample_01_computer.png', 'approved', 0, '2026-11-15 20:57:30'),
(2, 1, 'CSE311 lab textbook', 'CSE311 lab textbook in good condition.', 100, 'Books', 'university', 'sample_02_books.jpeg', 'approved', 0, '2026-11-15 20:58:29'),
(3, 2, 'CSE311L lab report (soft copy)', 'A lab report soft copy for reference.', 20, 'Other', 'university', 'sample_03_lab-report.png', 'approved', 0, '2026-11-15 21:02:03');

INSERT IGNORE INTO `posts` (`id`, `owner_id`, `title`, `description`, `price`, `category`, `segment`, `photo`, `status`, `sold`, `created_at`) VALUES
(4, 2, 'Database System Concepts (7th ed.)', 'Silberschatz, Korth, Sudarshan. Clean copy for CSE311, no highlighting, only a few pencil notes in chapters 3 and 4.', 650, 'Books', 'university', 'sample_04_database-system-concepts-7th-ed.png', 'approved', 0, '2026-11-16 09:00:00'),
(5, 1, 'Casio fx-991EX Calculator', 'Original ClassWiz scientific calculator, allowed in NSU exams. Works perfectly, cover included.', 1800, 'Stationery', 'university', 'sample_05_casio-fx-991ex-calculator.png', 'approved', 0, '2026-11-16 10:07:00'),
(6, 2, 'Arduino Uno R3 Starter Kit', 'Uno board, USB cable, LEDs, resistors, buttons, sensors and a small box. Used for one lab course only.', 1500, 'Lab Equipment', 'university', 'sample_06_arduino-uno-r3-starter-kit.png', 'approved', 0, '2026-11-16 11:14:00'),
(7, 1, 'Breadboard + Jumper Wire Set', '830-point breadboard with about 65 jumper wires. Good for CSE231 and EEE lab work.', 350, 'Lab Equipment', 'university', 'sample_07_breadboard-jumper-wire-set.png', 'approved', 0, '2026-11-17 12:21:00'),
(8, 2, 'CSE311L Lab Manual (printed)', 'Printed and spiral-bound lab manual with all SQL exercises. Margin notes inside.', 120, 'Books', 'university', 'sample_08_cse311l-lab-manual-printed.png', 'approved', 0, '2026-11-17 13:28:00'),
(9, 1, 'Engineering Drawing Kit', 'Full drafting set: compass, dividers, set squares, protractor and pencils in a hard case.', 450, 'Stationery', 'university', 'sample_09_engineering-drawing-kit.png', 'approved', 0, '2026-11-17 14:35:00'),
(10, 2, 'White Lab Coat (size M)', 'Washed and ironed lab coat, worn for two semesters. Fits height 5''6" to 5''9".', 400, 'Clothing', 'university', 'sample_10_white-lab-coat-size-m.png', 'approved', 0, '2026-11-17 15:42:00'),
(11, 1, 'Raspberry Pi 4 Model B (4GB)', 'Pi 4 with official power adapter and a 32GB SD card with OS installed. Selling after finishing my project.', 7500, 'Lab Equipment', 'university', 'sample_11_raspberry-pi-4-model-b-4gb.png', 'approved', 0, '2026-11-18 16:49:00'),
(12, 2, 'Digital Multimeter DT830', 'Basic digital multimeter with probes and a spare 9V battery. Measures voltage, current and resistance.', 600, 'Lab Equipment', 'university', 'sample_12_digital-multimeter-dt830.png', 'approved', 0, '2026-11-18 17:56:00'),
(13, 1, 'Thomas'' Calculus (14th ed.)', 'Textbook for MAT120 and MAT130. Hardcover, in good condition, no missing pages.', 500, 'Books', 'university', 'sample_13_thomas-calculus-14th-ed.png', 'approved', 0, '2026-11-18 09:03:00'),
(14, 2, 'Study Table with Drawer', 'Wooden study table, 4 ft wide, one drawer with lock. Buyer arranges pickup near Bashundhara.', 3500, 'Furniture', 'universal', 'sample_14_study-table-with-drawer.png', 'approved', 0, '2026-11-18 10:10:00'),
(15, 1, 'Wireless Mouse', '2.4 GHz wireless mouse with USB receiver. Silent clicks, one AA battery included.', 450, 'Electronics', 'universal', 'sample_15_wireless-mouse.png', 'approved', 0, '2026-11-19 11:17:00'),
(16, 2, 'Mechanical Keyboard (Blue switch)', 'Full-size keyboard with RGB backlight and blue switches. Two keycaps replaced, all keys work.', 2800, 'Electronics', 'universal', 'sample_16_mechanical-keyboard-blue-switch.png', 'approved', 0, '2026-11-19 12:24:00'),
(17, 1, 'Bicycle, 26 inch', 'City bicycle with 6 gears, recently serviced, new tyres. Good for getting around campus.', 9000, 'Bikes & Transport', 'universal', 'sample_17_bicycle-26-inch.png', 'approved', 0, '2026-11-19 13:31:00'),
(18, 2, 'Laptop Cooling Pad', 'Dual-fan cooling pad for 15.6 inch laptops, USB powered, adjustable height.', 700, 'Electronics', 'universal', 'sample_18_laptop-cooling-pad.png', 'approved', 0, '2026-11-19 14:38:00'),
(19, 1, 'Bluetooth Headphones', 'Over-ear wireless headphones, around 20 hours of battery. Charging cable included.', 1600, 'Electronics', 'universal', 'sample_19_bluetooth-headphones.png', 'approved', 0, '2026-11-20 15:45:00'),
(20, 2, 'Power Bank 10000mAh', 'Dual USB output power bank with LED indicator. Holds a full charge, about 6 months old.', 1100, 'Electronics', 'universal', 'sample_20_power-bank-10000mah.png', 'approved', 0, '2026-11-20 16:52:00'),
(21, 1, 'Waterproof Laptop Backpack', 'Fits up to 15.6 inch laptop, USB charging port, three compartments. Barely used.', 900, 'Clothing', 'universal', 'sample_21_waterproof-laptop-backpack.png', 'approved', 0, '2026-11-20 17:59:00'),
(22, 2, 'LED Table Lamp', 'Rechargeable desk lamp with three brightness levels and a flexible neck.', 550, 'Electronics', 'universal', 'sample_22_led-table-lamp.png', 'approved', 0, '2026-11-20 09:06:00'),
(23, 1, 'Hoodie, size L (black)', 'Heavy cotton hoodie, worn a few times. No stains, zip works smoothly.', 800, 'Clothing', 'universal', 'sample_23_hoodie-size-l-black.png', 'approved', 0, '2026-11-20 10:13:00');

-- a few posts in other states, so the admin pages and reports have something to show
INSERT IGNORE INTO posts (id, owner_id, title, description, price, category, segment, photo, status, sold, created_at) VALUES
(24, 3, 'Used scientific calculator', 'Casio fx-82MS, buttons a little worn.', 400, 'Stationery', 'university', NULL, 'pending', 0, '2026-11-21 11:00:00'),
(25, 3, 'Old phone charger', 'Generic 10W charger.', 150, 'Electronics', 'universal', NULL, 'rejected', 0, '2026-11-21 12:00:00');
UPDATE posts SET sold = 1 WHERE id IN (8, 15) AND sold = 0;

INSERT IGNORE INTO messages (id, post_id, buyer_id, sender_id, body, created_at) VALUES
(1, 3,  3, 3, 'Hi, how can I get this report?',              '2026-11-15 21:03:54'),
(2, 3,  3, 2, 'I can send it on WhatsApp after payment.',    '2026-11-15 21:10:00'),
(3, 11, 3, 3, 'Is the Raspberry Pi still available?',         '2026-11-18 18:00:00'),
(4, 11, 3, 1, 'Yes, you can pick it up at NSU tomorrow.',     '2026-11-18 18:05:00'),
(5, 4,  1, 1, 'Would you take 550 for the DB book?',          '2026-11-19 09:15:00');

INSERT IGNORE INTO universal_chat (id, user_id, body, approved, created_at) VALUES
(1, 1, 'Welcome to SoldNSU!', 1, '2026-11-15 20:58:47'),
(2, 3, 'Does anyone have a CSE311L report 1?', 1, '2026-11-15 20:59:05'),
(3, 2, 'I have one, check /post/3', 1, '2026-11-15 21:03:12'),
(4, 3, 'Anyone selling a lab coat?', 0, '2026-11-21 10:00:00');

INSERT IGNORE INTO cards (id, title, url, image, `position`, active) VALUES
(1, 'NSU Website', 'https://www.northsouth.edu', NULL, 1, 1),
(2, 'University Goods', '/?segment=university', NULL, 2, 1),
(3, 'Sell an item', '/sell', NULL, 3, 1);
