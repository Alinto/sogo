/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
/* JavaScript for SOGo Mailer */

var didStop      = false;
var field        = null;
var firstValue   = "";
var isRegistered = false;
var lastKeyPress = null;
var submitAfterMS = 500;

function ml_reloadTableView(searchtext, elementid) {
  var http = createHTTPClient();

  if (http) {
    var viewURL, url;
    var hasQueryPara;

    // TODO: properly parse query parameters    
    viewURL      = this.location.href;
    hasQueryPara = viewURL.indexOf("?") == -1 ? false : true;
    url = (hasQueryPara ? "&" : "?") + "noframe=1&search=";
    url = url + encodeURIComponent(searchtext);
    // alert("GET " + url);
    
    url = viewURL + url;
    http.open("GET", url, false);
    http.send(null);
    if (http.status != 200) {
      alert("Could not reload view.");
    }
    else {
      var tv;

      tv = document.getElementById(elementid)
      tv.innerHTML = http.responseText;
    }
  }
}

function ml_reloadSearchIfFieldChanged() {
  if (field) {
    if (field.value && field.value != firstValue) {
      ml_reloadTableView(field.value, "cl_tableview_reloadroot");
      firstValue = field.value;
    }
  }
}

function ml_timeoutCallback() {
  if (didStop) {
    didStop = false;
    return;
  }
  
  var now = new Date().getTime();
  if ((now - lastKeyPress) < submitAfterMS) {
    setTimeout("ml_timeoutCallback()", 10);
    isRegistered = true;
    return;
  }
  
  ml_reloadSearchIfFieldChanged();
  isRegistered = false;
}

function ml_activateSearchField(sender, _submitTimeout) {
  didStop    = false;
  field      = sender;
  firstValue = field.value;
  submitAfterMS = _submitTimeout;
  return true;
}
function ml_deactivateSearchField(sender) {
  didStop    = true;
  field      = null;
  firstValue = "";
  return true;
}

function ml_searchFieldKeyPressed(sender) {
  lastKeyPress = new Date().getTime();

  if (isRegistered)
    return;
  
  setTimeout("ml_timeoutCallback()", 10);
  isRegistered = true;
  return true;
}
