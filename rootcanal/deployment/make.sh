#! /bin/bash
# use -rtvni to do a dry run with itemized changes

svn up ~/svn-rootcanal
rsync -rti --exclude '.svn' --exclude 'js' --exclude 'scriptaculous/' --exclude 'admin.tt' ~/svn-rootcanal/web/ ~/public_html
rsync -rti --exclude '.svn' ~/svn-rootcanal/perl/STEDT/ ~/pm/STEDT
# add new files to js directory if necessary, but let minify do the replacing
rsync -rti --exclude '.svn' --ignore-existing --delete ~/svn-rootcanal/web/js/ ~/public_html/js
rsync -rti --exclude '.svn' --ignore-existing --delete ~/svn-rootcanal/web/scriptaculous/ ~/public_html/scriptaculous/
find ~/svn-rootcanal/web/js/ -name "*.js" -exec perl ~/svn-rootcanal/deployment/minify.pl {} \;
find ~/svn-rootcanal/web/scriptaculous/*/ -name "*.js" -exec perl ~/svn-rootcanal/deployment/minify.pl {} \;

svn info ~/svn-rootcanal | grep 'Revision' > ~/deployed.txt
perl -pe  's{<\!-- svnversion -->}{"<p>svn revision: " . `svnversion ~/svn-rootcanal/` . "</p>"}e' ~/svn-rootcanal/web/admin.tt > ~/public_html/admin.tt
