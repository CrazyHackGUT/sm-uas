--
-- This file is a part of "Unified Admin System".
-- Licensed by GNU GPL v3
-- 
-- All rights reserved.
-- (c) 2019 CrazyHackGUT aka Kruzya
--

-- 1. Start transaction.
START TRANSACTION;

-- 2. Create column
ALTER TABLE `uas_server` ADD COLUMN `synced_at` INT(11) UNSIGNED NOT NULL COMMENT 'Last date when server used sync' AFTER `deleted_at`;

-- 3. Set default value for all existing servers.
UPDATE `uas_server` SET `synced_at` = UNIX_TIMESTAMP();

-- 4. Commit.
COMMIT;

-- Required structure version for applying update: v1.0.0.1 (1000071)
-- New structure version after update:             v1.0.0.3 (1000073)