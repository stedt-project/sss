# -*- coding: utf-8 -*-
#
# script to convert Lahu transcriptions (converted to HTML from RTF) into XML..
#
# call something like:
#
# cd ~stedt/public_html/LahuTexts
# ls *.html | python ../genFiles.py >list.csv
#
import sys
import csv
import codecs
import re
import xml.etree.ElementTree as ET

# global hash for word tokens
tokens = {}

def xmlize(htmlfile,xmlfile):
    html = ET.parse(htmlfile)

    # get all the <p> elements. This are the only content we are interested in.
    p = html.findall('body/p')

    # build a tree structure
    xml = ET.Element("doc")
    
    for t in p:
        xml.append(t)
        accumulatetokens(t.text)
        
    tree = ET.ElementTree(xml)
    xf = open(xmlfile,'w')
    print >> xf, '<?xml version="1.0" encoding="UTF-8"?>\n<?xml-stylesheet href="it.xsl" type="text/xsl"?>'

    tree.write(xf, encoding='utf-8')
           #xml_declaration=True,
           #encoding='utf-8',
           #method="xml")

def accumulatetokens(str):

    #str = re.sub(r'(\d)[,](\d)',r'\1\2',str)
    try:
        str = str.encode("utf-8")
    except:
        return
    
    str = re.sub(r'[\.\?\"\,\!\:\;\)\(…]',' ',str)
    str = str.strip()
    p = re.compile(r' ')
    for token in p.split(str):
        tokens[token] = 1 + tokens.setdefault(token, 0)

def makenewfilename(filename):
    
    newfile = filename.replace('.html','')
    newfile = newfile.replace(' ','').lower()
    newfile = re.sub("[\W]", "", newfile)
    newfile = newfile[:20] + '.xml'
    return newfile
    
def genFiles():
    
    for row,filename in enumerate(sys.stdin):
        if not ".html" in filename: continue
        filename = filename.rstrip()
        newfile  = makenewfilename(filename)
        print "%s\t%s\t%s" % (row,filename,newfile)
        xmlize(filename,newfile)
        fmtstr = '<a target="_sound" href="http://localhost/cgi-bin/mediacut.pl?file=%s.mp3&start=%s&end=%s&suffix=.mp3">%s</a>'
        #href = fmtstr % (link[2],mmss2sec(link[3]),mmss2sec(link[4]),link[7])
            
    if False:
        print 'could not process file',catalogfile
        raise
        sys.exit(2)
    
if __name__ == '__main__':
    
  if len(sys.argv) != 1:
    print "Usage: python genFiles.py < FileList > FileFix.sh"
    sys.exit(1)
  
  #fileList = sys.argv[1]

  genFiles()

  for t in tokens:
      print "%s\t%s" % (t,tokens[t])

  
