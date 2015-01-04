alter table lexicon add originalgloss varchar(255) not null default '' AFTER gloss;
alter table lexicon add originalgfn varchar(15) not null default '' AFTER gfn;
alter table lexicon add originalreflex varchar(255) not null default '' AFTER reflex;
alter table lexicon add maintainer varchar(255) not null default '';
update lexicon set originalgloss=gloss,originalgfn=gfn,originalreflex=reflex;
CREATE INDEX idx_lexicon_maintainer ON lexicon (maintainer);
