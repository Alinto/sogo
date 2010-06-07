/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   Copyright (C) 2005 SKYRIX Software AG
   Copyright (C) 2006-2010 Inverse

   This file is part of SOGo

   SOGo is free software; you can redistribute it and/or modify it under
   the terms of the GNU Lesser General Public License as published by the
   Free Software Foundation; either version 2, or (at your option) any
   later version.

   SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
   License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with SOGo; see the file COPYING.  If not, write to the
   Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
   02111-1307, USA.
*/

/* some generic JavaScript code for SOGo */

var logConsole;
var logWindow = null;

var queryParameters;

var menus = new Array();
var search = {};
var sorting = {};

var lastClickedRow = -1;

// logArea = null;
var allDocumentElements = null;

// Alarms
var nextAlarm = null;
var Alarms = new Array();

// Ajax requests counts
var activeAjaxRequests = 0;
var removeFolderRequestCount = 0;

function createElement(tagName, id, classes,
                       attributes, htmlAttributes,
                       parentNode) {
    var newElement = $(document.createElement(tagName));
    if (id)
        newElement.setAttribute("id", id);
    if (classes) {
        if (typeof(classes) == "string")
            newElement.addClassName(classes);
        else
            for (var i = 0; i < classes.length; i++)
                newElement.addClassName(classes[i]);
    }
    if (attributes)
        for (var i in attributes)
            newElement[i] = attributes[i];
    if (htmlAttributes)
        for (var i in htmlAttributes)
            newElement.setAttribute(i, htmlAttributes[i]);
    if (parentNode)
        parentNode.appendChild(newElement);

    return newElement;
}

function URLForFolderID(folderID) {
    var folderInfos = folderID.split(":");
    var url;
    if (folderInfos.length > 1) {
        url = UserFolderURL + "../" + encodeURI(folderInfos[0]);
        if (!(folderInfos[0].endsWith('/')
              || folderInfos[1].startsWith('/')))
            url += '/';
        url += folderInfos[1];
    }
    else {
        var folderInfo = folderInfos[0];
        if (ApplicationBaseURL.endsWith('/')
            && folderInfo.startsWith('/'))
            folderInfo = folderInfo.substr(1);
        url = ApplicationBaseURL + encodeURI(folderInfo);
    }

    if (url[url.length-1] == '/')
        url = url.substr(0, url.length-1);

    return url;
}

function extractEmailAddress(mailTo) {
    var email = "";

    var emailre
        = /(([a-zA-Z0-9\._-]+)*[a-zA-Z0-9_-]+@([a-zA-Z0-9\._-]+)*[a-zA-Z0-9_-]+)/;
    if (emailre.test(mailTo)) {
        emailre.exec(mailTo);
        email = RegExp.$1;
    }

    return email;
}

function extractEmailName(mailTo) {
    var emailName = "";

    var tmpMailTo = mailTo.replace("&lt;", "<");
    tmpMailTo = tmpMailTo.replace("&gt;", ">");

    var emailNamere = /([ 	]+)?(.+)\ </;
    if (emailNamere.test(tmpMailTo)) {
        emailNamere.exec(tmpMailTo);
        emailName = RegExp.$2;
    }

    return emailName;
}

function extractSubject(mailTo) {
    var subject = "";

    var subjectre = /\?subject=([^&]+)/;
    if (subjectre.test(mailTo)) {
        subjectre.exec(mailTo);
        subject = RegExp.$1;
    }

    return subject;
}

function sanitizeMailTo(dirtyMailTo) {
    var emailName = extractEmailName(dirtyMailTo);
    var email = extractEmailAddress(dirtyMailTo);

    var mailto = "";
    if (emailName && emailName.length > 0)
        mailto = emailName + ' <' + email + '>';
    else
        mailto = email;

    return mailto;
}

function sanitizeWindowName(dirtyWindowName) {
    // IE is picky about the characters used for the window name.
    return dirtyWindowName.replace(/[\s\.\/\-\@]/g, "_");
}

function openUserFolderSelector(callback, type) {
    var urlstr = ApplicationBaseURL;
    if (! urlstr.endsWith('/'))
        urlstr += '/';
    urlstr += ("../../" + UserLogin + "/Contacts/userFolders");
    var w = window.open(urlstr, "_blank",
                        "width=322,height=250,resizable=1,scrollbars=0,location=0");
    w.opener = window;
    window.userFolderCallback = callback;
    window.userFolderType = type;
    w.focus();
}

function openContactWindow(url, wId) {
    if (!wId)
        wId = "_blank";
    else
        wId = sanitizeWindowName(wId);

    var w = window.open(url, wId,
                        "width=450,height=530,resizable=0,location=0");
    w.focus();

    return w;
}

function openMailComposeWindow(url, wId) {
    var parentWindow = this;

    if (!wId)
        wId = "_blank";
    else
        wId = sanitizeWindowName(wId);

    if (document.body.hasClassName("popup"))
        parentWindow = window.opener;

    var w = parentWindow.open(url, wId,
                              "width=680,height=520,resizable=1,scrollbars=1,toolbar=0,"
                              + "location=0,directories=0,status=0,menubar=0"
                              + ",copyhistory=0");

    w.focus();

    return w;
}

function openMailTo(senderMailTo) {
    var addresses = senderMailTo.split(",");
    var sanitizedAddresses = new Array();
    var subject = extractSubject(senderMailTo);
    for (var i = 0; i < addresses.length; i++) {
        var sanitizedAddress = sanitizeMailTo(addresses[i]);
        if (sanitizedAddress.length > 0)
            sanitizedAddresses.push(sanitizedAddress);
    }

    var mailto = sanitizedAddresses.join(",");

    if (mailto.length > 0)
        openMailComposeWindow(ApplicationBaseURL
                              + "../Mail/compose?mailto=" + encodeURI(mailto)
                              + ((subject.length > 0)?"?subject=" + encodeURI(subject):""));

    return false; /* stop following the link */
}

function deleteDraft(url) {
    /* this is called by UIxMailEditor with window.opener */
    new Ajax.Request(url, {
        asynchronous: false,
                method: 'post',
                onFailure: function(transport) {
                log("draftDeleteCallback: problem during ajax request: " + transport.status);
            }
    });
}

function refreshFolderByType(type) {
    /* this is called by UIxMailEditor with window.opener */
    if (typeof Mailer != 'undefined' && Mailer.currentMailboxType == type)
        refreshCurrentFolder();
}

function createHTTPClient() {
    return new XMLHttpRequest();
}

function onAjaxRequestStateChange(http) {
    try {
        if (http.readyState == 4
            && activeAjaxRequests > 0) {
            if (!http.aborted)
                http.callback(http);
            activeAjaxRequests--;
            checkAjaxRequestsState();
            http.onreadystatechange = Prototype.emptyFunction;
            http.callback = Prototype.emptyFunction;
            http.callbackData = null;
        }
    }
    catch(e) {
        activeAjaxRequests--;
        checkAjaxRequestsState();
        http.onreadystatechange = Prototype.emptyFunction;
        http.callback = Prototype.emptyFunction;
        http.callbackData = null;
        log("AJAX Request, Caught Exception: " + e.name);
        log(e.message);
        if (e.fileName) {
            if (e.lineNumber)
                log("at " + e.fileName + ": " + e.lineNumber);
            else
                log("in " + e.fileName);
        }
        log(backtrace());
        log("request url was '" + http.url + "'");
    }
}

/* taken from Lightning */
function getContrastingTextColor(bgColor) {
    var calcColor = bgColor.substring(1);
    var red = parseInt(calcColor.substring(0, 2), 16);
    var green = parseInt(calcColor.substring(2, 4), 16);
    var blue = parseInt(calcColor.substring(4, 6), 16);

    // Calculate the brightness (Y) value using the YUV color system.
    var brightness = (0.299 * red) + (0.587 * green) + (0.114 * blue);

    // Consider all colors with less than 56% brightness as dark colors and
    // use white as the foreground color, otherwise use black.
    return ((brightness < 144) ? "white" : "black");
}

function triggerAjaxRequest(url, callback, userdata, content, headers) {
    var http = createHTTPClient();
    if (http) {
        activeAjaxRequests++;
        document.animTimer = setTimeout("checkAjaxRequestsState();", 250);

        http.open("POST", url, true);
        http.url = url;
        http.callback = callback;
        http.callbackData = userdata;
        http.onreadystatechange = function() { onAjaxRequestStateChange(http);};
        //       = function() {
        // //       log ("state changed (" + http.readyState + "): " + url);
        //     };
        var hasContentLength = false;
        if (headers) {
            for (var i in headers) {
                if (i.toLowerCase() == "content-length")
                    hasContentLength = true;
                http.setRequestHeader(i, headers[i]);
            }
        } /*
            if (!hasContentLength) {
            var cLength = "0";
            if (content)
            cLength = "" + content.length;
            http.setRequestHeader("Content-Length", "" + cLength);
            } */
        http.send(content ? content : "");
    }
    else {
        log("triggerAjaxRequest: error creating HTTP Client!");
    }

    return http;
}

function startAnimation(parent, nextNode) {
    var anim = $("progressIndicator");
    if (!anim) {
        anim = createElement("img", "progressIndicator", null,
                             {src: ResourcesURL + "/busy.gif"});
        anim.setStyle({ visibility: "hidden" });
        if (nextNode)
            parent.insertBefore(anim, nextNode);
        else
            parent.appendChild(anim);
        anim.setStyle({ visibility: "visible" });
    }

    return anim;
}

function checkAjaxRequestsState() {
    var progressImage = $("progressIndicator");
    if (activeAjaxRequests > 0
        && !progressImage) {
        var toolbar = $("toolbar");
        if (toolbar)
            startAnimation(toolbar);
    }
    else if (!activeAjaxRequests
             && progressImage)
        progressImage.parentNode.removeChild(progressImage);
}

function isMac() {
    return (navigator.platform.indexOf('Mac') > -1);
}

function isWindows() {
    return (navigator.platform.indexOf('Win') > -1);
}

function isSafari3() {
    return (navigator.appVersion.indexOf("Version") > -1);
}

function isSafari() {
    //var agt = navigator.userAgent.toLowerCase();
    //var is_safari = ((agt.indexOf('safari')!=-1)&&(agt.indexOf('mac')!=-1))?true:false;

    return (navigator.vendor == "Apple Computer, Inc.") || (navigator.userAgent.toLowerCase().indexOf('konqueror') != -1);
}

function isHttpStatus204(status) {
    return (status == 204 ||                                  // Firefox
            (isSafari() && typeof(status) == 'undefined') ||  // Safari
            status == 1223);                                  // IE
}

function getTarget(event) {
    event = event || window.event;
    if (event.target)
        return $(event.target); // W3C DOM
    else
        return $(event.srcElement); // IE
}

function preventDefault(event) {
    if (event) {
        if (event.preventDefault)
            event.preventDefault(); // W3C DOM
        else
            event.returnValue = false; // IE
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

/* selection mechanism */

function eventIsLeftClick(event) {
   var isLeftClick = true;
    if (isMac() && isSafari()) {
        if (event.ctrlKey == 1)
            isLeftClick = false; // Control-click is equivalent to right-click under Mac OS X
        else if (event.metaKey == 1) // Command-click
            isLeftClick = true;
        else
            isLeftClick = Event.isLeftClick(event);
    }
    else {
        isLeftClick = event.isLeftClick();
    }

    return isLeftClick;
}

function deselectAll(parent) {
    for (var i = 0; i < parent.childNodes.length; i++) {
        var node = parent.childNodes.item(i);
        if (node.nodeType == 1)
            $(node).deselect();
    }
}

function isNodeSelected(node) {
    return $(node).hasClassName('_selected');
}

function acceptMultiSelect(node) {
    var response = false;
    var attribute = node.getAttribute('multiselect');
    if (attribute && attribute.length > 0) {
        log("node '" + node.getAttribute("id")
            + "' is still using old-stylemultiselect!");
        response = (attribute.toLowerCase() == 'yes');
    }
    else
        response = node.multiselect;

    return response;
}

function onRowClick(event) {
    var node = Event.element(event);
    var rowIndex = null;

    if (node.tagName != 'TD' && node.tagName != 'LI')
        node = this;

    if (node.tagName == 'TD') {
        node = node.parentNode; // select TR
    }
    if (node.tagName == 'TR') {
        var head = $(node).up('table').down('thead');
        rowIndex = node.rowIndex;
        if (head)
            rowIndex -= head.getElementsByTagName('tr').length;
    }
    else if (node.tagName == 'LI') {
        // Find index of clicked row
        var list = node.parentNode;
        if (list) {
            var items = list.childNodesWithTag("li");
            for (var i = 0; i < items.length; i++) {
                if (items[i] == node) {
                    rowIndex = i;
                    break;
                }
            }
        }
        else
            // No parent; stop here
            return true;
    }

    var initialSelection = $(node.parentNode).getSelectedNodes();

    if (initialSelection.length > 0 
        && initialSelection.indexOf(node) >= 0
        && !eventIsLeftClick(event))
        // Ignore non primary-click (ie right-click) inside current selection
        return true;

    if ((event.shiftKey == 1 || (isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1))
        && (lastClickedRow >= 0)
        && (acceptMultiSelect(node.parentNode)
            || acceptMultiSelect(node.parentNode.parentNode))) {
        if (event.shiftKey) {
            $(node.parentNode).selectRange(lastClickedRow, rowIndex);
        } else if (isNodeSelected(node)) {
            $(node).deselect();
            rowIndex = null;
        } else {
            $(node).selectElement();
        }
        // At this point, should empty content of 3-pane view
    } else {
        // Single line selection
        $(node.parentNode).deselectAll();
        $(node).selectElement();

        if (initialSelection != $(node.parentNode).getSelectedNodes()) {
            // Selection has changed; fire mousedown event
            var parentNode = node.parentNode;
            if (parentNode.tagName == 'TBODY')
                parentNode = parentNode.parentNode;
            parentNode.fire("mousedown");
        }
    }
    if (rowIndex != null)
        lastClickedRow = rowIndex;

    return true;
}

/* popup menus */

function popupMenu(event, menuId, target) {
    document.menuTarget = target;

    if (document.currentPopupMenu)
        hideMenu(document.currentPopupMenu);

    var popup = $(menuId);

    var deltaX = 0;
    var deltaY = 0;

    var pageContent = $("pageContent");
    if (popup.parentNode.tagName != "BODY") {
        var offset = pageContent.cascadeLeftOffset();
        deltaX = -($(popup.parentNode).cascadeLeftOffset() - offset);
        offset = pageContent.cascadeTopOffset();
        deltaY = -($(popup.parentNode).cascadeTopOffset() - offset);
    }

    var menuTop = Event.pointerY(event) + deltaY;
    var menuLeft = Event.pointerX(event) + deltaX;
    var heightDiff = ((window.height() + deltaY)
                      - (menuTop + popup.offsetHeight + 1));
    if (heightDiff < 0)
        menuTop += heightDiff;

    var leftDiff = ((window.width() + deltaX)
                    - (menuLeft + popup.offsetWidth));
    if (leftDiff < 0)
        menuLeft -= (popup.offsetWidth + 1);

    var isVisible = true;
    if (popup.prepareVisibility)
        if (!popup.prepareVisibility())
            isVisible = false;

    Event.stop(event);
    if (isVisible) {
        popup.setStyle({ top: menuTop + "px",
                    left: menuLeft + "px",
                    visibility: "visible" });

        document.currentPopupMenu = popup;

        $(document.body).observe("click", onBodyClickMenuHandler);
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

function onBodyClickMenuHandler(event) {
    hideMenu(document.currentPopupMenu);
    document.body.stopObserving("click", onBodyClickMenuHandler);
    document.body.stopObserving("mouseup", onBodyClickMenuHandler);
    document.currentPopupMenu = null;

    if (event)
        preventDefault(event);
}

function onMenuClickHandler(event) {
    if (!this.hasClassName("disabled"))
        this.menuCallback.apply(this, [event]);
}

function hideMenu(menuNode) {
    var onHide;

    if (!menuNode)
        return;

    if (menuNode.submenu) {
        hideMenu(menuNode.submenu);
        menuNode.submenu = null;
    }

    menuNode.setStyle({ visibility: "hidden" });
    if (menuNode.parentMenuItem) {
        menuNode.parentMenuItem.stopObserving("mouseover",
                                              onMouseEnteredSubmenu);
        menuNode.stopObserving("mouseover",
                               onMouseEnteredSubmenu);
        menuNode.parentMenuItem.stopObserving("mouseout",
                                              onMouseLeftSubmenu);
        menuNode.stopObserving("mouseout",
                               onMouseLeftSubmenu);
        menuNode.parentMenu.stopObserving("mouseover",
                                          onMouseEnteredParentMenu);
        $(menuNode.parentMenuItem).removeClassName("submenu-selected");
        menuNode.parentMenuItem.mouseInside = false;
        menuNode.parentMenuItem = null;
        menuNode.parentMenu.submenuItem = null;
        menuNode.parentMenu.submenu = null;
        menuNode.parentMenu = null;
    }

    $(menuNode).fire("mousedown");
}

function onMenuEntryClick(event) {
    var node = event.target;

    id = getParentMenu(node).menuTarget;

    return false;
}

/* query string */

function generateQueryString(queryDict) {
    var s = "";
    for (var key in queryDict) {
        var value = queryDict[key];
        if (typeof(value) == "string"
            || typeof(value) == "number") {
            if (s.length == 0)
                s = "?";
            else
                s = s + "&";
            s = s + key + "=" + escape(value);
        }
    }
    return s;
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
        logConsole.highlighted = false;
        logConsole.observe("dblclick", onLogDblClick, false);
        logConsole.update();
        Event.observe(window, "keydown", onBodyKeyDown);
    }
}

function onBodyKeyDown(event) {
    if (event.keyCode == Event.KEY_ESC) {
        toggleLogConsole();
        preventDefault(event);
    }
}

function toggleLogConsole(event) {
    var logConsole = $("logConsole");
    var display = '' + logConsole.style.display;
    if (display.length == 0) {
        logConsole.setStyle({ display: 'block' });
    } else {
        logConsole.setStyle({ display: '' });
    }
    if (event)
        preventDefault(event);
}

function log(message) {
    if (!logWindow) {
        logWindow = window;
        while (logWindow.opener)
            logWindow = logWindow.opener;
    }
    var logConsole = logWindow.document.getElementById("logConsole");
    if (logConsole) {
        if (message == "\c") {
            while (logConsole.firstChild) {
                logConsole.removeChild(logConsole.firstChild);
            }
            return;
        }
        if (message[message.length-1] == "\n") {
            message = message.substr(0, message.length-2);
        }
        var lines = message.split("\n");
        for (var i = 0; i < lines.length; i++) {
            logConsole.appendChild(document.createTextNode(lines[i]));
            logConsole.appendChild(createElement("br"));
        }
        logConsole.scrollTop += 300; /* abritrary number */
    }
}

function logOnly(message) {
    log("\c");
    log(message);
}

function onLogDblClick(event) {
    log("\c");
}

function backtrace() {
    var func = backtrace.caller;
    var str = "backtrace:\n";

    while (func) {
        if (func.name) {
            str += "  " + func.name;
            if (this)
                str += " (" + this + ")";
        }
        else
            str += "[anonymous]\n";

        str += "\n";
        func = func.caller;
    }
    str += "--\n";

    return str;
}

function popupSubmenu(event) {
    if (this.submenu && this.submenu != "" && !$(this).hasClassName("disabled")) {
        var submenuNode = $(this.submenu);
        var parentNode = getParentMenu(this);
        if (parentNode.submenu)
            hideMenu(parentNode.submenu);
        submenuNode.parentMenuItem = this;
        submenuNode.parentMenu = parentNode;
        parentNode.submenuItem = this;
        parentNode.submenu = submenuNode;

        if (submenuNode.prepareVisibility)
            submenuNode.prepareVisibility();

        var menuTop = (parentNode.offsetTop - 1
                       + this.offsetTop);

        if (window.height()
            < (menuTop + submenuNode.offsetHeight))
            if (submenuNode.offsetHeight < window.height())
                menuTop = window.height() - submenuNode.offsetHeight;
            else
                menuTop = 0;

        var menuLeft = (parentNode.offsetLeft + parentNode.offsetWidth - 3);
        if (window.width()
            < (menuLeft + submenuNode.offsetWidth))
            menuLeft = parentNode.offsetLeft - submenuNode.offsetWidth + 3;

        this.mouseInside = true;
        this.observe("mouseover", onMouseEnteredSubmenu);
        submenuNode.observe("mouseover", onMouseEnteredSubmenu);
        this.observe("mouseout", onMouseLeftSubmenu);
        submenuNode.observe("mouseout", onMouseLeftSubmenu);
        parentNode.observe("mouseover", onMouseEnteredParentMenu);
        $(this).addClassName("submenu-selected");
        submenuNode.setStyle({ top: menuTop + "px",
                    left: menuLeft + "px",
                    visibility: "visible" });
        preventDefault(event);
    }
}

function onMouseEnteredParentMenu(event) {
    if (this.submenuItem && !this.submenuItem.mouseInside)
        hideMenu(this.submenu);
}

function onMouseEnteredSubmenu(event) {
    $(this).mouseInside = true;
}

function onMouseLeftSubmenu(event) {
    $(this).mouseInside = false;
}

/* search field */
function popupSearchMenu(event) {
    var menuId = this.getAttribute("menuid");
    var offset = Position.cumulativeOffset(this);

    relX = Event.pointerX(event) - offset[0];
    relY = Event.pointerY(event) - offset[1];

    if (event.button == 0
        && relX < 24) {
        event.cancelBubble = true;
        event.returnValue = false;

        if (document.currentPopupMenu)
            hideMenu(document.currentPopupMenu);

        var popup = $(menuId);
        offset = Position.positionedOffset(this);
        popup.setStyle({ top: this.offsetHeight + "px",
                    left: (offset[0] + 3) + "px",
                    visibility: "visible" });

        document.currentPopupMenu = popup;
        $(document.body).observe("click", onBodyClickMenuHandler);
    }
}

function setSearchCriteria(event) {
    var searchValue = $("searchValue");
    var searchCriteria = $("searchCriteria");

    if (searchValue.ghostPhrase == searchValue.value)
        searchValue.value = this.innerHTML;

    searchValue.ghostPhrase = this.innerHTML;
    searchCriteria.value = this.getAttribute('id');

    if (this.parentNode.chosenNode)
        this.parentNode.chosenNode.removeClassName("_chosen");
    this.addClassName("_chosen");

    if (this.parentNode.chosenNode != this) {
        searchValue.lastSearch = "";
        this.parentNode.chosenNode = this;

        onSearchFormSubmit();
    }
}

function checkSearchValue(event) {
    var searchValue = $("searchValue");

    if (searchValue.value == searchValue.ghostPhrase)
        searchValue.value = "";
}

function configureSearchField() {
    var searchValue = $("searchValue");

    if (searchValue) {
        searchValue.observe("click", popupSearchMenu);
        searchValue.observe("blur", onSearchBlur);
        searchValue.observe("focus", onSearchFocus);
        searchValue.observe("keydown", onSearchKeyDown);
        searchValue.observe("mousedown", onSearchMouseDown);
    }
}

function onSearchMouseDown(event) {
    var superNode = this.parentNode.parentNode.parentNode;
    relX = (Event.pointerX(event) - superNode.offsetLeft - this.offsetLeft);
    relY = (Event.pointerY(event) - superNode.offsetTop - this.offsetTop);

    if (relX < 24)
        Event.stop(event);
}

function onSearchFocus(event) {
    ghostPhrase = this.ghostPhrase;
    if (this.value == ghostPhrase) {
        this.value = "";
        this.setAttribute("modified", "");
    } else {
        this.selectElement();
    }

    this.setStyle({ color: "#535D6D" });
}

function onSearchBlur(event) {
    if (!this.value || this.value.blank()) {
        this.setAttribute("modified", "");
        this.setStyle({ color: "#909090" });
        this.value = this.ghostPhrase;
        if (this.timer)
            clearTimeout(this.timer);
        search["value"] = "";
        if (this.lastSearch != "") {
            this.lastSearch = "";
            refreshCurrentFolder();
        }
    } else if (this.value == this.ghostPhrase) {
        this.setAttribute("modified", "");
        this.setStyle({ color: "#909090" });
    } else {
        this.setAttribute("modified", "yes");
        this.setStyle({ color: "#535D6D" });
    }
}

function IsCharacterKey(keyCode) {
    return (keyCode == 32 /* space */
            || (keyCode > 47 && keyCode < 58) /* digits */
            || (keyCode > 64 && keyCode < 91) /* letters */
            || (keyCode > 95 && keyCode < 112) /* numpad digits */
            || (keyCode > 186 && keyCode < 193)
            || (keyCode > 218 && keyCode < 223));
}

function onSearchKeyDown(event) {
    if (event.keyCode == Event.KEY_RETURN) {
        if (this.timer)
            clearTimeout(this.timer);
        onSearchFormSubmit();
        preventDefault(event);
    }
    else if (event.keyCode == Event.KEY_BACKSPACE
             || IsCharacterKey(event.keyCode)) {
        if (this.timer)
            clearTimeout(this.timer);
        this.timer = setTimeout("onSearchFormSubmit()", 500);
    }
}

function onSearchFormSubmit(event) {
    var searchValue = $("searchValue");
    var searchCriteria = $("searchCriteria");

    if (searchValue.value != searchValue.ghostPhrase
        && (searchValue.value != searchValue.lastSearch
            || searchValue.value.strip().length > 0)) {
        search["criteria"] = searchCriteria.value;
        search["value"] = searchValue.value;
        searchValue.lastSearch = searchValue.value;
        refreshCurrentFolder();
    }
}

function initCriteria() {
    var searchCriteria = $("searchCriteria");
    var searchValue = $("searchValue");
    var searchOptions = $("searchOptions");

    if (searchValue) {
        var firstOption = searchOptions.down("li");
        if (firstOption) {
            searchCriteria.value = firstOption.getAttribute('id');
            searchValue.ghostPhrase = firstOption.innerHTML;
            searchValue.lastSearch = "";
            if (searchValue.value == '') {
                searchValue.value = firstOption.innerHTML;
                searchValue.setAttribute("modified", "");
                searchValue.setStyle({ color: "#909090" });
            }
            // Set the checkmark to the first option
            if (searchOptions.chosenNode)
                searchOptions.chosenNode.removeClassName("_chosen");
            firstOption.addClassName("_chosen");
            searchOptions.chosenNode = firstOption;
        }
        searchValue.blur();
    }
}

/* toolbar buttons */
function popupToolbarMenu(node, menuId) {
    if (document.currentPopupMenu)
        hideMenu(document.currentPopupMenu);

    var popup = $(menuId);
    if (popup.prepareVisibility)
        popup.prepareVisibility();

    var offset = $(node).cumulativeOffset();
    var top = offset.top + node.offsetHeight;
    popup.setStyle({ top: top + "px",
                     left: offset.left + "px",
                     visibility: "visible" });

    document.currentPopupMenu = popup;
    $(document.body).observe("mouseup", onBodyClickMenuHandler);
}

/* contact selector */

function folderSubscriptionCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            if (http.callbackData)
                http.callbackData["method"](http.callbackData["data"]);
        }
        else
            window.alert(_("Unable to subscribe to that folder!"));
        document.subscriptionAjaxRequest = null;
    }
    else
        log ("folderSubscriptionCallback Ajax error");
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
        refreshCallbackData["window"].alert(_("You cannot subscribe to a folder that you own!"));
}

function folderUnsubscriptionCallback(http) {
    if (http.readyState == 4) {
        removeFolderRequestCount--;
        if (isHttpStatus204(http.status)) {
            if (http.callbackData)
                http.callbackData["method"](http.callbackData["data"]);
        }
        else
            window.alert(_("Unable to unsubscribe from that folder!"));
    }
}

function unsubscribeFromFolder(folderUrl, owner, refreshCallback,
                               refreshCallbackData) {
    if (document.body.hasClassName("popup")) {
        window.opener.unsubscribeFromFolder(folderUrl, owner, refreshCallback,
                                            refreshCallbackData);
    }
    else {
        if (owner.charAt(0) == '/')
            owner = owner.substring(1);
        if (owner != UserLogin) {
            var url = folderUrl + "/unsubscribe";
            removeFolderRequestCount++;
            var rfCbData = { method: refreshCallback, data: refreshCallbackData };
            triggerAjaxRequest(url, folderUnsubscriptionCallback, rfCbData);
        }
        else
            window.alert(_("You cannot unsubscribe from a folder that you own!"));
    }
}

function accessToSubscribedFolder(serverFolder) {
    var folder;

    var parts = serverFolder.split(":");
    if (parts.length > 1) {
        var paths = parts[1].split("/");
        folder = "/" + parts[0].asCSSIdentifier() + "_" + paths[2];
    }
    else
        folder = serverFolder;

    return folder;
}

function getSubscribedFolderOwner(serverFolder) {
    var owner;

    var parts = serverFolder.split(":");
    if (parts.length > 1) {
        owner = parts[0];
    }

    return owner;
}

function getListIndexForFolder(items, owner, folderName) {
    var i;
    var previousOwner = null;

    for (var i = 0; i < items.length; i++) {
        var currentFolderName = items[i].lastChild.nodeValue.strip();
        var currentOwner = items[i].readAttribute('owner');
        if (currentOwner == owner) {
            previousOwner = currentOwner;
            if (currentFolderName > folderName)
                break;
        }
        else if (previousOwner || 
                 (currentOwner != UserLogin && currentOwner > owner))
            break;
        else if (currentOwner == "nobody")
            break;
    }

    return i;
}

function listRowMouseDownHandler(event) {
    preventDefault(event);
    return false;
}

function reverseSortByAlarmTime(a, b) {
    var x = parseInt(a[2]);
    var y = parseInt(b[2]);
    return (y - x);
}

function refreshAlarms() {
    var url;
    var now = new Date();
    var utc = Math.floor(now.getTime()/1000);

    if (document.alarmsListAjaxRequest)
        return false;
    url = UserFolderURL + "Calendar/alarmslist?browserTime=" + utc;
    document.alarmsListAjaxRequest 
        = triggerAjaxRequest(url, refreshAlarmsCallback);

    return true;
}

function refreshAlarmsCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        document.alarmsListAjaxRequest = null;

        if (http.responseText.length > 0) {
            Alarms = http.responseText.evalJSON(true);
            Alarms.sort(reverseSortByAlarmTime);
            triggerNextAlarm();
        }
    }
    else
        log ("refreshAlarmsCallback Ajax error");
}

function triggerNextAlarm() {
    if (Alarms.length > 0) {
        var next = Alarms.pop();
        var now = new Date();
        var utc = Math.floor(now.getTime()/1000);
        var url = next[0] + '/' + next[1];
        var alarmTime = parseInt(next[2]);
        var delay = alarmTime;
        if (alarmTime > 0) delay -= utc;
        var d = new Date(alarmTime*1000);
        log ("now = " + now.toUTCString());
        log ("next event " + url + " in " + delay + " seconds (on " + d.toUTCString() + ")");
        showAlarm.delay(delay, url);
    }
}

function showAlarm(url) {
    url = UserFolderURL + "Calendar/" + url + "/view?resetAlarm=yes";
    if (document.viewAlarmAjaxRequest) {
        document.viewAlarmAjaxRequest.aborted = true;
        document.viewAlarmAjaxRequest.abort();
    }
    document.viewAlarmAjaxRequest = triggerAjaxRequest(url, showAlarmCallback);
}

function showAlarmCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        if (http.responseText.length) {
            var data = http.responseText.evalJSON(true);
            var msg = _("Reminder:") + " " + data["summary"] + "\n";
            if (data["startDate"]) {
                msg += _("Start:") + " " + data["startDate"];
                if (parseInt(data["isAllDay"]) == 0)
                    msg += " - " + data["startTime"];
                msg += "\n";
            }
            if (data["dueDate"]) {
                msg += _("Due Date:") + " " + data["dueDate"];
                if (data["dueTime"])
                    msg += " - " + data["dueTime"];
                msg += "\n";
            }
            if (data["location"].length)
                msg += "\n" + _("Location:") + " " + data["location"];
            if (data["description"].length)
                msg += "\n\n" + data["description"];

            window.alert(msg);
        }
        else
            log("showAlarmCallback ajax error: no data received");
    }
    else {
        log("showAlarmCallback ajax error (" + http.status + "): " + http.url);
    }

    triggerNextAlarm();
}

function initMenus() {
    var menus = getMenus();
    if (menus) {
        for (var menuID in menus) {
            var menuDIV = $(menuID);
            if (menuDIV)
                initMenu(menuDIV, menus[menuID]);
        }
    }
}

function initMenu(menuDIV, callbacks) {
    var uls = menuDIV.childNodesWithTag("ul");
    for (var i = 0; i < uls.length; i++) {
        var lis = $(uls[i]).childNodesWithTag("li");
        for (var j = 0; j < lis.length; j++) {
            var node = $(lis[j]);
            node.observe("mousedown", listRowMouseDownHandler, false);
            var callback;
            if (i > 0)
                callback = callbacks[i+j+1];
            else
                callback = callbacks[i+j];
            if (callback) {
                if (typeof(callback) == "string") {
                    if (callback == "-")
                        node.addClassName("separator");
                    else {
                        node.submenu = callback;
                        node.addClassName("submenu");
                        node.observe("mouseover", popupSubmenu);
                    }
                }
                else {
                    node.observe("mouseup", onBodyClickMenuHandler);
                    node.menuCallback = callback;
                    node.observe("click", onMenuClickHandler);
                }
            }
            else
                node.addClassName("disabled");
        }
    }
}

function openExternalLink(anchor) {
    return false;
}

function openAclWindow(url) {
    var w = window.open(url, "aclWindow",
                        "width=420,height=300,resizable=1,scrollbars=1,toolbar=0,"
                        + "location=0,directories=0,status=0,menubar=0"
                        + ",copyhistory=0");
    w.opener = window;
    w.focus();

    return w;
}

function getUsersRightsWindowHeight() {
    return usersRightsWindowHeight;
}

function getUsersRightsWindowWidth() {
    return usersRightsWindowWidth;
}

function getTopWindow() {
    var topWindow = null;
    var currentWindow = window;
    while (!topWindow) {
        if (currentWindow.document.body.hasClassName("popup")
            && currentWindow.opener)
            currentWindow = currentWindow.opener;
        else
            topWindow = currentWindow;
    }

    return topWindow;
}

//function enableAnchor(anchor) {
//    var classStr = '' + anchor.getAttribute("class");
//    var position = classStr.indexOf("_disabled", 0);
//    if (position > -1) {
//        var disabledHref = anchor.getAttribute("disabled-href");
//        if (disabledHref)
//            anchor.setAttribute("href", disabledHref);
//        var disabledOnclick = anchor.getAttribute("disabled-onclick");
//        if (disabledOnclick)
//            anchor.setAttribute("onclick", disabledOnclick);
//        anchor.removeClassName("_disabled");
//        anchor.setAttribute("disabled-href", null);
//        anchor.setAttribute("disabled-onclick", null);
//        anchor.disabled = 0;
//        anchor.enabled = 1;
//    }
//}

//function disableAnchor(anchor) {
//    var classStr = '' + anchor.getAttribute("class");
//    var position = classStr.indexOf("_disabled", 0);
//    if (position < 0) {
//        var href = anchor.getAttribute("href");
//        if (href)
//            anchor.setAttribute("disabled-href", href);
//        var onclick = anchor.getAttribute("onclick");
//        if (onclick)
//            anchor.setAttribute("disabled-onclick", onclick);
//        anchor.addClassName("_disabled");
//        anchor.setAttribute("href", "#");
//        anchor.setAttribute("onclick", "return false;");
//        anchor.disabled = 1;
//        anchor.enabled = 0;
//    }
//}

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
        while (currentValue) {
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

function reloadPreferences() {
    var url = UserFolderURL + "jsonDefaults";
    var http = createHTTPClient();
    http.open("GET", url, false);
    http.send("");

    if (http.status == 200) {
        if (http.responseText.length > 0) {
            UserDefaults = http.responseText.evalJSON(true);
            if (!UserDefaults)
                UserDefaults = {};
        }
        else
            UserDefaults = {};
    }

    url = UserFolderURL + "jsonSettings";
    http.open("GET", url, false);
    http.send("");
    if (http.status == 200) {
        if (http.responseText.length > 0)
            UserSettings = http.responseText.evalJSON(true);
        else
            UserSettings = {};
    }
}

function onLoadHandler(event) {
    queryParameters = parseQueryParameters('' + window.location);
    if (!$(document.body).hasClassName("popup")) {
        initLogConsole();
        if ($("calendarBannerLink")) {
            refreshAlarms();
        }
    }
    initCriteria();
    configureSearchField();
    initMenus();
    configureDragHandles();
    configureLinkBanner();
    var progressImage = $("progressIndicator");
    if (progressImage)
        progressImage.parentNode.removeChild(progressImage);
    $(document.body).observe("contextmenu", onBodyClickContextMenu);

    onFinalLoadHandler();
}

function onBodyClickContextMenu(event) {
    var target = $(event.target);
    if (!(target
          && (target.tagName == "INPUT"
              || target.tagName == "TEXTAREA"
              || (target.tagName == "A"
                  && target.hasClassName("clickableLink")))))
        preventDefault(event);
}

function configureSortableTableHeaders(table) {
    var headers = $(table).getElementsByClassName("sortableTableHeader");
    for (var i = 0; i < headers.length; i++) {
        var header = $(headers[i]);
        header.observe("selectstart", listRowMouseDownHandler);
        header.stopObserving("click", onHeaderClick);
        header.observe("click", onHeaderClick);
    }
}

function onLinkBannerClick() {
    activeAjaxRequests++;
    checkAjaxRequestsState();
}

function onPreferencesClick(event) {
    var urlstr = UserFolderURL + "preferences";
    var w = window.open(urlstr, "_blank",
                        "width=440,height=450,resizable=1,scrollbars=0,location=0");
    w.opener = window;
    w.focus();

    preventDefault(event);
}

function configureLinkBanner() {
    var linkBanner = $("linkBanner");
    if (linkBanner) {
        var moduleLinks = [ "calendar", "contacts", "mail" ];
        for (var i = 0; i < moduleLinks.length; i++) {
            var link = $(moduleLinks[i] + "BannerLink");
            if (link) {
                link.observe("mousedown", listRowMouseDownHandler);
                link.observe("click", onLinkBannerClick);
            }
        }
        link = $("preferencesBannerLink");
        if (link) {
            link.observe("mousedown", listRowMouseDownHandler);
            link.observe("click", onPreferencesClick);
        }
        link = $("consoleBannerLink");
        if (link) {
            link.observe("mousedown", listRowMouseDownHandler);
            link.observe("click", toggleLogConsole);
        }
    }
}

function CurrentModule() {
    var module = null;
    if (ApplicationBaseURL) {
        var parts = ApplicationBaseURL.split("/");
        var last = parts.length - 1;
        while (last > -1 && parts[last] == "") {
            last--;
        }
        if (last > -1) {
            module = parts[last];
        }
    }

    return module;
}

/* accessing another user's data */
function UserFolderURLForUser(user) {
    var folderArray = UserFolderURL.split("/");
    var count;
    if (UserFolderURL.endsWith('/'))
        count = folderArray.length - 2;
    else
        count = folderArray.length - 1;
    folderArray[count] = escape(user);

    return folderArray.join("/");
}

/* folder creation */
function createFolder(name, okCB, notOkCB) {
    if (name) {
        if (document.newFolderAjaxRequest) {
            document.newFolderAjaxRequest.aborted = true;
            document.newFolderAjaxRequest.abort();
        }
        var url = ApplicationBaseURL + "/createFolder?name=" + escape(name.utf8encode());
        document.newFolderAjaxRequest
            = triggerAjaxRequest(url, createFolderCallback,
                                 {name: name,
                                  okCB: okCB,
                                  notOkCB: notOkCB});
    }
}

function createFolderCallback(http) {
    if (http.readyState == 4) {
        var data = http.callbackData;
        if (http.status == 201) {
            if (data.okCB)
                data.okCB(data.name, "/" + http.responseText, UserLogin);
        }
        else if (http.status == 409) {
            alert (_("A folder by that name already exists."));
        }
        else {
            if (data.notOkCB)
                data.notOkCB(name);
            else
                log("ajax problem:" + http.status);
        }
    }
}

/* invitation delegation */
function delegateInvitation(componentUrl, callbackFunction, callbackData) {
    var input = $("delegatedTo");
    var delegatedTo = null;
    if (input.readAttribute("uid") != null)
        delegatedTo = input.readAttribute("uid");
    else if (input.value.blank())
        alert(_("noEmailForDelegation"));
    else
        delegatedTo = input.value;

    if (delegatedTo) {
        var receiveUpdates = false; //confirm("Do you want to keep receiving updates on the event?");
        var urlstr = componentUrl + "/delegate";
        var parameters = "to=" + delegatedTo + "&receiveUpdates=" + (receiveUpdates?"YES":"NO");
        return triggerAjaxRequest(urlstr, callbackFunction, callbackData, parameters,
                                  { "Content-type": "application/x-www-form-urlencoded" });
    }
}

function onFinalLoadHandler(event) {
    var safetyNet = $("javascriptSafetyNet");
    if (safetyNet)
        safetyNet.parentNode.removeChild(safetyNet);
}

function parent$(element) {
    return this.opener.document.getElementById(element);
}

/* stubs */
function refreshCurrentFolder() {
}

function configureDragHandles() {
}

function getMenus() {
}

function onHeaderClick(event) {
}

function _(key) {
    var value = key;
    if (labels[key]) {
        value = labels[key];
    }
    else {
        var topWindow = null;
        if (!topWindow) {
            topWindow = window;
            while (topWindow.opener)
                topWindow = topWindow.opener;
        }
        if (topWindow && topWindow.clabels && topWindow.clabels[key])
            value = topWindow.clabels[key];
    }

    return value;
}

/**
 *
 *  AJAX IFRAME METHOD (AIM)
 *  http://www.webtoolkit.info/
 *
 **/

AIM = {
    frame : function(c) {
        var d = new Element ('div');
        var n = d.identify ();
        d.innerHTML = '<iframe style="display:none" src="about:blank" id="' 
        + n + '" name="' + n + '" onload="AIM.loaded(\'' + n + '\')"></iframe>';
        document.body.appendChild(d);
        var i = $(n); // TODO: useful?
        if (c && typeof(c.onComplete) == 'function')
            i.onComplete = c.onComplete;
        return n;
    },

    form : function(f, name) {
        f.writeAttribute('target', name);
    },

    submit : function(f, c) {
        AIM.form(f, AIM.frame(c));
        if (c && typeof(c.onStart) == 'function')
            return c.onStart();
        else
            return true;
    },

    loaded : function(id) {
        var i = $(id);
        if (i.contentDocument)
            var d = i.contentDocument;
        else if (i.contentWindow)
            var d = i.contentWindow.document;
        else
            var d = window.frames[id].document;
        if (d.location.href == "about:blank")
            return;

        if (typeof(i.onComplete) == 'function')
            i.onComplete(d.body.innerHTML);
    }
};

function createDialog(id, title, legend, content, positionClass) {
    if (!positionClass)
        positionClass = "left";
    var newDialog = createElement("div", id, ["dialog", positionClass]);
    newDialog.setStyle({"display": "none"});

    var subdiv = createElement("div", null, null, null, null, newDialog);
    if (title && title.length > 0) {
        var titleh3 = createElement("h3", null, null, null, null, subdiv);
        titleh3.appendChild(document.createTextNode(title));
    }
    if (legend && legend.length > 0) {
        var legendP = createElement("p", null, null, null, null, subdiv);
        legendP.appendChild(document.createTextNode(legend));
    }
    if (content)
        subdiv.appendChild(content);

    return newDialog;
}

function createButton(id, caption, action) {
    var newButton = createElement("a", id, "button", { "href": "#" });
    if (caption && caption.length > 0) {
        var span = createElement("span", null, null, null, null, newButton);
        span.appendChild(document.createTextNode(caption));
    }
    if (action)
        newButton.observe("click", action);

    return newButton;
}

function readCookie(name) {
    var foundCookie = null;

    var prefix = name + "=";
    var pairs = document.cookie.split(';');
    for (var i = 0; !foundCookie && i < pairs.length; i++) {
        var currentPair = pairs[i];
        var start = 0;
        while (currentPair.charAt(start) == " ")
            start++;
        if (start > 0)
            currentPair = currentPair.substr(start);
        if (currentPair.indexOf(prefix) == 0)
            foundCookie = currentPair.substr(prefix.length);
    }

    return foundCookie;
}

function readLoginCookie() {
    var loginValues = null;
    var cookie = readCookie("0xHIGHFLYxSOGo");
    if (cookie && cookie.length > 8) {
        var value = decodeURIComponent(cookie.substr(8));
        loginValues = value.base64decode().split(":");
    }

    return loginValues;
}

/* logging widgets */
function SetLogMessage(containerId, message, msgType) {
    var container = $(containerId);
    if (container) {
        if (!msgType)
            msgType = "error";
        var typeClass = msgType + "Message";
        if (!container.typeClass || container.typeClass != typeClass) {
            if (container.typeClass) {
                container.removeClassName(container.typeClass);
            }
            container.typeClass = typeClass;
            container.addClassName(typeClass);
        }
        if (container.message != message) {
            while (container.lastChild) {
                container.removeChild(container.lastChild);
            }
            if (message && message.length > 0) {
                var sentences = message.split("\n");
                container.appendChild(document.createTextNode(sentences[0]));
                for (var i = 1; i < sentences.length; i++) {
                    container.appendChild(document.createElement("br"));
                    container.appendChild(document.createTextNode(sentences[i]));
                }
            }
            container.message = message;
        }
    }
}

document.observe("dom:loaded", onLoadHandler);
