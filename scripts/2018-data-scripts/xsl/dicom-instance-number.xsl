<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="1.0">
  <xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
  <xsl:template match="/">
    <xsl:value-of select="NativeDicomModel/DicomAttribute[@tag = '00200013']/Value[1]"/>
  </xsl:template>
</xsl:stylesheet>
