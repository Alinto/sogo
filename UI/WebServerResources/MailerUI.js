/* JavaScript for SOGoMail */
var accounts = {};
var mailboxTree;

var currentMessages = new Array();
var maxCachedMessages = 20;
var cachedMessages = new Array();
var currentMailbox = null;

var usersRightsWindowHeight = 320;
var usersRightsWindowWidth = 400;

/* mail list */

function openMessageWindow(msguid, url) {
   var wId = '';
   if (msguid) {
      wId += "SOGo_msg_" + msguid;
      markMailReadInWindow(window, msguid);
   }
   var msgWin = window.open(url, wId,
			    "width=680,height=520,resizable=1,scrollbars=1,toolbar=0,"
			    + "location=0,directories=0,status=0,menubar=0,copyhistory=0");
   if (msguid) {
      msgWin.messageId = msguid;
      msgWin.messageURL = ApplicationBaseURL + currentMailbox + "/" + msguid;
   }
   msgWin.focus();

   return false;
}

function onMessageDoubleClick(event) {
   resetSelection(window);
   var msguid = this.parentNode.id.substr(4);
   
   return openMessageWindow(msguid,
			    ApplicationBaseURL + currentMailbox + "/"
			    + msguid + "/popupview");
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
      alert(labels.error_validationfailed.decodeEntities() + ":\n"
	    + errortext.decodeEntities());
      return false;
   }
   return true;
}

function clickedEditorSend(sender) {
   if (!validateEditorInput(sender))
      return false;

   document.pageform.action = "send";
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
   document.pageform.action = "save";
   document.pageform.submit();
   refreshOpener();
   return true;
}

function clickedEditorDelete(sender) {
   document.pageform.action = "delete";
   document.pageform.submit();
   refreshOpener();
   window.close();
   return true;
}

function openAddressbook(sender) {
   var urlstr;
   
   urlstr = ApplicationBaseURL + "/../Contacts/?popup=YES";
   var w = window.open(urlstr, "Addressbook",
		       "width=640,height=400,resizable=1,scrollbars=1,toolbar=0,"
		       + "location=0,directories=0,status=0,menubar=0,copyhistory=0");
   w.focus();

   return false;
}

function onMenuSharing(event) {
   var folderID = document.menuTarget.getAttribute("dataname");
   var urlstr = URLForFolderID(folderID) + "/acls";
   preventDefault(event);

   openAclWindow(urlstr);
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

function openMessageWindowsForSelection(action) {
   if (document.body.hasClassName("popup"))
      win = openMessageWindow(window.messageId,
			      window.messageURL + "/" + action /* url */);
   else {
      var messageList = $("messageList");
      var rows  = messageList.getSelectedRowsId();
      var idset = "";
      for (var i = 0; i < rows.length; i++)
	 win = openMessageWindow(rows[i].substr(4)        /* msguid */,
				 ApplicationBaseURL + currentMailbox
				 + "/" + rows[i].substr(4)
				 + "/" + action /* url */);
   }

   return false;
}

function mailListMarkMessage(event) {
   var http = createHTTPClient();
   var url = ApplicationBaseURL + currentMailbox + "/" + action + "?uid=" + msguid;

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

function ml_highlight(sender) {
   oldMaillistHighlight = sender.className;
   if (oldMaillistHighlight == "tableview_highlight")
      oldMaillistHighlight = null;
   sender.className = "tableview_highlight";
}

function ml_lowlight(sender) {
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
   if (!confirm("Delete current folder?").decodeEntities())
      return false;
   
   // TODO: should use a form-POST or AJAX
	       window.location.href = "deleteFolder";
   return false;
}

/* bulk delete of messages */

function uixDeleteSelectedMessages(sender) {
   var failCount = 0;
   
   var messageList = $("messageList");
   var rowIds = messageList.getSelectedRowsId();

   for (var i = 0; i < rowIds.length; i++) {
      var url, http;
      var rowId = rowIds[i].substr(4);
      /* send AJAX request (synchronously) */

      var messageId = currentMailbox + "/" + rowId;
      url = ApplicationBaseURL + messageId + "/trash?jsonly=1";
      http = createHTTPClient();
      http.open("GET", url, false /* not async */);
      http.send("");
      if (http.status != 200) { /* request failed */
				    failCount++;
      http = null;
      continue;
      } else {
	 deleteCachedMessage(messageId);
	 if (currentMessages[currentMailbox] == rowId) {
	    var div = $('messageContent');
	    div.innerHTML = "";
	    currentMessages[currentMailbox] = null;
	 }
      }
      http = null;

      /* remove from page */

	  /* line-through would be nicer, but hiding is OK too */
	  var row = $(rowIds[i]);
      row.parentNode.removeChild(row);
   }

   if (failCount > 0)
      alert("Could not delete " + failCount + " messages!");
   
   return false;
}

function moveMessages(rowIds, folder) {
   var failCount = 0;

   for (var i = 0; i < rowIds.length; i++) {
      var url, http;

      /* send AJAX request (synchronously) */
	  
      var messageId = currentMailbox + "/" + rowIds[i];
      url = ApplicationBaseURL + messageId + "/move?jsonly=1&tofolder=" + folder;
      http = createHTTPClient();
      http.open("GET", url, false /* not async */);
      http.send("");
      if (http.status == 200) {
	 var row = $("row_" + rowIds[i]);
	 row.parentNode.removeChild(row);
	 deleteCachedMessage(messageId);
	 if (currentMessages[currentMailbox] == rowIds[i]) {
	    var div = $('messageContent');
	    div.innerHTML = "";
	    currentMessages[currentMailbox] = null;
	 }
      }
      else /* request failed */
	      failCount++;

      /* remove from page */

	  /* line-through would be nicer, but hiding is OK too */
	  }

   if (failCount > 0)
      alert("Could not move " + failCount + " messages!");
   
   return failCount;
}

function onMenuDeleteMessage(event) {
   uixDeleteSelectedMessages();
   preventDefault(event);
}

function onMailboxTreeItemClick(event) {
   var topNode = $("mailboxTree");
   var mailbox = this.parentNode.getAttribute("dataname");

   if (topNode.selectedEntry)
      topNode.selectedEntry.deselect();
   this.select();
   topNode.selectedEntry = this;

   search = {};
   $("searchValue").value = "";
   initCriteria();

   var datatype = this.parentNode.getAttribute("datatype");
   if (datatype == "account" || datatype == "additional") {
      currentMailbox = mailbox;
      $("messageContent").innerHTML = "";
      var body = $("messageList").tBodies[0];
      for (var i = body.rows.length - 1; i > 0; i--)
	 body.deleteRow(i);
   }
   else
      openMailbox(mailbox);
   
   preventDefault(event);
}

function onMailboxMenuMove() {
   window.alert("unimplemented");
}

function onMailboxMenuCopy() {
   window.alert("unimplemented");
}

function _refreshWindowMailbox() {
   openMailbox(currentMailbox, true);
}

function refreshMailbox() {
   var topWindow = getTopWindow();
   if (topWindow)
      topWindow._refreshWindowMailbox();

   return false;
}

function openMailbox(mailbox, reload) {
   if (mailbox != currentMailbox || reload) {
      currentMailbox = mailbox;
      var url = ApplicationBaseURL + mailbox + "/view?noframe=1&desc=1";
      var mailboxContent = $("mailboxContent");
      var rightDragHandle = $("rightDragHandle");
      var messageContent = $("messageContent");
      messageContent.innerHTML = '';
/*      if (mailbox.lastIndexOf("/") == 0) {
	 log ("mailbox.lastIndexOf...");
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
	 rightDragHandle.style.visibility = "hidden;";
	 messageContent.style.top = "0px;";
      } else { */
	 if (document.messageListAjaxRequest) {
	    document.messageListAjaxRequest.aborted = true;
	    document.messageListAjaxRequest.abort();
	 }
	 if (currentMessages[mailbox]) {
	    loadMessage(currentMessages[mailbox]);
	    url += '&pageforuid=' + currentMessages[mailbox];
	 }
	 var searchValue = search["value"];
	 if (searchValue && searchValue.length > 0)
	    url += ("&search=" + search["criteria"]
		    + "&value=" + searchValue);
	 document.messageListAjaxRequest
	    = triggerAjaxRequest(url, messageListCallback,
				 currentMessages[mailbox]);
	 if (mailboxContent.getStyle('visibility') == "hidden") {
	    mailboxContent.setStyle({ visibility: "visible" });
	    rightDragHandle.setStyle({ visibility: "visible" });
	    messageContent.setStyle({ top: (rightDragHandle.offsetTop
					    + rightDragHandle.offsetHeight
					    + 'px') });
	 }
//      }
   }
   //   triggerAjaxRequest(mailbox, 'toolbar', toolbarCallback);
}

function openMailboxAtIndex(event) {
   var idx = this.getAttribute("idx");
   var url = ApplicationBaseURL + currentMailbox + "/view?noframe=1&idx=" + idx;
   var searchValue = search["value"];
   if (searchValue && searchValue.length > 0)
      url += ("&search=" + search["criteria"]
	      + "&value=" + searchValue);

   if (document.messageListAjaxRequest) {
      document.messageListAjaxRequest.aborted = true;
      document.messageListAjaxRequest.abort();
   }
   document.messageListAjaxRequest
      = triggerAjaxRequest(url, messageListCallback);

   preventDefault(event);
}

function messageListCallback(http) {
   var div = $('mailboxContent');
   
   if (http.readyState == 4
       && http.status == 200) {
      document.messageListAjaxRequest = null;
      div.innerHTML = http.responseText;
      var selected = http.callbackData;
      if (selected) {
	 var row = $('row_' + selected);
	 row.select();
      }
      configureMessageListEvents();
      configureSortableTableHeaders();
   }
   else
      log("messageListCallback: problem during ajax request (readyState = " + http.readyState + ", status = " + http.status + ")");
}

function onMessageContextMenu(event) {
   var menu = $('messageListMenu');
   Event.observe(menu, "hideMenu", onMessageContextMenuHide);
   popupMenu(event, "messageListMenu", this);

   var topNode = $('messageList');
   var selectedNodes = topNode.getSelectedRows();
   for (var i = 0; i < selectedNodes.length; i++)
      selectedNodes[i].deselect();
   topNode.menuSelectedRows = selectedNodes;
   topNode.menuSelectedEntry = this;
   this.select();
}

function onMessageContextMenuHide(event) {
   var topNode = $('messageList');

   if (topNode.menuSelectedEntry) {
      topNode.menuSelectedEntry.deselect();
      topNode.menuSelectedEntry = null;
   }
   if (topNode.menuSelectedRows) {
      var nodes = topNode.menuSelectedRows;
      for (var i = 0; i < nodes.length; i++)
	 nodes[i].select();
      topNode.menuSelectedRows = null;
   }
}

function onFolderMenuClick(event) {
   var onhide, menuName;
   
   var menutype = this.parentNode.getAttribute("datatype");
   if (menutype) {
      if (menutype == "inbox") {
	 menuName = "inboxIconMenu";
      } else if (menutype == "account") {
	 menuName = "accountIconMenu";
      } else if (menutype == "trash") {
	 menuName = "trashIconMenu";
      } else {
	 menuName = "mailboxIconMenu";
      }
   } else {
      menuName = "mailboxIconMenu";
   }

   var menu = $(menuName);
   Event.observe(menu, "hideMenu", onFolderMenuHide);
   popupMenu(event, menuName, this.parentNode);

   var topNode = $("mailboxTree");
   if (topNode.selectedEntry)
      topNode.selectedEntry.deselect();
   if (topNode.menuSelectedEntry)
      topNode.menuSelectedEntry.deselect();
   topNode.menuSelectedEntry = this;
   this.select();

   preventDefault(event);
}

function onFolderMenuHide(event) {
   var topNode = $("mailboxTree");

   if (topNode.menuSelectedEntry) {
      topNode.menuSelectedEntry.deselect();
      topNode.menuSelectedEntry = null;
   }
   if (topNode.selectedEntry)
      topNode.selectedEntry.select();
}

function deleteCachedMessage(messageId) {
   var done = false;
   var counter = 0;

   while (counter < cachedMessages.length
	  && !done)
      if (cachedMessages[counter]
	  && cachedMessages[counter]['idx'] == messageId) {
	 cachedMessages.splice(counter, 1);
	 done = true;
      }
      else
	 counter++;
}

function getCachedMessage(idx) {
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

function storeCachedMessage(cachedMessage) {
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

function onMessageSelectionChange() {
   var rows = this.getSelectedRowsId();

   if (rows.length == 1) {
      var idx = rows[0].substr(4);

      if (currentMessages[currentMailbox] != idx) {
	 currentMessages[currentMailbox] = idx;
	 loadMessage(idx);
      }
   }
}

function loadMessage(idx) {
   if (document.messageAjaxRequest) {
      document.messageAjaxRequest.aborted = true;
      document.messageAjaxRequest.abort();
   }

   var cachedMessage = getCachedMessage(idx);

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
      configureLinksInMessage();
   }
}

function configureLinksInMessage() {
   var messageDiv = $('messageContent');
   var mailContentDiv = document.getElementsByClassName('mailer_mailcontent',
							messageDiv)[0];
   Event.observe(mailContentDiv, "contextmenu", onMessageContentMenu.bindAsEventListener(mailContentDiv));
   var anchors = messageDiv.getElementsByTagName('a');
   for (var i = 0; i < anchors.length; i++)
      if (anchors[i].href.substring(0,7) == "mailto:") {
	 Event.observe(anchors[i], "click", onEmailAddressClick.bindAsEventListener(anchors[i]));
	 Event.observe(anchors[i], "contextmenu", onEmailAddressClick.bindAsEventListener(anchors[i]));
      }
      else
	 Event.observe(anchors[i], "click", onMessageAnchorClick);
}

function onMessageContentMenu(event) {
   popupMenu(event, 'messageContentMenu', this);
}

function onEmailAddressClick(event) {
   popupMenu(event, 'addressMenu', this);
}

function onMessageAnchorClick (event) {
   window.open(this.href);
   preventDefault(event);
}

function messageCallback(http) {
   var div = $('messageContent');

   if (http.readyState == 4
       && http.status == 200) {
      document.messageAjaxRequest = null;
      div.innerHTML = http.responseText;
      configureLinksInMessage();
      
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
      log("messageCallback: problem during ajax request: " + http.status);
}

function processMailboxMenuAction(mailbox) {
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

function deleteSelectedMails() {
}

/* message menu entries */
function onMenuOpenMessage(event) {
   return openMessageWindowsForSelection('popupview');
}

function onMenuReplyToSender(event) {
   return openMessageWindowsForSelection('reply');
}

function onMenuReplyToAll(event) {
   return openMessageWindowsForSelection('replyall');
}

function onMenuForwardMessage(event) {
   return openMessageWindowsForSelection('forward');
}

/* contacts */
function newContactFromEmail(event) {
   var mailto = document.menuTarget.innerHTML;

   //   var emailre
	   //     = /([a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z])/g;
   //   emailre.exec(mailto);
   //   email = RegExp.$1;

   //   var namere = /(\w[\w\ _-]+)\ (&lt;|<)/;
   //   var c_name = '';
   //   if (namere.test(mailto)) {
      //     namere.exec(mailto);
      //     c_name += RegExp.$1;
      //   }

   var email = extractEmailAddress(mailto);
   var c_name = extractEmailName(mailto);
   if (email.length > 0)
   {
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
   return openMailTo(document.menuTarget.innerHTML);
}

function expandUpperTree(node) {
   var currentNode = node.parentNode;

   while (currentNode.className != "dtree") {
      if (currentNode.className == 'clip') {
	 var id = currentNode.getAttribute("id");
	 var number = parseInt(id.substr(2));
	 if (number > 0) {
	    var cn = mailboxTree.aNodes[number];
	    mailboxTree.nodeStatus(1, number, cn._ls);
	 }
      }
      currentNode = currentNode.parentNode;
   }
}

function onHeaderClick(event) {
   if (document.messageListAjaxRequest) {
      document.messageListAjaxRequest.aborted = true;
      document.messageListAjaxRequest.abort();
   }
   var link = this.getAttribute('href');
   url = ApplicationBaseURL + currentMailbox + "/" + link;
   if (!link.match(/noframe=/))
      url += "&noframe=1";
   document.messageListAjaxRequest
      = triggerAjaxRequest(url, messageListCallback);

   preventDefault(event);
}

function onSearchFormSubmit(event) {
   var searchValue = $("searchValue");
   var searchCriteria = $("searchCriteria");

   search["criteria"] = searchCriteria.value;
   search["value"] = searchValue.value;

   openMailbox(currentMailbox, true);
}

function pouetpouet(event) {
   window.alert("pouet pouet");
}

var mailboxSpanAcceptType = function(type) {
   return (type == "mailRow");
}

var mailboxSpanEnter = function() {
   this.addClassName("_dragOver");
}

var mailboxSpanExit = function() {
   this.removeClassName("_dragOver");
}

var mailboxSpanDrop = function(data) {
   var success = false;

   if (data) {
      var folder = this.parentNode.parentNode.getAttribute("dataname");
      if (folder != currentMailbox)
	 success = (moveMessages(data, folder) == 0);
   }
   else
   success = false;

   return success;
}

var plusSignEnter = function() {
   var nodeNr = parseInt(this.id.substr(2));
   if (!mailboxTree.aNodes[nodeNr]._io)
     this.plusSignTimer = setTimeout("openPlusSign('" + nodeNr + "');", 1000);
}

var plusSignExit = function() {
   if (this.plusSignTimer) {
      clearTimeout(this.plusSignTimer);
      this.plusSignTimer = null;
   }
}

function openPlusSign(nodeNr) {
   mailboxTree.nodeStatus(1, nodeNr, mailboxTree.aNodes[nodeNr]._ls);
   mailboxTree.aNodes[nodeNr]._io = 1;
   this.plusSignTimer = null;
}

var messageListGhost = function () {
   var newDiv = document.createElement("div");
   //   newDiv.style.width = "25px;";
   //   newDiv.style.height = "25px;";
   newDiv.style.backgroundColor = "#aae;";
   newDiv.style.border = "2px solid #a3a;";
   newDiv.style.padding = "5px;";
   newDiv.ghostOffsetX = 10;
   newDiv.ghostOffsetY = 5;

   var newImg = document.createElement("img");
   newImg.src = ResourcesURL + "/message-mail.png";

   var list = $("messageList");
   var count = list.getSelectedRows().length;
   newDiv.appendChild(newImg);
   newDiv.appendChild(document.createElement("br"));
   newDiv.appendChild(document.createTextNode(count + " messages..."));

   return newDiv;
}

var messageListData = function(type) {
   var rows = this.parentNode.parentNode.getSelectedRowsId();
   var msgIds = new Array();
   for (var i = 0; i < rows.length; i++)
   msgIds.push(rows[i].substr(4));

   return msgIds;
}

function configureMessageListEvents() {
   var messageList = $("messageList");
   if (messageList) {
      Event.observe(messageList, "mousedown",
		    onMessageSelectionChange.bindAsEventListener(messageList));
      var cell = messageList.tHead.rows[1].cells[0];
      if ($(cell).hasClassName("tbtv_navcell")) {
	 var anchors = $(cell).childNodesWithTag("a");
	 for (var i = 0; i < anchors.length; i++)
	    Event.observe(anchors[i], "click", openMailboxAtIndex.bindAsEventListener(anchors[i]));
      }

      rows = messageList.tBodies[0].rows;
      for (var i = 0; i < rows.length; i++) {
	 Event.observe(rows[i], "mousedown", onRowClick);
	 Event.observe(rows[i], "contextmenu", onMessageContextMenu.bindAsEventListener(rows[i]));
	 
	 rows[i].dndTypes = function() { return new Array("mailRow"); };
	 rows[i].dndGhost = messageListGhost;
	 rows[i].dndDataForType = messageListData;
	 document.DNDManager.registerSource(rows[i]);
	 
	 for (var j = 0; j < rows[i].cells.length; j++) {
	    var cell = rows[i].cells[j];
	    Event.observe(cell, "mousedown", listRowMouseDownHandler);
	    if (j == 2 || j == 3 || j == 5)
	       Event.observe(cell, "dblclick", onMessageDoubleClick.bindAsEventListener(cell));
	    else if (j == 4) {
	       var img = cell.childNodesWithTag("img")[0];
	       Event.observe(img, "click", mailListMarkMessage);
	    }
	 }
      }
   }
}

function configureDragHandles() {
   var handle = $("verticalDragHandle");
   if (handle) {
      handle.addInterface(SOGoDragHandlesInterface);
      handle.leftBlock=$("leftPanel");
      handle.rightBlock=$("rightPanel");
   }

   handle = $("rightDragHandle");
   if (handle) {
      handle.addInterface(SOGoDragHandlesInterface);
      handle.upperBlock=$("mailboxContent");
      handle.lowerBlock=$("messageContent");
   }
}

/* dnd */
function initDnd() {
   //   log("MailerUI initDnd");

   var tree = $("mailboxTree");
   if (tree) {
      var images = tree.getElementsByTagName("img");
      for (var i = 0; i < images.length; i++) {
	 if (images[i].id[0] == 'j') {
	    images[i].dndAcceptType = mailboxSpanAcceptType;
	    images[i].dndEnter = plusSignEnter;
	    images[i].dndExit = plusSignExit;
	    document.DNDManager.registerDestination(images[i]);
	 }
      }
      var nodes = document.getElementsByClassName("nodeName", tree);
      for (var i = 0; i < nodes.length; i++) {
	 nodes[i].dndAcceptType = mailboxSpanAcceptType;
	 nodes[i].dndEnter = mailboxSpanEnter;
	 nodes[i].dndExit = mailboxSpanExit;
	 nodes[i].dndDrop = mailboxSpanDrop;
	 document.DNDManager.registerDestination(nodes[i]);
      }
   }
}

/* stub */

function refreshContacts() {
}

function openInbox(node) {
   var done = false;
   openMailbox(node.parentNode.getAttribute("dataname"));
   var tree = $("mailboxTree");
   tree.selectedEntry = node;
   node.select();
   mailboxTree.o(1);
}

function initMailer(event) {
   if (!document.body.hasClassName("popup")) {
      configureMessageListEvents();
      initDnd();
      currentMailbox = "/" + accounts[0] + "/INBOX";
      initMailboxTree();
   }
}

function initMailboxTree() {
   mailboxTree = new dTree("mailboxTree");
   mailboxTree.config.folderLinks = true;
   mailboxTree.config.hideRoot = true;

   mailboxTree.icon.root = ResourcesURL + "/tbtv_account_17x17.gif";
   mailboxTree.icon.folder = ResourcesURL + "/tbtv_leaf_corner_17x17.gif";
   mailboxTree.icon.folderOpen	= ResourcesURL + "/tbtv_leaf_corner_17x17.gif";
   mailboxTree.icon.node = ResourcesURL + "/tbtv_leaf_corner_17x17.gif";
   mailboxTree.icon.line = ResourcesURL + "/tbtv_line_17x17.gif";
   mailboxTree.icon.join = ResourcesURL + "/tbtv_junction_17x17.gif";
   mailboxTree.icon.joinBottom	= ResourcesURL + "/tbtv_corner_17x17.gif";
   mailboxTree.icon.plus = ResourcesURL + "/tbtv_plus_17x17.gif";
   mailboxTree.icon.plusBottom	= ResourcesURL + "/tbtv_corner_plus_17x17.gif";
   mailboxTree.icon.minus = ResourcesURL + "/tbtv_minus_17x17.gif";
   mailboxTree.icon.minusBottom = ResourcesURL + "/tbtv_corner_minus_17x17.gif";
   mailboxTree.icon.nlPlus = ResourcesURL + "/tbtv_corner_plus_17x17.gif";
   mailboxTree.icon.nlMinus = ResourcesURL + "/tbtv_corner_minus_17x17.gif";
   mailboxTree.icon.empty = ResourcesURL + "/empty.gif";

   mailboxTree.add(0, -1, '');

   mailboxTree.pendingRequests = mailAccounts.length;
   for (var i = 0; i < mailAccounts.length; i++) {
      var url = ApplicationBaseURL + "/" + mailAccounts[i] + "/mailboxes";
      triggerAjaxRequest(url, onLoadMailboxesCallback, mailAccounts[i]);
   }
}

function updateMailboxTreeInPage() {
   $("folderTreeContent").innerHTML = mailboxTree;

   var inboxFound = false;
   var tree = $("mailboxTree");
   var nodes = document.getElementsByClassName("node", tree);
   for (i = 0; i < nodes.length; i++) {
      Event.observe(nodes[i], "click", onMailboxTreeItemClick.bindAsEventListener(nodes[i]));
      Event.observe(nodes[i], "contextmenu", onFolderMenuClick.bindAsEventListener(nodes[i]));
      if (!inboxFound
	  && nodes[i].parentNode.getAttribute("datatype") == "inbox") {
	 openInbox(nodes[i]);
	 inboxFound = true;
      }
   }
}

function mailboxMenuNode(type, name) {
   var newNode = document.createElement("li");
   var icon = MailerUIdTreeExtension.folderIcons[type];
   if (!icon)
      icon = "tbtv_leaf_corner_17x17.gif";
   var image = document.createElement("img");
   image.src = ResourcesURL + "/" + icon;
   newNode.appendChild(image);
   newNode.appendChild(document.createTextNode(" " + name));

   return newNode;
}

function generateMenuForMailbox(mailbox, prefix, callback) {
   var menuDIV = document.createElement("div");
   $(menuDIV).addClassName("menu");
   menuDIV.setAttribute("id", prefix + "Submenu");
   var menu = document.createElement("ul");
   menuDIV.appendChild(menu);

   var callbacks = new Array();
   if (mailbox.type != "account") {
      var newNode = document.createElement("li");
      newNode.mailbox = mailbox;
      newNode.appendChild(document.createTextNode("coucou"));
      menu.appendChild(newNode);
      menu.appendChild(document.createElement("li"));
      callbacks.push(callback);
      callbacks.push("-");
   }

   var submenuCount = 0;
   for (var i = 0; i < mailbox.children.length; i++) {
      var child = mailbox.children[i];
      var newNode = mailboxMenuNode(child.type, child.name);
      menu.appendChild(newNode);
      if (child.children.length > 0) {
	 var newPrefix = prefix + submenuCount;
	 var newSubmenu = generateMenuForMailbox(child,
						 newPrefix,
						 callback);
	 document.body.appendChild(newSubmenu);
	 callbacks.push(newPrefix + "Submenu");
	 submenuCount++;
      }
      else {
	 newNode.mailbox = child;
	 callbacks.push(callback);
      }
   }
   initMenu(menuDIV, callbacks);

   return menuDIV;
}

function updateMailboxMenus() {
   var mailboxActions = { move: onMailboxMenuMove,
			  copy: onMailboxMenuCopy };

   for (key in mailboxActions) {
      var menuId = key + "MailboxMenu";
      var menuDIV = $(menuId);
      if (menuDIV)
	 menuDIV.parentNode.removeChild(menuDIV);

      menuDIV = document.createElement("div");
      document.body.appendChild(menuDIV);

      var menu = document.createElement("ul");
      menuDIV.appendChild(menu);

      $(menuDIV).addClassName("menu");
      menuDIV.setAttribute("id", menuId);
      
      var submenuIds = new Array();
      for (var i = 0; i < mailAccounts.length; i++) {
	var menuEntry = mailboxMenuNode("account", mailAccounts[i]);
	 menu.appendChild(menuEntry);
	 var mailbox = accounts[mailAccounts[i]];
	 var newSubmenu = generateMenuForMailbox(mailbox,
						 key, mailboxActions[key]);
	 document.body.appendChild(newSubmenu);
	 submenuIds.push(newSubmenu.getAttribute("id"));
      }
      initMenu(menuDIV, submenuIds);
   }
}

function onLoadMailboxesCallback(http) {
   if (http.readyState == 4
       && http.status == 200) {
      var newAccount = buildMailboxes(http.callbackData,
				      http.responseText);
      accounts[http.callbackData] = newAccount;
      mailboxTree.addMailAccount(newAccount);
      mailboxTree.pendingRequests--;
      if (!mailboxTree.pendingRequests) {
	updateMailboxTreeInPage();
	updateMailboxMenus();
      }
  }

//       var tree = $("mailboxTree");
//       var treeNodes = document.getElementsByClassName("dTreeNode", tree);
//       var i = 0;
//       while (i < treeNodes.length
// 	     && treeNodes[i].getAttribute("dataname") != currentMailbox)
// 	 i++;
//       if (i < treeNodes.length) {
// 	 //     log("found mailbox");
// 	 var links = document.getElementsByClassName("node", treeNodes[i]);
// 	 if (tree.selectedEntry)
// 	    tree.selectedEntry.deselect();
// 	 links[0].select();
// 	 tree.selectedEntry = links[0];
// 	 expandUpperTree(links[0]);
//       }
}

function buildMailboxes(accountName, encoded) {
   var account = new Mailbox("account", accountName);
   var data = encoded.evalJSON(true);
   for (var i = 0; i < data.length; i++) {
      var currentNode = account;
      var names = data[i].path.split("/");
      for (var j = 1; j < (names.length - 1); j++) {
	 var node = currentNode.findMailboxByName(names[j]);
	 if (!node) {
	    node = new Mailbox("additional", names[j]);
	    currentNode.addMailbox(node);
	 }
	 currentNode = node;
      }
      var basename = names[names.length-1];
      var leaf = currentNode.findMailboxByName(basename);
      if (leaf)
	 leaf.type = data[i].type;
      else {
	 leaf = new Mailbox(data[i].type, basename);
	 currentNode.addMailbox(leaf);
      }
   }

   return account;
}

function onMenuCreateFolder(event) {
   var name = window.prompt(labels["Name :"].decodeEntities(), "");
   if (name && name.length > 0) {
      var folderID = document.menuTarget.getAttribute("dataname");
      var urlstr = URLForFolderID(folderID) + "/createFolder?name=" + name;
      triggerAjaxRequest(urlstr, folderOperationCallback);
   }
}

function onMenuRenameFolder(event) {
   var name = window.prompt(labels["Enter the new name of your folder :"]
			    .decodeEntities(),
			    "");
   if (name && name.length > 0) {
      var folderID = document.menuTarget.getAttribute("dataname");
      var urlstr = URLForFolderID(folderID) + "/renameFolder?name=" + name;
      triggerAjaxRequest(urlstr, folderOperationCallback);
   }
}

function onMenuDeleteFolder(event) {
   var answer = window.confirm(labels["Do you really want to move this folder into the trash ?"].decodeEntities());
   if (answer) {
      var folderID = document.menuTarget.getAttribute("dataname");
      var urlstr = URLForFolderID(folderID) + "/deleteFolder";
      triggerAjaxRequest(urlstr, folderOperationCallback);
   }
}

function onMenuEmptyTrash(event) {
   var folderID = document.menuTarget.getAttribute("dataname");
   var urlstr = URLForFolderID(folderID) + "/emptyTrash";
   triggerAjaxRequest(urlstr, folderOperationCallback);
}

function folderOperationCallback(http) {
   if (http.readyState == 4
       && http.status == 204)
      initMailboxTree();
   else
      window.alert(labels["Operation failed"].decodeEntities());
}

function getMenus() {
   var menus = {}
   menus["accountIconMenu"] = new Array(null, null, onMenuCreateFolder, null,
					null, null);
   menus["inboxIconMenu"] = new Array(null, null, null, "-", null,
				      onMenuCreateFolder, null, "-", null,
				      onMenuSharing);
   menus["trashIconMenu"] = new Array(null, null, null, "-", null,
				      onMenuCreateFolder, null,
				      onMenuEmptyTrash, "-", null,
				      onMenuSharing);
   menus["mailboxIconMenu"] = new Array(null, null, null, "-", null,
					onMenuCreateFolder,
					onMenuRenameFolder,
					null, onMenuDeleteFolder, "-", null,
					onMenuSharing);
   menus["addressMenu"] = new Array(newContactFromEmail, newEmailTo, null);
   menus["messageListMenu"] = new Array(onMenuOpenMessage, "-",
					onMenuReplyToSender,
					onMenuReplyToAll,
					onMenuForwardMessage, null,
					"-", "moveMailboxMenu",
					"copyMailboxMenu", "label-menu",
					"mark-menu", "-", null, null,
					null, onMenuDeleteMessage);
   menus["messageContentMenu"] = new Array(onMenuReplyToSender,
					   onMenuReplyToAll,
					   onMenuForwardMessage,
					   null, "moveMailboxMenu",
					   "copyMailboxMenu",
					   "-", "label-menu", "mark-menu",
					   "-",
					   null, null, null,
					   onMenuDeleteMessage);
   menus["label-menu"] = new Array(null, "-", null , null, null, null , null,
				   null);
   menus["mark-menu"] = new Array(null, null, null, null, "-", null, "-",
				  null, null, null);
   menus["searchMenu"] = new Array(setSearchCriteria, setSearchCriteria,
				   setSearchCriteria, setSearchCriteria,
				   setSearchCriteria);

   return menus;
}

addEvent(window, 'load', initMailer);

function Mailbox(type, name) {
   this.type = type;
   this.name = name;
   this.parentFolder = null;
   this.children = new Array();
   return this;
}

Mailbox.prototype.dump = function(indent) {
   if (!indent)
     indent = 0;
   log(" ".repeat(indent) + this.name);
   for (var i = 0; i < this.children.length; i++) {
      this.children[i].dump(indent + 2);
   }
}

Mailbox.prototype.findMailboxByName = function(name) {
   var mailbox = null;

   var i = 0;
   while (!mailbox && i <this.children.length)
      if (this.children[i].name == name)
	 mailbox = this.children[i];
      else
	 i++;

   return mailbox;
}

Mailbox.prototype.addMailbox = function(mailbox) {
   mailbox.parentFolder = this;
   this.children.push(mailbox);
}
