#
# command to 'sync' the svn website site directory with  ~stedt/public_html
#
# should be executed as user stedt! 
#
rsync -rtvu --exclude '.svn' --exclude 'sync.sh' ~/site/ ~/public_html
