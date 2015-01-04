#! /bin/bash
# use -rtvni to do a dry run with itemized changes
# script to set up rootcanal files in development directory

svn up ~/svn-rootcanal
rsync -rti --exclude '.svn' --exclude 'js' --exclude 'scriptaculous/' --exclude 'admin.tt' ~/svn-rootcanal/web/ ~/public_html/dev
rsync -rti --exclude '.svn' ~/svn-rootcanal/perl/STEDT/ ~/pm-dev/STEDT

rsync -rti --exclude '.svn' --delete ~/svn-rootcanal/web/js/ ~/public_html/dev/js
rsync -rti --exclude '.svn' --delete ~/svn-rootcanal/web/scriptaculous/ ~/public_html/dev/scriptaculous/

# svn info ~/svn-rootcanal | grep 'Revision' > ~/deployed.txt
# add indicators that the user is in a test environment
perl -pe  's{<\!-- svnversion -->}{"<p>svn revision [<span style=\"color:red;font-weight:bold;\">DEV</span>]: " . `svnversion ~/svn-rootcanal/` . "</p>"}e' ~/svn-rootcanal/web/admin.tt > ~/public_html/dev/admin.tt
perl -pe  's{logged in as}{<span style=\"color:red;font-weight:bold;\">DEV environment:</span> logged in as}' ~/svn-rootcanal/web/header.tt > ~/public_html/dev/header.tt
perl -pe 's{unshift \@INC.*$}{unshift \@INC, \"\.\./\.\./pm-dev\", \"\.\./\.\./lib\";}' ~/svn-rootcanal/rootcanal.pl > ~/public_html/dev/rootcanal.pl

# make admin page provide a link to the release environment
perl -pe 's{^.*switch to the test environment.*$}{\t<li><a href="[% self_base.replace("dev/","rootcanal.pl/admin") %]">switch to the release environment</a></li>}' ~/public_html/dev/admin.tt > ~/public_html/dev/admin2.tt
mv ~/public_html/dev/admin2.tt ~/public_html/dev/admin.tt

mv ~/public_html/dev/rootcanal.pl ~/public_html/dev/rootcanal-dev.pl
chmod u+x ~/public_html/dev/rootcanal-dev.pl
