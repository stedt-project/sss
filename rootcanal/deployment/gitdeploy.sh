#! /bin/bash

WEBDIR=/home/stedt-cgi/public_html
MODULESDIR=/home/stedt-cgi/pm

git pull -v

rsync -rti --exclude '.git*' --ignore-existing --delete ../web/js/ $WEBDIR/js
rsync -rti --exclude '.git*' --ignore-existing --delete ../web/scriptaculous/ $WEBDIR/scriptaculous/

rsync -rti --exclude '.git*' ../web/ $WEBDIR
rsync -rti --exclude '.git*' ../perl/STEDT/ $MODULESDIR/STEDT

git log | grep commit | head -1 | cut -f2 -d" " > deployed.txt
perl -pe 's{<\!-- svnversion -->}{"<p>git revision: " . `git rev-parse --short HEAD` . "</p>"}e' ../web/admin.tt > $WEBDIR/admin.tt
#perl -pe  's{<\!-- svnversion -->}{"<p>" . `git log | grep commit | head -1` . "</p>"}e' ../web/admin.tt > $WEBDIR/admin.tt
