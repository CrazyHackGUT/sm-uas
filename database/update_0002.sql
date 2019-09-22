--
-- This file is a part of "Unified Admin System".
-- Licensed by GNU GPL v3
-- 
-- All rights reserved.
-- (c) 2019 CrazyHackGUT aka Kruzya
--

-- 1. Start transaction.
START TRANSACTION;

-- 2. Create columns.
ALTER TABLE `uas_admin_server`
	ADD COLUMN `flags` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'Flags (bit-summ); If set - overrides the value from uas_admin' AFTER `server_id`,
	ADD COLUMN `immunity` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'Immunity; If set - overrides the value from uas_admin' AFTER `flags`,
	ADD COLUMN `deleted_at` INT(10) UNSIGNED NULL DEFAULT NULL COMMENT 'Deleted datetime (represented in UNIX TIMESTAMP); if null - administrator is not deleted' AFTER `immunity`;

-- 3. Insert admin_id <-> server_id pair for server_id = null.
INSERT IGNORE INTO `uas_admin_server` (`admin_id`, `server_id`, `deleted_at`)
SELECT `uas_admin`.`admin_id` AS `admin_id`, `uas_server`.`server_id` AS `server_id`, `uas_admin`.`deleted_at` AS `deleted_at` FROM `uas_admin`, `uas_server`;

-- 4. Drop all server_id IS NULL records.
DELETE FROM `uas_admin_server` WHERE `server_id` IS NULL;

-- 5. Update `deleted_at` in `uas_admin_server`.
REPLACE `uas_admin_server` (`admin_id`, `server_id`, `deleted_at`)
SELECT `uas_admin`.`admin_id`, `uas_admin_server`.`server_id`, `uas_admin`.`deleted_at` FROM `uas_admin` INNER JOIN `uas_admin_server` ON `uas_admin`.`admin_id` = `uas_admin_server`.`admin_id`;

-- 6. Change UNIQUE key to PRIMARY key, add comment, disallow use NULL in server_id.
ALTER TABLE `uas_admin_server`
	ALTER `server_id` DROP DEFAULT;
ALTER TABLE `uas_admin_server`
	CHANGE COLUMN `server_id` `server_id` INT(10) UNSIGNED NOT NULL COMMENT 'Server identifier' AFTER `admin_id`,
	DROP INDEX `admin_id_server_id`,
	ADD PRIMARY KEY (`admin_id`, `server_id`);

-- 7. Drop column `deleted_at`.
ALTER TABLE `uas_admin`
	DROP COLUMN `deleted_at`;

-- 8. Rename table, change comment.
ALTER TABLE `uas_admin_server`
	COMMENT='Assigned administrator custom permissions to servers';
RENAME TABLE `uas_admin_server` TO `uas_admin_flags`;

-- 9. Add deleted_at in `uas_admin_group`.
ALTER TABLE `uas_admin_group`
	ADD COLUMN `deleted_at` INT(10) UNSIGNED NULL COMMENT 'When admin group should be removed' AFTER `title`;

-- 10. Commit.
COMMIT;

-- Required structure version for applying update: v1.0.0.3 (1000073)
-- New structure version after update:             v1.0.0.4 (1000074)