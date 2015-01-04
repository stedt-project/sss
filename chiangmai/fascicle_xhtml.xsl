<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <html>
      <head>
	<title>Etymology</title>
	<style type="text/css">
	  table { 
	    padding-left: 18pt;
	    width: 90%; }

	  html { 
	    font-family: "Arial Unicode MS","Lucida Sans Unicode";
	    font-size: 12pt; }

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
	    font-weight: bold; }

	  h1 { font-size: 24pt; margin-left: 2pt; }
	  h2 { font-size: 18pt; margin-left: 10pt; }
	  h3 { font-size: 14pt; margin-left: 14pt; }
	  h4 { font-size: 12pt; margin-left: 18pt; }
	  h5 { font-size: 12pt; margin-left: 20pt; }

	  div.etymology {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 90%;
	    }

	  span.seqno {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 2em 0em 0em;
	    width: 33%; }

	  span.num,span.title,span.chapternum {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 1em 0em 0em; }

	  span.stedtnum {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 2em 0em 10em;
	    font-size: 10pt;
	    width: 33%; }

	  span.paf {
	    padding: 0em 2em 0em 0em;
	    /* font-style: italic; */
	    width: 33%; }

	  span.pgloss {
	    font-family: Arial, Helvetica, sans;
	    padding: 0em 0em 0em 0em;
	    width: 33%; }

	  span.cognate {
            font-weight: bold; }

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
	    width: 10% }

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

	  .reconstruction, .latinform {
	  font-weight: bold;
	  text-decoration: underline;
	  }

	</style>
      </head>
      <body>
	<xsl:for-each select="volume">
	  <h1>
	    <span class="num">
	      <xsl:value-of select="num"/>
	    </span>
	    <span class="title">
	      <xsl:value-of select="title"/>
	    </span>
	  </h1>
	  <xsl:for-each select="fascicle">
	    <h2>
	      <span class="num">
		<xsl:value-of select="num"/>
	      </span>
	      <span class="title">
		<xsl:value-of select="title"/>
	      </span>
	    </h2>
	    <xsl:for-each select="chapter">
	      <h3>
		<span class="chapternum">
		  <xsl:value-of select="chapternum"/>
		</span>
		<span class="chaptertitle">
		  <xsl:value-of select="chaptertitle"/>
		</span>
	      </h3>
	      <xsl:for-each select="etymology">
		<div class="etymology">
		  <h3>
		    <span class="seqno"><xsl:value-of select="seqno"/></span>
		    <xsl:variable name="seqno" select="seqno"/>
		    <span class="paf"><xsl:value-of select="paf"/> </span>
		    <span class="pgloss"><xsl:value-of select="pgloss"/> </span>
		    <span class="stedtnum">(<xsl:value-of select="stedtnum"/>)</span>
		    <xsl:variable name="tagnum" select="stedtnum"/>
		  </h3>
		  
		  <h4>Description</h4>
		  
		  <xsl:for-each select="desc">
		    <xsl:for-each select="note">
		      <div class="note">
			<xsl:for-each select="par">
			  <p>
			    <xsl:apply-templates />
			  </p>
			</xsl:for-each>
		      </div>
		    </xsl:for-each>
		  </xsl:for-each>
		  
		  <xsl:for-each select="subgroup">
		    <h5>
		      <span class="sgnum"><xsl:value-of select="sgnum"/></span>. 
		      <span class="sgname"><xsl:value-of select="sgname"/></span>
		    </h5>
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
		      <xsl:for-each select="reflex">
			<tr>
			  <td class="lgname"><xsl:value-of select="lgname"/></td>
			  <td class="rn"><xsl:value-of select="rn"/></td>
			  <td class="analysis"><xsl:value-of select="analysis"/></td>
			  <td class="form">
			    <xsl:for-each select="form">
			      <xsl:apply-templates />
			    </xsl:for-each>
			  </td>
			  <td class="gloss"><xsl:value-of select="gloss"/></td>
			  <td class="srcabbr"><xsl:value-of select="srcabbr"/></td>
			  <td class="srcid"><xsl:value-of select="srcid"/></td>
			</tr>
		      </xsl:for-each>
		    </table>
		  </xsl:for-each>
		</div>
		
	      </xsl:for-each>
	    </xsl:for-each>
	  </xsl:for-each>
	</xsl:for-each>
      </body>
    </html>
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
  
</xsl:stylesheet>
