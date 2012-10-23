/* -*- Mode: js2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/* JavaScript for SOGoMail */
var accounts = [];
var mailboxTree;

var Mailer = {
    defaultWindowTitle: null,
    currentMailbox: null,
    currentMailboxType: "",
    currentMessages: {},
    unseenCountMailboxes: [],
    maxCachedMessages: 20,
    cachedMessages: new Array(),
    foldersStateTimer: false,
    popups: new Array(),

    dataTable: null,
    dataSources: new Hash(),

    drops: new Array(),

    columnsOrder: null,
    sortByThread: false
};

var usersRightsWindowHeight = 335;
var usersRightsWindowWidth = 400;

var pageContent = $("pageContent");

var deleteMessageRequestCount = 0;

var messageCheckTimer;

/* We need to override this method since it is adapted to GCS-based folder
   references, which we do not use here */
function URLForFolderID(folderID, application) {
    if (application)
        application = UserFolderURL + application + "/";
    else
        application = ApplicationBaseURL;
    var url = application + encodeURI(folderID.substr(1));

    if (url[url.length-1] == '/')
        url = url.substr(0, url.length-1);

    return url;
}

/* mail list */

function openMessageWindow(msguid, url) {
    var wId = '';
    if (msguid) {
        wId += "SOGo_msg" + Mailer.currentMailbox + "/" + msguid;
        markMailReadInWindow(window, msguid);
    }
    var msgWin = openMailComposeWindow(url, wId);

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
        showAlertDialog(clabels["The user rights cannot be"
                             + " edited for this object!"]);
    else {
        var urlstr = URLForFolderID(folderID) + "/acls";
        openAclWindow(urlstr);
    }
}

/* mail list DOM changes */

/* Update the messages list when flagging/unflagging a message.
 * No AJAX is triggered here. */
function flagMailInWindow (win, msguid, flagged) {
    var row = win.$("row_" + msguid);

    if (row) {
        var col = row.down("TD.messageFlagColumn");
        var img = col.down("img");
        if (flagged) {
            img.setAttribute("src", ResourcesURL + "/flag.png");
            img.addClassName("messageIsFlagged");
        }
        else {
            img.setAttribute("src", ResourcesURL + "/dot.png");
            img.removeClassName ("messageIsFlagged");
        }
    }
}

/* Update the messages list when setting the unread/read flag of a message.
 * No AJAX is triggered here. See mailListToggleMessagesRead */
function markMailInWindow(win, msguid, markread) {
    var row = win.$("row_" + msguid);
    var unseenCount = 0;

    if (row) {
        if (markread) {
            if (row.hasClassName("mailer_unreadmail")) {
                row.removeClassName("mailer_unreadmail");
                var img = win.$("readdiv_" + msguid);
                if (img) {
                    img.setAttribute("src", ResourcesURL + "/dot.png");
                    var title = img.getAttribute("title-markunread");
                    if (title)
                        img.setAttribute("title", title);
                }
                else {
                    log ("No IMG found for " + msguid);
                }
                unseenCount = -1;
            }
        }
        else {
            if (!row.hasClassName("mailer_unreadmail")) {
                row.addClassName("mailer_unreadmail");
                var img = win.$("readdiv_" + msguid);
                if (img) {
                    img.setAttribute("src", ResourcesURL + "/unread.png");
                    var title = img.getAttribute("title-markread");
                    if (title)
                        img.setAttribute("title", title);
                }
                else {
                    log ("No IMG found for message " + msguid);
                }
                unseenCount = 1;
            }
        }

        if (unseenCount != 0) {
            var node = mailboxTree.getMailboxNode(Mailer.currentMailbox);
            if (node) {
                updateUnseenCount(node, unseenCount, true);
            }
        }
    }
    else {
        log ("No row found for message " + msguid);
    }

    return (unseenCount != 0);
}

/**
 * This is called by UIxMailView with window.opener.
 */
function markMailReadInWindow(win, msguid) {
    return markMailInWindow(win, msguid, true);
}

/* mail list reply */

function openMessageWindowsForSelection(action, firstOnly) {
    if ($(document.body).hasClassName("popup")) {
        var url = window.location.href;
        var parts = url.split("/");
        parts[parts.length-1] = action;
        window.name += "_" + action;
        window.location.href = parts.join("/");
    }
    else {
        var messageList = $("messageListBody");
        var rowsId = messageList.getSelectedRowsId();
        if (rowsId.length > 0) {
            for (var i = 0; i < rowsId.length; i++) {
                openMessageWindow(rowsId[i].substr(4),
                                  ApplicationBaseURL + encodeURI(Mailer.currentMailbox)
                                  + "/" + rowsId[i].substr(4)
                                  + "/" + action);
                if (firstOnly)
                    break;
            }
        } else {
            showAlertDialog(_("Please select a message."));
        }
    }

    return false;
}

/*
function mailListToggleMessageThread(row, cell) {
    var show = row.hasClassName('closedThread');
    $(cell).down('img').remove();
    if (show) {
        row.removeClassName('closedThread');
        row.addClassName('openedThread');
        var img = createElement("img", null, null, { src: ResourcesURL + '/arrow-down.png' });
        cell.insertBefore(img, cell.firstChild);
    }
    else {
        row.removeClassName('openedThread');
        row.addClassName('closedThread');
        var img = createElement("img", null, null, { src: ResourcesURL + '/arrow-right.png' });
        cell.insertBefore(img, cell.firstChild);
    }
    while ((row = row.next()) && row.hasClassName('thread')) {
        if (show)
            row.show();
        else
            row.hide();
    }
}
*/

/* Triggered when clicking on the read/unread dot of a message row or
 * through the contextual menu. */
function mailListToggleMessagesRead(row) {
    var selectedRowsId = [];
    if (row) {
        selectedRowsId = [row.id];
    }
    else {
        var messageList = $("messageListBody");
        if (messageList) {
            var selectedRows = messageList.getSelectedRows();
            row = selectedRows[0];
            selectedRowsId = messageList.getSelectedRowsId();
        }
    }
    if (selectedRowsId.length > 0) {
        var action;
        var markread;
        if (row.hasClassName("mailer_unreadmail")) {
            action = 'markMessageRead';
            markread = true;
        }
        else {
            action = 'markMessageUnread';
            markread = false;
        }

        for (var i = 0; i < selectedRowsId.length; i++) {
            var msguid = selectedRowsId[i].split('_')[1];
            markMailInWindow(window, msguid, markread);

            // Assume ajax request will succeed and invalidate data cache now.
	    Mailer.dataTable.invalidate(msguid, true);

            var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/"
                + msguid + "/" + action;

            var data = { "msguid": msguid };
            triggerAjaxRequest(url, mailListMarkMessageCallback, data);
        }
    }
}

/*
function mailListMarkMessage(event) {
    mailListToggleMessagesRead();

    preventDefault(event);

    return false;
}
*/

function mailListMarkMessageCallback(http) {
    var data = http.callbackData;
    if (!isHttpStatus204(http.status)) {
        log("Message Mark Failed (" + http.status + "): " + http.statusText);
	Mailer.dataTable.invalidate(data["msguid"], false);
    }
}

function mailListFlagMessageToggle(e) {
    mailListToggleMessagesFlagged();
}

/* Triggered when clicking on the flag/unflag dot of a message row */
function mailListToggleMessagesFlagged(row) {
    var selectedRowsId = [];
    if (row) {
        selectedRowsId = [row.id];
    }
    else {
        var messageList = $("messageListBody");
        if (messageList) {
            var selectedRows = messageList.getSelectedRows();
            row = selectedRows[0];
            selectedRowsId = messageList.getSelectedRowsId();
        }
    }
    if (selectedRowsId.length > 0) {
        var td = row.down("td.messageFlagColumn");
        var img = td.childElements().first();

        var action = "markMessageFlagged";
        var flagged = true;
        if (img.hasClassName("messageIsFlagged")) {
            action = "markMessageUnflagged";
            flagged = false;
        }

        for (var i = 0; i < selectedRowsId.length; i++) {
            var msguid = selectedRowsId[i].split("_")[1];
            flagMailInWindow(window, msguid, flagged);

            var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/"
                + msguid + "/" + action;
            var data = { "msguid": msguid };

            triggerAjaxRequest(url, mailListToggleMessageFlaggedCallback, data);
        }
    }
}

function mailListToggleMessageFlaggedCallback(http) {
    var data = http.callbackData;
    if (!isHttpStatus204(http.status)) {
        log("Message Mark Failed (" + http.status + "): " + http.statusText);
    }
    Mailer.dataTable.invalidate(data["msguid"], true);
}

function onUnload(event) {
    var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/expunge";

    new Ajax.Request(url, {
            asynchronous: false,
            method: 'get',
            onFailure: function(transport) {
                log("Can't expunge current folder: " + transport.status);
            }
    });

    return true;
}

function onDocumentKeydown(event) {
    var target = Event.element(event);
    if (target.tagName != "INPUT") {
        var keyCode = event.keyCode;
        if (!keyCode) {
            keyCode = event.charCode;
            if (keyCode == "a".charCodeAt(0)) {
                keyCode = "A".charCodeAt(0);
            }
        }
	if (keyCode == Event.KEY_DELETE ||
            keyCode == Event.KEY_BACKSPACE && isMac()) {
            deleteSelectedMessages();
            Event.stop(event);
        }
	else if (keyCode == Event.KEY_DOWN ||
                 keyCode == Event.KEY_UP) {
            if (Mailer.currentMessages[Mailer.currentMailbox]) {
                var row = $("row_" + Mailer.currentMessages[Mailer.currentMailbox]);
                var nextRow;
                if (keyCode == Event.KEY_DOWN)
                    nextRow = row.next("tr");
                else
                    nextRow = row.previous("tr");
                if (nextRow && nextRow.id != 'rowTop' && nextRow.id != 'rowBottom') {
                    Mailer.currentMessages[Mailer.currentMailbox] = nextRow.getAttribute("id").substr(4);
                    row.parentNode.deselectAll();

                    // Adjust the scollbar
                    var viewPort = $("mailboxList");
                    var divDimensions = viewPort.getDimensions();
                    var centerOffset = divDimensions.height/2;
                    var rowScrollOffset = nextRow.cumulativeScrollOffset();
                    var divBottom = divDimensions.height + rowScrollOffset.top;
                    var rowBottom = nextRow.offsetTop + nextRow.getHeight();

                    if (divBottom < rowBottom)
                        viewPort.scrollTop += rowBottom - divBottom + centerOffset;
                     else if (viewPort.scrollTop > nextRow.offsetTop)
                        viewPort.scrollTop -= rowScrollOffset.top - nextRow.offsetTop + centerOffset;

                    // Select and load the next message
                    nextRow.selectElement();
                    loadMessage(Mailer.currentMessages[Mailer.currentMailbox]);
                    // from generic.js
                    lastClickedRow = nextRow.rowIndex;
	            lastClickedRowId = nextRow.id;
                }
                Event.stop(event);
            }
        }
	else if (((isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1))
                 && keyCode == "A".charCodeAt(0)) {  // Ctrl-A
            $("messageListBody").down("TBODY").selectAll();
            Event.stop(event);
        }
    }
}

/* bulk delete of messages */

function deleteSelectedMessages(sender) {
    if (Mailer.currentMailboxType == "account" || Mailer.currentMailboxType == "additional")
        return false;

    var messageList = $("messageListBody").down("TBODY");
    var messageContent = $("messageContent");
    var rowIds = messageList.getSelectedNodesId();
    var uids = new Array(); // message IDs
    var paths = new Array(); // row IDs
    var unseenCount = 0;
    var refreshFolder = false;

    if (rowIds && rowIds.length > 0) {
        messageList.deselectAll();
        for (var i = 0; i < rowIds.length; i++) {
	    if (unseenCount < 1) {
		var rows = messageList.select('#' + rowIds[i]);
		if (rows.length > 0) {
		    var row = rows.first();
		    row.hide();
		    if (row.hasClassName("mailer_unreadmail"))
			unseenCount--;
		}
		else {
		    unseenCount = 1;
		}
	    }
            var uid = rowIds[i].substr(4); // drop "row_"
            var path = Mailer.currentMailbox + "/" + uid;
            uids.push(uid);
            paths.push(path);
            deleteMessageRequestCount++;

            deleteCachedMessage(path);
            if (Mailer.currentMessages[Mailer.currentMailbox] == uid) {
                if (messageContent) messageContent.innerHTML = '';
                Mailer.currentMessages[Mailer.currentMailbox] = null;
            }

            if (i+1 == rowIds.length) {
                // Select next message
                var row = $("row_" + uid);
                var nextRow = false;
                if (row) {
                    //row.addClassName("deleted"); // when we'll offer "mark as deleted"
                    nextRow = row.next("tr");
                    if (!nextRow.id.startsWith('row_'))
                        nextRow = row.previous("tr");
                    else if (row.hasClassName('openedThread') || row.hasClassName('closedThread')) {
                        // Thread root deleted -- must refresh folder
                        refreshFolder = true;
                        // New row will be the new thread root -- mark it as first mail of the thread
                        var nextUid = nextRow.id.substr(4);
                        var nextIndex = Mailer.dataTable.dataSource.indexOf(nextUid);
                        Mailer.dataTable.dataSource.uids[nextIndex][2] = 1; // mark it as "first"
                        Mailer.dataTable.dataSource.invalidate(nextUid); // next refresh will reload headers for row
                    }
                    if (nextRow.id.startsWith('row_')) {
                        Mailer.currentMessages[Mailer.currentMailbox] = nextRow.id.substr(4);
                        nextRow.selectElement();
                        if (loadMessage(Mailer.currentMessages[Mailer.currentMailbox]) && !refreshFolder) {
                            // Seen state has changed
                            Mailer.dataTable.dataSource.invalidate(Mailer.currentMessages[Mailer.currentMailbox]);
                            refreshFolder = true;
                        }
                    }
                }
                else if (messageContent) {
                    messageContent.innerHTML = '';
                }
                Mailer.dataTable.remove(uid);
                if (nextRow) {
                    // from generic.js
                    lastClickedRow = nextRow.rowIndex;
	            lastClickedRowId = nextRow.id;
                }
                if (Mailer.currentMailboxType != "trash")
                    deleteCachedMailboxByType("trash");
            }
            else {
                Mailer.dataTable.remove(uid);
            }
        }
        updateMessageListCounter(0 - rowIds.length, true);
        if (unseenCount < 0) {
            var node = mailboxTree.getMailboxNode(Mailer.currentMailbox);
            if (node) {
                updateUnseenCount(node, unseenCount, true);
            }
        }
        var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/batchDelete";
        var parameters = "uid=" + uids.join(",");
        var data = { "id": uids, "mailbox": Mailer.currentMailbox, "path": paths, "refreshUnseenCount": (unseenCount > 0), "refreshFolder": refreshFolder };
        triggerAjaxRequest(url, deleteSelectedMessagesCallback, data, parameters,
                           { "Content-type": "application/x-www-form-urlencoded" });
    }
    if (uids.length == 0)
        showAlertDialog(_("Please select a message."));

    return false;
}

function deleteSelectedMessagesCallback(http) {
    if (isHttpStatus204(http.status) || http.status == 200) {
        var data = http.callbackData;
        if (http.status == 200) {
            // The answer contains quota information
            var rdata = http.responseText.evalJSON(true);
            if (rdata.quotas && data["mailbox"].startsWith('/0/'))
                updateQuotas(rdata.quotas);
        }
	if (data["refreshUnseenCount"])
            // TODO : the unseen count should be returned when calling the batchDelete remote action,
            // in order to avoid this extra AJAX call.
	    getUnseenCountForFolder(data["mailbox"]);
        if (data["refreshFolder"])
            Mailer.dataTable.refresh();
    }
    else if (!http.callbackData["withoutTrash"]) {
        showConfirmDialog(_("Warning"),
                          _("The messages could not be moved to the trash folder. Would you like to delete them immediately?"),
                          deleteMessagesWithoutTrash.bind(document, http.callbackData),
                          function() { refreshCurrentFolder(); disposeDialog(); });
    }
    else {
        var html = new Element('div').update(http.responseText);
        log ("Messages deletion failed (" + http.status + ") : ");
        log (html.down('p').innerHTML);
        showAlertDialog(_("Operation failed"));
        refreshCurrentFolder();
    }
}

function deleteMessagesWithoutTrash(data) {
    var url = ApplicationBaseURL + encodeURI(data["mailbox"]) + "/batchDelete";
    var parameters = "uid=" + data["id"].join(",") + '&withoutTrash=1';
    data["withoutTrash"] = true;
    triggerAjaxRequest(url, deleteSelectedMessagesCallback, data, parameters,
                           { "Content-type": "application/x-www-form-urlencoded" });
    disposeDialog();
}

function onMenuDeleteMessage(event) {
    deleteSelectedMessages();
    preventDefault(event);
}

/**
 * The following two functions are called from UIxMailPopupView
 * with window.opener.
 */
function deleteMessageWithDelay(url, id, mailbox, messageId) {
    var row = $("row_" + id);
    if (row) row.hide();
    setTimeout("deleteMessage('" +
               url + "', '" +
               id + "', '" +
               mailbox + "', '" +
               messageId + "')",
               50);
}

function deleteMessage(url, id, mailbox, messageId) {
    var data = { "id": new Array(id), "mailbox": mailbox, "path": new Array(messageId) };
    var parameters = "uid=" + id;
    deleteMessageRequestCount++;
    triggerAjaxRequest(url, deleteSelectedMessagesCallback, data, parameters,
                       { "Content-type": "application/x-www-form-urlencoded" });
}

function onPrintCurrentMessage(event) {
    var messageList = $("messageListBody").down("TBODY");
    var rows = messageList.getSelectedNodesId();
    if (rows.length == 0) {
        showAlertDialog(_("Please select a message to print."));
    }
    else if (rows.length > 1) {
        showAlertDialog(_("Please select only one message to print."));
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
    $("searchValue").value = "";
    initCriteria();

    Mailer.currentMailboxType = this.parentNode.getAttribute("datatype");
    if (Mailer.currentMailboxType == "account" || Mailer.currentMailboxType == "additional") {
        Mailer.currentMailbox = mailbox;
        var messageContent = $("messageContent");
        if (messageContent) messageContent.innerHTML = '';
        $("messageCountHeader").childNodes[0].innerHTML = '&nbsp;';
        Mailer.dataTable._emptyTable();
        updateWindowTitle();
    }
    else {
        var datatype = this.parentNode.getAttribute("datatype");
        if (datatype == 'draft' || datatype == 'sent')
            toggleAddressColumn("from", "to");
        else
            toggleAddressColumn("to", "from");

        updateWindowTitle(this.childNodesWithTag("span")[0]);
        openMailbox(mailbox);
    }

    Event.stop(event);
}

function toggleAddressColumn(search, replace) {
    var header = $(search + "Header");
    if (header) {
        header.id = replace + "Header";
        header.update(_(replace.capitalize()));
        var i = Mailer.columnsOrder.indexOf(search.capitalize());
        if (i >= 0)
            Mailer.columnsOrder[i] = replace.capitalize();
    }
    if (sorting["attribute"] == search)
        sorting["attribute"] = replace;
}

function onMailboxMenuMove(event) {
    var targetMailbox;
    var messageList = $("messageListBody").down("TBODY");
    var rowIds = messageList.getSelectedNodesId();
    var uids = new Array(); // message IDs
    var paths = new Array(); // row IDs

    Mailer.currentMessages[Mailer.currentMailbox] = null;
    $('messageContent').update();

    if (this.tagName == 'LI') // from contextual menu
        targetMailbox = this.mailbox.fullName();
    else // from DnD
        targetMailbox = this.readAttribute("dataname");

    for (var i = 0; i < rowIds.length; i++) {
        var uid = rowIds[i].substr(4);
        var path = Mailer.currentMailbox + "/" + uid;
	var rows = messageList.select('#' + rowIds[i]);
	if (rows.length > 0)
	    rows.first().hide();
        uids.push(uid);
        paths.push(path);
        // Remove references to closed popups
        for (var j = Mailer.popups.length - 1; j > -1; j--)
            if (!Mailer.popups[j].open || Mailer.popups[j].closed)
                Mailer.popups.splice(j,1);
        // Close message popup if opened
        for (var j = 0; j < Mailer.popups.length; j++)
            if (Mailer.popups[j].messageUID == path) {
                Mailer.popups[j].close();
                Mailer.popups.splice(j,1);
                break;
            }
    }

    // Remove cache of target data source
    deleteCachedMailbox(targetMailbox);

    var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/moveMessages";
    var parameters = "uid=" + uids.join(",") + "&folder=" + encodeURIComponent(targetMailbox);
    var data = { "id": uids, "mailbox": Mailer.currentMailbox, "path": paths, "folder": targetMailbox, "refresh": true };
    triggerAjaxRequest(url, folderRefreshCallback, data, parameters,
                       { "Content-type": "application/x-www-form-urlencoded" });

    return false;
}

function onMailboxMenuCopy(event) {
    var messageList = $("messageListBody").down("TBODY");
    var rowIds = messageList.getSelectedNodesId();
    var uids = new Array(); // message IDs
    var paths = new Array(); // row IDs

    var targetMailbox;
    if (this.tagName == 'LI') // from contextual menu
        targetMailbox = this.mailbox.fullName();
    else // from DnD
        targetMailbox = this.readAttribute("dataname");
    for (var i = 0; i < rowIds.length; i++) {
        var uid = rowIds[i].substr(4);
        var path = Mailer.currentMailbox + "/" + uid;
        uids.push(uid);
        paths.push(path);
    }

    // Remove cache of target data source
    deleteCachedMailbox(targetMailbox);

    var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/copyMessages";
    var parameters = "uid=" + uids.join(",") + "&folder=" + encodeURIComponent(targetMailbox);
    var data = { "id": uids, "mailbox": Mailer.currentMailbox, "path": paths, "folder": targetMailbox, "refresh": false };
    triggerAjaxRequest(url, folderRefreshCallback, data, parameters,
                       { "Content-type": "application/x-www-form-urlencoded" });

    return false;
}

function refreshMailbox() {
    var topWindow = getTopWindow();
    if (topWindow) {
        topWindow.refreshCurrentFolder();
        topWindow.refreshUnseenCounts();
    }

    return false;
}

function onComposeMessage() {
    var topWindow = getTopWindow();
    if (topWindow)
        topWindow.composeNewMessage();

    return false;
}

function composeNewMessage() {
    var account;
    if (Mailer.currentMailbox)
        account = Mailer.currentMailbox.split("/")[1];
    else if (mailAccounts.length)
        account = "0";
    else
        account = null;
    if (account) {
        var url = ApplicationBaseURL + encodeURI(account) + "/compose";
        openMailComposeWindow(url);
    }
}

function openMailbox(mailbox, reload) {
    if (mailbox != Mailer.currentMailbox || reload) {
        var url = ApplicationBaseURL + encodeURI(mailbox);
        var urlParams = new Hash();

        if (!reload) {
            var messageContent = $("messageContent");
            if (messageContent) messageContent.innerHTML = '';
            $("messageCountHeader").childNodes[0].innerHTML = '&nbsp;';
            lastClickedRow = -1; // from generic.js
        }

        var searchValue = search["value"];
        if (searchValue && searchValue.length > 0) {
            urlParams.set("search", search["criteria"]);
            urlParams.set("value", escape(searchValue.utf8encode()));
        }
        var sortAttribute = sorting["attribute"];
        if (sortAttribute && sortAttribute.length > 0) {
            urlParams.set("sort", sorting["attribute"]);
            urlParams.set("asc", sorting["ascending"]);

            var sortHeader = $(sorting["attribute"] + "Header");
            if (sortHeader) {
                var sortImages = sortHeader.up('THEAD').select(".sortImage");
                $(sortImages).each(function(item) {
                        item.remove();
                    });
                var sortImage = createElement("img", "messageSortImage", "sortImage");
                sortHeader.insertBefore(sortImage, sortHeader.firstChild);
                if (sorting["ascending"])
                    sortImage.src = ResourcesURL + "/arrow-up.png";
                else
                    sortImage.src = ResourcesURL + "/arrow-down.png";
            }
        }

        var messageList = $("messageListBody").down('TBODY');
        var key = mailbox;
        if (urlParams.keys().length > 0) {
            var p = urlParams.keys().collect(function(key) { return key + "=" + urlParams.get(key); }).join("&");
            key += "?" + p;
        }

        if (reload) {
            // Don't change data source, only query UIDs from server and refresh
            // the view. Cases that end up here:
            // - performed a search
            // - clicked on Get Mail button
            urlParams.set("no_headers", "1");
            Mailer.dataTable.load(urlParams);
            Mailer.dataTable.refresh();
        }
        else {
            var dataSource = Mailer.dataSources.get(key);
            if (!dataSource) {
                // Data source is not cached
                dataSource = new SOGoMailDataSource(Mailer.dataTable, url);
                if (inboxData) {
                    // Use UIDs and headers from the WOX template; this only
                    // happens once and only with the inbox
                    dataSource.init(inboxData['uids'], inboxData['threaded'], inboxData['headers'], inboxData['quotas']);
                    inboxData = null; // invalidate this initial lookup
                }
                else
                    // Fetch UIDs and headers from server
                    dataSource.load(urlParams);
                // Cache data source
                Mailer.dataSources.set(key, dataSource);
                // Update unseen count
                getUnseenCountForFolder(mailbox);
            }
            else {
                // Data source is cached, query only UIDs from server
                urlParams.set("no_headers", "1");
                dataSource.load(urlParams);
            }
            // Associate data source with data table and render the view
            Mailer.dataTable.setSource(dataSource);
            Mailer.dataTable.render();
        }

        Mailer.currentMailbox = mailbox;

        if (Mailer.unseenCountMailboxes.indexOf(mailbox) == -1) {
            Mailer.unseenCountMailboxes.push(mailbox);
        }

	// Restore previous selection
        var currentMessage = Mailer.currentMessages[mailbox];
        if (currentMessage) {
            if (!reload) {
                loadMessage(currentMessage);
            }
	}
    }
}

/*
 * Called from SOGoDataTable.render()
 */
function messageListCallback(row, data, isNew) {
    var currentMessage = Mailer.currentMessages[Mailer.currentMailbox];
    row.id = data['rowID'];
    row.writeAttribute('labels', (data['labels']?data['labels']:""));
    row.className = data['rowClasses'];
    row.show(); // make sure the row is visible

    // Restore previous selection
    if (data['uid'] == currentMessage)
	row.addClassName('_selected');

    if (data['Thread'])
        row.addClassName('openedThread');
    else if (data['ThreadLevel'] > 0) {
        if (data['ThreadLevel'] > 10) data['ThreadLevel'] = 10;
        row.addClassName('thread');
        row.addClassName('thread' + data['ThreadLevel']);
    }

    var cells = row.childElements();
    for (var j = 0; j < cells.length; j++) {
        var cell = cells[j];
        var cellType = Mailer.columnsOrder[j];

        if (data[cellType]) cell.innerHTML = data[cellType];
        else cell.innerHTML = '&nbsp;';
    }
}

function refreshUnseenCounts() {
    for (var i = 0; i < Mailer.unseenCountMailboxes.length; i++) {
        var mailboxPath = Mailer.unseenCountMailboxes[i];
        var node = mailboxTree.getMailboxNode(mailboxPath);
        if (node) {
            getUnseenCountForFolder(mailboxPath);
        }
    }
}

function getUnseenCountForFolder(mailbox) {
    var url = ApplicationBaseURL + encodeURI(mailbox) + '/unseenCount';
    triggerAjaxRequest(url, unseenCountCallback, mailbox);
}

function unseenCountCallback(http) {
    var div = $('mailboxContent');
    var table = $('messageList');

    if (http.status == 200) {
        document.unseenCountAjaxRequest = null;
        var data = http.responseText.evalJSON(true);
        var node = mailboxTree.getMailboxNode(http.callbackData);
        if (node)
            updateUnseenCount(node, data.unseen, false);
    }
}

function updateUnseenCount(node, count, isDelta) {
    var unseenSpan = null;
    var counterSpan = null;

    var spans = node.select("SPAN.unseenCount");
    if (spans.length > 0) {
        counterSpan = spans[0];
        unseenSpan = counterSpan.parentNode;
    }
    if (counterSpan) {
        if (typeof(count) == "undefined" || isDelta) {
            if (typeof(count) == "undefined") {
                count = 0;
            }
            var content = "";
            for (var i = 0; i < counterSpan.childNodes.length; i++) {
                var cNode = counterSpan.childNodes[i];
                if (cNode.nodeType == 3) {
                    content += cNode.nodeValue;
                }
            }
            var digits = "";
            for (var i = 0; i < content.length; i++) {
                var code = content.charCodeAt(i);
                if (code > 47 && code < 58) {
                    digits += content.charAt(i);
                }
            }
            count += parseInt(digits);
        }
        while (counterSpan.firstChild) {
            counterSpan.removeChild(counterSpan.firstChild);
        }
        counterSpan.appendChild(document.createTextNode(" (" + count + ")"));
  	if (count > 0) {
            counterSpan.removeClassName("hidden");
            unseenSpan.addClassName("unseen");
  	}
        else {
            counterSpan.addClassName("hidden");
            unseenSpan.removeClassName("unseen");
        }
        if (node.getAttribute("dataname") == Mailer.currentMailbox)
            updateWindowTitle(unseenSpan);
    }
}

function updateMessageListCounter(count, isDelta) {
    var cell = $("messageCountHeader").down();

    if (isDelta) {
        var value = parseInt(cell.innerHTML);
        count += value;
    }

    if (count > 0)
        cell.update(count + " " + _("messages"));
    else
        cell.update(_("No message"));
}

function updateWindowTitle(span) {
    if (!Mailer.defaultWindowTitle)
        Mailer.defaultWindowTitle = document.title || "SOGo";
    else if (!span)
        document.title = Mailer.defaultWindowTitle;
    if (span) {
        var title = Mailer.defaultWindowTitle + " - ";
        if (span.hasClassName("unseen")) {
            var subtitle = span.innerHTML.stripTags();
            var idx = subtitle.lastIndexOf("(");
            var len = subtitle.length-idx-2;
            title += "(" +  subtitle.substr(idx+1, len)  + ") " + subtitle.substring(0, idx);
        }
        else
            title += span.childNodes[0].nodeValue;
        document.title = title;
    }
}

/* Function is called when the event datatable:rendered is fired from SOGoDataTable. */
function onMessageListRender(event) {
    // Restore previous selection
    var currentMessage = Mailer.currentMessages[Mailer.currentMailbox];
    if (currentMessage) {
	var rows = this.select("TR#row_" + currentMessage);
	if (rows.length == 1)
	    rows[0].selectElement();
    }
    // Update message counter in folder name
    updateMessageListCounter(event.memo, false);
}

function onMessageContextMenu(event) {
    var target = Event.element(event);
    var menu = $('messageListMenu');
    var topNode = $('messageListBody');
    var selectedNodes = topNode.getSelectedRowsId();
    var row = target.up('TR');

    if (selectedNodes.indexOf(row.id) < 0) {
        if (target.tagName != 'TD')
            target = target.up('TD');
        onRowClick(event, target);
        selectedNodes = topNode.getSelectedRowsId();
    }

    if (selectedNodes.length > 1)
        popupMenu(event, "messagesListMenu", selectedNodes);
    else if (selectedNodes.length == 1)
        popupMenu(event, "messageListMenu", row);

    return false;
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
    menu.on("contextmenu:hide", onFolderMenuHide);
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

    this.stopObserving("contextmenu:hide", onFolderMenuHide);
}

function deleteCachedMailboxByType(type) {
    var nodes = $("mailboxTree").select("DIV[datatype=" + type + "]");
    if (nodes.length == 1)
        deleteCachedMailbox(nodes[0].readAttribute("dataname"));

    if (Mailer.currentMailboxType == type)
        refreshCurrentFolder();
}

function deleteCachedMailbox(mailboxPath) {
    var keys = Mailer.dataSources.keys();
    for (var i = 0; i < keys.length; i++) {
	if (keys[i] == mailboxPath || keys[i].startsWith(mailboxPath + "?"))
            Mailer.dataSources.unset(keys[i]);
    }
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

function onMessageSelectionChange(event) {
    var t = getTarget(event);

    if (t.tagName == 'IMG') {
        t = t.parentNode;
        if (t.tagName == 'TD') {
            if (t.className == 'messageThreadColumn') {
                //mailListToggleMessageThread(t.parentNode, t); Disable thread collapsing
            }
            else if (t.className == 'messageUnreadColumn') {
                mailListToggleMessagesRead(t.parentNode);
                return false;
            }
            else if (t.className == 'messageFlagColumn') {
                mailListToggleMessagesFlagged(t.parentNode);
                return false;
            }
        }
    }
    if (t.tagName == 'SPAN')
        t = t.parentNode;

    // Update rows selection
    onRowClick(event, t);

    var messageContent = $("messageContent");
    var rows = this.getSelectedRowsId();
    if (rows.length == 1) {
        var idx = rows[0].substr(4);
        if (Mailer.currentMessages[Mailer.currentMailbox] != idx) {
            Mailer.currentMessages[Mailer.currentMailbox] = idx;
            if (messageContent) loadMessage(idx);
        }
    }
    else if (rows.length > 1 && messageContent)
        $('messageContent').innerHTML = '';

    return true;
}

function loadMessage(msguid) {
    if (document.messageAjaxRequest) {
        document.messageAjaxRequest.aborted = true;
        document.messageAjaxRequest.abort();
    }

    var div = $('messageContent');
    if (div == null)
        // Single-window mode
        return false;

    var cachedMessage = getCachedMessage(msguid);
    var row = $("row_" + msguid);
    var seenStateHasChanged = row && row.hasClassName('mailer_unreadmail');
    if (cachedMessage == null) {
        var url = (ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/"
                   + msguid + "/view?noframe=1");
        div.innerHTML = '';
        document.messageAjaxRequest = triggerAjaxRequest(url,
							 loadMessageCallback,
							 { 'mailbox': Mailer.currentMailbox,
                                                           'msguid': msguid,
                                                           'seenStateHasChanged': seenStateHasChanged });
	// Warning: We assume the user can set the read/unread flag of the message.
        markMailInWindow(window, msguid, true);
    }
    else {
        div.innerHTML = cachedMessage['text'];
        cachedMessage['time'] = (new Date()).getTime();
        document.messageAjaxRequest = null;
        configureLinksInMessage();
        resizeMailContent();
        if (seenStateHasChanged) {
            // Mark message as read on server
            mailListToggleMessagesRead();
        }
    }

    configureLoadImagesButton();
    configureSignatureFlagImage();

    return seenStateHasChanged;
}

function configureLoadImagesButton() {
    // We show/hide the "Load Images" button
    var loadImagesButton = $("loadImagesButton");
    var content = $("messageContent");
    var hiddenImgs = [];
    var imgs = content.select("IMG");
    $(imgs).each(function(img) {
            var unsafeSrc = img.getAttribute("unsafe-src");
            if (unsafeSrc) {
                hiddenImgs.push(img);
            }
        });
    content.hiddenImgs = hiddenImgs;

    var hiddenObjects = [];
    var objects = content.select("OBJECT");
    $(objects).each(function(obj) {
            if (obj.getAttribute("unsafe-data")
                || obj.getAttribute("unsafe-classid")) {
                hiddenObjects.push(obj);
            }
        });
    content.hiddenObjects = hiddenObjects;

    if (typeof(loadImagesButton) == "undefined" ||
        loadImagesButton == null ) {
        return;
    }
    if ((hiddenImgs.length + hiddenObjects.length) == 0) {
        loadImagesButton.setStyle({ display: 'none' });
    }
}

function configureSignatureFlagImage() {
    var signedPart = $("signedMessage");
    if (signedPart) {
        var supportsSMIME
            = parseInt(signedPart.getAttribute("supports-smime"));

        if (supportsSMIME) {
            var loadImagesButton = $("loadImagesButton");
            var parentNode = loadImagesButton.parentNode;

            var valid = parseInt(signedPart.getAttribute("valid"));
            var flagImage;

            if (valid)
                flagImage = "signature-ok.png";
            else
                flagImage = "signature-not-ok.png";

            var error = signedPart.getAttribute("error");
            var newImg = createElement("img", "signedImage", null, null,
                                       { src: ResourcesURL + "/" + flagImage });

            var msgDiv = $("signatureFlagMessage");
            if (msgDiv && error) {
                // First line in a h1, others each in a p
                var formattedMessage = "<h1>" + error.replace(/\n/, "</h1><p>");
                formattedMessage = formattedMessage.replace(/\n/g, "</p><p>") + "</p>";
                msgDiv.innerHTML = "<div>" + formattedMessage + "</div>";
                newImg.observe("mouseover", showSignatureMessage);
                newImg.observe("mouseout", hideSignatureMessage);
            }
            loadImagesButton.parentNode.insertBefore(newImg, loadImagesButton.nextSibling);
        }
    }
}

function showSignatureMessage () {
    var div = $("signatureFlagMessage");
    if (div) {
        var node = $("signedImage");
        var cellPosition = node.cumulativeOffset();
        var divDimensions = div.getDimensions();
        var left = cellPosition[0] - divDimensions['width'];
        var top = cellPosition[1];
        div.style.top = (top + 5) + "px";
        div.style.left = (left + 5) + "px";
        div.style.display = "block";
    }
}
function hideSignatureMessage () {
    var div = $("signatureFlagMessage");
    if (div)
      div.style.display = "none";
}

function configureLinksInMessage() {
    var messageDiv = $('messageContent');
    var mailContentDiv = document.getElementsByClassName('mailer_mailcontent',
                                                         messageDiv)[0];
    if (!$(document.body).hasClassName("popup"))
        mailContentDiv.observe("contextmenu", onMessageContentMenu);

    var anchors = messageDiv.getElementsByTagName('a');
    for (var i = 0; i < anchors.length; i++) {
        var anchor = $(anchors[i]);
        if (!anchor.href && anchor.readAttribute("moz-do-not-send")) {
            anchor.writeAttribute("moz-do-not-send", false);
            anchor.removeClassName("moz-txt-link-abbreviated");
            anchor.href = "mailto:" + anchors[i].innerHTML;
        }
        if (anchor.href.substring(0,7) == "mailto:") {
            anchor.observe("click", onEmailTo);
            anchor.observe("contextmenu", onEmailAddressClick);
            anchor.writeAttribute("moz-do-not-send", false);
        }
        else
            anchor.observe("click", onMessageAnchorClick);
    }

    var attachments = messageDiv.select ("DIV.linked_attachment_body");
    for (var i = 0; i < attachments.length; i++)
        $(attachments[i]).observe("contextmenu", onAttachmentClick);

    var images = messageDiv.select("IMG.mailer_imagecontent");
    for (var i = 0; i < images.length; i++)
        $(images[i]).observe("contextmenu", onImageClick);

    var editDraftButton = $("editDraftButton");
    if (editDraftButton)
        editDraftButton.observe("click",
                                onMessageEditDraft.bindAsEventListener(editDraftButton));

    var loadImagesButton = $("loadImagesButton");
    if (loadImagesButton)
        $(loadImagesButton).observe("click", onMessageLoadImages);

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
            button.stopObserving("click");
            button.observe("click",
                           onICalendarButtonClick.bindAsEventListener(button));
        }
    }

    var button = $("iCalendarDelegate");
    if (button) {
        button.stopObserving("click");
        button.observe("click", onICalendarDelegate);
        var delegatedTo = $("delegatedTo");
        delegatedTo.addInterface(SOGoAutoCompletionInterface);
        delegatedTo.uidField = "c_mail";
        delegatedTo.excludeGroups = true;
        delegatedTo.excludeLists = true;

        var editDelegate = $("editDelegate");
        if (editDelegate) {
            // The user delegates the invitation
            editDelegate.stopObserving("click");
            editDelegate.observe("click", function(event) {
                    $("delegateEditor").show();
                    $("delegatedTo").focus();
                    this.hide();
                });
        }

        var delegatedToLink = $("delegatedToLink");
        if (delegatedToLink) {
            // The user already delegated the invitation and wants
            // to change the delegated attendee
            delegatedToLink.stopObserving("click");
            delegatedToLink.observe("click", function(event) {
                    $("delegatedTo").show();
                    $("iCalendarDelegate").show();
                    $("delegatedTo").focus();
                    this.hide();
                    Event.stop(event);
                });
        }
    }
}

function onICalendarDelegate(event) {
    var link = $("iCalendarAttachment").value;
    if (link) {
        var currentMsg;
        if ($(document.body).hasClassName("popup"))
            currentMsg = mailboxName + "/" + messageName;
        else
            currentMsg = Mailer.currentMailbox + "/"
                + Mailer.currentMessages[Mailer.currentMailbox];
        delegateInvitation(link, ICalendarButtonCallback, currentMsg);
    }
    this.blur(); // required by IE
    Event.stop(event);
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

    this.blur(); // Required by IE
    Event.stop(event);
}

function ICalendarButtonCallback(http) {
    if ($(document.body).hasClassName("popup")) {
        if (window.opener && window.opener.open && !window.opener.closed)
            window.opener.ICalendarButtonCallback(http);
        else
            window.location.reload();
    }
    else {
        var oldMsg = http.callbackData;
        if (isHttpStatus204(http.status)) {
            var msg = Mailer.currentMailbox + "/" + Mailer.currentMessages[Mailer.currentMailbox];
            deleteCachedMessage(oldMsg);
            if (oldMsg == msg) {
                loadMessage(Mailer.currentMessages[Mailer.currentMailbox]);
            }
            for (var i = 0; i < Mailer.popups.length; i++) {
                if (Mailer.popups[i].messageUID == oldMsg) {
                    // Don't reload, just close;
                    // Reloading the popup would disconnect the popup from the parent
                    //Mailer.popups[i].location.reload();
                    Mailer.popups[i].close();
                    Mailer.popups.splice(i,1);
                    break;
                }
            }
        }
        else if (http.status == 403) {
            var data = http.responseText;
            var msg = data.replace(/^(.*\n)*.*<p>((.*\n)*.*)<\/p>(.*\n)*.*$/, "$2");
            for (var i = 0; i < Mailer.popups.length; i++) {
                if (Mailer.popups[i].messageUID == oldMsg) {
                    // Show the alert in the proper popup window
                    Mailer.popups[i].alert(_(msg));
                    break;
                }
            }
            if (i == Mailer.popups.length)
                showAlertDialog(_(msg));
        }
        else
            showAlertDialog("received code: " + http.status + "\nerror: " + http.responseText);
    }
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

function onMessageLoadImages(event) {
    var content = $("messageContent");
    $(content.hiddenImgs).each(function(img) {
            var unSafeSrc = img.getAttribute("unsafe-src");
            log ("unsafesrc: " + unSafeSrc);
            img.src = img.getAttribute("unsafe-src");
        });
    content.hiddenImgs = null;
    $(content.hiddenObjects).each(function(obj) {
            var unSafeData = obj.getAttribute("unsafe-data");
            if (unSafeData) {
                obj.setAttribute("data", unSafeData);
            }
            var unSafeClassId = obj.getAttribute("unsafe-classid");
            if (unSafeClassId) {
                obj.setAttribute("classid", unSafeClassId);
            }
        });
    content.hiddenObjects = null;


    var loadImagesButton = $("loadImagesButton");
    loadImagesButton.setStyle({ display: 'none' });

    Event.stop(event);
}

function onEmailAddressClick(event) {
    popupMenu(event, 'addressMenu', this);
    preventDefault(event);
    return false;
}

function onMessageAnchorClick(event) {
    if (this.href)
        window.open(this.href);
    preventDefault(event);
}

function onImageClick(event) {
    popupMenu(event, 'imageMenu', this);
    preventDefault(event);
    return false;
}

function onAttachmentClick (event) {
    popupMenu (event, 'attachmentMenu', this);
    preventDefault (event);
    return false;
}

function handleReturnReceipt() {
    var input = $("shouldAskReceipt");
    if (input) {
        if (eval(input.value)) {
            showConfirmDialog(_("Return Receipt"),
                              _("The sender of this message has asked to be notified when you read this message. "
                                + "Do you with to notify the sender?"),
                              onReadMessageConfirmMDN);
        }
    }
}

function onReadMessageConfirmMDN(event) {
    var messageURL;
    if (window.opener && window.opener.Mailer) {
        /* from UIxMailPopupView */
        messageURL = (ApplicationBaseURL + encodeURI(mailboxName)
                      + "/" + messageName);
    }
    else {
        /* from main window */
        messageURL = (ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/"
                      + Mailer.currentMessages[Mailer.currentMailbox]);
    }
    disposeDialog();
    var url = messageURL + "/sendMDN";
    triggerAjaxRequest(url);
}

function loadMessageCallback(http) {
    var div = $('messageContent');

    if (http.status == 200) {
        if (http.callbackData) {
            document.messageAjaxRequest = null;
	    var msguid = http.callbackData.msguid;
            var mailbox = http.callbackData.mailbox;
            if (Mailer.currentMailbox == mailbox &&
                Mailer.currentMessages[Mailer.currentMailbox] == msguid) {
                div.innerHTML = http.responseText;
                configureLinksInMessage();
                resizeMailContent();
                configureLoadImagesButton();
                configureSignatureFlagImage();
                handleReturnReceipt();
	        // Warning: If the user can't set the read/unread flag, it won't
	        // be reflected in the view unless we force the refresh.
                if (http.callbackData.seenStateHasChanged)
                    Mailer.dataTable.dataSource.invalidate(msguid);
            }
            var cachedMessage = new Array();
            cachedMessage['idx'] = Mailer.currentMailbox + '/' + msguid;
            cachedMessage['time'] = (new Date()).getTime();
            cachedMessage['text'] = http.responseText;
            if (cachedMessage['text'].length < 30000)
                storeCachedMessage(cachedMessage);
        }
    }
    else if (http.status == 404) {
        showAlertDialog (_("The message you have selected doesn't exist anymore."));
	Mailer.dataTable.remove(http.callbackData.msguid);
	Mailer.currentMessages[Mailer.currentMailbox] = null;
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

    if (currentNode) {
        action = currentNode.getAttribute('mailboxaction');
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
    var messageList = $("messageListBody");
    var rows = messageList.getSelectedRowsId();

    if (rows.length > 0) {
        var url = (ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/"
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

function saveAttachment(event) {
    var div = document.menuTarget;
    var link = div.select ("a").first ();
    var url = link.getAttribute("href");
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
    var s = this.innerHTML.strip();
    if (!/@/.test(s)) {
        s += ' <' + this.href.substr(7) + '>';
    }
    openMailTo(s);
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
    if (SOGoResizableTable._onHandle)
        return;

    var headerId = this.getAttribute("id");
    var newSortAttribute;
    if (headerId == "subjectHeader")
        newSortAttribute = "subject";
    else if (headerId == "fromHeader")
        newSortAttribute = "from";
    else if (headerId == "toHeader")
        newSortAttribute = "to";
    else if (headerId == "dateHeader")
        newSortAttribute = "date";
    else if (headerId == "sizeHeader")
        newSortAttribute = "size";
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
    if (Mailer.currentMailboxType != "account" && Mailer.currentMailboxType != "additional")
        openMailbox(Mailer.currentMailbox, true);
}

/* Called after sending an email */
function refreshMessage(mailbox, messageUID) {
    if (Mailer.currentMailboxType == 'sent')
        refreshCurrentFolder();
    else if (mailbox == Mailer.currentMailbox) {
	Mailer.dataTable.invalidate(messageUID);
    }
}

function configureMessageListEvents() {
    var headerTable = $("messageListHeader");
    var dataTable = $("messageListBody");
    var messageContent = $("messageContent");

    if (headerTable)
        // Sortable columns
        configureSortableTableHeaders(headerTable);

    if (dataTable) {
        dataTable.multiselect = true;
        if (messageContent) {
            dataTable.observe("click", onMessageSelectionChange);
            dataTable.observe("dblclick", onMessageDoubleClick);
        }
        else {
            // Single-window mode
            dataTable.observe("click", function(e) {
                onMessageSelectionChange.bind(this)(e) &&
                    onMessageDoubleClick.bind(this)(e); });
        }
        dataTable.observe("selectstart", listRowMouseDownHandler);
        dataTable.observe("contextmenu", onMessageContextMenu);
    }
}

function configureDragHandles() {
    var handle = $("verticalDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.leftMargin = 50;
        handle.leftBlock=$("leftPanel");
        handle.rightBlock=$("rightPanel");
    }

    handle = $("rightDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.upperBlock=$("mailboxContent");
        handle.lowerBlock=$("messageContent");
        handle.observe("handle:dragged", onMessageListResize);
    }
}

function onMessageListResize(event) {
    var h = $("mailboxContent").getHeight() - $("messageListHeader").getHeight();
    $("mailboxList").setStyle({'height': h + 'px'});
}

function onWindowResize(event) {
    var handle = $("verticalDragHandle");
    if (handle)
        handle.adjust();
    handle = $("rightDragHandle");
    if (handle)
        handle.adjust();
}

/* stub */

function refreshContacts() {
}

function openInbox(node) {
    var done = false;
    openMailbox(node.parentNode.getAttribute("dataname"), false);
    mailboxTree.o(1);
    mailboxTree.s(2);
}

function initMailer(event) {
    if (!$(document.body).hasClassName("popup")) {
        Mailer.columnsOrder = UserDefaults["SOGoMailListViewColumnsOrder"];
        Mailer.sortByThread = UserDefaults["SOGoMailSortByThreads"] != null && parseInt(UserDefaults["SOGoMailSortByThreads"]) > 0;
        if (Mailer.sortByThread && Mailer.columnsOrder[0] != "Thread")
            Mailer.columnsOrder = ["Thread"].concat(Mailer.columnsOrder);
        else if (!Mailer.sortByThread && Mailer.columnsOrder[0] == "Thread")
            Mailer.columnsOrder.shift(); // drop the thread column

        // Restore sorting from user settings
        if (UserSettings && UserSettings["Mail"] && UserSettings["Mail"]["SortingState"]) {
            sorting["attribute"] = UserSettings["Mail"]["SortingState"][0];
            sorting["ascending"] = parseInt(UserSettings["Mail"]["SortingState"][1]) > 0;
            if (sorting["attribute"] == 'to') sorting["attribute"] = 'from'; // initial mailbox is always the inbox
        }
        else {
            sorting["attribute"] = "date";
            sorting["ascending"] = false;
        }

        Mailer.dataTable = $("mailboxList");
        Mailer.dataTable.addInterface(SOGoDataTableInterface);
        Mailer.dataTable.setRowRenderCallback(messageListCallback);
        Mailer.dataTable.observe("datatable:rendered", onMessageListRender);

        var messageListHeader = $("messageListHeader");
        messageListHeader.addInterface(SOGoResizableTableInterface);
        if (UserSettings["Mail"] && UserSettings["Mail"]["ColumnsState"]) {
            messageListHeader.restore($H(UserSettings["Mail"]["ColumnsState"]));
        }
        else {
            messageListHeader.restore();
        }

        configureDraggables();
        configureMessageListEvents();

        initMailboxTree();
        initMessageCheckTimer();

        if (Prototype.Browser.Gecko)
            Event.observe(document, "keypress", onDocumentKeydown); // for FF2
        else
            Event.observe(document, "keydown", onDocumentKeydown);

        /* Perform an expunge when leaving the webmail */
//        if (isSafari()) {
//            $('calendarBannerLink').observe("click", onUnload);
//            $('contactsBannerLink').observe("click", onUnload);
//            $('logoff').observe("click", onUnload);
//        }
//        else
            Event.observe(window, "beforeunload", onUnload);

        onMessageListResize();
    }

    onWindowResize.defer();
    Event.observe(window, "resize", onWindowResize);
}

function initMessageCheckTimer() {
    var messageCheck = UserDefaults["SOGoMailMessageCheck"];
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
    mailboxTree.config.hideRoot = true;
    mailboxTree.icon.root = ResourcesURL + "/tbtv_account_17x17.gif";
    mailboxTree.icon.folder = ResourcesURL + "/tbtv_leaf_corner_17x17.png";
    mailboxTree.icon.folderOpen	= ResourcesURL + "/tbtv_leaf_corner_17x17.png";
    mailboxTree.icon.node = ResourcesURL + "/tbtv_leaf_corner_17x17.png";
    mailboxTree.icon.line = ResourcesURL + "/tbtv_line_17x22.png";
    mailboxTree.icon.join = ResourcesURL + "/tbtv_junction_17x22.png";
    mailboxTree.icon.joinBottom = ResourcesURL + "/tbtv_corner_17x22.png";
    mailboxTree.icon.plus = ResourcesURL + "/tbtv_plus_17x22.png";
    mailboxTree.icon.plusBottom = ResourcesURL + "/tbtv_corner_plus_17x22.png";
    mailboxTree.icon.minus = ResourcesURL + "/tbtv_minus_17x22.png";
    mailboxTree.icon.minusBottom = ResourcesURL + "/tbtv_corner_minus_17x22.png";
    mailboxTree.icon.nlPlus = ResourcesURL + "/tbtv_corner_plus_17x22.png";
    mailboxTree.icon.nlMinus = ResourcesURL + "/tbtv_corner_minus_17x22.png";
    mailboxTree.icon.empty = ResourcesURL + "/empty.gif";
    mailboxTree.preload ();

    mailboxTree.add(0, -1, '');

    var chainRq = new AjaxRequestsChain(initMailboxTreeCB);
    for (var i = 0; i < mailAccounts.length; i++) {
        var url = ApplicationBaseURL + i + "/mailboxes";
        chainRq.requests.push([url, onLoadMailboxesCallback, i]);
    }
    chainRq.start();
}

function initMailboxTreeCB() {
    updateMailboxTreeInPage();
    updateMailboxMenus();
    checkAjaxRequestsState();
    getFoldersState();
    configureDroppables();
    if (unseenCountFolders.length > 0) {
        for (var i = 0; i < unseenCountFolders.length; i++) {
            Mailer.unseenCountMailboxes.push(unseenCountFolders[i]);
        }
        refreshUnseenCounts();
    }
}

function onLoadMailboxesCallback(http) {
    if (http.status == 200) {
        checkAjaxRequestsState();
        if (http.responseText.length > 0) {
            var accountIdx = http.callbackData;
            var newAccount = buildMailboxes(accountIdx, http.responseText);
            accounts[accountIdx] = newAccount;
            mailboxTree.addMailAccount(newAccount);
        }
        else {
            log ("onLoadMailboxesCallback " + http.status);
        }
    }
}

function updateMailboxTreeInPage() {
    var treeContent = $("folderTreeContent");
    //treeContent.update(mailboxTree.toString ());
    treeContent.appendChild(mailboxTree.domObject ());

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

function updateQuotas(quotas) {
    if (quotas && parseInt(quotas.maxQuota) > 0) {
        log ("updating quotas " + quotas.usedSpace + "/" + quotas.maxQuota);
        var treeContent = $("folderTreeContent");
        var tree = $("mailboxTree");
        var quotaDiv = $("quotaIndicator");
        if (quotaDiv) {
            treeContent.removeChild(quotaDiv);
        }
        // Build quota indicator, show values in MB
        var percents = (Math.round(quotas.usedSpace * 10000
                                   / quotas.maxQuota)
                        / 100);
        var level = (percents > 85)? "alert" : (percents > 70)? "warn" : "ok";
        var format = _("quotasFormat");
        var text = format.formatted(percents,
                                    Math.round(quotas.maxQuota/10.24)/100);
        quotaDiv = new Element('div', { 'id': 'quotaIndicator',
                                        'class': 'quota',
                                        'info': text });
        var levelDiv = new Element('div', { 'class': 'level' });
        var valueDiv = new Element('div', { 'class': 'value ' + level, 'style': 'width: ' + ((percents > 100)?100:percents) + '%' });
        var marksDiv = new Element('div', { 'class': 'marks' });
        var textP = new Element('p').update(text);
        marksDiv.insert(new Element('div'));
        marksDiv.insert(new Element('div'));
        marksDiv.insert(new Element('div'));
        levelDiv.insert(valueDiv);
        levelDiv.insert(marksDiv);
        levelDiv.insert(textP);
        quotaDiv.insert(levelDiv);
        treeContent.insertBefore(quotaDiv, tree);
    }
}

function mailboxMenuNode(type, displayName) {
    var newNode = document.createElement("li");
    var icon = MailerUIdTreeExtension.folderIcons[type];
    if (!icon)
        icon = "tbtv_leaf_corner_17x17.png";
    var image = document.createElement("img");
    image.src = ResourcesURL + "/" + icon;
    newNode.appendChild(image);
    var dnOverride = MailerUIdTreeExtension.folderNames[type];
    if (dnOverride)
        displayName = dnOverride;
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
    menu.style.cssFloat="left";
    menu.style.styleFloat="left";
    menuDIV.appendChild(menu);
    pageContent.appendChild(menuDIV);

    var windowHeight = 0;
    if ( typeof(window.innerHeight) != "undefined" && window.innerHeight != 0 ) {
        windowHeight = window.innerHeight;
    }
    else {
        windowHeight = document.body.clientHeight;
    }
    var offset = 70;
    if ( navigator.appVersion.indexOf("Safari") >= 0 ) {
        offset = 140;
    }

    var callbacks = new Array();
    if (mailbox.type != "account") {
        var newNode = document.createElement("li");
        newNode.mailbox = mailbox;
        newNode.appendChild(document.createTextNode(_("This Folder")));
        menu.appendChild(newNode);
        menu.appendChild(document.createElement("li"));
        callbacks.push(callback);
        callbacks.push("-");
    }

    var submenuCount = 0;
    var newNode;
    for (var i = 0; i < mailbox.children.length; i++) {
        if (menu.offsetHeight > windowHeight-offset) {
            // Split menu to fit screen
            var menuWidth = (parseInt(menu.offsetWidth) + 15) + "px";
            menu.style.width = menuWidth;
            menu = document.createElement("ul");
            menu.style.cssFloat="left";
            menu.style.styleFloat="left";
            menuDIV.appendChild(menu);
        }
        var child = mailbox.children[i];
        newNode = mailboxMenuNode(child.type, child.displayName);
        newNode.style.width = "auto";
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
    menu.style.width = (parseInt(menu.offsetWidth) + 15) + "px";

    initMenu(menuDIV, callbacks);

    return menuDIV.getAttribute("id");
}

function updateMailboxMenus() {
    var mailboxActions = { move: onMailboxMenuMove,
                           copy: onMailboxMenuCopy };

    for (var key in mailboxActions) {
        for (var i = 0; i < mailAccounts.length; i++) {
            var mailbox = accounts[i];
            generateMenuForMailbox(mailbox, key + "-" + i,
                                   mailboxActions[key]);
        }
    }
}

function buildMailboxes(accountIdx, encoded) {
    var account = new Mailbox("account", "" + accountIdx,
                              undefined, //necessary, null will cause issues
                              mailAccounts[accountIdx]);
    var data = encoded.evalJSON(true);
    var mailboxes = data.mailboxes;
    var unseen = (data.status? data.status.unseen : 0);

    for (var i = 0; i < mailboxes.length; i++) {
        var currentNode = account;
        var names = mailboxes[i].path.split("/");
        var displayNames = mailboxes[i].displayName.split("/");

        for (var j = 1; j < (names.length - 1); j++) {
            var name = names[j];
            var node = currentNode.findMailboxByName(name);
            if (!node) {
                node = new Mailbox("additional", name, 0, displayNames[j]);
                currentNode.addMailbox(node);
            }
            currentNode = node;
        }
        var basename = names[names.length-1];
        var leaf = currentNode.findMailboxByName(basename);
        if (leaf)
            leaf.type = mailboxes[i].type;
        else {
            if (mailboxes[i].type == 'inbox')
                leaf = new Mailbox(mailboxes[i].type, basename, unseen, displayNames[names.length-1]);
            else
                leaf = new Mailbox(mailboxes[i].type, basename, 0, displayNames[names.length-1]);
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
        var urlstr =  ApplicationBaseURL + "saveFoldersState";
        var parameters = "expandedFolders=" + foldersState;
        triggerAjaxRequest(urlstr, saveFoldersStateCallback, null, parameters,
                           { "Content-type": "application/x-www-form-urlencoded" });
    }
}

function saveFoldersStateCallback(http) {
    if (isHttpStatus204(http.status)) {
        log ("folders state saved");
    }
}

function onMenuCreateFolder(event) {
    showPromptDialog(_("New Folder..."), _("Name :"), onMenuCreateFolderConfirm);
}

function onMenuCreateFolderConfirm(event) {
    var name = this.value;
    if (name && name.length > 0) {
        var folderID = document.menuTarget.getAttribute("dataname");
        var urlstr = URLForFolderID(folderID) + "/createFolder?name=" + encodeURIComponent(name);
        var errorLabel = labels["The folder with name \"%{0}\" could not be created."];
        triggerAjaxRequest(urlstr, folderOperationCallback,
                           errorLabel.formatted(name));
    }
    disposeDialog();
}

function onMenuRenameFolder(event) {
    showPromptDialog(_("Rename Folder..."), _("Enter the new name of your folder :"), onMenuRenameFolderConfirm);
}

function onMenuRenameFolderConfirm() {
    var name = this.value;
    if (name && name.length > 0) {
        var folderID = document.menuTarget.getAttribute("dataname");
        var urlstr = URLForFolderID(folderID) + "/renameFolder?name=" + encodeURIComponent(name);
        var errorLabel = labels["This folder could not be renamed to \"%{0}\"."];
        triggerAjaxRequest(urlstr, folderOperationCallback,
                           errorLabel.formatted(name));
    }
    disposeDialog();
}

function onMenuDeleteFolder(event) {
    showConfirmDialog(_("Confirmation"),
                     _("Do you really want to move this folder into the trash ?"),
                     onMenuDeleteFolderConfirm);
}

function onMenuDeleteFolderConfirm() {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/delete";
    var errorLabel = _("The folder could not be deleted.");
    triggerAjaxRequest(urlstr, folderOperationCallback, errorLabel);
    disposeDialog();
}

function onMenuExpungeFolder(event) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/expunge";
    triggerAjaxRequest(urlstr, folderRefreshCallback, { "mailbox": folderID, "refresh": false });
}

function onMenuEmptyTrash(event) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/emptyTrash";
    triggerAjaxRequest(urlstr, onMenuEmptyTrashCallback, { "mailbox" : folderID });

    if (folderID == Mailer.currentMailbox) {
        $('messageContent').innerHTML = '';
    }
    var msgID = Mailer.currentMessages[folderID];
    if (msgID) {
        delete Mailer.currentMessages[folderID];
        deleteCachedMessage(folderID + "/" + msgID);
    }
}

function onMenuEmptyTrashCallback(http) {
    if (http.readyState == 4
        && http.status == 200)   {
        deleteCachedMailboxByType('trash');
        // Reload the folder tree if there was folders in the trash
        var reloaded = false;
        var nodes = $("mailboxTree").select("DIV[datatype=trash]");
        for (var i = 0; i < nodes.length; i++) {
            if (http.callbackData.mailbox == nodes[i].readAttribute('dataname')) {
                // Reset the unread message count
                updateUnseenCount(nodes[i], 0);
                var sibling = nodes[i].next();
                if (sibling && sibling.hasClassName("clip")) {
                    initMailboxTree();
                    reloaded = true;
                    break;
                }
            }
        }
        if (!reloaded) {
            var data = http.responseText.evalJSON(true);
            // We currently only show the quota for the first account (0).
            if (data.quotas && http.callbackData.mailbox.startsWith('/0/'))
                updateQuotas(data.quotas);
        }
    }
    else
        showAlertDialog(_("The trash could not be emptied."));
}

function _onMenuChangeToXXXFolder(event, folder) {
    var type = document.menuTarget.getAttribute("datatype");
    if (type == "additional")
        showAlertDialog(_("You need to choose a non-virtual folder!"));
    else {
        var folderID = document.menuTarget.getAttribute("dataname");
        var urlstr = URLForFolderID(folderID) + "/setAs" + folder + "Folder";
        var errorLabel = _("The folder functionality could not be changed.");
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

function onMenuToggleMessageRead(event) {
    mailListToggleMessagesRead();
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

    var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/";
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
                     $('row_' + Mailer.currentMessages[Mailer.currentMailbox]).getAttribute("labels"));
    else if (Object.isArray(document.menuTarget))
        // Menu called from multiple selection in messages list view
        $(document.menuTarget).collect(function(rowID) {
            var row = $(rowID);
            if (row)
                messages.set(rowID.substr(4),
                             row.getAttribute("labels"));
            });
    else
        // Menu called from one selection in messages list view
        messages.set(document.menuTarget.getAttribute("id").substr(4),
                     document.menuTarget.getAttribute("labels"));

    var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/";
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

function onMenuToggleMessageFlag(event) {
    mailListToggleMessagesFlagged();
}

function folderOperationCallback(http) {
    if (http.readyState == 4
        && isHttpStatus204(http.status))
        initMailboxTree();
    else
        showAlertDialog(http.callbackData);
}

function folderRefreshCallback(http) {
    if (http.readyState == 4
        && (http.status == 200 || isHttpStatus204(http.status))) {
        var oldMailbox = http.callbackData.mailbox;
        if (http.callbackData.refresh
            && oldMailbox == Mailer.currentMailbox) {
	    getUnseenCountForFolder(oldMailbox);
            if (http.callbackData.id) {
                var s = http.callbackData.id + "";
                var uids = s.split(",");
                for (var i = 0; i < uids.length; i++)
                    Mailer.dataTable.remove(uids[i]);
                Mailer.dataTable.refresh();
            }
            else
                refreshCurrentFolder();
        }
        if (http.status == 200) {
            var data = http.responseText.evalJSON(true);
            if (data.quotas && http.callbackData.mailbox.startsWith('/0/'))
                updateQuotas(data.quotas);
        }
    }
    else {
        if (http.callbackData.id) {
            // Display hidden rows from move operation
            var s = http.callbackData.id + "";
            var uids = s.split(",");
            log ("folderRefreshCallback failed for UIDs " + s);
            for (var i = 0; i < uids.length; i++) {
                var row = $("row_" + uids[i]);
		if (row)
		    row.show();
            }
        }
        var msg = /<p>(.*)<\/p>/m.exec(http.responseText);
        showAlertDialog(_("Operation failed") + ": " + msg[1]);
    }
}

function messageFlagCallback(http) {
    if (http.readyState == 4
        && isHttpStatus204(http.status)) {
        var data = http.callbackData;
        if (data["mailbox"] == Mailer.currentMailbox) {
            Mailer.dataTable.invalidate(data["msg"]);
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
                row.writeAttribute("labels", flags.join(" "));
                row.toggleClassName("_selected");
                row.toggleClassName("_selected");
            }
            else
                row.writeAttribute("labels", "");
        }
    }
}

function onMessageListMenuPrepareVisibility() {
    /* This method attaches the right mailbox-menu to the generic message list
     menu. */
    var indexes = { "messageListMenu": 7,
                    "messagesListMenu": 2,
                    "messageContentMenu": 4 };
    if (document.menuTarget) {
        var mbx = Mailer.currentMailbox;
        if (mbx) {
            var lis = this.getElementsByTagName("li");
            var idx = indexes[this.id];
            var parts = mbx.split("/");
            var acctNbr = parseInt(parts[1]);
            lis[idx].submenu = "move-" + acctNbr + "Submenu";
            lis[idx+1].submenu = "copy-" + acctNbr + "Submenu";
        }
    }

    return true;
}

function onAccountIconMenuPrepareVisibility() {
    /* This methods disables or enables the "Delegation..." menu option on
     mail accounts. */
   if (document.menuTarget) {
        var mbx = document.menuTarget.getAttribute("dataname");
        if (mbx) {
            var lis = this.getElementsByTagName("li");
            var li = lis[lis.length - 1];
            var parts = mbx.split("/");
            var acctNbr = parseInt(parts[1]);
            if (acctNbr > 0) {
                li.addClassName("disabled");
            }
            else {
                li.removeClassName("disabled");
            }
        }
    }

    return true;
}

function onFolderMenuPrepareVisibility() {
    /* This methods disables or enables the "Sharing" menu option on
     mailboxes. */
    if (document.menuTarget) {
        var mbx = document.menuTarget.getAttribute("dataname");
        if (mbx) {
            var lis = this.getElementsByTagName("li");
            var li = lis[lis.length - 1];
            var parts = mbx.split("/");
            var acctNbr = parseInt(parts[1]);
            if (acctNbr > 0) {
                li.addClassName("disabled");
            }
            else {
                li.removeClassName("disabled");
            }
        }
    }

    return true;
}

function onLabelMenuPrepareVisibility() {
    var messageList = $("messageListBody");
    var flags = {};

    if (messageList) {
        var rows = messageList.getSelectedRows();
        for (var i = 0; i < rows.length; i++) {
            $w(rows[i].getAttribute("labels")).each(function(flag) {
                    flags[flag] = true;
                });
        }
    }

    var lis = this.childNodesWithTag("ul")[0].childNodesWithTag("li");
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

function onMarkMenuPrepareVisibility() {
    var messageList = $("messageListBody");
    if (messageList) {
        var nodes = messageList.down("TBODY").getSelectedNodesId();

        var isRead = false;
        var isFlagged = false;

        if (nodes.length > 0) {
            var row = null;
            for (var i = 0; row == null && i < nodes.length; i++)
                row = $(nodes[i]);
            var img = row.down('img');
            isFlagged = img.hasClassName ("messageIsFlagged");
            isRead = !row.hasClassName("mailer_unreadmail");
        }

        var menuUL = this.childElements()[0];
        var menuLIS = menuUL.childElements();

        if (isRead) {
            menuLIS[0].addClassName("_chosen");
        }
        else {
            menuLIS[0].removeClassName("_chosen");
        }
        if (isFlagged) {
            menuLIS[5].addClassName("_chosen");
        }
        else {
            menuLIS[5].removeClassName("_chosen");
        }
    }
}

function saveAs(event) {
    var messageList = $("messageListBody").down("TBODY");

    var uids = messageList.getSelectedNodesId();
    if (uids.length > 0) {
        for (var i = 0; i < uids.length; i++)
            uids[i] = uids[i].substr(4);
        var url = ApplicationBaseURL + encodeURI(Mailer.currentMailbox) + "/saveMessages";
        window.location.href = url + "?uid=" + uids.join(",");
    }
    else
        showAlertDialog(_("Please select a message."));

    return false;
}

function onMenuArchiveFolder(event) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var url = URLForFolderID(folderID) + "/exportFolder";
    window.location.href = url;
}

function onMenuAccountDelegation(event) {
    var folderID = document.menuTarget.getAttribute("dataname");
    var urlstr = ApplicationBaseURL + folderID + "/delegation";
    openAclWindow(urlstr);
}

function getMenus() {
    var menus = {
        accountIconMenu: [ null, null, onMenuCreateFolder, null, null, onMenuAccountDelegation ],
        inboxIconMenu: [ null, null, null, "-", null,
                         onMenuCreateFolder, onMenuExpungeFolder,
                         onMenuArchiveFolder, "-", null,
                         onMenuSharing ],
        trashIconMenu: [ null, null, null, "-", null,
                         onMenuCreateFolder, onMenuExpungeFolder,
                         onMenuArchiveFolder, onMenuEmptyTrash,
                         "-", null,
                         onMenuSharing ],
        mailboxIconMenu: [ null, null, null, "-", null,
                           onMenuCreateFolder,
                           onMenuRenameFolder,
                           onMenuExpungeFolder,
                           onMenuArchiveFolder,
                           onMenuDeleteFolder,
                           "folderTypeMenu",
                           "-", null,
                           onMenuSharing ],
        addressMenu: [ newContactFromEmail, newEmailTo ],
        messageListMenu: [ onMenuOpenMessage, "-",
                           onMenuReplyToSender,
                           onMenuReplyToAll,
                           onMenuForwardMessage, null,
                           "-", "moveMailboxMenu",
                           "copyMailboxMenu", "label-menu",
                           "mark-menu", "-", saveAs,
                           onMenuViewMessageSource, null,
                           null, onMenuDeleteMessage ],
        messagesListMenu: [ onMenuForwardMessage,
                            "-", "moveMailboxMenu",
                            "copyMailboxMenu", "label-menu",
                            "mark-menu", "-",
                            saveAs, null, null,
                            onMenuDeleteMessage ],
        imageMenu: [ saveImage ],
        attachmentMenu: [ saveAttachment ],
        messageContentMenu: [ onMenuReplyToSender,
                              onMenuReplyToAll,
                              onMenuForwardMessage,
                              null, "moveMailboxMenu",
                              "copyMailboxMenu",
                              "-", "label-menu", "mark-menu",
                              "-",
                              saveAs, onMenuViewMessageSource,
                              null, onPrintCurrentMessage,
                              onMenuDeleteMessage ],
        folderTypeMenu: [ onMenuChangeToSentFolder,
                          onMenuChangeToDraftsFolder,
                          onMenuChangeToTrashFolder  ],

        "label-menu": [ onMenuLabelNone, "-", onMenuLabelFlag1,
                        onMenuLabelFlag2, onMenuLabelFlag3,
                        onMenuLabelFlag4, onMenuLabelFlag5 ],
        "mark-menu": [ onMenuToggleMessageRead, null, null, null, "-", onMenuToggleMessageFlag ],
// , "-",
//                        null, null, null ],

        searchMenu: [ setSearchCriteria, setSearchCriteria,
                      setSearchCriteria, setSearchCriteria,
                      setSearchCriteria ]
    };

    var labelMenu = $("label-menu");
    if (labelMenu) {
        labelMenu.prepareVisibility = onLabelMenuPrepareVisibility;
    }

    var labelMenu = $("label-menu");
    if (labelMenu) {
        labelMenu.prepareVisibility = onLabelMenuPrepareVisibility;
    }

    var markMenu = $("mark-menu");
    if (markMenu) {
        markMenu.prepareVisibility = onMarkMenuPrepareVisibility;
    }

    var listMenus = [ "messageListMenu", "messagesListMenu", "messageContentMenu" ];
    for (var i = 0; i < listMenus.length; i++) {
        var menu = $(listMenus[i]);
        if (menu) {
            menu.prepareVisibility = onMessageListMenuPrepareVisibility;
        }
    }

    var accountIconMenu = $("accountIconMenu");
    if (accountIconMenu) {
        accountIconMenu.prepareVisibility = onAccountIconMenuPrepareVisibility;
    }

    var folderMenus = [ "inboxIconMenu", "trashIconMenu", "mailboxIconMenu" ];
    for (var i = 0; i < folderMenus.length; i++) {
        var menu = $(folderMenus[i]);
        if (menu) {
            menu.prepareVisibility = onFolderMenuPrepareVisibility;
        }
    }

    return menus;
}

document.observe("dom:loaded", initMailer);

function Mailbox(type, name, unseen, displayName) {
    this.type = type;
    if (displayName)
      this.displayName = displayName;
    else
      this.displayName = name;
    // log("name: " + name + "; dn: " + displayName);
    this.name = name.asCSSIdentifier();
    this.unseen = unseen;
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

        var searchName = name.asCSSIdentifier();

        var i = 0;
        while (!mailbox && i < this.children.length)
            if (this.children[i].name == searchName
                || this.children[i].displayName == name)
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

function configureDraggables() {
    var table = jQuery("#messageListBody");
    table.draggable({
        addClasses: false,
        helper: function (event) { return '<div id="dragDropVisual"></div>'; },
        start: startDragging,
        drag: whileDragging,
        stop: stopDragging,
        appendTo: 'body',
        cursorAt: { top: 15, right: 15 },
        scroll: false,
        distance: 4,
        zIndex: 20
    });
}

function configureDroppables() {
    jQuery('#mailboxTree .dTreeNode[datatype!="account"][datatype!="additional"] .node .nodeName').droppable({
        hoverClass: 'genericHoverClass',
              drop: dropAction });
}

function startDragging(event, ui) {
    var handle = ui.helper;
    var count = $('messageListBody').getSelectedRowsId().length;

    if (count == 0) {
        jQuery(this).trigger("stop");
        return false;
    }
    handle.html(count);

    if (event.shiftKey) {
        handle.addClass("copy");
    }
    handle.show();
}

function whileDragging(event, ui) {
    if (event) {
        var handle = ui.helper;
        if (event.shiftKey)
            handle.addClass("copy");
        else if (handle.hasClass("copy"))
            handle.removeClass("copy");
    }
}

function stopDragging(event, ui) {
    var handle = ui.helper;
    handle.hide();
    if (handle.hasClass("copy"))
        handle.removeClass("copy");
    for (var i = 0; i < accounts.length; i++) {
        handle.removeClass("account" + i);
    }
}

function dropAction(event, ui) {
    var destination = $(this).up("div.dTreeNode");

    var sourceAct = Mailer.currentMailbox.split("/")[1];
    var destAct = destination.getAttribute("dataname").split("/")[1];
    if (sourceAct == destAct) {
        var f;
        if (ui.helper.hasClass("copy")) {
            // Message(s) copied
            f = onMailboxMenuCopy.bind(destination);
        }
        else {
            // Message(s) moved
            f = onMailboxMenuMove.bind(destination);
        }

        f();
    }
}
