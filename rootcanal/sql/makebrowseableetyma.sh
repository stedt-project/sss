# silently overwrites etyma.csv if it exists!
mysql -D stedt --default-character-set=utf8 -e "select tag,chapter,sequence,plg,protoform,protogloss,notes from etyma order by protogloss,chapter" > etyma.csv
mysql -D stedt --default-character-set=utf8 -e "select rn,semkey,0,language,reflex,gloss,concat(srcabbr,' ',srcid) from lexicon l,languagenames n where l.lgid = n.lgid and substr(language,1,1) = '*' order by gloss,language" >> etyma.csv
# if you want to run this on other than jb's mac, delete the two jb-specific commands below.
# for jb's mac...
rm ~/Sites/dbs/stedt/stedt-etyma*.html
rm stedt-etyma*.html
perl makeEtymaBrowser.pl etyma.csv
# for jb's mac...
mv stedt-etyma*.html ~/Sites/dbs/stedt
