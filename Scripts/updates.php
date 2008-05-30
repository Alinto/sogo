<?php
/* updates.php - this file is part of SOGo
 *
 *  Copyright (C) 2006-2008 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* This script handles the automatic propagation of extensions pertaining to a
   SOGo site */
$plugins
= array( "sogo-connector@inverse.ca"
         => array( "application" => "thunderbird",
                   "version" => "0.67",
                   "filename" => "sogo-connector-0.80.xpi" ),
	 "sogo-integrator@inverse.ca"
	 => array( "application" => "thunderbird",
		   "version" => "0.67",
		   "filename" => "sogo-integrator-0.80-sogo-demo.xpi" ),
	 "{e2fda1a4-762b-4020-b5ad-a41df1933103}" 
	 => array( "application" => "thunderbird",
		   "version" => "0.8",
		   "filename" => "lightning-0.8.xpi" ));

$applications
= array( "thunderbird" => "<em:id>{3550f703-e582-4d05-9a08-453d09bdfdc6}</em:id>
                <em:minVersion>1.5</em:minVersion>
                <em:maxVersion>2.0.*</em:maxVersion>",
	 "firefox" => "<em:id>{ec8030f7-c20a-464f-9b0e-13a3a9e97384}</em:id>
                   <em:minVersion>1.5</em:minVersion>
                   <em:maxVersion>2.0.*</em:maxVersion>" );

$pluginname = $HTTP_GET_VARS["plugin"];
$plugin =& $plugins[$pluginname];
$application =& $applications[$plugin["application"]];

if ( $plugin ) {
  $platform = $HTTP_GET_VARS["platform"];
  if ( $platform
       && file_exists( $platform . "/" . $plugin["filename"] ) ) {
    $plugin["filename"] = $platform . "/" . $plugin["filename"];
  }
  elseif ( !file_exists( $plugin["filename"] ) ) {
    $plugin = false;
  }
}

if ( $plugin ) {
  header("Content-type: text/xml; charset=utf-8");
  echo ('<?xml version="1.0"?>' . "\n");
?>
<!DOCTYPE RDF>
<RDF xmlns="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:em="http://www.mozilla.org/2004/em-rdf#">
  <Description about="urn:mozilla:extension:<?= $pluginname ?>">
    <em:updates>
      <Seq>
        <li>
          <Description>
            <em:version><?= $plugin["version"] ?></em:version>
            <em:targetApplication>
              <Description><?= $applications[$plugin["application"]] ?>
		<em:updateLink>http://inverse.ca/downloads/extensions/<?= $plugin["filename"] ?></em:updateLink>
	      </Description>
            </em:targetApplication>
          </Description>
        </li>
      </Seq>
    </em:updates>
  </Description>
</RDF>
<?php
} else {
  header("Content-type: text/plain; charset=utf-8", true, 404);
  echo( 'Plugin not found' );
}
