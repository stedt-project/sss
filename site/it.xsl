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
            font-family: "Charis SIL", Gentium, Thyromanes,
              "Arial Unicode MS","Lucida Sans Unicode";
	    font-size: 14pt; }

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
	    font-size: 24pt;
	    font-weight: bold; }

	  h2 {
	    text-align: center;
	    font-size: 18pt;
	    font-weight: bold;
	    margin-left: 12pt;
	    }

	  h3 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 16pt;
	    font-weight: bold;
	    margin-left: 16pt; }

	  h4 {
	    font-family: Arial, Helvetica, sans;
	    font-size: 14pt;
	    font-weight: normal;
	    margin-left: 18pt; }

	  span.cognate {
            font-weight: bold; }

	  div.note {
	    padding-left: 18pt;
	    text-align: justify;
	    width: 90%;
	    }

	  .xref {
	  font-family: Arial, Helvetica, sans;
	  }

	</style>
      </head>
      <body>
	<xsl:for-each select="doc">
		<table>
		    <tr>
		      <th>ID</th>
		      <th>Sentence</th>
		    </tr>
		  <xsl:for-each select="p">
		    <tr>
		      <td class="id"><xsl:value-of select="@id"/></td>
		      <td class="p"><xsl:value-of select="."/></td>
		    </tr>
		  </xsl:for-each>
		</table>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
