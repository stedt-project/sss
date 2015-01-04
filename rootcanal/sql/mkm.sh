#
# create "sldb", two table which point from soundlaws to morphemes to lexical entries
# extract lexical entries from lexicon, tokenize into "morphemes", tokenize morphemes into syllabic constituents, create sound laws table.
#
# jbl 3/7/2012, and earlier
#
# clean up any old files
if [ ! -f SyllabificationStation.pm ];
then
  echo "NB: SyllabificationStation.pm and STEDTUtil.pm must be copied here from ../../printutils!"
  exit
fi
rm lexicon.csv temp1.csv morphemes.txt 
# extract lexicon records
mysql -D stedt --default-character-set=utf8 -u $1 -p$2 -e "SELECT rn,reflex,gloss,gfn,gloss as glosshandle,language,grp,grpno,languagenames.srcabbr,lexicon.srcid,semkey,lexicon.lgid,(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis FROM lexicon,languagenames,languagegroups WHERE lexicon.lgid=languagenames.lgid AND languagenames.grpid=languagegroups.grpid ORDER BY gloss,language,reflex;" > lexicon.csv
# split into "morphemes"
perl morphemes.pl < lexicon.csv > temp1.csv 
# split "morphemes" into syllabic constituents (needs to be .txt for mysql import)
perl transduce2.pl < temp1.csv > morphemes.txt
rm temp1.csv
# create morphemes table
mysql --default-character-set=utf8 --local stedt -u $1 -p$2 < ct.sql 
mysqlimport --local --default-character-set=utf8 -u $1 -p$2 stedt  morphemes.txt
mysql --local stedt --default-character-set=utf8 -u $1 -p$2 < mkindexMorphemes.sql
# extract "sound laws" from morphemes
mysql --local stedt --default-character-set=utf8 -u $1 -p$2 < mkSoundLaws.sql
