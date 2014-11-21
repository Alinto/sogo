<?xml version='1.0'?> 
<xsl:stylesheet  
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  version="1.0"> 

<!-- ********************************************************************

     SOGo Documentation Docbook FO Parameters

     This file is part of the SOGo project.
     Authors: 
       - Inverse inc. <info@inverse.ca>

     Copyright (C) 2011-2014 Inverse inc.
     License: GFDL 1.2 or later. http://www.gnu.org/licenses/fdl.html

     ******************************************************************** -->

<!--
    Global Tasks
    
    TODO prettier revhistory
    TODO prettier Table of Contents
    TODO generate PDF table of contents (like OSX's Preview shows on the right hand side)
    TODO title 2
    - align with text?
    - more above whitespace
    TODO change the bullet for a prettier one
    TODO title 3 and 4 
    - align with text?
    - should be easier to differentiate (check network guide)
    TODO icon on line wrap in monospace boxes
    TODO caution, notes, warnings, etc.
    - box around it
    - sexy icon
    TODO -> is converted into an arrow but it's not pretty (is it font or docbook-thingy?)

-->

  <!-- 
      Load default values

      Real upstream schema is at:
      <xsl:import href="http://docbook.sourceforge.net/release/xsl/current/fo/docbook.xsl"/>

      but we decided to load all sensible local xsd since it only produce a warning on missing imports.
  -->
  <!-- CentOS / RHEL -->
  <xsl:import href="/usr/share/sgml/docbook/xsl-stylesheets/fo/docbook.xsl"/>
  <!-- Debian / Ubuntu -->
  <xsl:import href="/usr/share/xml/docbook/stylesheet/docbook-xsl/fo/docbook.xsl"/>
  <!-- OSX through mac ports -->
  <xsl:import href="/opt/local/share/xsl/docbook-xsl/fo/docbook.xsl"/>

  <!-- title page extra styling -->
  <xsl:import href="titlepage-fo.xsl"/>

  <!-- header / footer extra styling -->
  <xsl:import href="headerfooter-fo.xsl"/>

  <!-- attaching an image to the verso legalnotice component -->
  <xsl:template match="legalnotice" mode="book.titlepage.verso.mode">
    <xsl:apply-templates mode="titlepage.mode"/>
    <fo:block text-align="right">
      <fo:external-graphic src="url('images/inverse-logo.jpg')" width="3in" content-width="scale-to-fit"/>
    </fo:block>
  </xsl:template>

  <!-- stylesheet options -->
  <xsl:param name="title.font.family">Lato-Medium</xsl:param>
  <xsl:param name="chapter.autolabel" select="0"/>
  <xsl:attribute-set name="component.title.properties">
    <xsl:attribute name="padding-bottom">2.5em</xsl:attribute>
    <xsl:attribute name="border-bottom">solid 2px</xsl:attribute>
    <xsl:attribute name="margin-bottom">1em</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="section.title.level1.properties">
    <xsl:attribute name="border-bottom">solid 1px</xsl:attribute>
    <xsl:attribute name="margin-top">2em</xsl:attribute>
    <xsl:attribute name="margin-bottom">1em</xsl:attribute>
  </xsl:attribute-set>

  <!-- titles spacing -->
  <xsl:attribute-set name="section.title.level2.properties">
    <xsl:attribute name="margin-top">1em</xsl:attribute>
  </xsl:attribute-set>

  <!-- default fonts -->
  <xsl:param name="body.font.family">Lato-Light</xsl:param>
  <xsl:param name="body.font.master">10</xsl:param>
  <xsl:param name="monospace.font.family">Incosolata</xsl:param>

  <!-- revision table layout -->
  <xsl:attribute-set name="revhistory.title.properties">
    <xsl:attribute name="font-size">12pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
    <xsl:attribute name="text-align">center</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="revhistory.table.properties">
    <xsl:attribute name="break-before">page</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="revhistory.table.cell.properties">
    <xsl:attribute name="border-bottom">1px solid</xsl:attribute>
  </xsl:attribute-set>

  <!-- Table Of Contents (TOC) options -->
  <!-- We only want 2 level of ToC depth -->
  <xsl:param name="toc.section.depth" select="1"/>

  <!-- titles left margin -->
  <xsl:attribute-set name="section.title.properties">
    <xsl:attribute name="start-indent"><xsl:value-of select="$body.start.indent"/></xsl:attribute>
  </xsl:attribute-set>

  <!-- lists type -->
  <xsl:template name="itemizedlist.label.markup">
    <xsl:param name="itemsymbol" select="'square'"/>
    <xsl:choose>
      <xsl:when test="$itemsymbol='square'"><fo:inline font-family="Lato-Light">&#x25aa;</fo:inline></xsl:when>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="next.itemsymbol">
    <xsl:param name="itemsymbol" select="'default'"/>
    <xsl:choose>
      <xsl:otherwise>square</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- admonition -->
  <xsl:param name="admon.graphics" select="1"></xsl:param>
  <xsl:param name="admon.graphics.path">images/</xsl:param>
  <xsl:param name="admon.graphics.extension">.png</xsl:param>
  <xsl:attribute-set name="graphical.admonition.properties">
    <xsl:attribute name="border-top">1px solid</xsl:attribute>
    <xsl:attribute name="border-bottom">1px solid</xsl:attribute>
    <xsl:attribute name="padding-top">0.5em</xsl:attribute>
    <xsl:attribute name="padding-bottom">0.5em</xsl:attribute>
    <xsl:attribute name="margin-left">2em</xsl:attribute>
  </xsl:attribute-set>


  <!-- grey boxes around code (screen, programlisting) -->
  <xsl:param name="shade.verbatim" select="1"/>
  <xsl:attribute-set name="shade.verbatim.style">
    <xsl:attribute name="background-color">#E0E0E0</xsl:attribute>
    <xsl:attribute name="border">thin #9F9F9F solid</xsl:attribute>
    <xsl:attribute name="margin">0pt</xsl:attribute>
    <xsl:attribute name="padding">0.5em</xsl:attribute>
    <!-- prevent page breaks in screen and programlisting tags -->
    <xsl:attribute name="keep-together.within-column">always</xsl:attribute>
  </xsl:attribute-set>

  <!-- breaking long lines in code (screen, programlisting) -->
  <xsl:attribute-set name="monospace.verbatim.properties">
    <xsl:attribute name="wrap-option">wrap</xsl:attribute>
  </xsl:attribute-set>

  <!-- don't show raw links in [ .. ] after a link -->
  <xsl:param name="ulink.show" select="0"/>

  <!-- blue underlined hyperlink -->
  <xsl:attribute-set name="xref.properties">
    <xsl:attribute name="color">blue</xsl:attribute>
    <xsl:attribute name="text-decoration">underline</xsl:attribute>
  </xsl:attribute-set>

  <!-- strong emphasis in bold -->
  <xsl:template match="emphasis[@role='strong']">
    <fo:inline font-family="Lato" font-weight="normal">
      <xsl:apply-templates/>
    </fo:inline>
  </xsl:template>

  <!-- copyright in range instead of seperated years -->
  <xsl:param name="make.year.ranges" select="1" />

  <!-- variablelist behavior (asciidoc's term:: lists) -->
  <!-- <xsl:param name="variablelist.term.break.after" select="1" /> -->

</xsl:stylesheet>
<!-- vim: set shiftwidth=2 tabstop=2 expandtab: -->
