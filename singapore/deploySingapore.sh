##
# deploy singapore (on mac)
CURRENT_DEPLOYMENT=~/Sites/v7
echo "Removing $CURRENT_DEPLOYMENT ..."
rm -rf $CURRENT_DEPLOYMENT
echo "Deploying current code ..."
svn export php $CURRENT_DEPLOYMENT
cd $CURRENT_DEPLOYMENT
# change this line for other than "default" deployments
#perl -i -pe "s/'localhost','root','',''/'localhost','stedtadmin','xxx password xxx'/" *.php
#
# ok, if web sharing is start, php enabled, etc, then visit:
#
# http://localhost/~youruser/v6/
