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

    try:
        options.db = MySQLdb.connect(user="root", db="stedt",use_unicode=True,charset="utf8" )
        #options.db = MySQLdb.connect(passwd="PASSWORD", user="stedtuser", host="192.168.100.222", db="stedt")
        #options.cursor=options.db.cursor()

        cursor = options.db.cursor()
        cursor.execute('SET autocommit=1;')
        cursor.execute('SET SESSION wait_timeout=3600;')
        
        MAKEUTF8 = """SET NAMES utf8;
                   SET CHARACTER SET utf8;
                   SET character_set_connection=utf8;"""
        
        cursor.execute(MAKEUTF8)

    except MySQLdb.Error, e:
        return (cgi.escape("MySQL error %d: %s" % (e.args[0], e.args[1])), None)

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
    

    options.db.close()

# "select uniqueid, storydate from story where story_key = %s limit 1"

def qDB(db, sql, skey):
    #print sql % skey
    try:
        c = db.cursor()
        #c.execute(sql, skey)
        c.execute(sql)
        r = c.fetchall()
        c.close()
        return r
    except MySQLdb.Error, e:
        return ("MySQL error: %s" % str(e), None, None)

def getparams():
    """return the input parameters as a plain dictionary,
    (rather than the '.value' system used by the cgi module.)"""
    params = {}
    cgiparams = cgi.FieldStorage()
    for key in cgiparams.keys():
        #print "key, val", key, cgiparams[ key ], "<br \>"
        params[ key ] = cgiparams[ key ].value
    return params

def output_error(err):
    """ output an error message """
    output = """<hr />
    <p >ERROR</p>
    <p style="color:red">%s</p>
    """
    
    print output % err

    
def renderform(params,actiontype):

    #   <h3>%s</h3>

    formstart = """
         <form action="morph.py" method="post">
         <input type="hidden" name="actiontype" size="10" value="%s"/>
         <table border="0">
    """ % (actiontype)
    
    if actiontype == "syllable":

        fields = ("morpheme","tag","initial","rhyme","tone","gloss","language","grp")
        formstart += "<tr><th>"+"</th><th>".join(fields)+"</th></tr><tr>"
        for p in fields:
            formstart += """
            <td><input type="text" name="%s" size="10" value="%s"/></td>""" % (p,params.get(p, ""))

            
    elif actiontype == "morpheme":

        fields = ("morpheme","gloss")
        formstart += "<tr><th>"+"</th><th>".join(fields)+"</th></tr><tr>"
        for p in fields:
            formstart += """
            <td><input type="text" name="%s" size="10" value="%s"/></td>""" % (p,params.get(p, ""))

    formstart += """
            </tr>
            <tr><td>
            <input type="submit" class="button" name="action" value="Search" />
            </td><td>
            <input type="submit" class="button" name="action" value="Reset" />
            </tr></td>
            </form>
            </table>
            
            <br />
            """
    
    return formstart

def disjunction(s1,s2,s3):
    r = []
    for s in s2.split(","):
        r.append(s3 %  (s1,s))
    return "(" + (" or ".join(r)) + ")"

def findsylls(params):
    qparms = []
    for p in params.keys():
        if params[p]:
            if p in ("morpheme","initial","rhyme","tone","tag"):
                print p,params[p],"<br/>"
                qparms.append(disjunction(p,params[p],'%s = "%s"'))
            elif p in ("gloss"):
                print p,params[p],"<br/>"
                qparms.append(disjunction(p,params[p],'%s RLIKE "[[:<:]]%s[[:>:]]"'))    
            elif p in ("language","grp"):
                print p,params[p],"<br/>"
                qparms.append(disjunction(p,params[p],'%s RLIKE "[[:<:]]%s[[:>:]]"'))
    
    class options:
        pass

    options.debug = False
    opendb(options)

    header =  ("morpheme","tag","initial","rhyme","tone","reflex","gloss","grp","language","srcabbr","srcid","lexicon.semcat")
    
    query = "SELECT " + ",".join(header) + """ FROM morphemes,lexicon join languagenames using (lgid)  join languagegroups using(grpid) WHERE (%s AND lexicon.rn=lex_rn ) ORDER BY lexicon.semcat,grpno,gloss,language,morpheme,reflex limit 2000;"""

    # select syll w matching structure from morhemes
    rows = qDB(options.db,(query % " and ".join(qparms)),'')

    #print "query:",(query % (" and ".join(qparms)))

    tableprint(rows,qparms,header)

def findmorphs(params):
    qparms = []
    for p in params.keys():
        if p in ("morpheme","lgid"):
            if params[p]:
                print p,params[p],"<br/>"
                qparms.append(disjunction(p,params[p],'%s = "%s"'))
        elif p in ("gloss"):
            if params[p]:
                print p,params[p],"<br/>"
                qparms.append(disjunction(p,params[p],'%s RLIKE "[[:<:]]%s[[:>:]]"'))
    
    class options:
        pass

    options.debug = False
    opendb(options)
    
    #header =  ("morpheme","reflex","gloss","grp","language","lexicon.lgid","srcabbr","srcid","lexicon.semcat")
    header =  ("morpheme","reflex","analysis","gloss","grp","language","srcabbr","srcid","lexicon.semcat")
    
    query = "SELECT " + ",".join(header) + """ FROM morphemes,lexicon join languagenames using (lgid)  join languagegroups using(grpid) WHERE (%s AND lexicon.rn=lex_rn ) ORDER BY lexicon.semcat,grpno,gloss,language,morpheme,reflex limit 2000;"""

    # select syll w matching structure from morhemes
    rows = qDB(options.db,(query % " and ".join(qparms)),'')

    #print "query:",(query % (" and ".join(qparms)))

    tableprint(rows,qparms,header)


def accum(bits,r,header):
    for b,h in zip(r,header):
        try:
            if not b in bits[h]:  bits[h].append(b)
        except:
            bits[h] = []
            bits[h].append(b)

def tableprint(rows,qparms,header):
    print "<p>result ",("%d" % len(rows))," ".join(qparms),"</p>"
    print "<table>"
    print "<tr><th>","</th><th>".join(header),"</th></tr>"
    bits = {}
    for i,r in enumerate(rows):
        accum(bits,r,header)
        if i < 100:
            print "<tr><td>", "</td><td>".join(r),"</td></tr>"
    print "</table>"

    print """<table border="1" cellpadding="10">"""
    header2 = ("initial","rhyme","tone")
    print "<tr><th>","</th><th>".join(header2),"</th></tr><tr>"
    for i in header2:
        print """<td valign="top">""", "<br/>".join(bits[i]),"</td>"
    print "</tr></table>"
    
    #print bits

def one_page():
    """ output a single page
        (Which page depends on the values of the parameters passed in
        from the browser)
    """
    
    params = getparams()
    action = params.get("actiontype","")
    qtype = params.get("qtype","")
    
    #print params

    if qtype == "Morphemes":
        print renderform(params,"morpheme")
    else:
        print renderform(params,"syllable")
    
    if 'syllable' == action:
        findsylls(params)
    elif 'morpheme' == action:
        findmorphs(params)
    elif 'action' == action:
        pass
    else:
        pass
    
def main():
#    cgitb.enable(display=0, logdir="/finder_debug")
    
    reload(sys)
    sys.setdefaultencoding('utf-8')
    cgitb.enable()

    print "Content-type: text/html; charset=utf-8"
    print
    print """<html>
    <header>
    <link href="../css/header.css" rel="stylesheet" type="text/css" />
    </header>
    <body>
    <title>Etymology Helper</title>
    <table width="100%" border="0">
    <tr>
        <td width="50px"><img src="http://stedt.berkeley.edu/images/STB32x32.gif"/></td>
        <td valign="middle"><b>Etymology Helper</b></td>
        <td>v1.1</td>
    </tr>
    </table>
    """

    keep = """  
    <table>
    <tr><td>
    <form action="morph.py" method="post">
    <input type="submit" class="button" name="qtype" value="Syllable" />
    </td><td>
    <input type="submit" class="button" name="qtype" value="Morphemes" />
    </tr></td>
    </form>
    </table>
    """

    try:
        one_page()
    except():
#        err_msg = traceback.format_exc()
        output_error("Unexpected error" )

    print footer()
    print """
</body>
</html>
"""

if __name__ == "__main__":
    main()
