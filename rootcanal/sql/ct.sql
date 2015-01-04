DROP TABLE morphemes;
CREATE TABLE morphemes (
  rn mediumint(6) unsigned,
  mseq smallint(5) unsigned NOT NULL DEFAULT '1',
  morpheme varchar(200) DEFAULT '',

  reflex varchar(84) NOT NULL DEFAULT '',
  gloss varchar(255) NOT NULL DEFAULT '',
  gfn varchar(15) NOT NULL DEFAULT '',
  glosshandle varchar(255) NOT NULL DEFAULT '',

  language varchar(80) NOT NULL,
  grp varchar(80) NOT NULL,
  grpno varchar(80) NOT NULL,

  srcabbr varchar(13) NOT NULL DEFAULT '',
  srcid varchar(21) NOT NULL DEFAULT '',
  semkey varchar(30) NOT NULL DEFAULT '',
  lgid smallint(5) unsigned NOT NULL DEFAULT '0',

  segments varchar(200) DEFAULT '',
  handle varchar(200) DEFAULT '',
  template varchar(200) DEFAULT '',
  prefx varchar(8) NOT NULL DEFAULT '',
  initial varchar(8) NOT NULL DEFAULT '',
  rhyme varchar(8) NOT NULL DEFAULT '',
  tone varchar(8) NOT NULL DEFAULT '',

  tag varchar(30) NOT NULL DEFAULT '',

  id int(11) NOT NULL AUTO_INCREMENT,

  modtime timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) CHARSET=utf8 ;