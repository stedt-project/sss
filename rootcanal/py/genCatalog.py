import sys
import os
import time
import csv
import codecs
import re

def makenewfilename(filename):
    
    newfile = filename.replace('.html','')
    newfile = newfile.replace(' ','').lower()
    newfile = re.sub("[\W]", "", newfile)
    newfile = newfile[:20] + '.xml'
    return newfile
    
def mmss2sec(str):
    #(h, m, s) = str.split(':')
    #result = int(h) * 3600 + int(m) * 60 + int(s)

    try:
        (m, s) = str.split(':')
    except:
        return str
    
    return "%6.4f" % ( float(int(m) * 60) + float(s) )

def getCatalog(catalogfile):
    print '<h1>Lahu Texts</h1>'
    print '<p><i>as of',time.strftime('%m-%d-%Y %H:%M:%S'),'</i></p>'

    #print '<link rel="stylesheet" href="http://l.yimg.com/pb/media/p/ptw/www/reset-226.css" type="text/css" media="all" />'
    #print '<link rel="stylesheet" href="http://l.yimg.com/pb/media/p/ptw/www/ptw-767.css" type="text/css" media="all" />'

    print '<script type="text/javascript" src="http://webplayer.yahooapis.com/player.js"></script>'

    #print '<script type="text/javascript" src="http://mediaplayer.yahoo.com/js"></script>'
    print "<table>"
    try:
        clog = csv.reader(codecs.open(catalogfile,'rb','utf-8'))
        for row,link in enumerate(clog):
            print "<tr><td>"
            fmtstr = '<a target="_blank" href="http://stedt.berkeley.edu/~stedt/mp3v2/%s.mp3">%s</a>'
            href = fmtstr % (link[0],link[8])
            transcription = makenewfilename(link[8])
            #fmtstr = '<a target="_blank" href="http://stedt.berkeley.edu/~stedt-cgi/mediacut.pl?file=%s.mp3&start=%s&end=%s&suffix=.mp3">%s</a>'
            #href = fmtstr % (link[3],mmss2sec(link[4]),mmss2sec(link[5]),link[8])
            #print 'wget "http://stedt.berkeley.edu/~stedt-cgi/mediacut.pl?file=%s.mp3&start=%s&end=%s&suffix=.mp3" -O  %s.mp3' % (link[3],mmss2sec(link[4]),mmss2sec(link[5]),link[0])
            
            #fmtstr = '<td><b>%s</b><td><embed type="application/x-shockwave-flash" flashvars="audioUrl=http://localhost/cgi-bin/mediacut.pl?file=%s.mp3&start=%s&end=%s" src="http://www.google.com/reader/ui/3523697345-audio-player.swf" width="200" height="27" quality="best"></embed>'
            
            #fmtstr = '<td><b>%s</b><td><embed target="_new" name="plugin" type="audio/mpeg" src="http://localhost/cgi-bin/mediacut.pl?file=%s.mp3&start=%s&end=%s"/>'
            #href = fmtstr % (link[7],link[2],mmss2sec(link[3]),mmss2sec(link[4]))
            if row != 0:
                link[8] = href
                if os.path.isfile("/home/stedt/public_html/LahuTexts/"+transcription):
                    link[10] = '<a href="LahuTexts/%s" target="_text">text</a>' % transcription
                else:
                    link[10] = ''
            else:
                link[10] = 'View'
 
            link[11] = '' 
            #print "<td>".join(link)
            print "<td>".join(link[0:1]+link[3:13])
            print "</tr>"
    except:
        print 'could not process catalog file',catalogfile
        raise
        sys.exit(2)
    
    print "</table>"
    
if __name__ == '__main__':
    
  if len(sys.argv) != 2:
    print "Usage: python genCatalog.py catalogfile"
    sys.exit(1)
  
  catalogfile = sys.argv[1]

  getCatalog(catalogfile)

  
