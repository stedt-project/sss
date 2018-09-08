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

    class options:
        pass

    options.debug = False
    opendb(options)

    # select distinct(chapter) from majorcats order by chapter,subchapter
    # select * from otherchapters where chapter = "5f"
    divs = qDB(options.db, "select * from majorcats order by %s,subchapter",'chapter')
    majordivs = sorted(set([ d[0] for d in divs]))
    print """<outline text="STEDT Semcats">"""

    for i,c in enumerate(majordivs):
        url = "http://stedt.berkeley.edu/~jblowe/v1/tagger.pl?"
        subchaps = filter(lambda s: s[0] == c,divs)
        print """<outline text="Volume %s %s">""" % (subchaps[0][0],subchaps[0][3])
        for d in subchaps:
            print """<outline text="%s%s :: %s :: %s [reflexes=%s]">""" % d[0:5]
            subcats = qDB(options.db, "select * from otherchapters where chapter = %s order by chapter;",''.join(d[0:2]))
            for s in subcats:   
                #parms = urllib.urlencode({'submit' : 'Search', 'lexicon.semcat' : "%s%s/%s" % (d[0],d[1],s[3])})
                parms = urllib.urlencode({'lexicon.semcat' : "%s%s/%s" % (d[0],d[1],s[3])})
                print """<outline url="%s%s" text="%s %s :: (words=%s)">""" % (url,parms,s[3],cgi.escape(s[1]),s[5])
                glosswords = qDB(options.db, "select word from glosswords where subcat = %s ;",('%s/%s' % (s[0],s[3])))
                #print glosswords
                if len(glosswords) == 0:
                    pass
                else:
                    out = "<li><span>"
                    for g in glosswords:
                        parms = urllib.urlencode({'submit' : 'Search', 'lexicon.gloss' : g[0]})
                        out += """<i><a href="%s%s" target="rfx">%s</a></i>, """ % (url,parms,g[0])
                    #print out + "</span></li>"
                print "</outline>"
            print "</outline>"
        print "</outline>"

    print "</outline>"

form = cgi.FieldStorage()


#print "Content-type: text/html; charset=utf-8"
#print
print """<?xml version="1.0" encoding="ISO-8859-1"?>
<?xml-stylesheet type="text/xsl" href="opml.xslt" version="1.0"?>
<opml version="1.0">
	<head>
		<title>STEDT Semcats</title>
		<dateCreated>Mon, 23 Jan 2011 18:02:37 GMT</dateCreated>
		<dateModified>Mon, 23 Jan 2011 18:02:37 GMT</dateModified>
		<ownerName>John Lowe</ownerName>
		<ownerEmail>jblowe@berkeley.edu</ownerEmail>
		<expansionState>5, 12, 20, 28</expansionState>
		<vertScrollState>1</vertScrollState>
		</head>
	<body>
"""
printtree()

print """
</body>
</opml>
"""
