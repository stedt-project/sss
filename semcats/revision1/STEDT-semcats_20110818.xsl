<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method='html'/>
<xsl:template match="/">
<html>
<head>
<title>STEDT-semcats_20110818</title>
</head>
<body>
<xsl:apply-templates/>
</body>
</html>
</xsl:template>

<xsl:template match="/ROOT">
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="VOLUME[@item='y']">
<xsl:if test="normalize-space(./V.F_old1)">
<xsl:for-each select="./V.F_old1">
<a id="{.}" />
</xsl:for-each></xsl:if>
<xsl:if test="normalize-space(./Number_DWB) or normalize-space(./Label)">
<xsl:text>Volume </xsl:text><xsl:if test="normalize-space(./Number_DWB)"><xsl:text></xsl:text><xsl:value-of select="./Number_DWB"/><xsl:text></xsl:text></xsl:if><xsl:text>: </xsl:text><xsl:if test="normalize-space(./Label)"><xsl:text></xsl:text><xsl:value-of select="./Label"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Semcat_old1) or normalize-space(./V.F_old1) or normalize-space(./Chapter_old1)">
<xsl:text>Cat1 (old): </xsl:text><xsl:if test="normalize-space(./Semcat_old1)"><xsl:text></xsl:text><xsl:value-of select="./Semcat_old1"/><xsl:text></xsl:text></xsl:if><xsl:text> </xsl:text><xsl:if test="normalize-space(./V.F_old1)"><xsl:text></xsl:text><xsl:value-of select="./V.F_old1"/><xsl:text></xsl:text></xsl:if><xsl:text>/</xsl:text><xsl:if test="normalize-space(./Chapter_old1)"><xsl:text></xsl:text><xsl:value-of select="./Chapter_old1"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Semcat_old2) or normalize-space(./V.F_old2) or normalize-space(./Chapter_old2)">
<xsl:text>Cat2 (old): </xsl:text><xsl:if test="normalize-space(./Semcat_old2)"><xsl:text></xsl:text><xsl:value-of select="./Semcat_old2"/><xsl:text></xsl:text></xsl:if><xsl:text> </xsl:text><xsl:if test="normalize-space(./V.F_old2)"><xsl:text></xsl:text><xsl:value-of select="./V.F_old2"/><xsl:text></xsl:text></xsl:if><xsl:text>/</xsl:text><xsl:if test="normalize-space(./Chapter_old2)"><xsl:text></xsl:text><xsl:value-of select="./Chapter_old2"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Note)">
<xsl:text>Note: </xsl:text><xsl:if test="normalize-space(./Note)"><xsl:text></xsl:text><xsl:value-of select="./Note"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<br/>
<div style="margin-left:20px">
<xsl:apply-templates/>
</div>
</xsl:template>

<xsl:template match="DEFAULT[@item='y']">
<xsl:if test="normalize-space(./V.F_old1)">
<xsl:for-each select="./V.F_old1">
<a id="{.}" />
</xsl:for-each></xsl:if>
<xsl:if test="normalize-space(./Number_DWB) or normalize-space(./Label)">
<xsl:if test="normalize-space(./Number_DWB)"><xsl:text></xsl:text><xsl:value-of select="./Number_DWB"/><xsl:text></xsl:text></xsl:if><xsl:text>. </xsl:text><xsl:if test="normalize-space(./Label)"><xsl:text></xsl:text><xsl:value-of select="./Label"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Semcat_old1) or normalize-space(./V.F_old1) or normalize-space(./Chapter_old1)">
<xsl:text>Cat1 (old): </xsl:text><xsl:if test="normalize-space(./Semcat_old1)"><xsl:text></xsl:text><xsl:value-of select="./Semcat_old1"/><xsl:text></xsl:text></xsl:if><xsl:text> </xsl:text><xsl:if test="normalize-space(./V.F_old1)"><xsl:text></xsl:text><xsl:value-of select="./V.F_old1"/><xsl:text></xsl:text></xsl:if><xsl:text>/</xsl:text><xsl:if test="normalize-space(./Chapter_old1)"><xsl:text></xsl:text><xsl:value-of select="./Chapter_old1"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Semcat_old2) or normalize-space(./V.F_old2) or normalize-space(./Chapter_old2)">
<xsl:text>Cat2 (old): </xsl:text><xsl:if test="normalize-space(./Semcat_old2)"><xsl:text></xsl:text><xsl:value-of select="./Semcat_old2"/><xsl:text></xsl:text></xsl:if><xsl:text> </xsl:text><xsl:if test="normalize-space(./V.F_old2)"><xsl:text></xsl:text><xsl:value-of select="./V.F_old2"/><xsl:text></xsl:text></xsl:if><xsl:text>/</xsl:text><xsl:if test="normalize-space(./Chapter_old2)"><xsl:text></xsl:text><xsl:value-of select="./Chapter_old2"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<xsl:if test="normalize-space(./Note)">
<xsl:text>Note: </xsl:text><xsl:if test="normalize-space(./Note)"><xsl:text></xsl:text><xsl:value-of select="./Note"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<br/>
<div style="margin-left:20px">
<xsl:apply-templates/>
</div>
</xsl:template>

<xsl:template match="ROOT[@item='y']">
<xsl:if test="normalize-space(./Name)">
<xsl:for-each select="./Name">
<a id="{.}" />
</xsl:for-each></xsl:if>
<xsl:if test="normalize-space(./Name)">
<xsl:if test="normalize-space(./Name)"><xsl:text></xsl:text><xsl:value-of select="./Name"/><xsl:text></xsl:text></xsl:if><br />
</xsl:if>
<br/>
<div style="margin-left:20px">
<xsl:apply-templates/>
</div>
</xsl:template>

<xsl:template match="*" />

</xsl:stylesheet>
