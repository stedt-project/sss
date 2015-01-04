#! /bin/bash
# use -rtvni to do a dry run with itemized changes

rsync -rti --exclude '.DS_Store' --exclude '.svn' --exclude 'js' --exclude 'scriptaculous/' ../web/ ~/Sites/rootcanal
rsync -rti --exclude '.DS_Store' --exclude '.svn' ../perl/STEDT/ ~/Sites/rootcanal/STEDT
# add new files to js directory if necessary, but let minify do the replacing
rsync -rti --exclude '.DS_Store' --exclude '.svn' --ignore-existing --delete ../web/js/ ~/Sites/rootcanal/js
rsync -rti --exclude '.DS_Store' --exclude '.svn' --ignore-existing --delete ../web/scriptaculous/ ~/Sites/rootcanal/scriptaculous/
#find ../web/js -name "*.js" -exec perl minify.pl {} \;
#find ../web/scriptaculous/* -name "*.js" -exec perl minify.pl {} \;

svn info .. | grep 'Revision' > ../deployed.txt
perl -pe  's{<\!-- svnversion -->}{"<p>svn revision: " . `svnversion ../` . "</p>"}e' ../web/admin.tt > ~/Sites/rootcanal/admin.tt
