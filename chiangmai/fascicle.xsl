<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" encoding="UTF-8"/>
  <xsl:template match="/">
    <html>
      <head>
	<title>Etymology</title>
	<style type="text/css">
	  <xsl:text>
	    table { 
	    padding-left: 18pt;
	    width: 100%; }

	    html { 
            font-family: "Doulos SIL", "Charis SIL", "Gentium",
		"SILDoulosUnicodeIPA", "Thryomanes",
		"Cardo", "Lucida Grande", "Arial Unicode MS", "Lucida Sans Unicode";
	    font-size: medium;}

	    hr { 
	    width: 100%;
	    text-align: left; }

	    th {
	    text-align: left;
	    color: white;
	    background-color: DarkBlue;
	    font-family: Arial, Helvetica, sans;
	    font-weight: normal; }

	    h1 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 18pt;
	    font-weight: bold; }

	    h2 {
	    text-align: center;
	    font-size: 14pt;
	    font-weight: bold;
	    margin-left: 12pt;
	    }

	    h3 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 12pt;
	    font-weight: bold;
	    margin-left: 10pt; }

	    h4 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 12pt;
	    font-weight: normal;
	    margin-left: 10pt; }

	    span.stedtnum {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 2em 0em 0em;
	    width: 33%; }

	    span.paf {
	    padding: 0em 2em 0em 0em;
	    /* font-style: italic; */
	    width: 33%; }

	    span.pgloss {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 0em 0em 0em;
	    width: 33%; }

	    .lgname {
	    width: 25% }

	    .rn {
	    width: 5% }

	    .analysis {
	    width: 10% }

	    .form {
	    width: 20% }

	    .gloss {
	    width: 20% }

	    .srcabbr {
	    width: 15% }

	    .srcid {
	    width: 10% }

	    div.note {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 90%;
	    }

	    .xref {
	    font-family: Arial, Helvetica, sans;
	    }

	    .reconstruction, .latinform, .form {
            font-family: "Charis SIL", Gentium, Thyromanes, STEDTU;
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

  <xsl:template match="fascicle">
    <xsl:apply-templates select="chapter"/>
  </xsl:template>

  <xsl:template match="chapter">
    <h1>
      <span class="chapternum"><xsl:value-of select="chapternum"/></span>
      <xsl:text> </xsl:text>
      <span class="chaptertitle"><xsl:value-of select="chaptertitle"/></span>
    </h1>
    <h2>
      <xsl:apply-templates select="flowchart"/>
    </h2>
    <xsl:for-each select="etymology">
      <xsl:variable name="tagnum" select="stedtnum"/>
      <h2>
	<span class="stedtnum">(<xsl:value-of select="$tagnum"/>)</span>
	<span class="paf"><xsl:value-of select="paf"/> </span>
	<span class="pgloss"><xsl:value-of select="pgloss"/> </span>
      </h2>
      <h3>Notes</h3>
      <xsl:apply-templates select="desc"/>
      <h3>Reflexes</h3>
      <xsl:for-each select="subgroup">
	<xsl:apply-templates select="."/>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

<xsl:template match="flowchart">
  <xsl:text>Metastatic Flowchart: </xsl:text>
  <img>
    <xsl:attribute name="src">
      <xsl:value-of select="@id" /><xsl:text>.gif</xsl:text>
    </xsl:attribute>
  </img>
</xsl:template>
  
  <xsl:template match="desc">
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
      <span class="sgnum"><xsl:value-of select="sgnum"/></span><xsl:text>.</xsl:text>
      <span class="sgname"><xsl:value-of select="sgname"/></span>
    </h4>
    <table>
      <tr>
	<th>Language</th>
	<th>Rn</th>
	<th>Analysis</th>
	<th>Reflex</th>
	<th>Gloss</th>
	<th>Src Abbr</th>
	<th>Src Id</th>
      </tr>
      <xsl:apply-templates select="reflex"/>
    </table>
  </xsl:template>

  <xsl:template match="reflex">
    <tr>
      <td class="lgname"><xsl:value-of select="lgname"/></td>
      <td class="rn"><xsl:value-of select="rn"/></td>
      <td class="analysis"><xsl:value-of select="analysis"/></td>
      <td class="form"><xsl:apply-templates select="form"/></td>
      <td class="gloss"><xsl:value-of select="gloss"/></td>
      <td class="srcabbr"><xsl:value-of select="srcabbr"/></td>
      <td class="srcid"><xsl:value-of select="srcid"/></td>
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
