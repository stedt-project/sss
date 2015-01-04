<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" encoding="UTF-8"/>
  <xsl:template match="/">
    <html>
      <head>
	<title><xsl:apply-templates select="header"/></title>
	<style type="text/css">
	  <xsl:text>
	    table { 
	    padding-left: 40pt;
	    border: 0px;
	    border-spacing: 0px;
	    width: 100%; }

	    html { 
            font-family: "Arial Unicode MS", "Lucida Sans Unicode","Doulos SIL", "Charis SIL", "Gentium";
	    font-size: small;}

	    hr { 
	    width: 100%;
	    text-align: left; }

	    th {
	    text-align: left;
	    color: white;
	    background-color: DarkBlue;
	    font-family: Arial, Helvetica, sans;
	    font-weight: normal; }

	  h1,h2,h3,h4,h5 {
	    font-family: Arial, Helvetica, sans;
	    margin-top: 0.4em;
	    margin-bottom: 0.1em;
	    font-weight: bold; }

	  h1 { font-size: 24pt; margin-left: 2pt; }
	  h2 { font-size: 18pt; margin-left: 10pt; }
	  h3 { font-size: 14pt; margin-left: 14pt; font-style: italic; }
	  h4 { font-size: 12pt; margin-left: 22pt; }
	  h5 { font-size: 12pt; margin-left: 26pt; }

	  div.etymology {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 95%;
	    }

	  span.num,span.title,span.chapternum {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 4px 0em 0em; }

	  table.etymon {
	    padding-left: 0px;
	    border: 0px;
	    border-spacing: 0px;
	    width: 95%; }

	  td.seqno {
	    font-family: Arial, Helvetica, sans;
	    font-size: 12pt;
	    width: 10%; }

	  td.plg {
	    width: 10%; }

	  td.paf {
	    font-size: 20pt;
	    /* font-style: italic; */
	    width: 25%; }

	  td.pgloss {
	    font-family: Arial, Helvetica, sans;
	    width: 45%; }

	  td.stedtnum {
	    font-family: Arial, Helvetica, sans;
	    font-size: 10pt;
	    width: 10%;
	    text-align: right; }

	    .lgname {
	    width: 8% }

	    .rn {
	    width: 5% }

	    .analysis {
	    width: 10% }

	    .form {
	    width: 10% }

	    .gloss {
	    font-style: italic;
	    width: 10% }

	    .srcabbr {
	    width: 10% }

	    .srcid {
	    width: 8% }

	    div.note {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 90%;
	    }

	    .xref {
	    font-family: Arial, Helvetica, sans;
	    }

	    .reconstruction, .latinform, {
            /* font-style: italic; */
	    }

            .cognate {
            background-color:yellow; /* #99ff99*/
            /*text-decoration: underline;*/
            }

	  </xsl:text>
	</style>
      </head>
      <body>
	<xsl:apply-templates />
      </body>
    </html>
  </xsl:template>

  <xsl:template match="header">
    <xsl:value-of select="num"/><xsl:text>. </xsl:text><xsl:value-of select="title"/>
  </xsl:template>

  <xsl:template match="volume">
    <h1>
      <span class="num">
	<xsl:value-of select="num"/>.
      </span>
      <span class="title">
	<xsl:value-of select="title"/>
      </span>
    </h1>
    <xsl:apply-templates select="fascicle"/>
  </xsl:template>
  
  <xsl:template match="fascicle">
    <h2>
      <span class="num">
	<xsl:value-of select="num"/>.
      </span>
      <span class="title">
	<xsl:value-of select="title"/>
      </span>
    </h2>
    <xsl:apply-templates select="chapter"/>
  </xsl:template>

  <xsl:template match="chapter">
    <h3>
      <span class="chapternum"><xsl:value-of select="chapternum"/></span>
      <xsl:text> </xsl:text>
      <span class="chaptertitle"><xsl:value-of select="chaptertitle"/></span>
    </h3>
    <xsl:apply-templates select="flowchart"/>
    <xsl:for-each select="etymology">
      <xsl:variable name="seqno" select="seqno"/>
      <xsl:variable name="tagnum" select="stedtnum"/>
      <h3>
	<table class="etymon">
	  <tr>
	    <td class="seqno"><xsl:value-of select="$seqno"/></td>
	    <td class="plg"><xsl:value-of select="plg"/> </td>
	    <td class="paf"><xsl:value-of select="paf"/> </td>
	    <td class="pgloss"><xsl:value-of select="pgloss"/> </td>
	    <td class="stedtnum">(<xsl:value-of select="$tagnum"/>)</td>
	  </tr>
	</table>
      </h3>
      <xsl:apply-templates select="desc"/>
      <xsl:for-each select="subgroup">
	<xsl:apply-templates select="."/>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

<xsl:template match="flowchart">
  <h4>
  <xsl:text>Metastatic Flowchart: </xsl:text>
  <img>
    <xsl:attribute name="src">
      <xsl:value-of select="@id" /><xsl:text>.gif</xsl:text>
    </xsl:attribute>
  </img>
  </h4>
</xsl:template>
  
  <xsl:template match="desc">
    <h4>Notes</h4>
    <xsl:for-each select="note">
      <div class="note">
	<xsl:for-each select="par">
	  <p><xsl:apply-templates /></p>
	</xsl:for-each>
      </div>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="hanform">
    <span class="hanform">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="latinform">
    <span class="latinform">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:template match="reconstruction">
    <span class="reconstruction">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <xsl:attribute-set name="reference">
    <xsl:attribute name="href">
      <xsl:text>etymology.pl?tag=</xsl:text>
      <xsl:value-of select="@ref"/>
    </xsl:attribute>
    <xsl:attribute name="class">
      xref
    </xsl:attribute>
  </xsl:attribute-set>

  <xsl:template match="xref">
    <xsl:element name="a" use-attribute-sets="reference">
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="subgroup">
    <h4>
      <span class="sgnum"><xsl:value-of select="sgnum"/></span><xsl:text>. </xsl:text>
      <span class="sgname"><xsl:value-of select="sgname"/></span>
    </h4>
    <table>
      <xsl:apply-templates select="reflex"/>
    </table>
  </xsl:template>

  <xsl:template match="reflex">
    <tr>
      <td class="lgname"><xsl:value-of select="lgname"/></td>
      <td class="form">
	<xsl:attribute name="title">
	  <xsl:text>rn:</xsl:text>
	  <xsl:value-of select="rn"/>
	  <xsl:text>: </xsl:text>
	  <xsl:value-of select='analysis'/>
	</xsl:attribute>
	<xsl:apply-templates select="form"/>
      </td>
      <td class="gloss"><xsl:value-of select="gloss"/></td>
      <td class="srcabbr"><xsl:value-of select="srcabbr"/><xsl:text> </xsl:text><xsl:value-of select="srcid"/></td>
    </tr>
  </xsl:template>

  <xsl:template match="form">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="cognate">
    <span class="cognate">
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

</xsl:stylesheet>
