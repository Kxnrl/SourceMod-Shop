CREATE TABLE IF NOT EXISTS `dxg_users` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `steamid` bigint(20) unsigned NOT NULL DEFAULT '0',
  `username` varchar(32) NOT NULL DEFAULT 'unnamed',
  `imm` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT 'AdminImmunityLevel',
  `spt` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `vip` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `ctb` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `opt` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `adm` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `own` tinyint(2) unsigned NOT NULL DEFAULT '0',
  `money` int(11) unsigned NOT NULL DEFAULT '0',
  `firstjoin` int(11) unsigned NOT NULL DEFAULT '0',
  `lastseen` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `steam_unique` (`steamid`),
  UNIQUE KEY `bind_unique` (`id`,`steamid`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `dxg_inventory` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `unique` varchar(32) NOT NULL DEFAULT 'invalid',
  `cost` int(11) unsigned NOT NULL DEFAULT '0',
  `date_of_purchase` int(11) NOT NULL DEFAULT '0',
  `date_of_expiration` int(11) NOT NULL DEFAULT '-1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk` (`uid`,`unique`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `dxg_banklog` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(11) unsigned NOT NULL DEFAULT '0',
  `money` int(11) NOT NULL DEFAULT '0',
  `reason` varchar(128) DEFAULT NULL,
  `date` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;