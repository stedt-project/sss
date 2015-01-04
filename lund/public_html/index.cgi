#!/usr/bin/perl

use CGI qw/:standard *table/;

my %desc = (
'database_editor.html'=>'main editor/tagger interface',
'etyma.pl'=>'used in database_editor.html',
'tagger2.pl'=>'used in database_editor.html',
'xoverview.pl'=>'a script by JB that returns some interesting database facts',
'etymology.pl'=>'Takes a GET parameter "tag" and returns the etymology corresponding to
	the etyma with that tag number. Requires client-side XSLt support and a
	browser that does the Right Thing (tm) with UTF-8 encoded XHTML files
	produced via XSLt. In practice, this seems to mean using Firefox or
	Mozilla (and perhaps very recent versions of IE).',
'fascicle-count-forms.pl' => 'counts number of distinct forms and prints out a plain text file',
'fascicle.pl' => 'generates fascicle as XeLaTeX. Works best if you redirect to a local file, then download it to your machine.',
'comparanda.pl' => 'generates XeLaTeX comparanda only, for Zev to proofread.',
'skin.pl' => 'generates fascicle for SKIN roots.',
'notes.pl'=>'notes editor',
'lexicon.pl'=>'non regex search',
'lexicon2.pl'=>'regex search',
'lexicon3.pl'=>'mystery file? same as lexicon2 except no analysis search, yes srcabbr search',

'dbbrowse.pl'=>'sample lexicon db script',
'dbrows.pl'=>'sample XML output',
'zchapters.pl'=>'unused?',
'ztagger.html'=>'JB was working on a simpler interface',
);

print header(-charset => "utf8"), # calls charset for free, so forms don't mangle text
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=utf8'}),
	       -encoding => 'utf-8',
	       -title=>'list of files', 
	       -style=>{'src'=>'/styles/tagger.css'});

print p("Dominic hates typing in pathnames, so he wrote a script to list all the files in this directory.");
print start_table;
while (<*>) {
	$_ .= '/' if -d;
	print Tr(td(a({-href=>$_},$_)), td($desc{$_}));
}
print end_table;

print end_html;
