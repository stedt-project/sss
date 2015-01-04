alter table etyma add semkey varchar(50);
alter table lexicon add semkey varchar(50);
alter table glosswords add semkey varchar(50);
update glosswords,chapters set glosswords.semkey = chapters.chapter where glosswords.subcat = concat(old_chapter,"/",old_subchapter);
