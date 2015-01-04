• File List	Use

• account.tt	These are all Template Toolkit files, used to generate various pages in the new interface under development by DY

• ChangeLog	Sort of a version history

• chapters.pl
• chapters_new.pl	Lists the proposed chapters

• dump.pl	Test scripts to run to make sure things running properly. dump.pl outputs some random stuff.

• echo.pl	Test scripts to run to make sure things running properly. echo.pl returns whatever is sent in as a CGI parameter

• etyma.pl	Used in database_editor.html; lets you search and edit the etyma table

• etyma_delete_check.pl	Something Dominic set up for the process of deleting etyma from the etyma table

• EtymaSets.pm

• etymology-old.pl
• etymology.pl	Takes a GET parameter "tag" and returns the etymology corresponding to the etyma with that tag number. Requires client-side XSLt support and a browser that does the Right Thing (tm) with UTF-8 encoded XHTML files produced via XSLt. In practice, this seems to mean using Firefox or Mozilla (and perhaps very recent versions of IE).

• FascicleXetexUtil.pm	DY thinks he wrote this perl module to help output XeTeX for TBRS and subsequent root canals

• gif/	This directory contains gif-ified files (converted from the original PICT) of the original semantic flowcharts for the fascicles.

• header.tt	These are all Template Toolkit files, used to generate various pages in the new interface under development by DY

• hptb.pl 
• hptb_new.pl	Gives searchable access to the hptb table, which has all the proto forms from HPTB, their page numbers, etc.

• index.cgi	Outputs a barebones help page, to be fleshed out with real documentation.

• index.tt	These are all Template Toolkit files, used to generate various pages in the new interface under development by DY

• json_lg.pl	Ajax?

• languagenames.pl	To add entries for each language in the source (language abbrevation, language name, the string to use when sorting, etc.); lets you search and edit the languagenames table

• lg_table.cgi	This script presents updated statistics about the languages in the database (it also exists in the stedt-cgi/public_html directory)
• lg_table_old.cgi

• lggroups.pl	Rudimentary language groups interface.

• list_by_semcat.pl	Don't remember. Looks like a JB thing.

• login.cgi

• login.tt	These are all Template Toolkit files, used to generate various pages in the new interface under development by DY

• malla_edit.pl	For Brenden and Charmaine to make those updates Malla recommended.

• malla_print.pl	For Brenden and Charmaine to make those updates Malla recommended. 

• notes.pl	Notes editor

• old stuff/	Old stuff, saved here because we're packrats.

• phpmyadmin/	Alias to the current phpmyadmin distribution.

• phpMyAdmin-2.11.9.6-english/	The current phpmyadmin distribution. 
•  
• rootcanal.pl	This is the new interface DY is working on.

• scriptaculous/	Contains magical javascript scripts for the interface.

• semcat.pl	Don't remember. Looks like a JB thing. Semantic Categorization.

• sil2lg.txt	This is a list of the ISO codes with their language names, and is required for lg_table.cgi to operate.

• srcbib.pl	To add an entry for a source (source abbreviation, author, title, imprint, notes, status, todo, format, etc.); lets you search and edit the srcbib table

• STEDTUtil.pm	Perl module to help with logging in the mysql database, etc. THIS SHOULD NOT BE IN THE PUBLIC DOC ROOT. Check other files to make sure no user credentials are readable by non-STEDT.

• styles/	CSS stylesheets

• SyllabificationStation.pm	David Mortensen wrote this perl module to syllabify lexicon entries (this is the reason we can bold certain syllables in TBRS, or highlight certain syllables in yellow on the web interface)

• TableEdit.pm	Perl module used by most of the current web interface scripts to output tables, add records, etc. Basically the workhorse of the current web interface.

• tablekit-ordering.js

• tablekit.js	Makes on-the-fly table sorting and edit-in-place possible.

• tagger2.pl	Used in database_editor.html; to add lexicon entries from each language in the source (gloss, reflex, source id); lets you search and edit the lexicon table

• Notes:

• If you see stuff like *_new.pl or *_old.pl, that's DB working on making versions that hide the database login info

• Zev doesn't have a CalNet ID, so DY made a special script for him in the stedt-cgi directory (not the ssl dir) for the purpose of adding Chinese stuff to TBRS.

• It should actually be safe to click on any of the scripts in this directory.  I don't think any of them make any automatic changes. The ones you need to be careful of are in the "data" directory, and those should either have explanatory names or comments inside them...

