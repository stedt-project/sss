# these commands set various field defaults that weren't previously defined

use stedt;
ALTER TABLE  `etyma` CHANGE  `uid`  `uid` MEDIUMINT( 8 ) UNSIGNED NOT NULL DEFAULT  '0';
ALTER TABLE  `changelog` CHANGE  `col`  `col` VARCHAR( 15 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `changelog` CHANGE  `owner_uid`  `owner_uid` MEDIUMINT( 8 ) UNSIGNED NOT NULL DEFAULT  '0';
ALTER TABLE  `languagenames` CHANGE  `silcode`  `silcode` VARCHAR( 3 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `location`  `location` VARCHAR( 24 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `dataformat`  `dataformat` VARCHAR( 8 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `haveit`  `haveit` VARCHAR( 10 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `proofer`  `proofer` VARCHAR( 16 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `inputter`  `inputter` VARCHAR( 26 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `dbprep`  `dbprep` VARCHAR( 10 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `dbload`  `dbload` VARCHAR( 10 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `dbcheck`  `dbcheck` VARCHAR( 10 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `callnumber`  `callnumber` VARCHAR( 38 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `scope`  `scope` INT( 11 ) NOT NULL DEFAULT  '0';
ALTER TABLE  `srcbib` CHANGE  `refonly`  `refonly` VARCHAR( 2 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `citechk`  `citechk` VARCHAR( 20 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `pi`  `pi` VARCHAR( 20 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `srcbib` CHANGE  `totalnum`  `totalnum` VARCHAR( 16 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  '';
ALTER TABLE  `mesoroots` CHANGE  `old_tag`  `old_tag` SMALLINT( 6 ) UNSIGNED NOT NULL DEFAULT  '0';
ALTER TABLE  `etyma` CHANGE  `semkey`  `semkey` VARCHAR( 50 ) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT  ''