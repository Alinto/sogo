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

/*
  DOM ids available in mail list view:
    row_$msgid
    div_$msgid
    readdiv_$msgid
    unreaddiv_$msgid

  Window Properties:
    width, height
    bool: resizable, scrollbars, toolbar, location, directories, status,
          menubar, copyhistory
*/

var currentMessages = new Array();
var maxCachedMessages = 20;
var cachedContacts = new Array();
var currentContactFolder = '';
/* mail list */

function openContactWindow(sender, contactuid, url) {
  log ("message window at url: " + url);
  var msgWin = window.open(url, "SOGo_msg_" + contactuid,
			   "width=640,height=480,resizable=1,scrollbars=1,toolbar=0," +
			   "location=0,directories=0,status=0,menubar=0,copyhistory=0");

  msgWin.focus();
}

function clickedUid(sender, contactuid) {
  resetSelection(window);
  openContactWindow(sender, contactuid,
                    ApplicationBaseURL + currentContactFolder + "/" + contactuid + "/view");
  return true;
}

function doubleClickedUid(sender, contactuid) {
  alert("DOUBLE Clicked " + contactuid);

  return false;
}

function toggleMailSelect(sender) {
  var row;
  row = document.getElementById(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
}

function collectSelectedRows() {
  var rows = new Array();
  var contactsList = document.getElementById('contactsList');
  var tbody = (contactsList.getElementsByTagName('tbody'))[0];
  var selectedRows = getSelectedNodes(tbody);

  for (var i = 0; i < selectedRows.length; i++) {
    var row = selectedRows[i];
    var rowId = row.getAttribute('id');
    rows[rows.length] = rowId;
  }

  return rows;
}

/* mail editor */

function validateEditorInput(sender) {
  var errortext = "";
  var field;
  
  field = document.pageform.subject;
  if (field.value == "")
    errortext = errortext + labels.error_missingsubject + "\n";

  if (!UIxRecipientSelectorHasRecipients())
    errortext = errortext + labels.error_missingrecipients + "\n";
  
  if (errortext.length > 0) {
    alert(labels.error_validationfailed + ":\n" + errortext);
    return false;
  }
  return true;
}

function clickedEditorSend(sender) {
  if (!validateEditorInput(sender))
    return false;

  document.pageform.action="send";
  document.pageform.submit();
  // if everything is ok, close the window
  return true;
}

function clickedEditorAttach(sender) {
  var urlstr;
  
  urlstr = "viewAttachments";
  window.open(urlstr, "SOGo_attach",
	      "width=320,height=320,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

function clickedEditorSave(sender) {
  document.pageform.action="save";
  document.pageform.submit();
  refreshOpener();
  return true;
}

function clickedEditorDelete(sender) {
  document.pageform.action="delete";
  document.pageform.submit();
  refreshOpener();
  window.close();
  return true;
}

function showInlineAttachmentList(sender) {
  var r, l;
  
  r = document.getElementById('compose_rightside');
  r.style.display = 'block';
  l = document.getElementById('compose_leftside');
  l.style.width = "67%";
  this.adjustInlineAttachmentListHeight(sender);
}

function updateInlineAttachmentList(sender, attachments) {
  if (!attachments || (attachments.length == 0)) {
    this.hideInlineAttachmentList(sender);
    return;
  }
  var e, i, count, text;
  
  count = attachments.length;
  text  = "";
  for (i = 0; i < count; i++) {
    text = text + attachments[i];
    text = text + '<br />';
  }

  e = document.getElementById('compose_attachments_list');
  e.innerHTML = text;
  this.showInlineAttachmentList(sender);
}

function adjustInlineAttachmentListHeight(sender) {
  var e;
  
  e = document.getElementById('compose_rightside');
  if (e.style.display == 'none') return;

  /* need to lower left size first, because left auto-adjusts to right! */
  xHeight('compose_attachments_list', 10);

  var leftHeight, rightHeaderHeight;
  leftHeight        = xHeight('compose_leftside');
  rightHeaderHeight = xHeight('compose_attachments_header');
  xHeight('compose_attachments_list', (leftHeight - rightHeaderHeight) - 16);
}

function hideInlineAttachmentList(sender) {
  var e;
  
//  xVisibility('compose_rightside', false);
  e = document.getElementById('compose_rightside');
  e.style.display = 'none';
  e = document.getElementById('compose_leftside');
  e.style.width = "100%";
}

/* ajax contactsFolder handling */

var activeAjaxRequests = 0;

function triggerAjaxRequest(url, callback, userdata) {
  var http = createHTTPClient();

  activeAjaxRequests += 1;
  document.animTimer = setTimeout("checkAjaxRequestsState();", 200);

  if (http) {
    http.onreadystatechange
      = function() {
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
          alert('AJAX Request, Caught Exception: ' + e.description);
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

function onContactsFolderTreeItemClick(element)
{
  var topNode = document.getElementById('d');
  var contactsFolder = element.parentNode.getAttribute("dataname");

  if (topNode.selectedEntry)
    deselectNode(topNode.selectedEntry);
  selectNode(element);
  topNode.selectedEntry = element;

  openContactsFolder(contactsFolder);
}

function openContactsFolder(contactsFolder, params)
{
  if (contactsFolder != currentContactFolder || params) {
    currentContactFolder = contactsFolder;
    var url = ApplicationBaseURL + contactsFolder + "/view?noframe=1&sort=cn&desc=0";
    if (params)
      url += '&' + params;

    var contactsListContent = document.getElementById("contactsListContent");
//     var contactsFolderDragHandle = document.getElementById("contactsFolderDragHandle");
//     var messageContent = document.getElementById("messageContent");
//     messageContent.innerHTML = '';
    if (document.contactsListAjaxRequest) {
      document.contactsListAjaxRequest.aborted = true;
      document.contactsListAjaxRequest.abort();
    }
//     if (currentMessages[contactsFolder]) {
//       loadMessage(currentMessages[contactsFolder]);
//       url += '&pageforuid=' + currentMessages[contactsFolder];
//     }
    document.contactsListAjaxRequest
      = triggerAjaxRequest(url, contactsListCallback,
                           currentMessages[contactsFolder]);
    if (contactsListContent.style.visibility == "hidden") {
      contactsListContent.style.visibility = "visible;";
//         contactsFolderDragHandle.style.visibility = "visible;";
//         messageContent.style.top = (contactsFolderDragHandle.offsetTop
//                                     + contactsFolderDragHandle.offsetHeight
//                                     + 'px;');
    }
  }
//   triggerAjaxRequest(contactsFolder, 'toolbar', toolbarCallback);
}

function openContactsFolderAtIndex(element) {
  var idx = element.getAttribute("idx");
  var url = ApplicationBaseURL + currentContactFolder + "/view?noframe=1&idx=" + idx;

  if (document.contactsListAjaxRequest) {
    document.contactsListAjaxRequest.aborted = true;
    document.contactsListAjaxRequest.abort();
  }
  document.contactsListAjaxRequest
    = triggerAjaxRequest(url, contactsListCallback);
}

function contactsListCallback(http)
{
  var div = document.getElementById('contactsListContent');

  if (http.readyState == 4
      && http.status == 200) {
    document.contactsListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var selected = http.callbackData;
    if (selected) {
      var row = document.getElementById('row_' + selected);
      selectNode(row);
    }
    initCriteria();
  }
  else
    log ("ajax fuckage");
}

function onContactContextMenu(event, element)
{
  var menu = document.getElementById('contactMenu');
  menu.addEventListener("hideMenu", onContactContextMenuHide, false);
  onMenuClick(event, 'contactMenu');

  var topNode = document.getElementById('contactsList');
  var selectedNodeIds = collectSelectedRows();
  topNode.menuSelectedRows = selectedNodeIds;
  for (var i = 0; i < selectedNodeIds.length; i++) {
    var selectedNode = document.getElementById(selectedNodeIds[i]);
    deselectNode (selectedNode);
  }
  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onContactContextMenuHide(event)
{
  var topNode = document.getElementById('contactsList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodeIds = topNode.menuSelectedRows;
    for (var i = 0; i < nodeIds.length; i++) {
      var node = document.getElementById(nodeIds[i]);
      selectNode (node);
    }
    topNode.menuSelectedRows = null;
  }
}

function onFolderMenuHide(event)
{
  var topNode = document.getElementById('d');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.selectedEntry)
    selectNode(topNode.selectedEntry);
}

function getCachedMessage(idx)
{
  var message = null;
  var counter = 0;

  while (counter < cachedContacts.length
         && message == null)
    if (cachedContacts[counter]
        && cachedContacts[counter]['idx'] == currentContactFolder + '/' + idx)
      message = cachedContacts[counter];
    else
      counter++;

  return message;
}

function storeCachedMessage(cachedContact)
{
  var oldest = -1;
  var timeOldest = -1;
  var counter = 0;

  if (cachedContacts.length < maxCachedMessages)
    oldest = cachedContacts.length;
  else {
    while (cachedContacts[counter]) {
      if (oldest == -1
          || cachedContacts[counter]['time'] < timeOldest) {
        oldest = counter;
        timeOldest = cachedContacts[counter]['time'];
      }
      counter++;
    }

    if (oldest == -1)
      oldest = 0;
  }

  cachedContacts[oldest] = cachedContact;
}

function onMessageSelectionChange()
{
  var selection = collectSelectedRows();
  if (selection.length == 1)
    {
      var idx = selection[0];

      if (currentMessages[currentContactFolder] != idx) {
        currentMessages[currentContactFolder] = idx;
        loadMessage(idx);
      }
    }
}

function loadMessage(idx)
{
  var cachedContact = getCachedMessage(idx);

  if (document.messageAjaxRequest) {
    document.messageAjaxRequest.aborted = true;
    document.messageAjaxRequest.abort();
  }

  if (cachedContact == null) {
    var url = (ApplicationBaseURL + currentContactFolder + "/"
               + idx + "/view?noframe=1");
    document.messageAjaxRequest
      = triggerAjaxRequest(url, messageCallback, idx);
    markMailInWindow(window, idx, true);
  } else {
    var div = document.getElementById('messageContent');
    div.innerHTML = cachedContact['text'];
    cachedContact['time'] = (new Date()).getTime();
    document.messageAjaxRequest = null;
  }
}

function messageCallback(http)
{
  var div = document.getElementById('messageContent');

  if (http.readyState == 4
      && http.status == 200) {
    document.messageAjaxRequest = null;
    div.innerHTML = http.responseText;
    
    if (http.callbackData) {
      var cachedContact = new Array();
      cachedContact['idx'] = currentContactFolder + '/' + http.callbackData;
      cachedContact['time'] = (new Date()).getTime();
      cachedContact['text'] = http.responseText;
      if (cachedContact['text'].length < 30000)
        storeCachedMessage(cachedContact);
    }
  }
  else
    log ("ajax fuckage");
}

var rowSelectionCount = 0;

validateControls();

function showElement(e, shouldShow) {
  e.style.display = shouldShow ? "" : "none";
}

function enableElement(e, shouldEnable) {
  if(!e)
    return;
  if(shouldEnable) {
    if(e.hasAttribute("disabled"))
      e.removeAttribute("disabled");
  }
  else {
    e.setAttribute("disabled", "1");
  }
}

function validateControls() {
  var e = document.getElementById("moveto");
  this.enableElement(e, rowSelectionCount > 0);
}

function moveTo(uri) {
  alert("MoveTo: " + uri);
}

function popupSearchMenu(event, menuId)
{
  var node = event.target;

  superNode = node.parentNode.parentNode.parentNode;
  relX = (event.pageX - superNode.offsetLeft - node.offsetLeft);
  relY = (event.pageY - superNode.offsetTop - node.offsetTop);

  if (event.button == 0
      && relX < 24) {
    event.cancelBubble = true;
    event.returnValue = false;

    var popup = document.getElementById(menuId);
    hideMenu(event, popup);

    var menuTop = superNode.offsetTop + node.offsetTop + node.offsetHeight;
    var menuLeft = superNode.offsetLeft + node.offsetLeft;
    var heightDiff = (window.innerHeight
		      - (menuTop + popup.offsetHeight));
    if (heightDiff < 0)
      menuTop += heightDiff;

    var leftDiff = (window.innerWidth
		    - (menuLeft + popup.offsetWidth));
    if (leftDiff < 0)
      menuLeft -= popup.offsetWidth;

    popup.style.top = menuTop + "px";
    popup.style.left = menuLeft + "px";
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
  log ("changed...");
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
  log ("search blur: '" + searchValue.value + "'");
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

/* contact menu entries */
function onContactRowDblClick(event, node)
{
  var contactId = node.getAttribute('id');

  openContactWindow(null, contactId,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/view");

  return false;
}

function onMenuEditContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null, contactId,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuWriteToContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null, contactId,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/write");

  return false;
}

function onMenuDeleteContact(event, node)
{
  uixDeleteSelectedContacts(node);

  return false;
}

function onToolbarEditSelectedContacts(event)
{
  var rows;
  
  rows = collectSelectedRows();
  for (var i = 0; i < rows.length; i++) {
    openContactWindow(null, 'edit_' + rows[i],
                      ApplicationBaseURL + currentContactFolder
                      + "/" + rows[i] + "/edit");
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event)
{
  var rows;
  
  rows = collectSelectedRows();
  for (var i = 0; i < rows.length; i++) {
    openContactWindow(null, 'writeto_' + rows[i],
                      ApplicationBaseURL + currentContactFolder
                      + "/" + rows[i] + "/write");
  }

  return false;
}

function uixDeleteSelectedContacts(sender)
{
  var rows;
  var failCount = 0;
  
  rows = collectSelectedRows();
  for (var i = 0; i < rows.length; i++) {
    var url, http, rowElem;
    
    /* send AJAX request (synchronously) */
    
    url = (ApplicationBaseURL + currentContactFolder + "/"
           + rows[i] + "/delete");
    http = createHTTPClient();
    http.open("POST", url, false /* not async */);
    http.send("");
    if (http.status != 200) { /* request failed */
      failCount++;
      http = null;
      continue;
    }
    http = null;

    /* remove from page */

    /* line-through would be nicer, but hiding is OK too */
    rowElem = document.getElementById(rows[i]);
    rowElem.parentNode.removeChild(rowElem);
  }

  if (failCount > 0)
    alert("Could not delete " + failCount + " messages!");
  
  return false;
}

function newEmailTo(sender) {
  var mailto = sanitizeMailTo(sender.parentNode.parentNode.menuTarget.innerHTML);

  if (mailto.length > 0)
    {
      w = window.open("compose?mailto=" + mailto,
		      "SOGo_compose",
		      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
		      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
}

function onHeaderClick(node)
{
  var href = node.getAttribute("href");

  if (document.contactsListAjaxRequest) {
    document.contactsListAjaxRequest.aborted = true;
    document.contactsListAjaxRequest.abort();
  }
  url = ApplicationBaseURL + currentContactFolder + "/" + href;
  if (!href.match(/noframe=/))
    url += "&noframe=1";
  log ("url: " + url);
  document.contactsListAjaxRequest
    = triggerAjaxRequest(url, contactsListCallback);

  return false;
}

function registerDraggableMessageNodes()
{
  log ("can we drag...");
}

function newContact(sender) {
  var urlstr;

  urlstr = ApplicationBaseURL + currentContactFolder + "/new";
  newcwin = window.open(urlstr, "SOGo_new_contact",
			"width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
			"location=0,directories=0,status=0,menubar=0,copyhistory=0");
  newcwin.focus();

  return false; /* stop following the link */
}

function onFolderSelectionChange()
{
  var folderList = document.getElementById("contactFolders");
  var nodes = getSelectedNodes(folderList);
  var newFolder = nodes[0].getAttribute("id");

  openContactsFolder(newFolder);
}

function onSearchFormSubmit()
{
  var searchValue = document.getElementById("searchValue");

  openContactsFolder(currentContactFolder, "search=" + searchValue.value);

  return false;
}

function onSearchKeyDown(searchValue)
{
  if (searchValue.timer)
    clearTimeout(searchValue.timer);

  searchValue.timer = setTimeout("onSearchFormSubmit()", 1000);
}

function onConfirmContactSelection()
{
  var rows = collectSelectedRows();

  var folderLi = document.getElementById(currentContactFolder);
  var currentContactFolderName = folderLi.innerHTML;

  for (i = 0; i < rows.length; i++)
    {
      var row = document.getElementById(rows[i]);
//       opener.window.log (rows[i] + " selected.");
//       opener.window.log (row.cells.length);
      var cid = row.getAttribute("contactid");
      if (cid)
        {
          var cname = '' + row.getAttribute("contactname");
          opener.window.log('cid = ' + cid + '; cname = ' + cname );
          if (cid.length > 0)
            opener.window.addContact(contactSelectorId,
                                     cid,
                                     currentContactFolderName + '/' + cname);
        }
    }

  return false;
}
