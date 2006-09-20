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
  row = $(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
}

function clearSearch(sender) {
  var searchField = window.$("search");
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
  
  r = $('compose_rightside');
  r.style.display = 'block';
  l = $('compose_leftside');
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

  e = $('compose_attachments_list');
  e.innerHTML = text;
  this.showInlineAttachmentList(sender);
}

function openAddressbook(sender) {
  var urlstr;
  
  urlstr = ApplicationBaseURL + "/../Contacts/select";
  var w = window.open(urlstr, "Addressbook",
                      "width=640,height=400,left=10,top=10,toolbar=no," +
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

  msgDiv = win.$("div_" + msguid);
  if (msgDiv) {
    if (markread) {
      msgDiv.removeClassName("mailer_unreadmailsubject");
      msgDiv.addClassName("mailer_readmailsubject");
      msgDiv = win.$("unreaddiv_" + msguid);
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
      msgDiv.removeClassName('mailer_readmailsubject');
      msgDiv.addClassName('mailer_unreadmailsubject');
      msgDiv = win.$("readdiv_" + msguid);
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
  var messageList = $("messageList");
  var rows  = messageList.getSelectedRowsId();
  var idset = "";

  for (var i = 0; i < rows.length; i++)
    win = openMessageWindow(sender,
			    rows[i].substr(4)        /* msguid */,
			    ApplicationBaseURL + currentMailbox
                            + "/" + rows[i].substr(4)
                            + "/" + action /* url */);
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
  var failCount = 0;
  
  var messageList = $("messageList");
  var rows = messageList.getSelectedRows();

  for (var i = 0; i < rows.length; i++) {
    var url, http;
    
    /* send AJAX request (synchronously) */
    
    url = (ApplicationBaseURL + currentMailbox + "/"
           + rows[i].getAttribute("id").substr(4)
           + "/trash?jsonly=1");
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
    rows[i].parentNode.removeChild(rows[i]);
  }

  if (failCount > 0)
    alert("Could not delete " + failCount + " messages!");
  
  return false;
}

function onMailboxTreeItemClick(element)
{
  var topNode = $('d');
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
    var mailboxContent = $("mailboxContent");
    var mailboxDragHandle = $("mailboxDragHandle");
    var messageContent = $("messageContent");
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
  var div = $('mailboxContent');

  if (http.readyState == 4
      && http.status == 200) {
    document.messageListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var selected = http.callbackData;
    if (selected) {
      var row = $('row_' + selected);
      selectNode(row);
    }
  }
  else
    log ("ajax fuckage");
}

function onMessageContextMenu(event, element)
{
  var menu = $('messageListMenu');
  menu.addEventListener("hideMenu", onMessageContextMenuHide, false);
  onMenuClick(event, 'messageListMenu');

  var topNode = $('messageList');
  var selectedNodes = topNode.getSelectedRows();
  for (var i = 0; i < selectedNodes.length; i++)
    deselectNode (selectedNodes[i]);
  topNode.menuSelectedRows = selectedNodes;
  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onMessageContextMenuHide(event)
{
  var topNode = $('messageList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodes = topNode.menuSelectedRows;
    for (var i = 0; i < nodes.length; i++)
      selectNode(nodes[i]);
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

  var menu = $(menuName);
  menu.addEventListener("hideMenu", onFolderMenuHide, false);
  onMenuClick(event, menuName);

  var topNode = $('d');
  if (topNode.selectedEntry)
    deselectNode(topNode.selectedEntry);
  if (topNode.menuSelectedEntry)
    deselectNode(topNode.menuSelectedEntry);
  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onFolderMenuHide(event)
{
  var topNode = $('d');

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
  var messageList = $("messageList");
  var rows  = messageList.getSelectedRowsId();

  if (rows.length == 1) {
    var idx = rows[0].substr(4);

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
    var div = $('messageContent');
    div.innerHTML = cachedMessage['text'];
    cachedMessage['time'] = (new Date()).getTime();
    document.messageAjaxRequest = null;
  }
}

function messageCallback(http)
{
  var div = $('messageContent');

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
//       var rows  = collectSelectedRows();
//       var rString = rows.join(', ');
//       alert("performing '" + action + "' on " + rString
//             + " to " + mailboxName);
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
  var e = $("moveto");
  this.enableElement(e, rowSelectionCount > 0);
}

function moveTo(uri) {
  alert("MoveTo: " + uri);
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
  var mailto = sender.parentNode.parentNode.menuTarget.innerHTML;

  var emailre
    = /([a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z])/g;
  emailre.exec(mailto);
  email = RegExp.$1;

  var namere = /(\w[\w\ _-]+)\ (&lt;|<)/;
  var c_name = '';
  if (namere.test(mailto)) {
    namere.exec(mailto);
    c_name += RegExp.$1;
  }

  if (email.length > 0)
    {
      emailre.exec("");
      var url = UserFolderURL + "Contacts/new?contactEmail=" + email;
      if (c_name)
        url += "&contactFN=" + c_name;
      w = window.open(url, null,
                      "width=546,height=490,resizable=1,scrollbars=1,toolbar=0,"
                      + "location=0,directories=0,status=0,menubar=0,copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
}

function newEmailTo(sender) {
  return openMailTo(sender.parentNode.parentNode.menuTarget.innerHTML);
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

  var tree = $("d");
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

function onSearchFormSubmit()
{
  log ("search not implemented");

  return false;
}
