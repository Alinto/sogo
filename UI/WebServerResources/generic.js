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

/* emails */

var uixEmailUsr = 
  "([a-zA-Z0-9][a-zA-Z0-9_.-]*|\"([^\\\\\x80-\xff\015\012\"]|\\\\[^\x80-\xff])+\")";
var uixEmailDomain = 
  "([a-zA-Z0-9][a-zA-Z0-9._-]*\\.)*[a-zA-Z0-9][a-zA-Z0-9._-]*\\.[a-zA-Z]{2,5}";
var uixEmailRegex = new RegExp("^"+uixEmailUsr+"\@"+uixEmailDomain+"$");

function sanitizeMailTo(dirtyMailTo) {
  var email = "";
  var name = "";

  var emailre
    = /([a-zA-Z0-9]+[a-zA-Z0-9\._-]+[a-zA-Z0-9]+@[a-zA-Z0-9]+[a-zA-Z0-9\._-]+[a-zA-Z0-9]+)/g;
  if (emailre.test(dirtyMailTo)) {
    emailre.exec(dirtyMailTo);
    email = RegExp.$1;
  }

  var namere = /(\w[\w\ _-]+)\ (&lt;|<)/;
  if (namere.test(dirtyMailTo)) {
    namere.exec(dirtyMailTo);
    name = RegExp.$1;
  }

  var mailto = "";
  if (name.length > 0)
    mailto = name + ' <' + email + '>';
  else
    mailto = email;

  return mailto;
}

/* escaping */

function escapeHTML(s) {
        s = s.replace(/&/g, "&amp;");
        s = s.replace(/</g, "&lt;");
        s = s.replace(/>/g, "&gt;");
        s = s.replace(/\"/g, "&quot;");
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

function addClassName(node, className) {
  var classStr = '' + node.getAttribute("class");

  position = classStr.indexOf(className, 0);
  if (position < 0) {
    classStr = classStr + ' ' + className;
    node.setAttribute('class', classStr);
  }
}

function removeClassName(node, className) {
  var classStr = '' + node.getAttribute('class');

  position = classStr.indexOf(className, 0);
  while (position > -1) {
    classStr1 = classStr.substring(0, position); 
    classStr2 = classStr.substring(position + 10, classStr.length);
    classStr = classStr1 + classStr2;
    position = classStr.indexOf(className, 0);
  }

  node.setAttribute('class', classStr);
}

/* selection mechanism */

function selectNode(node) {
  addClassName(node, '_selected');
}

function deselectNode(node) {
  removeClassName(node, '_selected');
}

function deselectAll(parent) {
  for (var i = 0; i < parent.childNodes.length; i++) {
    var node = parent.childNodes.item(i);
    if (node.nodeType == 1) {
      removeClassName(node, '_selected');
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

function getSelectedNodes(parentNode) {
  var selArray = new Array();

  for (var i = 0; i < parentNode.childNodes.length; i++) {
    node = parentNode.childNodes.item(i);
    if (node.nodeType == 1
	&& isNodeSelected(node))
      selArray.push(node);
  }

  return selArray;
}

function onRowClick(event) {
  var node = event.target;
  if (node.tagName == 'TD')
    node = node.parentNode;

  var startSelection = getSelectedNodes(node.parentNode);
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
  if (startSelection != getSelectedNodes(node.parentNode)) {
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

function initLogConsole() {
  logConsole = document.getElementById('logConsole');
  logConsole.innerHTML = '';
}

function toggleLogConsole() {
  var visibility = '' + logConsole.style.visibility;
  if (visibility.length == 0) {
    logConsole.style.visibility = 'visible;';
  } else {
    logConsole.style.visibility = '';
  }

  return false;
}

function log(message) {
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
      var menuTop = (node.parentNode.parentNode.offsetTop
		     + node.offsetTop - 1);
      
      var heightDiff = (window.innerHeight
			- (menuTop + submenuNode.offsetHeight));
      if (heightDiff < 0)
	menuTop += heightDiff;
      var menuLeft = (node.parentNode.parentNode.offsetLeft
		      + node.parentNode.parentNode.offsetWidth
		      - 2);
      var leftDiff = (window.innerWidth
		      - (menuLeft + submenuNode.offsetWidth));
      if (leftDiff < 0)
	menuLeft -= (node.parentNode.parentNode.offsetWidth
		     + submenuNode.offsetWidth
		     - 4);

      submenuNode.parentMenuItem = node;
      submenuNode.parentMenu = parentNode;
      parentNode.submenuItem = node;
      parentNode.submenu = submenuNode;
      parentNode.setAttribute('onmousemove', 'checkDropDown(event);');
      node.setAttribute('class', 'submenu-selected');
      submenuNode.style.top = menuTop + "px;";
      submenuNode.style.left = menuLeft + "px;";
      submenuNode.style.visibility = "visible;";
    }
}

function checkDropDown(event)
{
  var parentNode = getParentMenu(event.target);
  var submenuNode = parentNode.submenu;
  if (submenuNode)
    {
      var submenuItem = parentNode.submenuItem;
      var itemX = submenuItem.offsetLeft + parentNode.offsetLeft;
      var itemY = submenuItem.offsetTop + parentNode.offsetTop;

      if (event.clientX >= itemX
	  && event.clientX < submenuNode.offsetLeft
	  && (event.clientY < itemY
	      || event.clientY > (itemY
				  + submenuItem.offsetHeight)))
	{
	  hideMenu(event, submenuNode);
	  parentNode.submenu = null;
	  parentNode.submenuItem = null;
	  parentNode.setAttribute('onmousemove', null);
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
      dragHandleOrigRight = document.getElementById(rightBlock).offsetLeft;
      document.body.style.cursor = "e-resize";
    } else if (upperBlock && lowerBlock) {
      dragHandle.dhType = 'vertical';
      var uBlock = document.getElementById(upperBlock);
      var lBlock = document.getElementById(lowerBlock);
      dragHandleOrigY = dragHandle.offsetTop;
      dragHandleOrigUpper = uBlock.offsetHeight;
      dragHandleDiff = event.clientY - dragHandle.offsetTop;
      dragHandleOrigLower = lBlock.offsetTop;
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
