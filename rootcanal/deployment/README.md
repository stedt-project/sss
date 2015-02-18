To deploy the STEDT database interface on a production server:

* Install MySQL
* Load a STEDT database dump.
* Install this code (see below)
* Resolve all PERL module dependencies

Installing the database interface code:

```
git clone https://github.com/stedt-project/sss.git
cd sss/rootcanal/deployment
cp deploy.cfg.example deploy.cfg
vi deploy.cfg
```

Edit the deploy.cfg file with your target web directory (e.g., ~/Sites/rootcanal),
and the directory where your script will see the perl modules.
To minify javascript files, set minify = 1 and install either the google
closure compiler <https://developers.google.com/closure/compiler/>
or the JavaScript::Packer perl module.
Once you're set up, you can run the deploy script to install most of the files,
then copy over and configure the main CGI script:

```
./make.sh
cp ../rootcanal.pl your-web-directory-here
cp ../rootcanal.conf wherever-you-like
# need to configure the app just a little bit...
vi wherever-you-like/rootcanal.conf      # edit in your stedt database login/password
vi your-web-directory-here/rootcanal.pl  # edit to point to your .conf file; edit @INC to include your module directory if necessary
```

When you or others have made changes on the repository and you want to
update the code on your server to match:

* Sign in to your production server
* Deploy the changes

```
cd sss/rootcanal/deployment
./make.sh;
```
