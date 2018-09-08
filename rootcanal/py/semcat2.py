#!/usr/bin/env /Library/Frameworks/Python.framework/Versions/2.6/bin/python
# keep !/usr/bin/env python

import sys

import time
import csv
import random
import httplib, urllib
import cgi
import cgitb; cgitb.enable()  # for troubleshooting
#
import MySQLdb

def opendb(options):

    options.db = MySQLdb.connect(user="root", db="stedt")
    #options.db = MySQLdb.connect(passwd="PASSWORD", user="stedtuser", host="192.168.100.222", db="stedt")
    #options.cursor=options.db.cursor()

    cursor = options.db.cursor()
    cursor.execute('SET autocommit=1;')
    cursor.execute('SET SESSION wait_timeout=3600;')
    cursor.close()

def header():
    h = '<span class="cssText1">zzz</span><br>\n' 
    h += '<table border="0"><tr><td>'
    h += '</td></tr></table>'
    return h

def footer():
    r = ''
    #r += '<input type="hidden" name="name" value="%s"/>' % name
    r +=  '<hr>'
    r += '<span class="cssText2">Copyright John B. Lowe. All Rights Reserved.</span>'
    r +=  '<hr>'
    return r

def about():
# splash page
    return """
<h1>STEDT</h1>
"""

def processForm(form):
    class options:
        pass

    options.debug = False
    opendb(options)
    
    dbdata = {}
    scores = {}
    for f in form:
        #print 'f',f,form[f].value,"<br/>"
        pair = f.split(".")
        if len(pair) == 2:
            fld,item = pair
            if dbdata.has_key(item):
                pass
            else:
                dbdata[item] = []
            if fld == "addtodb":
                #print "found add to db<br/>"
                scores[item] = True
            else:
                dbdata[item].append( [ fld, form[f].value ] )

    #datakeys = dbdata.keys().sort

    #for item in datakeys:
    for item in dbdata.keys():
        #print 'adding',item,'...<br/>'
        #print dbdata[item]
        if scores.has_key(item): 
            options.msg =  "item "+str(int(item)+1)
            #dealExtractor.loadItemIntoDB(dbdata[item],options)
            print options.msg, "<br/>"
        else:
            print "skipping item",(int(item)+1)," (unchecked)...<br/>"

    options.db.close()

# "select uniqueid, storydate from story where story_key = %s limit 1"

def qDB(db, sql, skey):
    #sql = query % skey
    try:
        c = db.cursor()
        c.execute(sql, skey)
        r = c.fetchall()
        c.close()
        return (r)
    except MySQLdb.Error, e:
       return ("MySQL error: %s" % str(e), None, None)



def printtree():
    print """
<!-- markup for expand/contract links -->
<div id="expandcontractdiv">
	<a id="collapse" href="#">Collapse all</a>
</div>

<div id="stedtDiv" class="whitebg">
"""

    class options:
        pass

    options.debug = False
    opendb(options)

    # select distinct(chapter) from majorcats order by chapter,subchapter
    # select * from otherchapters where chapter = "5f"
    divs = qDB(options.db, "select * from majorcats order by %s,subchapter",'chapter')
    majordivs = sorted(set([ d[0] for d in divs]))
    print "<ul>"

    for i,c in enumerate(majordivs):
        url = "http://stedt.berkeley.edu/~jblowe/v1/tagger.pl?"
        #print 'c',c
        subchaps = filter(lambda s: s[0] == c,divs)
        print """<li><h2>Chapter %s %s</h2>""" % (subchaps[0][0],subchaps[0][3])
        print "<ul>"
        for d in subchaps:
            print """<li><span>%s%s &nbsp; %s <b>%s</b> [reflexes=%s]</span>""" % d[0:5]
            subcats = qDB(options.db, "select * from otherchapters where chapter = %s order by chapter;",''.join(d[0:2]))
            print "<ul>"
            for s in subcats:   
                print """<li><span>%s &nbsp; <i>%s</i> %s (words=%s)</span>""" % (s[3],s[1],s[2],s[5])
                glosswords = qDB(options.db, "select word from glosswords where subcat = %s ;",('%s/%s' % (s[0],s[3])))
                #print glosswords
                print "<ul>"
                if len(glosswords) == 0:
                    pass
                else:
                    out = "<li><span>"
                    for g in glosswords:
                        parms = urllib.urlencode({'submit' : 'Search', 'lexicon.gloss' : g[0]})
                        out += """<i><a href="#" onClick="loadDoc('%s'); return false;">%s</a></i>, """ % (g[0],g[0])
                    print out + "</span></li>"
                print "</li></ul>"
            print "</ul>"
        print "</ul>"

    print "</ul>"
    
    x =  """

	<ul>
		<li class="expanded">List 0
			<ul>
				<li class="expanded">List 0-0
					<ul>
						<li>item 0-0-0</li>
						<li><a target="_new" href="www.elsewhere.com" title="go elsewhere">elsewhere</a></li>
					</ul>
				</li>

			</ul>
		</li>
		<li>List 1
			<ul>
				<li>List 1-0
					<ul>
						<li yuiConfig='{"type":"DateNode","editable":true}'>02/01/2009</li>
						<li><span>item <strong>1-1-0</strong></span></li>

					</ul>
				</li>
			</ul>
		</li>
	</ul>
"""

    print """
</div>
"""

def printreset():
    return """
    <form>
    <input class="cssText1" type="submit" name="lookup" value="Reset"/>
    </form>
"""

def printrender():

    return """
<script type="text/javascript">
//an anonymous function wraps our code to keep our variables
//in function scope rather than in the global namespace:
(function() {
	var tree; //will hold our TreeView instance
		
	function treeInit() {
		
		//Hand off ot a method that generates tree nodes from STEDT data:
		buildTree();
		
		//handler for collapsing all nodes
		YAHOO.util.Event.on("collapse", "click", function(e) {
			<!-- YAHOO.log("Collapsing all TreeView  nodes.", "info", "example"); -->
			tree.collapseAll();
			YAHOO.util.Event.preventDefault(e);
		});
	}
	
	//This method will build a TreeView instance and populate it with
	//STEDT semantic data
	function buildTree () {
	
		//instantiate the tree:
		tree = new YAHOO.widget.TreeView("stedtDiv");
		tree.render();
		
		//tree.subscribe('dblClickEvent',tree.onEventEditNode);
		//once it's all built out, we need to render our TreeView instance:
		// tree.draw();
	}
	
	//When the DOM is done loading, we can initialize our TreeView
	//instance:
	YAHOO.util.Event.onDOMReady(treeInit);
	
})();//anonymous function wrapper closed; () notation executes function

</script>
"""

form = cgi.FieldStorage()

yui = "http://yui.yahooapis.com/2.8.2r1/build"
yui = '"' + "http://localhost/yui2/build"

print "Content-type: text/html; charset=utf-8"
print
print """
<html>
<!-- pillaged from http://developer.yahoo.com/yui/examples/treeview/tv-markup_clean.html -->

<head>


<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>STEDT Semcat Browser</title>

<style type="text/css">
body {
	margin:0;
	padding:10;
}
</style>
<link rel="stylesheet" type="text/css" href=""" + yui + """/fonts/fonts-min.css" />
<link rel="stylesheet" type="text/css" href=""" + yui + """/treeview/assets/skins/sam/treeview.css" />
<link rel="stylesheet" type="text/css" href=""" + yui + """/treeview/assets/css/menu/tree.css"> 
<link rel="stylesheet" type="text/css" href="css/stedt.css" media="screen"/>

<script type="text/javascript" src=""" + yui + """/yahoo-dom-event/yahoo-dom-event.js"></script>
<script type="text/javascript" src=""" + yui + """/treeview/treeview-min.js"></script>

<!--begin custom header content for this example-->
<!--bring in the folder-style CSS for the TreeView Control-->
<link rel="stylesheet" type="text/css" href=""" + yui + """/treeview/assets/treeview-menu.css" />
<!-- Some custom style for the expand/contract section-->
<style>
#expandcontractdiv {border:1px dotted #dedede; background-color:#EBE4F2; margin:0 0 .5em 0; padding:0.4em;}
#stedtDiv { background: #fff; padding:1em; margin-top:1em; }
</style>

<script type="text/javascript"
 src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js"></script>
<script type="text/javascript">  function loadDoc(srchVal){
    $("#main").html('<iframe width="900" height="900" src="http://stedt.berkeley.edu/~jblowe/v1/tagger.pl?submit=Search&lexicon.gloss=' + srchVal + '"/>');
  }
  $(document).ready(function() {
    // This is more like it!
  });
</script>

<!--end custom header content for this example-->

</head>
<body class="yui-skin-sam">

<div class="exampleIntro">
	<p>Using Yahoo's <a href="http://developer.yahoo.com/yui/treeview/">TreeView Control</a> we render the tree of chapters and semcats from the STEDT database.</p>			

</div>
"""


debug = form.getvalue("debug")

# debug
#print cgi.FieldStorage()

if form.getvalue("lookup") == "lookup":
    print "<h2>Lookup </h2>"
    if url != None:
       pass
    else:
        print "please enter something to look up."

elif form.getvalue("url") == None and form.getvalue("text") == None:
    printtree()
    print printrender()
    print 10 * "<br>"

else:

    print printreset()

print footer()
print """
</body>
</html>
"""
