/* JavaScript for SOGoMail */
var accounts = {};
var mailboxTree;
var mailAccounts;
var quotaSupport;
if (typeof textMailAccounts != 'undefined') {
  if (textMailAccounts.length > 0)
    mailAccounts = textMailAccounts.evalJSON(true);
  else
    mailAccounts = new Array();
}
if (typeof textQuotaSupport != 'undefined') {
  if (textQuotaSupport.length > 0)
    quotaSupport = textQuotaSupport.evalJSON(true);
  else
    quotaSupport = new Array();
}

var Mailer = {
 currentMailbox: null,
 currentMailboxType: "",
 currentMessages: {},
 maxCachedMessages: 20,
 cachedMessages: new Array(),
 foldersStateTimer: false,
 popups: new Array()
};

var usersRightsWindowHeight = 320;
var usersRightsWindowWidth = 400;

var pageContent;

var deleteMessageRequestCount = 0;

var messageCheckTimer;

/* mail list */

function openMessageWindow(msguid, url) {
  var wId = '';
  if (msguid) {
    wId += "SOGo_msg" + msguid;
    markMailReadInWindow(window, msguid);
  }
  var msgWin = openMailComposeWindow(url, wId);
  msgWin.messageUID = msguid;
  msgWin.focus();
  Mailer.popups.push(msgWin);

  return false;
}

function onMessageDoubleClick(event) {
  var action;

  if (Mailer.currentMailboxType == "draft")
    action = "edit";
  else
    action = "popupview";

  return openMessageWindowsForSelection(action, true);
}

function toggleMailSelect(sender) {
  var row;
  row = $(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
}

function openAddressbook(sender) {
  var urlstr;

  urlstr = ApplicationBaseURL + "../Contacts/?popup=YES";
  var w = window.open(urlstr, "Addressbook",
		      "width=640,height=400,resizable=1,scrollbars=1,toolbar=0,"
		      + "location=no,directories=0,status=0,menubar=0,copyhistory=0");
  w.focus();

  return false;
}

function onMenuSharing(event) {
  var folderID = document.menuTarget.getAttribute("dataname");
  var type = document.menuTarget.getAttribute("datatype");

  if (type == "additional")
    window.alert(clabels["The user rights cannot be"
			 + " edited for this object!"]);
  else {
    var urlstr = URLForFolderID(folderID) + "/acls";
    openAclWindow(urlstr);
  }
}

/* mail list DOM changes */

function markMailInWindow(win, msguid, markread) {
  var row = win.$("row_" + msguid);
  var subjectCell = win.$("div_" + msguid);
  if (row && subjectCell) {
    if (markread) {
      row.removeClassName("mailer_unreadmail");
      subjectCell.addClassName("mailer_readmailsubject");
      var img = win.$("unreaddiv_" + msguid);
      if (img) {
	img.removeClassName("mailerUnreadIcon");
	img.addClassName("mailerReadIcon");
	img.setAttribute("id", "readdiv_" + msguid);
	img.setAttribute("src", ResourcesURL + "/icon_read.gif");
	var title = img.getAttribute("title-markunread");
	if (title)
	  img.setAttribute("title", title);
      }
    }
    else {
      row.addClassName("mailer_unreadmail");
      subjectCell.removeClassName('mailer_readmailsubject');
      var img = win.$("readdiv_" + msguid);
      if (img) {
	img.removeClassName("mailerReadIcon");
	img.addClassName("mailerUnreadIcon");
	img.setAttribute("id", "unreaddiv_" + msguid);
	img.setAttribute("src", ResourcesURL + "/icon_unread.gif");
	var title = img.getAttribute("title-markread");
	if (title)
	  img.setAttribute("title", title);
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

/* mail list reply */

function openMessageWindowsForSelection(action, firstOnly) {
  if (document.body.hasClassName("popup")) {
    var url = window.location.href;
    var parts = url.split("/");
    parts[parts.length-1] = action;
    window.location.href = parts.join("/");
  }
  else {
    var messageList = $("messageList");
    var rows = messageList.getSelectedRowsId();
    if (rows.length > 0) {
      for (var i = 0; i < rows.length; i++) {
	openMessageWindow(Mailer.currentMailbox + "/" + rows[i].substr(4),
			  ApplicationBaseURL + Mailer.currentMailbox
			  + "/" + rows[i].substr(4)
			  + "/" + action);
	if (firstOnly)
	  break;
      }
    } else {
      window.alert(labels["Please select a message."]);
    }
  }

  return false;
}

function mailListMarkMessage(event) {
  var msguid = this.id.split('_')[1];
  var action;
  var markread;
  if ($(this).hasClassName('mailerUnreadIcon')) {
    action = 'markMessageRead';
    markread = true;
  }
  else {
    action = 'markMessageUnread';
    markread = false;
  }
  var url = ApplicationBaseURL + Mailer.currentMailbox + "/" + msguid + "/" + action;

  var data = { "window": window, "msguid": msguid, "markread": markread };
  triggerAjaxRequest(url, mailListMarkMessageCallback, data);

  preventDefault(event);
  return false;
}

function mailListMarkMessageCallback(http) {
  if (isHttpStatus204(http.status)) {
    var data = http.callbackData;
    markMailInWindow(data["window"], data["msguid"], data["markread"]);
  }
  else {
    alert("Message Mark Failed (" + http.status + "): " + http.statusText);
    window.location.reload();
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


/* bulk delete of messages */

function deleteSelectedMessages(sender) {
  var messageList = $("messageList");
  var rowIds = messageList.getSelectedRowsId();
  
  if (rowIds.length > 0) {
    for (var i = 0; i < rowIds.length; i++) {
      var url;
      var rowId = rowIds[i].substr(4);
      var messageId = Mailer.currentMailbox + "/" + rowId;
      url = ApplicationBaseURL + messageId + "/trash";
      deleteMessageRequestCount++;
      var data = { "id": rowId, "mailbox": Mailer.currentMailbox, "messageId": messageId };
      triggerAjaxRequest(url, deleteSelectedMessagesCallback, data);
    }
  }
  else
    window.alert(labels["Please select a message."]);
   
  return false;
}

function deleteSelectedMessagesCallback(http) {
  if (isHttpStatus204(http.status)) {
    var data = http.callbackData;
    deleteCachedMessage(data["messageId"]);
    deleteMessageRequestCount--;
    if (Mailer.currentMailbox == data["mailbox"]) {
      var div = $('messageContent');
      if (Mailer.currentMessages[Mailer.currentMailbox] == data["id"]) {
        div.update();
        Mailer.currentMessages[Mailer.currentMailbox] = null;	
      }

      var row = $("row_" + data["id"]);
      var nextRow = row.next("tr");
      if (!nextRow)
	nextRow = row.previous("tr");
      //	row.addClassName("deleted"); // when we'll offer "mark as deleted"
      
      if (deleteMessageRequestCount == 0) {
        if (nextRow) {
          Mailer.currentMessages[Mailer.currentMailbox] = nextRow.getAttribute("id").substr(4);
          loadMessage(Mailer.currentMessages[Mailer.currentMailbox]);
        }
        refreshCurrentFolder();
      }
    }
  }
  else
    log ("deleteSelectedMessagesCallback: problem during ajax request " + http.status);
}

function moveMessages(rowIds, folder) {
  var failCount = 0;

  for (var i = 0; i < rowIds.length; i++) {
    var url, http;

    /* send AJAX request (synchronously) */
	  
    var messageId = Mailer.currentMailbox + "/" + rowIds[i];
    url = (ApplicationBaseURL + messageId
	   + "/move?tofolder=" + folder);
    http = createHTTPClient();
    http.open("GET", url, false /* not async */);
    http.send("");
    if (http.status == 200) {
      var row = $("row_" + rowIds[i]);
      row.parentNode.removeChild(row);
      deleteCachedMessage(messageId);
      if (Mailer.currentMessages[Mailer.currentMailbox] == rowIds[i]) {
	var div = $('messageContent');
	div.update();
	Mailer.currentMessages[Mailer.currentMailbox] = null;
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
  deleteSelectedMessages();
  preventDefault(event);
}

function deleteMessage(url, id, mailbox, messageId) {
  var data = { "id": id, "mailbox": mailbox, "messageId": messageId };
  deleteMessageRequestCount++;
  triggerAjaxRequest(url, deleteSelectedMessagesCallback, data);
}

function deleteMessageWithDelay(url, id, mailbox, messageId) {
  /* this is called by UIxMailPopupView with window.opener */
  setTimeout("deleteMessage('" +
	     url + "', '" +
	     id + "', '" +
	     mailbox + "', '" +
	     messageId + "')",
	     50);
}

function onPrintCurrentMessage(event) {
  var rowIds = $("messageList").getSelectedRowsId();
  if (rowIds.length == 0) {
    window.alert(labels["Please select a message to print."]);
  }
  else if (rowIds.length > 1) {
    window.alert(labels["Please select only one message to print."]);
  }
  else
    window.print();

  preventDefault(event);
}

function onMailboxTreeItemClick(event) {
  var topNode = $("mailboxTree");
  var mailbox = this.parentNode.getAttribute("dataname");

  if (topNode.selectedEntry)
    topNode.selectedEntry.deselect();
  this.selectElement();
  topNode.selectedEntry = this;

  search = {};
  sorting = {};
  $("searchValue").value = "";
  initCriteria();

  Mailer.currentMailboxType = this.parentNode.getAttribute("datatype");
  if (Mailer.currentMailboxType == "account" || Mailer.currentMailboxType == "additional") {
    Mailer.currentMailbox = mailbox;
    $("messageContent").update();
    var table = $("messageList");
    var head = table.tHead;
    var body = table.tBodies[0];
    for (var i = body.rows.length; i > 0; i--)
      body.deleteRow(i-1);
    if (head.rows[1])
      head.rows[1].firstChild.update();
  }
  else
    openMailbox(mailbox);
   
  Event.stop(event);
}

function _onMailboxMenuAction(menuEntry, error, actionName) {
  var targetMailbox = menuEntry.mailbox.fullName();
  var messages = new Array();

  if (targetMailbox == Mailer.currentMailbox)
    window.alert(labels[error]);
  else {
    if (document.menuTarget.tagName == "DIV")
      // Menu called from message content view
      messages.push(Mailer.currentMessages[Mailer.currentMailbox]);
    else if (Object.isArray(document.menuTarget))
      // Menu called from multiple selection in messages list view
      messages = $(document.menuTarget).collect(function(row) {
	  return row.getAttribute("id").substr(4);
	});
    else
      // Menu called from one selection in messages list view
      messages.push(document.menuTarget.getAttribute("id").substr(4));

    var url_prefix = URLForFolderID(Mailer.currentMailbox) + "/";
    messages.each(function(msgid, i) {
	var url = url_prefix + msgid + "/" + actionName
	  + "?folder=" + targetMailbox;
	triggerAjaxRequest(url, folderRefreshCallback,
			   ((i == messages.size() - 1)?Mailer.currentMailbox:""));
      });
  }
}

function onMailboxMenuMove(event) {
  _onMailboxMenuAction(this,
		       "Moving a message into its own folder is impossible!",
		       "move");
}

function onMailboxMenuCopy(event) {
  _onMailboxMenuAction(this,
		       "Copying a message into its own folder is impossible!",
		       "copy");
}

function refreshMailbox() {
  var topWindow = getTopWindow();
  if (topWindow)
    topWindow.refreshCurrentFolder();

  return false;
}

function onComposeMessage() {
  var topWindow = getTopWindow();
  if (topWindow)
    topWindow.composeNewMessage();

  return false;
}

function composeNewMessage() {
  var account = Mailer.currentMailbox.split("/")[1];
  var url = ApplicationBaseURL + "/" + account + "/compose";
  openMailComposeWindow(url);
}

function openMailbox(mailbox, reload, idx) {
  if (mailbox != Mailer.currentMailbox || reload) {
    Mailer.currentMailbox = mailbox;
    var url = ApplicationBaseURL + encodeURI(mailbox) + "/view?noframe=1";
    
    if (!reload || idx) {
      var messageContent = $("messageContent");
      messageContent.update();
      lastClickedRow = -1; // from generic.js
    }

    var currentMessage;

    if (!idx) {
      currentMessage = Mailer.currentMessages[mailbox];
      if (currentMessage) {
	url += '&pageforuid=' + currentMessage;
	if (!reload)
	  loadMessage(currentMessage);
      }
    }

    var searchValue = search["value"];
    if (searchValue && searchValue.length > 0)
      url += ("&search=" + search["criteria"]
	      + "&value=" + escape(searchValue.utf8encode()));
    var sortAttribute = sorting["attribute"];
    if (sortAttribute && sortAttribute.length > 0)
      url += ("&sort=" + sorting["attribute"]
	      + "&asc=" + sorting["ascending"]);
    if (idx)
      url += "&idx=" + idx;

    if (document.messageListAjaxRequest) {
      document.messageListAjaxRequest.aborted = true;
      document.messageListAjaxRequest.abort();
    }

    var mailboxContent = $("mailboxContent");
    if (mailboxContent.getStyle('visibility') == "hidden") {
      mailboxContent.setStyle({ visibility: "visible" });
      var rightDragHandle = $("rightDragHandle");
      rightDragHandle.setStyle({ visibility: "visible" });
      messageContent.setStyle({ top: (rightDragHandle.offsetTop
				      + rightDragHandle.offsetHeight
				      + 'px') });
    }
    document.messageListAjaxRequest
      = triggerAjaxRequest(url, messageListCallback,
			   currentMessage);

    var account = Mailer.currentMailbox.split("/")[1];
    if (accounts[account].supportsQuotas) {
      var quotasUrl = ApplicationBaseURL + mailbox + "/quotas";
      if (document.quotaAjaxRequest) {
	document.quotaAjaxRequest.aborted = true;
	document.quotaAjaxRequest.abort();
      }
      document.quotaAjaxRequest = triggerAjaxRequest(quotasUrl, quotasCallback);
    }
  }
}

function openMailboxAtIndex(event) {
  openMailbox(Mailer.currentMailbox, true, this.getAttribute("idx"));

  Event.stop(event);
}

function messageListCallback(http) {
  var div = $('mailboxContent');
  var table = $('messageList');
  
  if (http.status == 200) {
    document.messageListAjaxRequest = null;

    if (table) {
      // Update table
      var thead = table.tHead;
      var addressHeaderCell = thead.rows[0].cells[3];
      var tbody = table.tBodies[0];
      var tmp = document.createElement('div');
      $(tmp).update(http.responseText);
      thead.rows[1].parentNode.replaceChild(tmp.firstChild.tHead.rows[1], thead.rows[1]);
      addressHeaderCell.replaceChild(tmp.firstChild.tHead.rows[0].cells[3].lastChild, 
				     addressHeaderCell.lastChild);
      table.replaceChild(tmp.firstChild.tBodies[0], tbody);
    }
    else {
      // Add table
      div.update(http.responseText);
      table = $('messageList');
      configureMessageListEvents(table);
      TableKit.Resizable.init(table, {'trueResize' : true, 'keepWidth' : true});
    }
    configureMessageListBodyEvents(table);

    var selected = http.callbackData;
    if (selected) {
      var row = $("row_" + selected);
      if (row) {
	row.selectElement();
	lastClickedRow = row.rowIndex - $(row).up('table').down('thead').getElementsByTagName('tr').length;  
	var rowPosition = row.rowIndex * row.getHeight();
	if ($(row).up('div').getHeight() > rowPosition)
	  rowPosition = 0;
	div.scrollTop = rowPosition; // scroll to selected message
      }
      else
	$("messageContent").update();
    }
    else
      div.scrollTop = 0;
    
    if (sorting["attribute"] && sorting["attribute"].length > 0) {
      var sortHeader = $(sorting["attribute"] + "Header");
      
      if (sortHeader) {
	var sortImages = $(table.tHead).select(".sortImage");
	$(sortImages).each(function(item) {
	    item.remove();
	  });

	var sortImage = createElement("img", "messageSortImage", "sortImage");
	sortHeader.insertBefore(sortImage, sortHeader.firstChild);
	if (sorting["ascending"])
	  sortImage.src = ResourcesURL + "/title_sortdown_12x12.png";
	else
	  sortImage.src = ResourcesURL + "/title_sortup_12x12.png";
      }
    }
  }
  else {
    var data = http.responseText;
    var msg = data.replace(/^(.*\n)*.*<p>((.*\n)*.*)<\/p>(.*\n)*.*$/, "$2");
    log("messageListCallback: problem during ajax request (readyState = " + http.readyState + ", status = " + http.status + ", response = " + msg + ")");
  }
}

function quotasCallback(http) {
  if (http.status == 200) {
    var hasQuotas = false;

    if (http.responseText.length > 0) {
      var quotas = http.responseText.evalJSON(true);
      for (var i in quotas) {
	hasQuotas = true;
	break;
      }
    }
    
    if (hasQuotas) {
      var treePath = Mailer.currentMailbox.split("/");
      var quotasMB = new Array();
      for (var i = 2; i < treePath.length; i++)
	quotasMB.push(treePath[i].substr(6));
      var mbQuotas = quotas["/" + quotasMB.join("/")];
      var used = mbQuotas["usedSpace"];
      var max = mbQuotas["maxQuota"];
      var percents = (Math.round(used * 10000 / max) / 100);
      var format = labels["quotasFormat"];
      var text = format.formatted(used, max, percents);
      window.status = text;
    }
  }

  document.quotaAjaxRequest = null;
}

function onMessageContextMenu(event) {
  var menu = $('messageListMenu');
  var topNode = $('messageList');
  var selectedNodes = topNode.getSelectedRows();

  menu.observe("hideMenu", onMessageContextMenuHide);
  
  if (selectedNodes.length > 1)
    popupMenu(event, "messagesListMenu", selectedNodes);
  else
    popupMenu(event, "messageListMenu", this);    
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
      nodes[i].selectElement();
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
  menu.observe("hideMenu", onFolderMenuHide);
  popupMenu(event, menuName, this.parentNode);

  var topNode = $("mailboxTree");
  if (topNode.selectedEntry)
    topNode.selectedEntry.deselect();
  if (topNode.menuSelectedEntry)
    topNode.menuSelectedEntry.deselect();
  topNode.menuSelectedEntry = this;
  this.selectElement();

  preventDefault(event);
}

function onFolderMenuHide(event) {
  var topNode = $("mailboxTree");

  if (topNode.menuSelectedEntry) {
    topNode.menuSelectedEntry.deselect();
    topNode.menuSelectedEntry = null;
  }
  if (topNode.selectedEntry)
    topNode.selectedEntry.selectElement();
}

function deleteCachedMessage(messageId) {
  var done = false;
  var counter = 0;

  while (counter < Mailer.cachedMessages.length
	 && !done)
    if (Mailer.cachedMessages[counter]
	&& Mailer.cachedMessages[counter]['idx'] == messageId) {
      Mailer.cachedMessages.splice(counter, 1);
      done = true;
    }
    else
      counter++;
}

function getCachedMessage(idx) {
  var message = null;
  var counter = 0;

  while (counter < Mailer.cachedMessages.length
	 && message == null)
    if (Mailer.cachedMessages[counter]
	&& Mailer.cachedMessages[counter]['idx'] == Mailer.currentMailbox + '/' + idx)
      message = Mailer.cachedMessages[counter];
    else
      counter++;

  return message;
}

function storeCachedMessage(cachedMessage) {
  var oldest = -1;
  var timeOldest = -1;
  var counter = 0;

  if (Mailer.cachedMessages.length < Mailer.maxCachedMessages)
    oldest = Mailer.cachedMessages.length;
  else {
    while (Mailer.cachedMessages[counter]) {
      if (oldest == -1
	  || Mailer.cachedMessages[counter]['time'] < timeOldest) {
	oldest = counter;
	timeOldest = Mailer.cachedMessages[counter]['time'];
      }
      counter++;
    }

    if (oldest == -1)
      oldest = 0;
  }

  Mailer.cachedMessages[oldest] = cachedMessage;
}

function onMessageSelectionChange() {
  var rows = this.getSelectedRowsId();

  if (rows.length == 1) {
    var idx = rows[0].substr(4);
    if (Mailer.currentMessages[Mailer.currentMailbox] != idx) {
      Mailer.currentMessages[Mailer.currentMailbox] = idx;
      loadMessage(idx);
    }
  }
  else if (rows.length > 1)
    $('messageContent').update();
}

function loadMessage(idx) {
  if (document.messageAjaxRequest) {
    document.messageAjaxRequest.aborted = true;
    document.messageAjaxRequest.abort();
  }

  var cachedMessage = getCachedMessage(idx);

  markMailInWindow(window, idx, true);
  if (cachedMessage == null) {
    var url = (ApplicationBaseURL + Mailer.currentMailbox + "/"
	       + idx + "/view?noframe=1");
    document.messageAjaxRequest
      = triggerAjaxRequest(url, messageCallback, idx);
  } else {
    var div = $('messageContent');
    div.update(cachedMessage['text']);
    cachedMessage['time'] = (new Date()).getTime();
    document.messageAjaxRequest = null;
    configureLinksInMessage();
    resizeMailContent();
  }
}

function configureLinksInMessage() {
  var messageDiv = $('messageContent');
  var mailContentDiv = document.getElementsByClassName('mailer_mailcontent',
						       messageDiv)[0];
  if (!document.body.hasClassName("popup"))
    mailContentDiv.observe("contextmenu", onMessageContentMenu);

  var anchors = messageDiv.getElementsByTagName('a');
  for (var i = 0; i < anchors.length; i++)
    if (anchors[i].href.substring(0,7) == "mailto:") {
      $(anchors[i]).observe("click", onEmailTo);
      $(anchors[i]).observe("contextmenu", onEmailAddressClick);
    }
    else
      $(anchors[i]).observe("click", onMessageAnchorClick);

  var images = messageDiv.getElementsByTagName('img');
  for (var i = 0; i < images.length; i++)
    $(images[i]).observe("contextmenu", onImageClick);

  var editDraftButton = $("editDraftButton");
  if (editDraftButton)
    editDraftButton.observe("click",
			    onMessageEditDraft.bindAsEventListener(editDraftButton));

  configureiCalLinksInMessage();
}

function configureiCalLinksInMessage() {
  var buttons = { "iCalendarAccept": "accept",
		  "iCalendarDecline": "decline",
		  "iCalendarTentative": "tentative",
		  "iCalendarUpdateUserStatus": "updateUserStatus",
		  "iCalendarAddToCalendar": "addToCalendar",
		  "iCalendarDeleteFromCalendar": "deleteFromCalendar" };

  for (var key in buttons) {
    var button = $(key);
    if (button) {
      button.action = buttons[key];
      button.observe("click",
		     onICalendarButtonClick.bindAsEventListener(button));
    }
  }
}

function onICalendarButtonClick(event) {
  var link = $("iCalendarAttachment").value;
  if (link) {
    var urlstr = link + "/" + this.action;
    var currentMsg;
    currentMsg = Mailer.currentMailbox + "/"
      + Mailer.currentMessages[Mailer.currentMailbox];
    triggerAjaxRequest(urlstr, ICalendarButtonCallback, currentMsg);
  }
  else
    log("no link");
}

function ICalendarButtonCallback(http) {
  if (isHttpStatus204(http.status)) {
    var oldMsg = http.callbackData;
    var msg = Mailer.currentMailbox + "/" + Mailer.currentMessages[Mailer.currentMailbox];
    deleteCachedMessage(oldMsg);
    if (oldMsg == msg) {
      loadMessage(Mailer.currentMessages[Mailer.currentMailbox]);
    }
    for (var i = 0; i < Mailer.popups.length; i++)
      if (Mailer.popups[i].messageUID == oldMsg) {
	Mailer.popups[i].location.reload();
	break;
      }
  }
  else
    window.alert("received code: " + http.status);
}

function resizeMailContent() {
  var headerTable = document.getElementsByClassName('mailer_fieldtable')[0];
  var contentDiv = document.getElementsByClassName('mailer_mailcontent')[0];
  
  contentDiv.setStyle({ 'top':
	(Element.getHeight(headerTable) + headerTable.offsetTop) + 'px' });

  // Show expand buttons if necessary
  var spans = $$("TABLE TR.mailer_fieldrow TD.mailer_fieldvalue SPAN");
  spans.each(function(span) {
      var row = span.up("TR");
      if (span.getWidth() > row.getWidth()) {
	var cell = row.select("TD.mailer_fieldname").first();
	var link = cell.down("img");
	link.show();
	link.observe("click", toggleDisplayHeader);
      }
    });
}

function toggleDisplayHeader(event) {
  var row = this.up("TR");
  var span = row.down("SPAN");
   
  if (this.hasClassName("collapse")) {
    this.writeAttribute("src", ResourcesURL + '/minus.png');
    this.writeAttribute("class", "expand");
    span.writeAttribute("class", "expand");
  }
  else {
    this.writeAttribute("src", ResourcesURL + '/plus.png');
    this.writeAttribute("class", "collapse");
    span.writeAttribute("class", "collapse");
  }
  resizeMailContent();

  preventDefault(event);
  return false;
}

function onMessageContentMenu(event) {
  var element = getTarget(event);
  if ((element.tagName == 'A' && element.href.substring(0,7) == "mailto:")
      || element.tagName == 'IMG')
    // Don't show the default contextual menu; let the click propagate to 
    // other observers
    return true;
  popupMenu(event, 'messageContentMenu', this);
}

function onMessageEditDraft(event) {
  return openMessageWindowsForSelection("edit", true);
}

function onEmailAddressClick(event) {
  popupMenu(event, 'addressMenu', this);
  preventDefault(event);
  return false;
}

function onMessageAnchorClick(event) {
  window.open(this.href);
  preventDefault(event);
}

function onImageClick(event) {
  popupMenu(event, 'imageMenu', this);
  preventDefault(event);
  return false;
}

function messageCallback(http) {
  var div = $('messageContent');

  if (http.status == 200) {
    document.messageAjaxRequest = null;
    div.update(http.responseText);
    configureLinksInMessage();
    resizeMailContent();
    
    if (http.callbackData) {
      var cachedMessage = new Array();
      cachedMessage['idx'] = Mailer.currentMailbox + '/' + http.callbackData;
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

function onMenuViewMessageSource(event) {
  var messageList = $("messageList");
  var rows = messageList.getSelectedRowsId();

  if (rows.length > 0) {
    var url = (ApplicationBaseURL + Mailer.currentMailbox + "/"
	       + rows[0].substr(4) + "/viewsource");
    openMailComposeWindow(url);
  }

  preventDefault(event);
}

function saveImage(event) {
  var img = document.menuTarget;
  var url = img.getAttribute("src");
  var urlAsAttachment = url.replace(/(\/[^\/]*)$/,"/asAttachment$1");

  window.location.href = urlAsAttachment;
}

/* contacts */
function newContactFromEmail(event) {
  var mailto = document.menuTarget.innerHTML;

  var email = extractEmailAddress(mailto);
  var c_name = extractEmailName(mailto);
  if (email.length > 0) {
    var url = (UserFolderURL + "Contacts/personal/newcontact?contactEmail="
	       + encodeURI(email));
    if (c_name)
      url += "&contactFN=" + c_name;
    openContactWindow(url);
  }

  return false; /* stop following the link */
}

function onEmailTo(event) {
  openMailTo(this.innerHTML.strip());
  Event.stop(event);
  return false;
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
  if (TableKit.Resizable._onHandle)
    return;
  
  var headerId = this.getAttribute("id");
  var newSortAttribute;
  if (headerId == "subjectHeader")
    newSortAttribute = "subject";
  else if (headerId == "fromHeader")
    newSortAttribute = "from";
  else if (headerId == "dateHeader")
    newSortAttribute = "date";
  else
    newSortAttribute = "arrival";

  if (sorting["attribute"] == newSortAttribute)
    sorting["ascending"] = !sorting["ascending"];
  else {
    sorting["attribute"] = newSortAttribute;
    sorting["ascending"] = true;
  }
  refreshCurrentFolder();
  
  Event.stop(event);
}

function refreshCurrentFolder() {
  openMailbox(Mailer.currentMailbox, true);
}

function refreshFolderByType(type) {
  if (Mailer.currentMailboxType == type)
    refreshCurrentFolder();
}

var mailboxSpanAcceptType = function(type) {
  return (type == "mailRow");
};

var mailboxSpanEnter = function() {
   this.addClassName("_dragOver");
};

var mailboxSpanExit = function() {
   this.removeClassName("_dragOver");
};

var mailboxSpanDrop = function(data) {
	var success = false;
   
	if (data) {
      var folder = this.parentNode.parentNode.getAttribute("dataname");
      if (folder != Mailer.currentMailbox)
         success = (moveMessages(data, folder) == 0);
	}
	else
      success = false;
   
	return success;
};
   
var plusSignEnter = function() {
   var nodeNr = parseInt(this.id.substr(2));
   if (!mailboxTree.aNodes[nodeNr]._io)
      this.plusSignTimer = setTimeout("openPlusSign('" + nodeNr + "');", 1000);
};
   
var plusSignExit = function() {
   if (this.plusSignTimer) {
      clearTimeout(this.plusSignTimer);
      this.plusSignTimer = null;
   }
};
	
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
};

var messageListData = function(type) {
  var rows = this.parentNode.parentNode.getSelectedRowsId();
  var msgIds = new Array();
  for (var i = 0; i < rows.length; i++)
     msgIds.push(rows[i].substr(4));

  return msgIds;
};

/* a model for a futur refactoring of the sortable table headers mechanism */
function configureMessageListEvents(table) {
   if (table) {
      table.multiselect = true;
      // Each body row can load a message
      table.observe("mousedown",
                    onMessageSelectionChange.bindAsEventListener(table));    
      // Sortable columns
      configureSortableTableHeaders(table);
   }
}

function configureMessageListBodyEvents(table) {
   if (table) {
      // Page navigation
      var cell = table.tHead.rows[1].cells[0];
      if ($(cell).hasClassName("tbtv_navcell")) {
         var anchors = $(cell).childNodesWithTag("a");
         for (var i = 0; i < anchors.length; i++)
            $(anchors[i]).observe("click", openMailboxAtIndex);
      }
      
      rows = table.tBodies[0].rows;
      for (var i = 0; i < rows.length; i++) {
         var row = $(rows[i]);
         row.observe("mousedown", onRowClick);
         row.observe("selectstart", listRowMouseDownHandler);
         row.observe("contextmenu", onMessageContextMenu);
         
         row.dndTypes = function() { return new Array("mailRow"); };
         row.dndGhost = messageListGhost;
         row.dndDataForType = messageListData;
         //   document.DNDManager.registerSource(row);
         
         for (var j = 0; j < row.cells.length; j++) {
            var cell = $(row.cells[j]);
            cell.observe("mousedown", listRowMouseDownHandler);
            if (j == 2 || j == 3 || j == 5)
               cell.observe("dblclick", onMessageDoubleClick.bindAsEventListener(cell));
            else if (j == 4) {
               var img = $(cell.childNodesWithTag("img")[0]);
               img.observe("click", mailListMarkMessage.bindAsEventListener(img));
            }
         }
      }
   }
}

function configureDragHandles() {
  var handle = $("verticalDragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.leftMargin = 1;
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
  node.selectElement();
  mailboxTree.o(1);
}

function initMailer(event) {
  if (!$(document.body).hasClassName("popup")) {
    //     initDnd();
    initMailboxTree();
    initMessageCheckTimer();
  }
  
  // Default sort options
  sorting["attribute"] = "date";
  sorting["ascending"] = false;
}

function initMessageCheckTimer() {
  var messageCheck = userDefaults["MessageCheck"];
  if (messageCheck && messageCheck != "manually") {
    var interval;
    if (messageCheck == "once_per_hour")
      interval = 3600;
    else if (messageCheck == "every_minute")
      interval = 60;
    else {
      interval = parseInt(messageCheck.substr(6)) * 60;
    }
    messageCheckTimer = window.setInterval(onMessageCheckCallback,
					   interval * 1000);
  }
}

function onMessageCheckCallback(event) {
  refreshMailbox();
}

function initMailboxTree() {
  var node = $("mailboxTree");
  if (node)
    node.parentNode.removeChild(node);
  mailboxTree = new dTree("mailboxTree");
  mailboxTree.config.folderLinks = true;
  mailboxTree.config.hideRoot = true;

  mailboxTree.icon.root = ResourcesURL + "/tbtv_account_17x17.gif";
  mailboxTree.icon.folder = ResourcesURL + "/tbtv_leaf_corner_17x17.png";
  mailboxTree.icon.folderOpen	= ResourcesURL + "/tbtv_leaf_corner_17x17.png";
  mailboxTree.icon.node = ResourcesURL + "/tbtv_leaf_corner_17x17.png";
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
  activeAjaxRequests += mailAccounts.length;
  for (var i = 0; i < mailAccounts.length; i++) {
    var url = ApplicationBaseURL + mailAccounts[i] + "/mailboxes";
    triggerAjaxRequest(url, onLoadMailboxesCallback, mailAccounts[i]);
  }
}

function updateMailboxTreeInPage() {
  $("folderTreeContent").update(mailboxTree);

  var inboxFound = false;
  var tree = $("mailboxTree");
  var nodes = document.getElementsByClassName("node", tree);
  for (i = 0; i < nodes.length; i++) {
    nodes[i].observe("click",
		     onMailboxTreeItemClick.bindAsEventListener(nodes[i]));
    nodes[i].observe("contextmenu",
		     onFolderMenuClick.bindAsEventListener(nodes[i]));
    if (!inboxFound
	&& nodes[i].parentNode.getAttribute("datatype") == "inbox") {
      Mailer.currentMailboxType = "inbox";
      openInbox(nodes[i]);
      inboxFound = true;
    }
  }
}

function mailboxMenuNode(type, name) {
  var newNode = document.createElement("li");
  var icon = MailerUIdTreeExtension.folderIcons[type];
  if (!icon)
    icon = "tbtv_leaf_corner_17x17.png";
  var image = document.createElement("img");
  image.src = ResourcesURL + "/" + icon;
  newNode.appendChild(image);
  var displayName = MailerUIdTreeExtension.folderNames[type];
  if (!displayName)
    displayName = name;
  newNode.appendChild(document.createTextNode(" " + displayName));

  return newNode;
}

function generateMenuForMailbox(mailbox, prefix, callback) {
  var menuDIV = document.createElement("div");
  $(menuDIV).addClassName("menu");
  var menuID = prefix + "Submenu";
  var previousMenuDIV = $(menuID);
  if (previousMenuDIV)
    previousMenuDIV.parentNode.removeChild(previousMenuDIV);
  menuDIV.setAttribute("id", menuID);
  var menu = document.createElement("ul");
  menuDIV.appendChild(menu);
  pageContent.appendChild(menuDIV);

  var callbacks = new Array();
  if (mailbox.type != "account") {
    var newNode = document.createElement("li");
    newNode.mailbox = mailbox;
    newNode.appendChild(document.createTextNode(labels["This Folder"]));
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
      var newSubmenuId = generateMenuForMailbox(child, newPrefix, callback);
      callbacks.push(newSubmenuId);
      submenuCount++;
    }
    else {
      newNode.mailbox = child;
      callbacks.push(callback);
    }
  }
  initMenu(menuDIV, callbacks);

  return menuDIV.getAttribute("id");
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
    pageContent = $("pageContent");
    pageContent.appendChild(menuDIV);

    var menu = document.createElement("ul");
    menuDIV.appendChild(menu);

    $(menuDIV).addClassName("menu");
    menuDIV.setAttribute("id", menuId);

    var submenuIds = new Array();
    for (var i = 0; i < mailAccounts.length; i++) {
      var menuEntry = mailboxMenuNode("account", mailAccounts[i]);
      menu.appendChild(menuEntry);
      var mailbox = accounts[mailAccounts[i]];
      var newSubmenuId = generateMenuForMailbox(mailbox,
						key, mailboxActions[key]);
      submenuIds.push(newSubmenuId);
    }
    initMenu(menuDIV, submenuIds);
  }
}

function onLoadMailboxesCallback(http) {
  if (http.status == 200) {
    checkAjaxRequestsState();
    if (http.responseText.length > 0) {
      var newAccount = buildMailboxes(http.callbackData,
				      http.responseText);
      accounts[http.callbackData] = newAccount;
      mailboxTree.addMailAccount(newAccount);
      mailboxTree.pendingRequests--;
      activeAjaxRequests--;
      if (!mailboxTree.pendingRequests) {
	updateMailboxTreeInPage();
	updateMailboxMenus();
	checkAjaxRequestsState();
	getFoldersState();
      }
    }
  }

  //       var tree = $("mailboxTree");
  //       var treeNodes = document.getElementsByClassName("dTreeNode", tree);
  //       var i = 0;
  //       while (i < treeNodes.length
  // 	     && treeNodes[i].getAttribute("dataname") != Mailer.currentMailbox)
  // 	 i++;
  //       if (i < treeNodes.length) {
  // 	 //     log("found mailbox");
  // 	 var links = document.getElementsByClassName("node", treeNodes[i]);
  // 	 if (tree.selectedEntry)
  // 	    tree.selectedEntry.deselect();
  // 	 links[0].selectElement();
  // 	 tree.selectedEntry = links[0];
  // 	 expandUpperTree(links[0]);
  //       }
}

function buildMailboxes(accountName, encoded) {
  var account = new Mailbox("account", accountName);

  var accountIndex = mailAccounts.indexOf(accountName);
  account.supportsQuotas = (quotaSupport[accountIndex] != 0);

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

function getFoldersState() {
  if (mailAccounts.length > 0) {
    var urlstr =  ApplicationBaseURL + "foldersState";
    triggerAjaxRequest(urlstr, getFoldersStateCallback);
  }
}

function getFoldersStateCallback(http) {
  if (http.status == 200) {
    if (http.responseText.length > 0) {
      // The response text is a JSON array
      // of the folders that were left opened.
      var data = http.responseText.evalJSON(true);
      for (var i = 1; i < mailboxTree.aNodes.length; i++) {
	if ($(data).indexOf(mailboxTree.aNodes[i].dataname) > 0)
	  // If the folder is found, open it
	  mailboxTree.o(i);
      }
    }
    mailboxTree.autoSync();
  }
}

function saveFoldersState() {
  if (mailAccounts.length > 0) {
    var foldersState = mailboxTree.getFoldersState();
    var urlstr =  ApplicationBaseURL + "saveFoldersState" + "?expandedFolders=" + foldersState;
    triggerAjaxRequest(urlstr, saveFoldersStateCallback);
  }
}

function saveFoldersStateCallback(http) {
  if (isHttpStatus204(http.status)) {
    log ("folders state saved");
  }
}

function onMenuCreateFolder(event) {
  var name = window.prompt(labels["Name :"], "");
  if (name && name.length > 0) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/createFolder?name=" + name;
    var errorLabel = labels["The folder with name \"%{0}\" could not be created."];
    triggerAjaxRequest(urlstr, folderOperationCallback,
                       errorLabel.formatted(name));
  }
}

function onMenuRenameFolder(event) {
  var name = window.prompt(labels["Enter the new name of your folder :"],
                           "");
  if (name && name.length > 0) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/renameFolder?name=" + name;
    var errorLabel = labels["This folder could not be renamed to \"%{0}\"."];
    triggerAjaxRequest(urlstr, folderOperationCallback,
                       errorLabel.formatted(name));
  }
}

function onMenuDeleteFolder(event) {
  var answer = window.confirm(labels["Do you really want to move this folder into the trash ?"]);
  if (answer) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/deleteFolder";
    var errorLabel = labels["The folder could not be deleted."];
    triggerAjaxRequest(urlstr, folderOperationCallback, errorLabel);
  }
}

function onMenuExpungeFolder(event) {
  var folderID = document.menuTarget.getAttribute("dataname");
  var urlstr = URLForFolderID(folderID) + "/expunge";
  triggerAjaxRequest(urlstr, folderRefreshCallback, folderID);
}

function onMenuEmptyTrash(event) {
  var folderID = document.menuTarget.getAttribute("dataname");
  var urlstr = URLForFolderID(folderID) + "/emptyTrash";
  var errorLabel = labels["The trash could not be emptied."];
  triggerAjaxRequest(urlstr, folderOperationCallback, errorLabel);

  if (folderID == Mailer.currentMailbox) {
    var div = $('messageContent');
    for (var i = div.childNodes.length - 1; i > -1; i--)
      div.removeChild(div.childNodes[i]);
    refreshCurrentFolder();
  }
  var msgID = Mailer.currentMessages[folderID];
  if (msgID)
    deleteCachedMessage(folderID + "/" + msgID);
}

function _onMenuChangeToXXXFolder(event, folder) {
  var type = document.menuTarget.getAttribute("datatype");
  if (type == "additional")
    window.alert(labels["You need to choose a non-virtual folder!"]);
  else {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/setAs" + folder + "Folder";
    var errorLabel = labels["The folder functionality could not be changed."];
    triggerAjaxRequest(urlstr, folderOperationCallback, errorLabel);
  }
}

function onMenuChangeToDraftsFolder(event) {
  return _onMenuChangeToXXXFolder(event, "Drafts");
}

function onMenuChangeToSentFolder(event) {
  return _onMenuChangeToXXXFolder(event, "Sent");
}

function onMenuChangeToTrashFolder(event) {
  return _onMenuChangeToXXXFolder(event, "Trash");
}

function onMenuLabelNone() {
  var messages = new Array();

  if (document.menuTarget.tagName == "DIV")
    // Menu called from message content view
    messages.push(Mailer.currentMessages[Mailer.currentMailbox]);
  else if (Object.isArray(document.menuTarget))
    // Menu called from multiple selection in messages list view
    $(document.menuTarget).collect(function(row) {
	messages.push(row.getAttribute("id").substr(4));
      });
  else
    // Menu called from one selection in messages list view
    messages.push(document.menuTarget.getAttribute("id").substr(4));
  
  var url = ApplicationBaseURL + Mailer.currentMailbox + "/";
  messages.each(function(id) {
      triggerAjaxRequest(url + id + "/removeAllLabels",
			 messageFlagCallback,
			 { mailbox: Mailer.currentMailbox, msg: id, label: null } );
    });  
}

function _onMenuLabelFlagX(flag) {
  var messages = new Hash();

  if (document.menuTarget.tagName == "DIV")
    // Menu called from message content view
    messages.set(Mailer.currentMessages[Mailer.currentMailbox],
		 $('tr#row_' + Mailer.currentMessages[Mailer.currentMailbox]).getAttribute("labels"));
  else if (Object.isArray(document.menuTarget))
    // Menu called from multiple selection in messages list view
    $(document.menuTarget).collect(function(row) {
	messages.set(row.getAttribute("id").substr(4),
		     row.getAttribute("labels"));
      });
  else
    // Menu called from one selection in messages list view
    messages.set(document.menuTarget.getAttribute("id").substr(4),
		 document.menuTarget.getAttribute("labels"));
  
  var url = ApplicationBaseURL + Mailer.currentMailbox + "/";
  messages.keys().each(function(id) {
      var flags = messages.get(id).split(" ");
      var operation = "add";
      
      if (flags.indexOf("label" + flag) > -1)
	operation = "remove";

      triggerAjaxRequest(url + id + "/" + operation + "Label" + flag,
			 messageFlagCallback,
			 { mailbox: Mailer.currentMailbox, msg: id,
			     label: operation + flag } );
    });
}

function onMenuLabelFlag1() {
  _onMenuLabelFlagX(1);
}

function onMenuLabelFlag2() {
  _onMenuLabelFlagX(2);
}

function onMenuLabelFlag3() {
  _onMenuLabelFlagX(3);
}

function onMenuLabelFlag4() {
  _onMenuLabelFlagX(4);
}

function onMenuLabelFlag5() {
  _onMenuLabelFlagX(5);
}

function folderOperationCallback(http) {
  if (http.readyState == 4
      && isHttpStatus204(http.status))
    initMailboxTree();
  else
    window.alert(http.callbackData);
}

function folderRefreshCallback(http) {
  if (http.readyState == 4
      && isHttpStatus204(http.status)) {
    var oldMailbox = http.callbackData;
    if (oldMailbox == Mailer.currentMailbox)
      refreshCurrentFolder();
  }
  else
    window.alert(labels["Operation failed"]);
}

function messageFlagCallback(http) {
  if (http.readyState == 4
      && isHttpStatus204(http.status)) {
    var data = http.callbackData;
    if (data["mailbox"] == Mailer.currentMailbox) {
      var row = $("row_" + data["msg"]);
      var operation = data["label"];
      if (operation) {
	var labels = row.getAttribute("labels");
	var flags;
	if (labels.length > 0)
	  flags = labels.split(" ");
	else
	  flags = new Array();
	if (operation.substr(0, 3) == "add")
	  flags.push("label" + operation.substr(3));
	else {
	  var flag = "label" + operation.substr(6);
	  var idx = flags.indexOf(flag);
	  flags.splice(idx, 1);
	}
	row.setAttribute("labels", flags.join(" "));
      }
      else
	row.setAttribute("labels", "");
    }
  }
}

function onLabelMenuPrepareVisibility() {
  var messageList = $("messageList");
  var flags = {};

  if (messageList) {
    var rows = messageList.getSelectedRows();
    for (var i = 0; i < rows.length; i++) {
      $w(rows[i].getAttribute("labels")).each(function(flag) {
	  flags[flag] = true;
	});
    }
  }

  var lis = this.childNodesWithTag("ul")[0].childNodesWithTag("li")
    var isFlagged = false;
  for (var i = 1; i < 6; i++) {
    if (flags["label" + i]) {
      isFlagged = true;
      lis[1 + i].addClassName("_chosen");
    }
    else
      lis[1 + i].removeClassName("_chosen");
  }
  if (isFlagged)
    lis[0].removeClassName("_chosen");
  else
    lis[0].addClassName("_chosen");
}

function getMenus() {
  var menus = {}
  menus["accountIconMenu"] = new Array(null, null, onMenuCreateFolder, null,
				       null, null);
  menus["inboxIconMenu"] = new Array(null, null, null, "-", null,
				     onMenuCreateFolder, onMenuExpungeFolder,
				     "-", null,
				     onMenuSharing);
  menus["trashIconMenu"] = new Array(null, null, null, "-", null,
				     onMenuCreateFolder, onMenuExpungeFolder,
				     onMenuEmptyTrash, "-", null,
				     onMenuSharing);
  menus["mailboxIconMenu"] = new Array(null, null, null, "-", null,
				       onMenuCreateFolder,
				       onMenuRenameFolder,
				       onMenuExpungeFolder,
				       onMenuDeleteFolder,
				       "folderTypeMenu",
				       "-", null,
				       onMenuSharing);
  menus["addressMenu"] = new Array(newContactFromEmail, newEmailTo, null);
  menus["messageListMenu"] = new Array(onMenuOpenMessage, "-",
				       onMenuReplyToSender,
				       onMenuReplyToAll,
				       onMenuForwardMessage, null,
				       "-", "moveMailboxMenu",
				       "copyMailboxMenu", "label-menu",
				       "mark-menu", "-", null,
				       onMenuViewMessageSource, null,
				       null, onMenuDeleteMessage);
  menus["messagesListMenu"] = new Array(onMenuForwardMessage,
					"-", "moveMailboxMenu",
					"copyMailboxMenu", "label-menu",
					"mark-menu", "-",
					null, null,
					onMenuDeleteMessage);
  menus["imageMenu"] = new Array(saveImage);
  menus["messageContentMenu"] = new Array(onMenuReplyToSender,
					  onMenuReplyToAll,
					  onMenuForwardMessage,
					  null, "moveMailboxMenu",
					  "copyMailboxMenu",
					  "-", "label-menu", "mark-menu",
					  "-",
					  null, onMenuViewMessageSource,
					  null, onPrintCurrentMessage,
					  onMenuDeleteMessage);
  menus["folderTypeMenu"] = new Array(onMenuChangeToSentFolder,
				      onMenuChangeToDraftsFolder,
				      onMenuChangeToTrashFolder);

  menus["label-menu"] = new Array(onMenuLabelNone, "-", onMenuLabelFlag1,
				  onMenuLabelFlag2, onMenuLabelFlag3,
				  onMenuLabelFlag4, onMenuLabelFlag5);
  menus["mark-menu"] = new Array(null, null, null, null, "-", null, "-",
				 null, null, null);
  menus["searchMenu"] = new Array(setSearchCriteria, setSearchCriteria,
				  setSearchCriteria, setSearchCriteria,
				  setSearchCriteria);
  var labelMenu = $("label-menu");
  if (labelMenu)
    labelMenu.prepareVisibility = onLabelMenuPrepareVisibility;

  return menus;
}

FastInit.addOnLoad(initMailer);

function Mailbox(type, name) {
  this.type = type;
  this.name = name;
  this.parentFolder = null;
  this.children = new Array();
  return this;
}

Mailbox.prototype = {
 dump: function(indent) {
    if (!indent)
      indent = 0;
    log(" ".repeat(indent) + this.name);
    for (var i = 0; i < this.children.length; i++) {
      this.children[i].dump(indent + 2);
    }
  },
 fullName: function() {
   var fullName = "";

   var currentFolder = this;
   while (currentFolder.parentFolder) {
     fullName = "/folder" + currentFolder.name + fullName;
     currentFolder = currentFolder.parentFolder;
   }

   return "/" + currentFolder.name + fullName;
 },
 findMailboxByName: function(name) {
   var mailbox = null;

   var i = 0;
   while (!mailbox && i < this.children.length)
     if (this.children[i].name == name)
       mailbox = this.children[i];
     else
       i++;

   return mailbox;
 },
 addMailbox: function(mailbox) {
   mailbox.parentFolder = this;
   this.children.push(mailbox);
 }
};

