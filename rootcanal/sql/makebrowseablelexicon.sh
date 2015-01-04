#
# should be run in the web directory in which the .html files will reside
# requires the lexicon.csv file created by mkm.sh (in the "morphemes/soundlaw system")
rm ~/Sites/dbs/stedt/stedt-etyma*.html
rm stedt-finder*.html
perl makeLexiconBrowser.pl lexicon.csv
# for jb's mac...
mv stedt-finder*.html ~/Sites/dbs/stedt
