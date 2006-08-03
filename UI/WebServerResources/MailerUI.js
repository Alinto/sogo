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
var cachedMessages = new Array();
var currentMailbox = '';
/* mail list */

function openMessageWindow(sender, msguid, url) {
  log ("message window at url: " + url);
  var msgWin = window.open(url, "SOGo_msg_" + msguid,
			   "width=640,height=480,resizable=1,scrollbars=1,toolbar=0," +
			   "location=0,directories=0,status=0,menubar=0,copyhistory=0");

  msgWin.focus();
}

function clickedUid(sender, msguid) {
  resetSelection(window);
  openMessageWindow(sender, msguid,
                    ApplicationBaseURL + currentMailbox + "/" + msguid + "/view");
  return true;
}

function doubleClickedUid(sender, msguid) {
  alert("DOUBLE Clicked " + msguid);

  return false;
}

function toggleMailSelect(sender) {
  var row;
  row = document.getElementById(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
}

function collectSelectedRows() {
  var rows = new Array();
  var messageList = document.getElementById('messageList');
  var tbody = (messageList.getElementsByTagName('tbody'))[0];
  var selectedRows = getSelectedNodes(tbody);

  for (var i = 0; i < selectedRows.length; i++) {
    var row = selectedRows[i];
    var rowId = row.getAttribute('id').substring(4);
    rows[rows.length] = rowId;
  }

  return rows;
}

function clearSearch(sender) {
  var searchField = window.document.getElementById("search");
  if (searchField) searchField.value="";
  return true;
}

/* compose support */

function clickedCompose(sender) {
  var urlstr;
  
  urlstr = "compose";
  window.open(urlstr, "SOGo_compose",
	      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
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

/* addressbook helpers */

function openAnais(sender) {
  var urlstr;

  urlstr = "anais";
  var w = window.open(urlstr, "Anais",
                      "width=350,height=600,left=10,top=10,toolbar=no," +
                      "dependent=yes,menubar=no,location=no,resizable=yes," +
                      "scrollbars=yes,directories=no,status=no");
  w.focus();
}

function openAddressbook(sender) {
  var urlstr;
  
  urlstr = "addressbook";
  var w = window.open(urlstr, "Addressbook",
                      "width=600,height=400,left=10,top=10,toolbar=no," +
                      "dependent=yes,menubar=no,location=no,resizable=yes," +
                      "scrollbars=yes,directories=no,status=no");
  w.focus();
}

/* filters */

function clickedFilter(sender, scriptname) {
  var urlstr;
  
  urlstr = scriptname + "/edit";
  window.open(urlstr, "SOGo_filter_" + scriptname,
	      "width=640,height=480,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0")
  return true;
}

function clickedNewFilter(sender) {
  var urlstr;
  
  urlstr = "create";
  window.open(urlstr, "SOGo_filter",
	      "width=680,height=480,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

/* mail list DOM changes */

function markMailInWindow(win, msguid, markread) {
  var msgDiv;

  msgDiv = win.document.getElementById("div_" + msguid);
  if (msgDiv) {
    if (markread) {
      removeClassName(msgDiv, 'mailer_unreadmailsubject');
      addClassName(msgDiv, 'mailer_readmailsubject');
      msgDiv = win.document.getElementById("unreaddiv_" + msguid);
      if (msgDiv)
        {
          msgDiv.setAttribute("class", "mailerUnreadIcon");
          msgDiv.setAttribute("id", "readdiv_" + msguid);
          msgDiv.setAttribute("src", ResourcesURL + "/icon_read.gif");
          msgDiv.setAttribute("onclick", "mailListMarkMessage(this,"
                              + " 'markMessageUnread', " + msguid
                              + ", false);"
                              +" return false;");
          var title = msgDiv.getAttribute("title-markunread");
          if (title)
            msgDiv.setAttribute("title", title);
        }
    }
    else {
      removeClassName(msgDiv, 'mailer_readmailsubject');
      addClassName(msgDiv, 'mailer_unreadmailsubject');
      msgDiv = win.document.getElementById("readdiv_" + msguid);
      if (msgDiv)
        {
          msgDiv.setAttribute("class", "mailerReadIcon");
          msgDiv.setAttribute("id", "unreaddiv_" + msguid);
          msgDiv.setAttribute("src", ResourcesURL + "/icon_unread.gif");
          msgDiv.setAttribute("onclick", "mailListMarkMessage(this,"
                              + " 'markMessageRead', " + msguid
                              + ", true);"
                              +" return false;");
          var title = msgDiv.getAttribute("title-markread");
          if (title)
            msgDiv.setAttribute("title", title);
        }
    }
    return true;
  }
  else
    return false;
}

function markMailReadInWindow(win, msguid) {
  /* this is called by UIxMailView with window.opener */
  return markMailInWindow(win, msguid, true);
}

/* main window */

function reopenToRemoveLocationBar() {
  // we cannot really use this, see below at the close comment
  if (window.locationbar && window.locationbar.visible) {
    newwin = window.open(window.location.href, "SOGo",
			 "width=800,height=600,resizable=1,scrollbars=1," +
			 "toolbar=0,location=0,directories=0,status=0," + 
			 "menubar=0,copyhistory=0");
    if (newwin) {
      window.close(); // this does only work for windows opened by scripts!
      newwin.focus();
      return true;
    }
    return false;
  }
  return true;
}

/* mail list reply */

function openMessageWindowsForSelection(sender, action)
{
  var rows  = collectSelectedRows();
  var idset = "";
  
  for (var i = 0; i < rows.length; i++) {
    win = openMessageWindow(sender,
			    rows[i]                /* msguid */,
			    ApplicationBaseURL + currentMailbox
                            + "/" + rows[i] + "/" + action /* url */);
  }
}

function mailListMarkMessage(sender, action, msguid, markread)
{
  var url;
  var http = createHTTPClient();

  url = ApplicationBaseURL + currentMailbox + "/" + action + "?uid=" + msguid;

  if (http) {
    // TODO: add parameter to signal that we are only interested in OK
    http.open("POST", url + "&jsonly=1", false /* not async */);
    http.send("");
    if (http.status != 200) {
      // TODO: refresh page?
      alert("Message Mark Failed: " + http.statusText);
      window.location.reload();
    }
    else {
      markMailInWindow(window, msguid, markread);
    }
  }
  else {
    window.location.href = url;
  }
}

/* maillist row highlight */

var oldMaillistHighlight = null; // to remember deleted/selected style

function ml_highlight(sender)
{
  oldMaillistHighlight = sender.className;
  if (oldMaillistHighlight == "tableview_highlight")
    oldMaillistHighlight = null;
  sender.className = "tableview_highlight";
}

function ml_lowlight(sender)
{
  if (oldMaillistHighlight) {
    sender.className = oldMaillistHighlight;
    oldMaillistHighlight = null;
  }
  else
    sender.className = "tableview";
}


/* folder operations */

function ctxFolderAdd(sender) {
  var folderName;
  
  folderName = prompt("Foldername: ");
  if (folderName == undefined)
    return false;
  if (folderName == "")
    return false;
  
  // TODO: should use a form-POST or AJAX
  window.location.href = "createFolder?name=" + escape(folderName);
  return false;
}

function ctxFolderDelete(sender) {
  if (!confirm("Delete current folder?"))
    return false;
  
  // TODO: should use a form-POST or AJAX
  window.location.href = "deleteFolder";
  return false;
}

/* bulk delete of messages */

function uixDeleteSelectedMessages(sender) {
  var rows;
  var failCount = 0;
  
  rows = collectSelectedRows();
  for (var i = 0; i < rows.length; i++) {
    var url, http, rowElem;
    
    /* send AJAX request (synchronously) */
    
    url = (ApplicationBaseURL + currentMailbox + "/"
           + rows[i] + "/trash?jsonly=1");
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
    rowElem = document.getElementById("row_" + rows[i]);

    rowElem.parentNode.removeChild(rowElem);
  }

  if (failCount > 0)
    alert("Could not delete " + failCount + " messages!");
  
  return false;
}

/* ajax mailbox handling */

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

function onMailboxTreeItemClick(element)
{
  var topNode = document.getElementById('d');
  var mailbox = element.parentNode.getAttribute("dataname");

  if (topNode.selectedEntry)
    deselectNode(topNode.selectedEntry);
  selectNode(element);
  topNode.selectedEntry = element;

  openMailbox(mailbox);
}

function openMailbox(mailbox)
{
  if (mailbox != currentMailbox) {
    currentMailbox = mailbox;
    var url = ApplicationBaseURL + mailbox + "/view?noframe=1&desc=1";
    var mailboxContent = document.getElementById("mailboxContent");
    var mailboxDragHandle = document.getElementById("mailboxDragHandle");
    var messageContent = document.getElementById("messageContent");
    messageContent.innerHTML = '';
    if (mailbox.lastIndexOf("/") == 0) {
      var url = (ApplicationBaseURL + currentMailbox + "/"
                 + "/view?noframe=1");
      if (document.messageAjaxRequest) {
        document.messageAjaxRequest.aborted = true;
        document.messageAjaxRequest.abort();
      }
      document.messageAjaxRequest
        = triggerAjaxRequest(url, messageCallback);
      mailboxContent.innerHTML = '';
      mailboxContent.style.visibility = "hidden;";
      mailboxDragHandle.style.visibility = "hidden;";
      messageContent.style.top = "0px;";
    } else {
      if (document.messageListAjaxRequest) {
        document.messageListAjaxRequest.aborted = true;
        document.messageListAjaxRequest.abort();
      }
      if (currentMessages[mailbox]) {
        loadMessage(currentMessages[mailbox]);
        url += '&pageforuid=' + currentMessages[mailbox];
      }
      document.messageListAjaxRequest
        = triggerAjaxRequest(url, messageListCallback,
                             currentMessages[mailbox]);
      if (mailboxContent.style.visibility == "hidden") {
        mailboxContent.style.visibility = "visible;";
        mailboxDragHandle.style.visibility = "visible;";
        messageContent.style.top = (mailboxDragHandle.offsetTop
                                    + mailboxDragHandle.offsetHeight
                                    + 'px;');
      }
    }
  }
//   triggerAjaxRequest(mailbox, 'toolbar', toolbarCallback);
}

function openMailboxAtIndex(element) {
  var idx = element.getAttribute("idx");
  var url = ApplicationBaseURL + currentMailbox + "/view?noframe=1&idx=" + idx;

  if (document.messageListAjaxRequest) {
    document.messageListAjaxRequest.aborted = true;
    document.messageListAjaxRequest.abort();
  }
  document.messageListAjaxRequest
    = triggerAjaxRequest(url, messageListCallback);
}

function messageListCallback(http)
{
  var div = document.getElementById('mailboxContent');

  if (http.readyState == 4
      && http.status == 200) {
    document.messageListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var selected = http.callbackData;
    if (selected) {
      var row = document.getElementById('row_' + selected);
      selectNode(row);
    }
  }
  else
    log ("ajax fuckage");
}

function onMessageContextMenu(event, element)
{
  var menu = document.getElementById('messageListMenu');
  menu.addEventListener("hideMenu", onMessageContextMenuHide, false);
  onMenuClick(event, 'messageListMenu');

  var topNode = document.getElementById('messageList');
  var selectedNodeIds = collectSelectedRows();
  topNode.menuSelectedRows = selectedNodeIds;
  for (var i = 0; i < selectedNodeIds.length; i++) {
    var selectedNode = document.getElementById("row_" + selectedNodeIds[i]);
    deselectNode (selectedNode);
  }
  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onMessageContextMenuHide(event)
{
  var topNode = document.getElementById('messageList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodeIds = topNode.menuSelectedRows;
    for (var i = 0; i < nodeIds.length; i++) {
      var node = document.getElementById("row_" + nodeIds[i]);
      selectNode (node);
    }
    topNode.menuSelectedRows = null;
  }
}

function onFolderMenuClick(event, element, menutype)
{
  var onhide, menuName;

  if (menutype == "inbox") {
    menuName = "inboxIconMenu";
  } else if (menutype == "account") {
    menuName = "accountIconMenu";
  } else if (menutype == "trash") {
    menuName = "trashIconMenu";
  } else {
    menuName = "mailboxIconMenu";
  }

  var menu = document.getElementById(menuName);
  menu.addEventListener("hideMenu", onFolderMenuHide, false);
  onMenuClick(event, menuName);

  var topNode = document.getElementById('d');
  if (topNode.selectedEntry)
    deselectNode(topNode.selectedEntry);
  if (topNode.menuSelectedEntry)
    deselectNode(topNode.menuSelectedEntry);
  topNode.menuSelectedEntry = element;
  selectNode(element);
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

  while (counter < cachedMessages.length
         && message == null)
    if (cachedMessages[counter]
        && cachedMessages[counter]['idx'] == currentMailbox + '/' + idx)
      message = cachedMessages[counter];
    else
      counter++;

  return message;
}

function storeCachedMessage(cachedMessage)
{
  var oldest = -1;
  var timeOldest = -1;
  var counter = 0;

  if (cachedMessages.length < maxCachedMessages)
    oldest = cachedMessages.length;
  else {
    while (cachedMessages[counter]) {
      if (oldest == -1
          || cachedMessages[counter]['time'] < timeOldest) {
        oldest = counter;
        timeOldest = cachedMessages[counter]['time'];
      }
      counter++;
    }

    if (oldest == -1)
      oldest = 0;
  }

  cachedMessages[oldest] = cachedMessage;
}

function onMessageSelectionChange()
{
  var selection = collectSelectedRows();
  if (selection.length == 1)
    {
      var idx = selection[0];

      if (currentMessages[currentMailbox] != idx) {
        currentMessages[currentMailbox] = idx;
        loadMessage(idx);
      }
    }
}

function loadMessage(idx)
{
  var cachedMessage = getCachedMessage(idx);

  if (document.messageAjaxRequest) {
    document.messageAjaxRequest.aborted = true;
    document.messageAjaxRequest.abort();
  }

  if (cachedMessage == null) {
    var url = (ApplicationBaseURL + currentMailbox + "/"
               + idx + "/view?noframe=1");
    document.messageAjaxRequest
      = triggerAjaxRequest(url, messageCallback, idx);
    markMailInWindow(window, idx, true);
  } else {
    var div = document.getElementById('messageContent');
    div.innerHTML = cachedMessage['text'];
    cachedMessage['time'] = (new Date()).getTime();
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
      var cachedMessage = new Array();
      cachedMessage['idx'] = currentMailbox + '/' + http.callbackData;
      cachedMessage['time'] = (new Date()).getTime();
      cachedMessage['text'] = http.responseText;
      if (cachedMessage['text'].length < 30000)
        storeCachedMessage(cachedMessage);
    }
  }
  else
    log ("ajax fuckage");
}

function processMailboxMenuAction(mailbox)
{
  var currentNode, upperNode;
  var mailboxName;
  var action;

  mailboxName = mailbox.getAttribute('mailboxname');
  currentNode = mailbox;
  upperNode = null;

  while (currentNode
         && !currentNode.hasAttribute('mailboxaction'))
    currentNode = currentNode.parentNode.parentNode.parentMenuItem;

  if (currentNode)
    {
      action = currentNode.getAttribute('mailboxaction');
      var rows  = collectSelectedRows();
      var rString = rows.join(', ');
      alert("performing '" + action + "' on " + rString
            + " to " + mailboxName);
    }
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
  searchField = document.getElementById('searchValue');
  searchCriteria = document.getElementById('searchCriteria');
  
  var node = event.target;
  searchField.setAttribute("ghost-phrase", node.innerHTML);
  searchCriteria = node.getAttribute('id');
}

function checkSearchValue(event)
{
  var form = event.target;
  var searchField = document.getElementById('searchValue');
  var ghostPhrase = searchField.getAttribute('ghost-phrase');

  if (searchField.value == ghostPhrase)
    searchField.value = "";
}

function onSearchChange()
{
}

function onSearchMouseDown(event)
{
  searchField = document.getElementById('searchValue');
  superNode = searchField.parentNode.parentNode.parentNode;
  relX = (event.pageX - superNode.offsetLeft - searchField.offsetLeft);
  relY = (event.pageY - superNode.offsetTop - searchField.offsetTop);

  if (relY < 24) {
    event.cancelBubble = true;
    event.returnValue = false;
  }
}

function onSearchFocus(event)
{
  searchField = document.getElementById('searchValue');
  ghostPhrase = searchField.getAttribute("ghost-phrase");
  if (searchField.value == ghostPhrase) {
    searchField.value = "";
    searchField.setAttribute("modified", "");
  } else {
    searchField.select();
  }

  searchField.style.color = "#000";
}

function onSearchBlur()
{
  var searchField = document.getElementById('searchValue');
  var ghostPhrase = searchField.getAttribute("ghost-phrase");

  if (searchField.value == "") {
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";
    searchField.value = ghostPhrase;
  } else if (searchField.value == ghostPhrase) {
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";
  } else {
    searchField.setAttribute("modified", "yes");
    searchField.style.color = "#000";
  }
}

function initCriteria()
{
  var searchCriteria = document.getElementById('searchCriteria');
  var searchField = document.getElementById('searchValue');
  var firstOption;
 
  if (searchCriteria.value == ''
      || searchField.value == '') {
    firstOption = document.getElementById('searchOptions').childNodes[1];
    searchCriteria.value = firstOption.getAttribute('id');
    searchField.value = firstOption.innerHTML;
    searchField.setAttribute('ghost-phrase', firstOption.innerHTML);
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";
  }
}

function deleteSelectedMails()
{
}


/* message menu entries */
function onMenuOpenMessage(event)
{
  var node = getParentMenu(event.target).menuTarget.parentNode;
  var msgId = node.getAttribute('id').substr(4);

  openMessageWindow(null, msgId,
                    ApplicationBaseURL + currentMailbox
                    + "/" + msgId + "/view");

  return false;
}

function onMenuReplyToSender(event)
{
  openMessageWindowsForSelection(null, 'reply');

  return false;
}

function onMenuReplyToAll(event)
{
  openMessageWindowsForSelection(null, 'replyall');

  return false;
}

function onMenuForwardMessage(event)
{
  openMessageWindowsForSelection(null, 'forward');

  return false;
}

function onMenuDeleteMessage(event)
{
  uixDeleteSelectedMessages(null);

  return false;
}

/* contacts */
function newContactFromEmail(sender) {
  var emailre
    = /([a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z])/g;

  emailre.exec(sender.parentNode.parentNode.menuTarget.innerHTML);
  email = RegExp.$1;

  if (email.length > 0)
    {
      emailre.exec("");
      w = window.open(UserFolderURL + "/Contacts/new?contactEmail=" + email,
		      "SOGo_new_contact",
		      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0,"
                      + "location=0,directories=0,status=0,menubar=0,"
                      + "copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
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

function expandUpperTree(node)
{
  var currentNode = node.parentNode;

  while (currentNode.className != "dtree")
    {
      if (currentNode.className == 'clip')
        {
          var id = currentNode.getAttribute("id");
          var number = parseInt(id.substr(2));
          if (number > 0)
            {
              var cn = d.aNodes[number];
              d.nodeStatus(1, number, cn._ls);
            }
        }
      currentNode = currentNode.parentNode;
    }
}

function initMailboxSelection(mailboxName)
{
  currentMailbox = mailboxName;

  var tree = document.getElementById("d");
  var treeNodes = getElementsByClassName('DIV', 'dTreeNode', tree);
  var i = 0;
  while (i < treeNodes.length
         && treeNodes[i].getAttribute("dataname") != currentMailbox)
    i++;
  if (i < treeNodes.length) {
    var links = getElementsByClassName('A', 'node', treeNodes[i]);
    if (tree.selectedEntry)
      deselectNode(tree.selectedEntry);
    selectNode(links[0]);
    tree.selectedEntry = links[0];
    expandUpperTree(links[0]);
  }
}

function initMailboxAppearance()
{
  var mailboxContent = document.getElementById('mailboxContent');
  var messageContent = document.getElementById('messageContent');
  var mailboxDragHandle = document.getElementById('mailboxDragHandle');

  mailboxContent.style.height = (mailboxDragHandle.offsetTop
                                 - mailboxContent.offsetTop + 'px;');
  messageContent.style.top = (mailboxDragHandle.offsetTop
                              + mailboxDragHandle.offsetHeight
                              + 'px;');
}

function onHeaderClick(node)
{
  var href = node.getAttribute("href");

  if (document.messageListAjaxRequest) {
    document.messageListAjaxRequest.aborted = true;
    document.messageListAjaxRequest.abort();
  }
  url = ApplicationBaseURL + currentMailbox + "/" + href;
  if (!href.match(/noframe=/))
    url += "&noframe=1";
  log ("url: " + url);
  document.messageListAjaxRequest
    = triggerAjaxRequest(url, messageListCallback);

  return false;
}

function registerDraggableMessageNodes()
{
  log ("can we drag...");
}
