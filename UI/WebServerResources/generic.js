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
function getAllScopeElements(scope) {
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

function getAllElements(scope) {
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
function getElementsByClassName2(_tag, _class, _scope) {
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

function URLForFolderID(folderID) {
   var folderInfos = folderID.split(":");
   var url;
   if (folderInfos.length > 1) {
      url = UserFolderURL + "../" + folderInfos[0];
      if (folderInfos[1][0] != '/')
        url += '/';
      url += folderInfos[1];
   }
   else
      url = ApplicationBaseURL + folderInfos[0];
   
   if (url[url.length-1] == '/')
      url = url.substr(0, url.length-1);

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

  var emailNamere = /(.+)\ </;
  if (emailNamere.test(mailTo)) {
    emailNamere.exec(mailTo);
    emailName = RegExp.$1;
  }

  return emailName;
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

function openUserFolderSelector(callback, type) {
   var urlstr = ApplicationBaseURL;
   if (urlstr[urlstr.length-1] != '/')
      urlstr += '/';
   urlstr += ("../../" + UserLogin + "/Contacts/userFolders");
   var w = window.open(urlstr, "User Selector",
		       "width=322,height=250,resizable=1,scrollbars=0");
   w.opener = window;
   w.userFolderCallback = callback;
   w.userFolderType = type;
   w.focus();
}

function openMailComposeWindow(url) {
  var w = window.open(url, null,
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

function checkAjaxRequestsState() {
  var toolbar = document.getElementById("toolbar");
  if (toolbar) {
    if (activeAjaxRequests > 0
        && !document.busyAnim) {
      var anim = document.createElement("img");
      document.busyAnim = anim;
      anim.id = "progressIndicator";
      anim.src = ResourcesURL + "/busy.gif";
      anim.style.visibility = "hidden;";
      toolbar.appendChild(anim);
      anim.style.visibility = "visible;";
    }
    else if (activeAjaxRequests == 0
	     && document.busyAnim) {
      document.busyAnim.parentNode.removeChild(document.busyAnim);
      document.busyAnim = null;
    }
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

function deselectAll(parent) {
  for (var i = 0; i < parent.childNodes.length; i++) {
    var node = parent.childNodes.item(i);
    if (node.nodeType == 1)
      node.deselect();
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
      node.deselect();
    } else {
      node.select();
    }
  } else {
    deselectAll(node.parentNode);
    node.select();
  }

  if (startSelection != node.parentNode.getSelectedNodes()) {
    var parentNode = node.parentNode;
    if (parentNode instanceof HTMLTableSectionElement)
      parentNode = parentNode.parentNode;
    var onSelectionChangeEvent = document.createEvent("Event");
    onSelectionChangeEvent.initEvent("selectionchange", true, true);
    parentNode.dispatchEvent(onSelectionChangeEvent);
  }
}

/* popup menus */

var bodyOnClick = "";
// var acceptClick = false;

function onMenuClick(event, menuId) {
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

function setupMenuTarget(menu, target) {
  menu.menuTarget = target;
  var menus = document.getElementsByClassName("menu", menu);
  for (var i = 0; i < menus.length; i++) {
    menus[i].menuTarget = target;
  }
}

function getParentMenu(node) {
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

function onBodyClick(event) {
  document.currentPopupMenu.menuTarget = null;
  hideMenu(event, document.currentPopupMenu);
  document.body.setAttribute("onclick", bodyOnClick);

  return false;
}

function hideMenu(event, menuNode) {
  var onHide;

//   log('hiding menu "' + menuNode.getAttribute('id') + '"');
  if (menuNode.submenu) {
    hideMenu(event, menuNode.submenu);
    menuNode.submenu = null;
  }

  menuNode.style.visibility = "hidden";
  if (menuNode.parentMenuItem) {
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

function onMenuEntryClick(event, menuId) {
  var node = event.target;

  id = getParentMenu(node).menuTarget;
//   log("clicked " + id + "/" + id.tagName);

  return false;
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
  var logConsole = $("logConsole");
  if (logConsole) {
    logConsole.addEventListener("dblclick", onLogDblClick, false);
    logConsole.innerHTML = "";
    node = document.getElementsByTagName('body')[0];
    node.addEventListener("keydown", onBodyKeyDown, true);
  }
}

function onBodyKeyDown(event) {
  if (event.keyCode == 27) {
    toggleLogConsole();
    event.cancelBubble = true;
    event.returnValue = false;
  }
}

function onLogDblClick(event) {
  var logConsole = $("logConsole");
  logConsole.innerHTML = "";
}

function toggleLogConsole(event) {
  var logConsole = $("logConsole");
  var display = '' + logConsole.style.display;
  if (display.length == 0) {
    logConsole.style.display = 'block;';
  } else {
    logConsole.style.display = '';
  }
  event.cancelBubble = true;
  event.returnValue = false;
  event.preventDefault();
}

function log(message) {
  if (!logWindow) {
    logWindow = window;
    while (logWindow.opener)
      logWindow = logWindow.opener;
  }
  var logConsole = logWindow.document.getElementById("logConsole");
  if (logConsole)
    logConsole.innerHTML += message + '<br />' + "\n";
}

function backtrace() {
   var func = backtrace.caller;
   var str = "backtrace:<br/>";

   while (func)
   {
      if (func.name)
      {
         str += "  " + func.name;
         if (this)
            str += " (" + this + ")";
      }
      else
         str += "[anonymous]\n";

      str += "<br/>";
      func = func.caller;
   }
   str += "--\n";

   return str;
}

function dropDownSubmenu(event) {
  var node = event.target;
  var submenu = node.getAttribute("submenu");
  if (submenu && submenu != "") {
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

function checkDropDown(event) {
  var parentMenu = getParentMenu(event.target);
  var submenuItem = parentMenu.submenuItem;
  if (submenuItem) {
    var menuX = event.clientX - parentMenu.cascadeLeftOffset();
    var menuY = event.clientY - parentMenu.cascadeTopOffset();
    var itemX = submenuItem.offsetLeft;
    var itemY = submenuItem.offsetTop - 75;

    if (menuX >= itemX
        && menuX < itemX + submenuItem.offsetWidth
        && (menuY < itemY
            || menuY > (itemY + submenuItem.offsetHeight))) {
      hideMenu(event, parentMenu.submenu);
      parentMenu.submenu = null;
      parentMenu.submenuItem = null;
      parentMenu.setAttribute('onmousemove', null);
    }
  }
}

/* search field */
function popupSearchMenu(event) {
  var node = event.target;

  var menuId = this.getAttribute("menuid");
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

function setSearchCriteria(event) {
  searchValue = $("searchValue");
  searchCriteria = $("searchCriteria");
  
  var node = event.target;
  searchValue.setAttribute("ghost-phrase", node.innerHTML);
  searchCriteria = node.getAttribute('id');
}

function checkSearchValue(event) {
  var form = event.target;
  var searchValue = $("searchValue");
  var ghostPhrase = searchValue.getAttribute('ghost-phrase');

  if (searchValue.value == ghostPhrase)
    searchValue.value = "";
}

function onSearchChange() {
  log ("onSearchChange()...");
}

function onSearchMouseDown(event) {
   var superNode = this.parentNode.parentNode.parentNode;
   relX = (event.pageX - superNode.offsetLeft - this.offsetLeft);
   relY = (event.pageY - superNode.offsetTop - this.offsetTop);

   if (relY < 24) {
      event.cancelBubble = true;
      event.returnValue = false;
   }
}

function onSearchFocus() {
  ghostPhrase = this.getAttribute("ghost-phrase");
  if (this.value == ghostPhrase) {
    this.value = "";
    this.setAttribute("modified", "");
  } else {
    this.select();
  }

  this.style.color = "#000";
}

function onSearchBlur(event) {
  var ghostPhrase = this.getAttribute("ghost-phrase");
//   log ("search blur: '" + this.value + "'");
  if (!this.value) {
    this.setAttribute("modified", "");
    this.style.color = "#aaa";
    this.value = ghostPhrase;
  } else if (this.value == ghostPhrase) {
    this.setAttribute("modified", "");
    this.style.color = "#aaa";
  } else {
    this.setAttribute("modified", "yes");
    this.style.color = "#000";
  }
}

function onSearchKeyDown(event) {
  if (this.timer)
    clearTimeout(this.timer);

  this.timer = setTimeout("onSearchFormSubmit()", 1000);
}

function initCriteria() {
  var searchCriteria = $("searchCriteria");
  var searchValue = $("searchValue");
  var firstOption;
 
  var searchOptions = $("searchOptions");
  if (searchOptions) {
    firstOption = searchOptions.childNodes[1];
    searchCriteria.value = firstOption.getAttribute('id');
    searchValue.setAttribute('ghost-phrase', firstOption.innerHTML);
    if (searchValue.value == '') {
      searchValue.value = firstOption.innerHTML;
      searchValue.setAttribute("modified", "");
      searchValue.style.color = "#aaa";
    }
  }
}

/* toolbar buttons */
function popupToolbarMenu(event, menuId) {
   var toolbar = $("toolbar");
   var node = event.target;
   if (node.tagName != 'A')
      node = node.getParentWithTagName("a");
   node = node.childNodesWithTag("span")[0];

   if (event.button == 0) {
      event.cancelBubble = true;
      event.returnValue = false;
      
      if (document.currentPopupMenu)
	 hideMenu(event, document.currentPopupMenu);
      
      var popup = document.getElementById(menuId);
      var top = node.offsetTop + node.offsetHeight - 2;
      popup.style.top = top + "px";
      popup.style.left = node.cascadeLeftOffset() + "px";
      popup.style.visibility = "visible";
      
      bodyOnClick = "" + document.body.getAttribute("onclick");
      document.body.setAttribute("onclick", "onBodyClick('" + menuId + "');");
      document.currentPopupMenu = popup;
   }
}

/* contact selector */

function folderSubscriptionCallback(http) {
   if (http.readyState == 4) {
      if (http.status == 204) {
	 if (http.callbackData)
	    http.callbackData["method"](http.callbackData["data"]);
      }
      else
	 window.alert(labels["Unable to subscribe to that folder!"].decodeEntities());
      document.subscriptionAjaxRequest = null;
   }
   else
      log ("ajax fuckage");
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
   var folderData = refreshCallbackData["folder"].split(":");
   var username = folderData[0];
   var folderPath = folderData[1];
   if (username != UserLogin) {
      var url = (UserFolderURL + "../" + username
                 + folderPath + "/subscribe");
      if (document.subscriptionAjaxRequest) {
	 document.subscriptionAjaxRequest.aborted = true;
	 document.subscriptionAjaxRequest.abort();
      }
      var rfCbData = { method: refreshCallback, data: refreshCallbackData };
      document.subscriptionAjaxRequest = triggerAjaxRequest(url,
							    folderSubscriptionCallback,
							    rfCbData);
   }
   else
      window.alert(labels["You cannot subscribe to a folder that you own!"].decodeEntities());
}

function folderUnsubscriptionCallback(http) {
   if (http.readyState == 4) {
      if (http.status == 204) {
	 if (http.callbackData)
	    http.callbackData["method"](http.callbackData["data"]);
      }
      else
	 window.alert(labels["Unable to unsubscribe from that folder!"].decodeEntities());
      document.unsubscriptionAjaxRequest = null;
   }
}

function unsubscribeFromFolder(folder, refreshCallback, refreshCallbackData) {
   if (document.body.hasClassName("popup")) {
      window.opener.unsubscribeFromFolder(folder, refreshCallback, refreshCallbackData);
   }
   else {
      var folderData = folder.split(":");
      var username = folderData[0];
      var folderPath = folderData[1];
      if (username != UserLogin) {
	 var url = (UserFolderURL + "../" + username
		    + "/" + folderPath + "/unsubscribe");
	 if (document.unsubscriptionAjaxRequest) {
	    document.unsubscriptionAjaxRequest.aborted = true;
	    document.unsubscriptionAjaxRequest.abort();
	 }
	 var rfCbData = { method: refreshCallback, data: refreshCallbackData };
	 document.unsubscriptionAjaxRequest = triggerAjaxRequest(url,
								 folderUnsubscriptionCallback,
								 rfCbData);
      }
      else
	 window.alert(labels["You cannot unsubscribe from a folder that you own!"].decodeEntities());
   }
}

function listRowMouseDownHandler(event) {
  event.preventDefault();
}

/* tabs */
function initTabs() {
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

function initMenusNamed(menuDivNames) {
  for (var i = 0; i < menuDivNames.length; i++) {
    var menuDIV = $(menuDivNames[i]);
    if (menuDIV)
      initMenu(menuDIV);
    else
      log("menu named '" + menuDivNames[i] + "' not found");
  }
}

function initMenu(menuDIV) {
  var lis = menuDIV.childNodesWithTag("ul")[0].childNodesWithTag("li");
  for (var j = 0; j < lis.length; j++)
    lis[j].addEventListener("mousedown", listRowMouseDownHandler, false);
  var subMenus = menuDIV.childNodesWithTag("div");
  for (var i = 0; i < subMenus.length; i++)
    initMenu(subMenus[i]);
}

function onTabMouseDown(event) {
  event.cancelBubble = true;
  event.preventDefault();
}

function openExternalLink(anchor) {
  return false;
}

function openAclWindow(url) {
  var w = window.open(url, "aclWindow",
                      "width=300,height=300,resizable=1,scrollbars=1,toolbar=0,"
                      + "location=0,directories=0,status=0,menubar=0"
                      + ",copyhistory=0");
  w.opener = window;
  w.focus();

  return w;
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
  var h = hD.substr(d & 15, 1);

  while (d > 15) {
    d >>= 4;
    h = hD.substr(d & 15, 1) + h;
  }

  return h;
}

function indexColor(number) {
  var color;

  if (number == 0)
    color = "#ccf";
  else {
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
    
    color = ("#"
             + d2h((256 / colorTable[2]) - 1)
             + d2h((256 / colorTable[1]) - 1)
             + d2h((256 / colorTable[0]) - 1));
  }

  return color;
}

var onLoadHandler = {
  handleEvent: function (event) {
    queryParameters = parseQueryParameters('' + window.location);
    if (!document.body.hasClassName("popup")) {
      initLogConsole();
      initializeMenus();
      initCriteria();
    }
    initTabs();
    configureDragHandles();
    configureSortableTableHeaders();
    configureLinkBanner();
    var progressImage = $("progressIndicator");
    if (progressImage)
      progressImage.parentNode.removeChild(progressImage);
  }
}

function configureSortableTableHeaders() {
  var headers = document.getElementsByClassName("sortableTableHeader");
  for (var i = 0; i < headers.length; i++) {
    var anchor = headers[i].childNodesWithTag("a")[0];
    if (!anchor.link) {
      anchor.link = anchor.getAttribute("href");
      anchor.href = "#";
      anchor.addEventListener("click", onHeaderClick, true);
    }
  }
}

function onLinkBannerClick() {
  activeAjaxRequests++;
  checkAjaxRequestsState();
}

function configureLinkBanner() {
  var linkBanner = $("linkBanner");
  if (linkBanner) {
    var anchors = linkBanner.childNodesWithTag("a");
    for (var i = 0; i < 2; i++) {
      anchors[i].addEventListener("mousedown", listRowMouseDownHandler,
                                  false);
      anchors[i].addEventListener("click", onLinkBannerClick, false);
    }
    if (anchors.length > 3)
      anchors[3].addEventListener("click", toggleLogConsole, true);
  }
}

window.addEventListener("load", onLoadHandler, false);

/* stubs */
function configureDragHandles() {
}

function initializeMenus() {
}

function onHeaderClick(event) {
  window.alert("generic headerClick");
}

function parent$(element) {
   return window.opener.document.getElementById(element);
}
