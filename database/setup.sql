-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               5.7.26-29 - Percona Server (GPL), Release '29', Revision '11ad961'
-- Server OS:                    debian-linux-gnu
-- HeidiSQL Version:             10.2.0.5599
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Dumping structure for table uas.uas_admin
CREATE TABLE IF NOT EXISTS `uas_admin` (
  `admin_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique administrator identifier',
  `username` varchar(256) NOT NULL DEFAULT '' COMMENT 'Username',
  `auth_method` varchar(32) NOT NULL COMMENT 'Auth method name',
  `auth_value` varchar(64) NOT NULL COMMENT 'Auth method value',
  `password` varchar(256) NOT NULL DEFAULT '' COMMENT 'Password',
  `flags` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Flags (bit-summ)',
  `immunity` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Immunity',
  `deleted_at` int(11) DEFAULT NULL COMMENT 'Deleted datetime (represented in UNIX TIMESTAMP); if null - administrator is not deleted',
  PRIMARY KEY (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Administrators storage';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_admin_group
CREATE TABLE IF NOT EXISTS `uas_admin_group` (
  `admin_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique admin group pair id',
  `admin_id` int(10) unsigned NOT NULL COMMENT 'Administrator identifier',
  `server_id` int(10) unsigned NOT NULL COMMENT 'Server identifier (if null - group will be added to all servers)',
  `title` varchar(256) NOT NULL COMMENT 'Group title',
  PRIMARY KEY (`admin_group_id`),
  UNIQUE KEY `admin_id_server_id_title` (`admin_id`,`server_id`,`title`),
  KEY `FK_uas_admin_group_uas_group` (`title`),
  KEY `FK_uas_admin_group_uas_server` (`server_id`),
  CONSTRAINT `FK_uas_admin_group_uas_admin` FOREIGN KEY (`admin_id`) REFERENCES `uas_admin` (`admin_id`) ON UPDATE CASCADE,
  CONSTRAINT `FK_uas_admin_group_uas_group` FOREIGN KEY (`title`) REFERENCES `uas_group` (`title`) ON UPDATE CASCADE,
  CONSTRAINT `FK_uas_admin_group_uas_server` FOREIGN KEY (`server_id`) REFERENCES `uas_server` (`server_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Describes what groups used by administrator on what server';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_admin_server
CREATE TABLE IF NOT EXISTS `uas_admin_server` (
  `admin_id` int(10) unsigned NOT NULL COMMENT 'Administrator identifier',
  `server_id` int(10) unsigned DEFAULT NULL,
  UNIQUE KEY `admin_id_server_id` (`admin_id`,`server_id`),
  KEY `FK_uas_admin_server_uas_server` (`server_id`),
  CONSTRAINT `FK_uas_admin_server_uas_admin` FOREIGN KEY (`admin_id`) REFERENCES `uas_admin` (`admin_id`) ON UPDATE CASCADE,
  CONSTRAINT `FK_uas_admin_server_uas_server` FOREIGN KEY (`server_id`) REFERENCES `uas_server` (`server_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Assigned administrators to servers';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_group
CREATE TABLE IF NOT EXISTS `uas_group` (
  `title` varchar(256) NOT NULL COMMENT 'Group name (should be unique)',
  `immunity` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Immunity level',
  `flags` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'Flags (bit-summ)',
  `deleted_at` int(11) DEFAULT NULL COMMENT 'Deleted datetime (represented in UNIX TIMESTAMP); if null - group is not deleted',
  PRIMARY KEY (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Groups storage';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_group_immunity
CREATE TABLE IF NOT EXISTS `uas_group_immunity` (
  `target` varchar(256) NOT NULL,
  `other` varchar(256) NOT NULL,
  UNIQUE KEY `target_other` (`target`,`other`),
  KEY `FK_uas_group_immunity_uas_group_2` (`other`),
  CONSTRAINT `FK_uas_group_immunity_uas_group` FOREIGN KEY (`target`) REFERENCES `uas_group` (`title`) ON UPDATE CASCADE,
  CONSTRAINT `FK_uas_group_immunity_uas_group_2` FOREIGN KEY (`other`) REFERENCES `uas_group` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Defines what group can not be targeted by another group';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_group_override
CREATE TABLE IF NOT EXISTS `uas_group_override` (
  `title` varchar(256) NOT NULL COMMENT 'Group title',
  `command` varchar(256) NOT NULL COMMENT 'String containing command name',
  `override_type` enum('Command','CommandGroup') NOT NULL COMMENT 'Override type (specific command or group)',
  `has_access` enum('Y','N') NOT NULL COMMENT 'New access level (Y - allowed, D - denied)',
  PRIMARY KEY (`command`,`override_type`,`title`),
  KEY `FK_uas_group_override_uas_group` (`title`),
  CONSTRAINT `FK_uas_group_override_uas_group` FOREIGN KEY (`title`) REFERENCES `uas_group` (`title`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Group Overrides storage';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_override
CREATE TABLE IF NOT EXISTS `uas_override` (
  `override_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Override identifier',
  `command` varchar(256) NOT NULL COMMENT 'String containing command name',
  `override_type` enum('Command','CommandGroup') NOT NULL COMMENT 'Override type (specific command or group)',
  `flags` int(11) NOT NULL DEFAULT '0' COMMENT 'New admin flag',
  PRIMARY KEY (`override_id`),
  UNIQUE KEY `command_override_type` (`command`,`override_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Overrides storage';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_override_server
CREATE TABLE IF NOT EXISTS `uas_override_server` (
  `server_id` int(10) unsigned DEFAULT NULL COMMENT 'Server identifier',
  `override_id` int(10) unsigned NOT NULL COMMENT 'Override identifier',
  UNIQUE KEY `server_id_override_id` (`server_id`,`override_id`),
  KEY `FK_uas_override_server_uas_override` (`override_id`),
  CONSTRAINT `FK__uas_server` FOREIGN KEY (`server_id`) REFERENCES `uas_server` (`server_id`) ON UPDATE CASCADE,
  CONSTRAINT `FK_uas_override_server_uas_override` FOREIGN KEY (`override_id`) REFERENCES `uas_override` (`override_id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Storages server relations with overrides';

-- Data exporting was unselected.

-- Dumping structure for table uas.uas_server
CREATE TABLE IF NOT EXISTS `uas_server` (
  `server_id` int(10) unsigned NOT NULL COMMENT 'Unique server identifier',
  `address` int(10) unsigned NOT NULL COMMENT 'Server address',
  `port` smallint(5) unsigned NOT NULL COMMENT 'Server port',
  `hostname` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Server hostname',
  `deleted_at` int(11) DEFAULT NULL COMMENT 'Deleted datetime (represented in UNIX TIMESTAMP); if null - server is not deleted',
  `synced_at` int(11) unsigned NOT NULL COMMENT 'Last date when server used sync',
  PRIMARY KEY (`server_id`),
  UNIQUE KEY `address_port` (`address`,`port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Servers storage';

-- Data exporting was unselected.

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
