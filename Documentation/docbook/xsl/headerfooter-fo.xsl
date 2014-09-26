<?xml version='1.0'?>
<xsl:stylesheet  
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  version="1.0">

<!-- ********************************************************************

     Header / Footer customizations

     This file is part of the SOGo project.
     Authors: 
       - Inverse inc. <info@inverse.ca>

     Copyright (C) 2011-2014 Inverse inc.
     License: GFDL 1.2 or later. http://www.gnu.org/licenses/fdl.html

     ******************************************************************** -->

<!--
     Here we are re-defining docbook-xsl/fo/pagesetup.xsl to fit our needs.
     - top: chapter number on the left
     - bottom: copyright, chapter name, page
-->

<xsl:param name="header.rule" select="0"/>

<xsl:template name="header.content">
  <xsl:param name="pageclass" select="''"/>
  <xsl:param name="sequence" select="''"/>
  <xsl:param name="position" select="''"/>
  <xsl:param name="gentext-key" select="''"/>

  <fo:block>
    <!-- sequence can be odd, even, first, blank -->
    <!-- position can be left, center, right -->
    <xsl:choose>
      <xsl:when test="$sequence = 'blank'">
        <!-- nothing -->
      </xsl:when>

      <xsl:when test="($sequence='first' or $sequence='odd' or $sequence='even') and $position='left'">
        <xsl:if test="$pageclass != 'titlepage' and $pageclass != 'lot'">
          <xsl:call-template name="gentext">
            <xsl:with-param name="key" select="'chapter'"/>
          </xsl:call-template>
          <xsl:call-template name="gentext.space"/>
          <xsl:number count="chapter" from="book" level="any"/>
        </xsl:if>
      </xsl:when>

      <!-- draft -->
      <xsl:when test="$position='right'">
        <xsl:call-template name="draft.text"/>
      </xsl:when>

      <xsl:otherwise>
        <!-- nop -->
      </xsl:otherwise>
    </xsl:choose>
  </fo:block>
</xsl:template>

<xsl:param name="footer.rule" select="0"/>
<xsl:template name="footer.content">
  <xsl:param name="pageclass" select="''"/>
  <xsl:param name="sequence" select="''"/>
  <xsl:param name="position" select="''"/>
  <xsl:param name="gentext-key" select="''"/>

  <fo:block>
    <!-- pageclass can be front, body, back -->
    <!-- sequence can be odd, even, first, blank -->
    <!-- position can be left, center, right -->
    <xsl:choose>
      <xsl:when test="$pageclass = 'titlepage'">
        <!-- nop; no footer on title pages -->
      </xsl:when>

      <xsl:when test="$double.sided = 0 and $position='left'">
        <xsl:apply-templates select="//copyright[1]" mode="titlepage.mode"/>
      </xsl:when>

      <xsl:when test="($sequence='first' or $sequence='odd' or $sequence='even') and $position='center'">
        <xsl:if test="$pageclass != 'titlepage' and $pageclass != 'lot'">
          <xsl:apply-templates select="." mode="titleabbrev.markup"/>
        </xsl:if>
      </xsl:when>

      <xsl:when test="$double.sided = 0 and $position='right'">
        <fo:page-number/>
      </xsl:when>

      <xsl:when test="$sequence='blank'">
        <!-- nop -->
      </xsl:when>

      <xsl:otherwise>
        <!-- nop -->
      </xsl:otherwise>
    </xsl:choose>
  </fo:block>
</xsl:template>


</xsl:stylesheet>
<!-- vim: set shiftwidth=2 tabstop=2 expandtab: -->
