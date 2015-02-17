#! /bin/bash
# use -rtvni to do a dry run with itemized changes

cfgfile=deploy.cfg
if [ -r $cfgfile ]; then
	while IFS='= ' read lhs rhs
	do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%*( )}"   # Del trailing spaces
			declare $lhs="$rhs"
		fi
	done < $cfgfile
fi

if [ ! -d $webdir ]; then
	echo "No valid web directory specified! (tried '$webdir')"
	exit 1
fi
if [ ! -d $modulesdir ]; then
	echo "No valid modules directory specified! (tried '$modulesdir')"
	exit 1
fi

git pull -v
rsync -rti --exclude 'js' --exclude 'scriptaculous/' --exclude 'admin.tt' ../web/ $webdir
rsync -rti ../perl/STEDT/ $modulesdir/STEDT
if [ $minify = 1 ]; then
	# add new files to js directory if necessary, but let minify do the replacing
        echo minifying files in $webdir/js and $webdir/scriptaculous directories...
	rsync -rti --ignore-existing --delete ../web/js/ $webdir/js
	rsync -rti --ignore-existing --delete ../web/scriptaculous/ $webdir/scriptaculous
	find ../web/js -name "*.js" -exec perl minify.pl {} \;
	find ../web/scriptaculous/* -name "*.js" -exec perl minify.pl {} \;
else
        echo deploying unminified files...
	rsync -rti --delete ../web/js/ $webdir/js
	rsync -rti --delete ../web/scriptaculous/ $webdir/scriptaculous
fi

perl -pe 's{<\!-- svnversion -->}{"<p>git revision: " . `git rev-parse --short HEAD` . "</p>"}e' ../web/admin.tt > $webdir/admin.tt
