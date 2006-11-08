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

var logConsole;
var logWindow = null;

var queryParameters;

var activeAjaxRequests = 0;

// logArea = null;
var allDocumentElements = null;

/* a W3C compliant document.all */
function getAllScopeElements(scope)
{
  var elements = new Array();

  for (var i = 0; i < scope.childNodes.length; i++)
    if (typeof(scope.childNodes[i]) == "object"
	&& scope.childNodes[i].tagName
	&& scope.childNodes[i].tagName != '')
      {
	elements.push(scope.childNodes[i]);
	var childElements = getAllElements(scope.childNodes[i]);
	if (childElements.length > 0)
	  elements.push(childElements);
      }

  return elements;
}

function getAllElements(scope)
{
  var elements;

  if (scope == null)
    scope = document;

  if (scope == document
      && allDocumentElements != null)
    elements = allDocumentElements;
  else
    {
      elements = getAllScopeElements(scope);
      if (scope == document)
	allDocumentElements = elements;
    }

  return elements;
}

/* from
   http://www.robertnyman.com/2005/11/07/the-ultimate-getelementsbyclassname/ */
function getElementsByClassName(_tag, _class, _scope) {
  var regexp, classes, elements, element, returnElements;

  _scope = _scope || document;

  elements = (!_tag || _tag == "*"
	      ? getAllElements(null)
	      : _scope.getElementsByTagName(_tag));
  returnElements = [];

  classes = _class.split(/\s+/);
  regexp = new RegExp("(^|\s+)("+ classes.join("|") +")(\s+|$)","i");

  if (_class) {
    for(var i = 0; element = elements[i]; i++) {
      if (regexp.test(element.className)) {
	returnElements.push(element);
      }
    }
    return returnElements;
  } else {
    return elements;
  }
}

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

function extractEmailAddress(mailTo) {
  var email = "";

  var emailre
    = /([a-zA-Z0-9]+[a-zA-Z0-9\._-]+[a-zA-Z0-9]+@[a-zA-Z0-9]+[a-zA-Z0-9\._-]+[a-zA-Z0-9]+)/g;
  if (emailre.test(mailTo)) {
    emailre.exec(mailTo);
    email = RegExp.$1;
  }

  return email;
}

function extractEmailName(mailTo) {
  var emailName = "";

  var emailNamere = /(\w[\w\ _-]+)\ (&lt;|<)/;
  if (emailNamere.test(mailTo)) {
    emailNamere.exec(mailTo);
    emailName = RegExp.$1;
  }
}

function sanitizeMailTo(dirtyMailTo) {
  var emailName = extractEmailName(dirtyMailTo);
  var email = "" + extractEmailAddress(dirtyMailTo);

  var mailto = "";
  if (emailName && emailName.length > 0)
    mailto = emailName + ' <' + email + '>';
  else
    mailto = email;

  return mailto;
}

function openMailComposeWindow(url) {
  w = window.open(url, null,
                  "width=680,height=520,resizable=1,scrollbars=1,toolbar=0,"
                  + "location=0,directories=0,status=0,menubar=0"
                  + ",copyhistory=0");
  w.focus();

  return w;
}

function openMailTo(senderMailto) {
  var mailto = sanitizeMailTo(senderMailto);

  if (mailto.length > 0)
    openMailComposeWindow(ApplicationBaseURL
                          + "/../Mail/compose?mailto=" + mailto);

  return false; /* stop following the link */
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

function triggerAjaxRequest(url, callback, userdata) {
  var http = createHTTPClient();

  activeAjaxRequests += 1;
  document.animTimer = setTimeout("checkAjaxRequestsState();", 200);

  if (http) {
    http.onreadystatechange
      = function() {
//         log ("state changed (" + http.readyState + "): " + url);
        try {
          if (http.readyState == 4
              && activeAjaxRequests > 0) {
                if (!http.aborted) {
                  http.callbackData = userdata;
                  callback(http);
                }
                activeAjaxRequests -= 1;
                checkAjaxRequestsState();
              }
        }
        catch( e ) {
          activeAjaxRequests -= 1;
          checkAjaxRequestsState();
          log("AJAX Request, Caught Exception: " + e.name);
          log(e.message);
        }
      };
    http.url = url;
    http.open("GET", url, true);
    http.send("");
  }

  return http;
}

function checkAjaxRequestsState()
{
  if (activeAjaxRequests > 0
      && !document.busyAnim) {
    var anim = document.createElement("img");
    document.busyAnim = anim;
    anim.setAttribute("src", ResourcesURL + '/busy.gif');
    anim.style.position = "absolute;";
    anim.style.top = "2.5em;";
    anim.style.right = "1em;";
    anim.style.visibility = "hidden;";
    anim.style.zindex = "1;";
    var folderTree = document.getElementById("toolbar");
    folderTree.appendChild(anim);
    anim.style.visibility = "visible;";
  } else if (activeAjaxRequests == 0
	     && document.busyAnim) {
    document.busyAnim.parentNode.removeChild(document.busyAnim);
    document.busyAnim = null;
  }
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
  node.addClassName('_selected');
}

function deselectNode(node) {
//   log ("deselecting a node: '" + node.tagName + "'");
  node.removeClassName('_selected');
}

function deselectAll(parent) {
  for (var i = 0; i < parent.childNodes.length; i++) {
    var node = parent.childNodes.item(i);
    if (node.nodeType == 1)
      deselectNode(node);
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

function onRowClick(event) {
  var node = event.target;
  if (node.tagName == 'TD')
    node = node.parentNode;

  var startSelection = node.parentNode.getSelectedNodes();
  if (event.shiftKey == 1
      && (acceptMultiSelect(node.parentNode)
	  || acceptMultiSelect(node.parentNode.parentNode))) {
    if (isNodeSelected(node) == true) {
      deselectNode(node);
    } else {
      selectNode(node);
    }
  } else {
    deselectAll(node.parentNode);
    selectNode(node);
  }

  if (startSelection != node.parentNode.getSelectedNodes()) {
    var parentNode = node.parentNode;
    if (parentNode.tagName == 'TBODY')
      parentNode = parentNode.parentNode;
    var code = '' + parentNode.getAttribute('onselectionchange');
    if (code.length > 0) {
      node.eval(code);
    }
  }
}

/* popup menus */

var bodyOnClick = "";
// var acceptClick = false;

function onMenuClick(event, menuId)
{
  var node = event.target;

  if (document.currentPopupMenu)
    hideMenu(event, document.currentPopupMenu);

  var popup = document.getElementById(menuId);

  var menuTop = event.pageY;
  var menuLeft = event.pageX;
  var heightDiff = (window.innerHeight
		    - (menuTop + popup.offsetHeight));
  if (heightDiff < 0)
    menuTop += heightDiff;

  var leftDiff = (window.innerWidth
		  - (menuLeft + popup.offsetWidth));
  if (leftDiff < 0)
    menuLeft -= popup.offsetWidth;

  popup.style.top = menuTop + "px;";
  popup.style.left = menuLeft + "px;";
  popup.style.visibility = "visible;";
  setupMenuTarget(popup, node);

  bodyOnClick = "" + document.body.getAttribute("onclick");
  document.body.setAttribute("onclick", "onBodyClick(event);");
  document.currentPopupMenu = popup;

  event.cancelBubble = true;
  event.returnValue = false;

  return false;
}

function setupMenuTarget(menu, target)
{
  menu.menuTarget = target;
  var menus = getElementsByClassName("*", "menu", menu);
  for (var i = 0; i < menus.length; i++) {
    menus[i].menuTarget = target;
  }
}

function getParentMenu(node)
{
  var currentNode, menuNode;

  menuNode = null;
  currentNode = node;
  var menure = new RegExp("(^|\s+)menu(\s+|$)", "i");

  while (menuNode == null
	 && currentNode)
    if (menure.test(currentNode.className))
      menuNode = currentNode;
    else
      currentNode = currentNode.parentNode;

  return menuNode;
}

function onBodyClick(event)
{
  document.currentPopupMenu.menuTarget = null;
  hideMenu(event, document.currentPopupMenu);
  document.body.setAttribute("onclick", bodyOnClick);

  return false;
}

function hideMenu(event, menuNode)
{
  var onHide;

//   log('hiding menu "' + menuNode.getAttribute('id') + '"');
  if (menuNode.submenu)
    {
      hideMenu(event, menuNode.submenu);
      menuNode.submenu = null;
    }

  menuNode.style.visibility = "hidden";
  if (menuNode.parentMenuItem)
    {
      menuNode.parentMenuItem.setAttribute('class', 'submenu');
      menuNode.parentMenuItem = null;
      menuNode.parentMenu.setAttribute('onmousemove', null);
      menuNode.parentMenu.submenuItem = null;
      menuNode.parentMenu.submenu = null;
      menuNode.parentMenu = null;
    }

  var onhideEvent = document.createEvent("Event");
  onhideEvent.initEvent("hideMenu", false, true);
  menuNode.dispatchEvent(onhideEvent);
}

function onMenuEntryClick(event, menuId)
{
  var node = event.target;

  id = getParentMenu(node).menuTarget;
//   log("clicked " + id + "/" + id.tagName);

  return false;
}

function initQueryParameters() {
  queryParameters = parseQueryParameters('' + window.location);
}

function parseQueryParameters(url) {
  var parameters = new Array();

  var params = url.split("?")[1];
  if (params) {
    var pairs = params.split("&");
    for (var i = 0; i < pairs.length; i++) {
      var pair = pairs[i].split("=");
      parameters[pair[0]] = pair[1];
    }
  }

  return parameters;
}

function initLogConsole() {
  var logConsole = document.getElementById('logConsole');
  logConsole.innerHTML = '<a style="-moz-opacity: 1.0; text-decoration: none; float: right; padding: .5em; background: #aaa; color: #333;" id="logConsoleClose" href="#" onclick="return toggleLogConsole();">X</a>';

  var node = document.getElementsByTagName('body')[0];

  node.addEventListener("keydown", onBodyKeyDown, false);
  logConsole.addEventListener("dblclick", onLogDblClick, false);
}

function onBodyKeyDown(event)
{
  if (event.keyCode == 27) {
    toggleLogConsole();
    event.cancelBubble = true;
    event.returnValue = false;
  }
}

function onLogDblClick(event)
{
  var logConsole = document.getElementById('logConsole');
  logConsole.innerHTML = '<a style="-moz-opacity: 1.0; text-decoration: none; float: right; padding: .5em; background: #aaa; color: #333;" id="logConsoleClose" href="#" onclick="return toggleLogConsole();">X</a>';
}

function toggleLogConsole() {
  var logConsole = document.getElementById('logConsole');

  var display = '' + logConsole.style.display;
  if (display.length == 0) {
    logConsole.style.display = 'block;';
  } else {
    logConsole.style.display = '';
  }

  return false;
}

function log(message) {
  if (!logWindow) {
    logWindow = window;
    while (logWindow.opener)
      logWindow = logWindow.opener;
  }
  var logConsole = logWindow.document.getElementById('logConsole');
  logConsole.innerHTML += message + '<br />' + "\n";
}

function dropDownSubmenu(event)
{
  var node = event.target;
  var submenu = node.getAttribute("submenu");
  if (submenu && submenu != "")
    {
      var submenuNode = document.getElementById(submenu);
      var parentNode = getParentMenu(node);
      if (parentNode.submenu)
	hideMenu(event, parentNode.submenu);
      submenuNode.parentMenuItem = node;
      submenuNode.parentMenu = parentNode;
      parentNode.submenuItem = node;
      parentNode.submenu = submenuNode;

      var menuTop = (node.offsetTop - 2);
      
      var heightDiff = (window.innerHeight
			- (menuTop + submenuNode.offsetHeight));
      if (heightDiff < 0)
	menuTop += heightDiff;

      var menuLeft = parentNode.offsetWidth - 3;
      if (window.innerWidth
          < (menuLeft + submenuNode.offsetWidth
             + parentNode.cascadeLeftOffset()))
	menuLeft = -submenuNode.offsetWidth + 3;

      parentNode.setAttribute('onmousemove', 'checkDropDown(event);');
      node.setAttribute('class', 'submenu-selected');
      submenuNode.style.top = menuTop + "px;";
      submenuNode.style.left = menuLeft + "px;";
      submenuNode.style.visibility = "visible;";
    }
}

function checkDropDown(event)
{
  var parentMenu = getParentMenu(event.target);
  var submenuItem = parentMenu.submenuItem;
  if (submenuItem)
    {
      var menuX = event.clientX - parentMenu.cascadeLeftOffset();
      var menuY = event.clientY - parentMenu.cascadeTopOffset();
      var itemX = submenuItem.offsetLeft;
      var itemY = submenuItem.offsetTop - 75;

      if (menuX >= itemX
          && menuX < itemX + submenuItem.offsetWidth
          && (menuY < itemY
              || menuY > (itemY + submenuItem.offsetHeight)))
	{
	  hideMenu(event, parentMenu.submenu);
	  parentMenu.submenu = null;
	  parentMenu.submenuItem = null;
	  parentMenu.setAttribute('onmousemove', null);
	}
    }
}

/* drag handle */

var dragHandle;
var dragHandleOrigX;
var dragHandleOrigLeft;
var dragHandleOrigRight;
var dragHandleOrigY;
var dragHandleOrigUpper;
var dragHandleOrigLower;
var dragHandleDiff;

function startHandleDragging(event) {
  if (event.button == 0) {
    var leftBlock = event.target.getAttribute('leftblock');
    var rightBlock = event.target.getAttribute('rightblock');
    var upperBlock = event.target.getAttribute('upperblock');
    var lowerBlock = event.target.getAttribute('lowerblock');

    dragHandle = event.target;
    if (leftBlock && rightBlock) {
      dragHandle.dhType = 'horizontal';
      dragHandleOrigX = dragHandle.offsetLeft;
      dragHandleOrigLeft = document.getElementById(leftBlock).offsetWidth;
      dragHandleDiff = 0;
      dragHandleOrigRight = document.getElementById(rightBlock).offsetLeft - 5;
      document.body.style.cursor = "e-resize";
    } else if (upperBlock && lowerBlock) {
      dragHandle.dhType = 'vertical';
      var uBlock = document.getElementById(upperBlock);
      var lBlock = document.getElementById(lowerBlock);
      dragHandleOrigY = dragHandle.offsetTop;
      dragHandleOrigUpper = uBlock.offsetHeight;
      dragHandleDiff = event.clientY - dragHandle.offsetTop;
      dragHandleOrigLower = lBlock.offsetTop - 5;
      document.body.style.cursor = "n-resize";
    }

    document.addEventListener('mouseup', stopHandleDragging, true);
    document.addEventListener('mousemove', dragHandleMove, true);

    dragHandleMove(event);
    event.cancelBubble = true;
  }

  return false;
}

function stopHandleDragging(event) {
  if (dragHandle.dhType == 'horizontal') {
    var diffX = Math.floor(event.clientX - dragHandleOrigX
                           - (dragHandle.offsetWidth / 2));
    var lBlock
      = document.getElementById(dragHandle.getAttribute('leftblock'));
    var rBlock
      = document.getElementById(dragHandle.getAttribute('rightblock'));
    
    rBlock.style.left = (dragHandleOrigRight + diffX) + 'px;';
    lBlock.style.width = (dragHandleOrigLeft + diffX) + 'px;';
  } else if (dragHandle.dhType == 'vertical') {
    var diffY = Math.floor(event.clientY - dragHandleOrigY
                           - (dragHandle.offsetHeight / 2));
    var uBlock
      = document.getElementById(dragHandle.getAttribute('upperblock'));
    var lBlock
      = document.getElementById(dragHandle.getAttribute('lowerblock'));

    lBlock.style.top = (dragHandleOrigLower + diffY
                        - dragHandleDiff) + 'px;';
    uBlock.style.height = (dragHandleOrigUpper + diffY - dragHandleDiff) + 'px;';
  }
 
  document.removeEventListener('mouseup', stopHandleDragging, true);
  document.removeEventListener('mousemove', dragHandleMove, true);
  document.body.setAttribute('style', '');
  event.cancelBubble = true;

  dragHandleMove(event);

  return false;
}

function dragHandleMove(event) {
  if (dragHandle.dhType == 'horizontal') {
    var width = dragHandle.offsetWidth;
    var hX = event.clientX;
    if (hX > -1) {
      var newLeft = Math.floor(hX - (width / 2));
      dragHandle.style.left = newLeft + 'px;';
      event.cancelBubble = true;
      
      return false;
    }
  } else if (dragHandle.dhType == 'vertical') {
    var height = dragHandle.offsetHeight;
    var hY = event.clientY;
    if (hY > -1) {
      var newTop = Math.floor(hY - (height / 2))  - dragHandleDiff;
      dragHandle.style.top = newTop + 'px;';
      event.cancelBubble = true;

      return false;
    }
  }
}

function dragHandleDoubleClick(event) {
  dragHandle = event.target;

  if (dragHandle.dhType == 'horizontal') {
    var lBlock
      = document.getElementById(dragHandle.getAttribute('leftblock'));
    var lLeft = lBlock.offsetLeft;
    
    if (dragHandle.offsetLeft > lLeft) {
      var rBlock
        = document.getElementById(dragHandle.getAttribute('rightblock'));
      var leftDiff = rBlock.offsetLeft - dragHandle.offsetLeft;

      dragHandle.style.left = lLeft + 'px;';
      lBlock.style.width = '0px';
      rBlock.style.left = (lLeft + leftDiff) + 'px;';
    }
  } else if (dragHandle.dhType == 'vertical') {
    var uBlock
      = document.getElementById(dragHandle.getAttribute('upperblock'));
    var uTop = uBlock.offsetTop;

    if (dragHandle.offsetTop > uTop) {
      var lBlock
        = document.getElementById(dragHandle.getAttribute('lowerblock'));
      var topDiff = lBlock.offsetTop - dragHandle.offsetTop;
      
      dragHandle.style.top = uTop + 'px;';
      uBlock.style.width = '0px';
      lBlock.style.top = (uTop + topDiff) + 'px;';
    }
  }
}

/* search field */
function popupSearchMenu(event, menuId)
{
  var node = event.target;
  relX = event.pageX - node.cascadeLeftOffset();
  relY = event.pageY - node.cascadeTopOffset();

  if (event.button == 0
      && relX < 24) {
    event.cancelBubble = true;
    event.returnValue = false;

    if (document.currentPopupMenu)
      hideMenu(event, document.currentPopupMenu);

    var popup = document.getElementById(menuId);
    popup.style.top = node.offsetHeight + "px";
    popup.style.left = (node.offsetLeft + 3) + "px";
    popup.style.visibility = "visible";
  
    bodyOnClick = "" + document.body.getAttribute("onclick");
    document.body.setAttribute("onclick", "onBodyClick('" + menuId + "');");
    document.currentPopupMenu = popup;
  }
}

function setSearchCriteria(event)
{
  searchValue = document.getElementById('searchValue');
  searchCriteria = document.getElementById('searchCriteria');
  
  var node = event.target;
  searchValue.setAttribute("ghost-phrase", node.innerHTML);
  searchCriteria = node.getAttribute('id');
}

function checkSearchValue(event)
{
  var form = event.target;
  var searchValue = document.getElementById('searchValue');
  var ghostPhrase = searchValue.getAttribute('ghost-phrase');

  if (searchValue.value == ghostPhrase)
    searchValue.value = "";
}

function onSearchChange()
{
  log ("onSearchChange()...");
}

function onSearchMouseDown(event, searchValue)
{
  superNode = searchValue.parentNode.parentNode.parentNode;
  relX = (event.pageX - superNode.offsetLeft - searchValue.offsetLeft);
  relY = (event.pageY - superNode.offsetTop - searchValue.offsetTop);

  if (relY < 24) {
    event.cancelBubble = true;
    event.returnValue = false;
  }
}

function onSearchFocus(searchValue)
{
  ghostPhrase = searchValue.getAttribute("ghost-phrase");
  if (searchValue.value == ghostPhrase) {
    searchValue.value = "";
    searchValue.setAttribute("modified", "");
  } else {
    searchValue.select();
  }

  searchValue.style.color = "#000";
}

function onSearchBlur(searchValue)
{
  var ghostPhrase = searchValue.getAttribute("ghost-phrase");
//   log ("search blur: '" + searchValue.value + "'");
  if (!searchValue.value) {
    searchValue.setAttribute("modified", "");
    searchValue.style.color = "#aaa";
    searchValue.value = ghostPhrase;
  } else if (searchValue.value == ghostPhrase) {
    searchValue.setAttribute("modified", "");
    searchValue.style.color = "#aaa";
  } else {
    searchValue.setAttribute("modified", "yes");
    searchValue.style.color = "#000";
  }
}

function onSearchKeyDown(searchValue)
{
  if (searchValue.timer)
    clearTimeout(searchValue.timer);

  searchValue.timer = setTimeout("onSearchFormSubmit()", 1000);
}

function initCriteria()
{
  var searchCriteria = document.getElementById('searchCriteria');
  var searchValue = document.getElementById('searchValue');
  var firstOption;
 
  firstOption = document.getElementById('searchOptions').childNodes[1];
  searchCriteria.value = firstOption.getAttribute('id');
  searchValue.setAttribute('ghost-phrase', firstOption.innerHTML);
  if (searchValue.value == '') {
    searchValue.value = firstOption.innerHTML;
    searchValue.setAttribute("modified", "");
    searchValue.style.color = "#aaa";
  }
}
 
/* contact selector */

function onContactAdd(node)
{
  var selector = null;
  var selectorUrl = '?popup=YES';
  if (node) {
    selector = node.parentNode.parentNode;
    selectorUrl += ("&selectorId=" + selector.getAttribute("id"));
  }

  urlstr = ApplicationBaseURL;
  if (urlstr[urlstr.length-1] != '/')
    urlstr += '/';
  urlstr += ("../../" + UserLogin + "/Contacts/"
             + contactSelectorAction + selectorUrl);
//   log (urlstr);
  var w = window.open(urlstr, "Addressbook",
                      "width=640,height=400,resizable=1,scrollbars=0");
  w.selector = selector;
  w.opener = this;
  w.focus();

  return false;
}

function onContactRemove(node) {
  var selector = node.parentNode.parentNode;
  var selectorId = selector.getAttribute("id");
  var hasChanged = false;

  var names = $('uixselector-' + selectorId + '-display');
  var nodes = names.getSelectedNodes();
  hasChanged = (nodes.length > 0);
  for (var i = 0; i < nodes.length; i++) {
    var currentNode = nodes[i];
    currentNode.parentNode.removeChild(currentNode);
  }

  var uids = $('uixselector-' + selectorId + '-uidList');
  nodes = node.parentNode.childNodes;
  var ids = new Array();
  for (var i = 0; i < nodes.length; i++)
    if (nodes[i] instanceof HTMLLIElement)
      ids.push(nodes[i].getAttribute("uid"));
  uids.value = ids.join(",");

  if (selector.changeNotification && hasChanged)
    selector.changeNotification("removal");

  return false;
}

/* tabs */
function initTabs()
{
  var containers = document.getElementsByClassName("tabsContainer");
  for (var x = 0; x < containers.length; x++) {
    var container = containers[x];
    var nodes = container.childNodes[1].childNodes;

    var firstTab;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] instanceof HTMLLIElement) {
        if (!firstTab) {
          firstTab = nodes[i];
        }
        nodes[i].addEventListener("mousedown", onTabMouseDown, true);
        nodes[i].addEventListener("click", onTabClick, true);
      }
    }

    firstTab.addClassName("first");
    firstTab.addClassName("active");
    container.activeTab = firstTab;

    var target = $(firstTab.getAttribute("target"));
    target.addClassName("active");
  }
}

function onTabMouseDown(event) {
  event.cancelBubble = true;
  return false;
}

function openExternalLink(anchor) {
  return false;
}

function onTabClick(event) {
  var node = event.target;

  var target = node.getAttribute("target");

  var container = node.parentNode.parentNode;
  var oldTarget = container.activeTab.getAttribute("target");
  var content = $(target);
  var oldContent = $(oldTarget);

  oldContent.removeClassName("active");
  container.activeTab.removeClassName("active");
  container.activeTab = node;
  container.activeTab.addClassName("active");
  content.addClassName("active");

  return false;
}

function enableAnchor(anchor) {
  var classStr = '' + anchor.getAttribute("class");
  var position = classStr.indexOf("_disabled", 0);
  if (position > -1) {
    var disabledHref = anchor.getAttribute("disabled-href");
    if (disabledHref)
      anchor.setAttribute("href", disabledHref);
    var disabledOnclick = anchor.getAttribute("disabled-onclick");
    if (disabledOnclick)
      anchor.setAttribute("onclick", disabledOnclick);
    anchor.removeClassName("_disabled");
    anchor.setAttribute("disabled-href", null);
    anchor.setAttribute("disabled-onclick", null);
    anchor.disabled = 0;
    anchor.enabled = 1;
  }
}

function disableAnchor(anchor) {
  var classStr = '' + anchor.getAttribute("class");
  var position = classStr.indexOf("_disabled", 0);
  if (position < 0) {
    var href = anchor.getAttribute("href");
    if (href)
      anchor.setAttribute("disabled-href", href);
    var onclick = anchor.getAttribute("onclick");
    if (onclick)
      anchor.setAttribute("disabled-onclick", onclick);
    anchor.addClassName("_disabled");
    anchor.setAttribute("href", "#");
    anchor.setAttribute("onclick", "return false;");
    anchor.disabled = 1;
    anchor.enabled = 0;
  }
}

function d2h(d) {
  var hD = "0123456789abcdef";
  var h = hD.substr(d&15,1);
  while (d>15) {
    d>>=4;
    h=hD.substr(d&15,1)+h;
  }
  return h;
}

function indexColor(number) {
  var colorTable = new Array(1, 1, 1);

  var currentValue = number;
  var index = 0;
  while (currentValue)
    {
      if (currentValue & 1)
        colorTable[index]++;
      if (index == 3)
        index = 0;
      currentValue >>= 1;
      index++;
    }

  return ("#"
          + d2h((256 / colorTable[2]) - 1)
          + d2h((256 / colorTable[1]) - 1)
          + d2h((256 / colorTable[0]) - 1));
}

var onLoadHandler = {
  handleEvent: function (event) {
    initTabs();
    genericInitDnd();
  }
}

window.addEventListener("load", onLoadHandler, false);

/* drag and drop */
document.DNDManager = {
  lastSource: 0,
  lastDestination: 0,
  sources: new Array(),
  destinations: new Array(),
  registerSource: function (source) {
    var id = source.getAttribute("id");
    if (!id) {
      id = "_dndSource" + (this.lastSource + 1);
      source.setAttribute("id", id);
    }
    this.sources[id] = source;
    this.lastSource++;
    if (source instanceof HTMLTableElement) {
      source.addEventListener("draggesture-hack",
                              document.DNDManager.sourceGesture, false);
    }
  },
  registerDestination: function (destination) {
    var id = destination.getAttribute("id");
    if (!id) {
      id = "_dndDestination" + (this.lastDestination + 1);
      destination.setAttribute("id", id);
    }
    this.destinations[id] = destination;
    this.lastDestination++;
  },
  _lookupSource: function (target) {
    var source = null;
    var id = target.getAttribute("id");
    if (id)
      source = document.DNDManager.sources[id];
    return source;
  },
  _lookupDestination: function (target) {
    var destination = null;
    var id = target.getAttribute("id");
    if (id)
      destination = document.DNDManager.destinations[id];
    return destination;
  },
  sourceGesture: function (event) {
    var source = document.DNDManager._lookupSource (event.target);
    if (source)
      document.DNDManager.currentDndOperation = new document.DNDOperation (source);
  },
  destinationEnter: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    var destination = document.DNDManager._lookupDestination (event.target);
    if (operation && destination && destination.dndAcceptType) {
      operation.type = null;
      var i = 0;
      while (operation.type == null
             && i < operation.types.length) {
        if (destination.dndAcceptType(operation.types[i])) {
          operation.type = operation.types[i];
          operation.setDestination(destination);
          if (destination.dndEnter)
            destination.dndEnter(event, operation.source, operation.type);
        }
        else
          i++;
      }
    }
  },
  destinationExit: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    if (operation
        && operation.destination == event.target) {
//       log("exit: " + event.target);
      if (operation.destination.dndExit)
        event.target.dndExit();
      operation.setDestination(null);
    }
  },
  destinationOver: function (event) {
//     var operation = document.DNDManager.currentDndOperation;
//     if (operation
//         && operation.destination == event.target)
//       log("over: " + event.target);
  },
  destinationDrop: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    if (operation) {
      if (operation.ghost)
        operation.bustGhost();
      if (operation.source instanceof HTMLTableElement) {
        window.removeEventListener("mouseup",
                                   document.DNDManager.destinationDrop, false);
        window.removeEventListener("mouseover",
                                   document.DNDManager.destinationEnter, false);
        window.removeEventListener("mousemove",
                                   document.DNDManager.destinationOver, false);
        window.removeEventListener("mouseout",
                                   document.DNDManager.destinationExit, false);
      }
      if (operation.destination == event.target) {
        log("drag / drop: " + operation.source + " to " + operation.destination);
        if (operation.destination.dndExit)
          event.target.dndExit();
        if (operation.destination.dndDrop) {
          var data = operation.source.dndDataForType(operation.type);
          event.target.dndDrop(data);
        }
      }
      document.DNDManager.currentDndOperation = null;
    }
  },
  currentDndOperation: null,
}

document.DNDOperation = function (source) {
  this.source = source;
  if (source.dndTypes) {
    this.types = source.dndTypes();
  }
  this.type = null;
  this.destination = null;
  if (source.dndGhost) {
    var ghost = source.dndGhost();
    ghost.style.position = "absolute;";
    ghost.style.zIndex = 10000;
    ghost.style.MozOpacity = 0.8;
    document.body.appendChild(ghost);
    this.ghost = ghost;

    document.addEventListener("mousemove", this.moveGhost, false);
  }

  return this;
};

document.DNDOperation.prototype.setDestination = function(destination) {
  this.destination = destination;
}

document.DNDOperation.prototype.moveGhost = function(event) {
  var offsetX = event.clientX;
  var offsetY = event.clientY;
  if (document.DNDManager.currentDndOperation.ghost.ghostOffsetX)
    offsetX += document.DNDManager.currentDndOperation.ghost.ghostOffsetX;
  if (document.DNDManager.currentDndOperation.ghost.ghostOffsetY)
    offsetY += document.DNDManager.currentDndOperation.ghost.ghostOffsetY;

  document.DNDManager.currentDndOperation.ghost.style.left = offsetX + "px;";
  document.DNDManager.currentDndOperation.ghost.style.top = offsetY + "px;";
}

document.DNDOperation.prototype.bustGhost = function() {
  document._dyingOperation = this;
  document.removeEventListener("mousemove", this.moveGhost, false);
  this.ghost.bustStep = 10;
  setTimeout("document._dyingOperation._fadeGhost();", 50);
}

document.DNDOperation.prototype._fadeGhost = function() {
  if (this.ghost.bustStep) {
    this.ghost.style.MozOpacity = (0.1 * this.ghost.bustStep);
    this.ghost.bustStep--;
    setTimeout("document._dyingOperation._fadeGhost();", 50);
  }
  else {
    document.body.removeChild(this.ghost);
    this.ghost = null;
  }
}

function genericInitDnd() {
  log ("generic initDnd");
//   var tables = document.getElementsByTagName("table");
  window.addEventListener("draggesture", document.DNDManager.sourceGesture, false);
  window.addEventListener("dragenter", document.DNDManager.destinationEnter, false);
  window.addEventListener("dragexit", document.DNDManager.destinationExit, false);
  window.addEventListener("dragover", document.DNDManager.destinationOver, false);
  window.addEventListener("dragdrop", document.DNDManager.destinationDrop, false);
//   for (var i = 0; i < tables.length; i++) {
//     tables[i].addEventListener("draggesture", document.DNDManager.sourceGesture, false);
//     tables[i].addEventListener("dragstart", document.DNDManager.sourceStart, false);
//     tables[i].addEventListener("dragstop", document.DNDManager.sourceStop, false);
//   }
}
