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
/* some generic JavaScript code for SOGo */

// TODO: replace things with Prototype where applicable

/* generic stuff */

function ml_stripActionInURL(url) {
  if (url[url.length - 1] != '/') {
    var i;
    
    i = url.lastIndexOf("/");
    if (i != -1) url = url.substring(0, i);
  }
  if (url[url.length - 1] != '/') // ensure trailing slash
    url = url + "/";
  return url;
}

/* emails */

var uixEmailUsr = 
  "([a-zA-Z0-9][a-zA-Z0-9_.-]*|\"([^\\\\\x80-\xff\015\012\"]|\\\\[^\x80-\xff])+\")";
var uixEmailDomain = 
  "([a-zA-Z0-9][a-zA-Z0-9._-]*\\.)*[a-zA-Z0-9][a-zA-Z0-9._-]*\\.[a-zA-Z]{2,5}";
var uixEmailRegex = new RegExp("^"+uixEmailUsr+"\@"+uixEmailDomain+"$");

/* escaping */

function escapeHTML(s) {
        s = s.replace(/&/g, "&amp;");
        s = s.replace(/</g, "&lt;");
        s = s.replace(/>/g, "&gt;");
        s = s.replace(/"/g, "&quot;");
        return s;
}
function unescapeHTML(s) {
        s = s.replace(/&lt;/g, "<");
        s = s.replace(/&gt;/g, ">");
        s = s.replace(/&quot;/g, '"');
        s = s.replace(/&amp;/g, "&");
        return s;
}

function createHTTPClient() {
  // http://developer.apple.com/internet/webcontent/xmlhttpreq.html
  if (typeof XMLHttpRequest != "undefined")
    return new XMLHttpRequest();
  
  try { return new ActiveXObject("Msxml2.XMLHTTP"); } 
  catch (e) { }
  try { return new ActiveXObject("Microsoft.XMLHTTP"); } 
  catch (e) { }
  return null;
}

function resetSelection(win) {
  var t = "";
  if (win && win.getSelection) {
    t = win.getSelection().toString();
    win.getSelection().removeAllRanges();
  }
  return t;
}

function refreshOpener() {
  if (window.opener && !window.opener.closed) {
    window.opener.location.reload();
  }
}

/* query string */

function parseQueryString() {
  var queryArray, queryDict
  var key, value, s, idx;
  queryDict.length = 0;
  
  queryDict  = new Array();
  queryArray = location.search.substr(1).split('&');
  for (var i in queryArray) {
    if (!queryArray[i]) continue ;
    s   = queryArray[i];
    idx = s.indexOf("=");
    if (idx == -1) {
      key   = s;
      value = "";
    }
    else {
      key   = s.substr(0, idx);
      value = unescape(s.substr(idx + 1));
    }
    
    if (typeof queryDict[key] == 'undefined')
      queryDict.length++;
    
    queryDict[key] = value;
  }
  return queryDict;
}

function generateQueryString(queryDict) {
  var s = "";
  for (var key in queryDict) {
    if (s.length == 0)
      s = "?";
    else
      s = s + "&";
    s = s + key + "=" + escape(queryDict[key]);
  }
  return s;
}

function getQueryParaArray(s) {
  if (s.charAt(0) == "?") s = s.substr(1, s.length - 1);
  return s.split("&");
}
function getQueryParaValue(s, name) {
  var t;
  
  t = getQueryParaArray(s);
  for (var i = 0; i < t.length; i++) {
    var s = t[i];
    
    if (s.indexOf(name) != 0)
      continue;
    
    s = s.substr(name.length, s.length - name.length);
    return decodeURIComponent(s);
  }
  return null;
}

/* opener callback */

function triggerOpenerCallback() {
  /* this code has some issue if the folder has no proper trailing slash! */
  if (window.opener && !window.opener.closed) {
    var t, cburl;
    
    t = getQueryParaValue(window.location.search, "openerurl=");
    cburl = window.opener.location.href;
    if (cburl[cburl.length - 1] != "/") {
      cburl = cburl.substr(0, cburl.lastIndexOf("/") + 1);
    }
    cburl = cburl + t;
    window.opener.location.href = cburl;
  }
}

/* selection mechanism */

function selectNode(node) {
  var classStr = '' + node.getAttribute('class');

  position = classStr.indexOf('_selected', 0);
  if (position < 0) {
    classStr = classStr + ' _selected';
    node.setAttribute('class', classStr);
  }
}

function deselectNode(node) {
  var classStr = '' + node.getAttribute('class');

  position = classStr.indexOf('_selected', 0);
  while (position > -1) {
    classStr1 = classStr.substring(0, position); 
    classStr2 = classStr.substring(position + 10, classStr.length);
    classStr = classStr1 + classStr2;
    position = classStr.indexOf('_selected', 0);
  }

  node.setAttribute('class', classStr);
}

function deselectAll(parent) {
  for (var i = 0; i < parent.childNodes.length; i++) {
    var node = parent.childNodes.item(i);
    if (node.nodeType == 1) {
      deselectNode(node);
    }
  }
}

function isNodeSelected(node) {
  var classStr = '' + node.getAttribute('class');
  var position = classStr.indexOf('_selected', 0);

  return (position > -1);
}

function acceptMultiSelect(node) {
  var accept = ('' + node.getAttribute('multiselect')).toLowerCase();

  return (accept == 'yes');
}

function getSelection(parentNode) {
  var selArray = new Array();

  for (var i = 0; i < parentNode.childNodes.length; i++) {
    node = parentNode.childNodes.item(i);
    if (node.nodeType == 1
	&& isNodeSelected(node)) {
      selArray.push(i);
    }
  }

  return selArray.join('|');
}

function onRowClick(node, event) {
  var text = document.getElementById('list');
  text.innerHTML = '';

  var startSelection = getSelection(node.parentNode);
  if (event.shiftKey == 1
      && acceptMultiSelect(node.parentNode)) {
    if (isNodeSelected(node) == true) {
      deselectNode(node);
    } else {
      selectNode(node);
    }
  } else {
    deselectAll(node.parentNode);
    selectNode(node);
  }
  if (startSelection != getSelection(node.parentNode)) {
    var code = '' + node.parentNode.getAttribute('onselectionchange');
    if (code.length > 0) {
      node.eval(code);
    }
  }
}
