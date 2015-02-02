/* -*- Mode: js2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var searchParams = {
     searchLocation: "",
     subfolder: true,
     filterMatching: "AND",
     filters: []
};

// This variable allowed the user to stop the ongoing search
var stopOngoingSearch = false;

/************ Search mail header ************/

function onSearchClick() {
// This function updates the searchParams
    var filterRows = $$(".filterRow");
    var searchButton = $("searchButton").down().innerHTML;
    var mailAccountsList = $("mailAccountsList").options;

    if (searchButton == _("Search")) {
        searchParams.filters = [];
        stopOngoingSearch = false;

        // Get the mailboxe(s)
        for (i = 0; i < mailAccountsList.length ; i++) {
            if (mailAccountsList[i].selected) {
                searchParams.searchLocation = mailAccountsList[i].innerHTML;
                break;
            }
        }

        for (i = 0; i < filterRows.length; i++) {
            // Get the information from every filter row before triggering the AJAX call
            var filter = {};
            var searchByOptions = filterRows[i].down(".searchByList").options;
            var searchArgumentsOptions = filterRows[i].down(".searchArgumentsList").options;
            var searchInput = filterRows[i].down(".searchInput");

            // Get the searchBy
            // Options : 0-Subject, 1-From, 2-To, 3-Cc, 4-Body
            filter.searchBy = searchByOptions[searchByOptions.selectedIndex].getAttribute("value");

            // Get the searchArgument
            // Options : 0-contains, 1-doesn't contains; on the IMAP query add the prefix NOT to negate the statement
            filter.negative = ((searchArgumentsOptions == 1) ? true:false);
            filter.searchArgument = "doesContain";

            // Get the input text
            filter.searchInput = searchInput.getValue();

            // Add the filter inside the searchParams.filters if the input is not empty
            if (!filter.searchInput.empty())
                searchParams.filters.push(filter);
        }
        // Send the request only if there is at least one filter
        if (searchParams.filters.length > 0) {
            $("searchButton").down().innerHTML = _("Stop");
            searchMails();
        }
        else
            alert(_("Please specify at least one filter"));
    }
    else {
        stopOngoingSearch = true;
        onSearchEnd();
    }
}

function searchMails() {
    // Variables for the subfolders search
    var optionsList = $("mailAccountsList").options;
    var nbOptions = optionsList.length;
    var selectedIndex = optionsList.selectedIndex;
    var accountNumber, folderPath, folderName;
    var mailAccountIndex = mailAccounts.indexOf(searchParams.searchLocation);
    var root = false;

    if (mailAccountIndex != -1) {
        accountNumber = "/" + mailAccountIndex;
        folderName = "INBOX";
        folderPath = accountNumber + "/folderINBOX";
        root = true;
    }
    else {
        var searchLocation = searchParams.searchLocation.split("/");
        accountNumber = "/" + userNames.indexOf(searchLocation[0]);       
        folderName = optionsList[optionsList.selectedIndex].text.split("/").pop();

        var paths = optionsList[optionsList.selectedIndex].value.split("/");
        folderPath = accountNumber;
        for (j = 1; j < paths.length; j++) {
            folderPath += "/folder" + paths[j];
        }
    }

    var subfolders = [];
    if (searchParams.subfolder === true) {
        for (i = 1; i < nbOptions; i++) {
            var paths = optionsList[i].value.split("/");
            var subfolder = accountNumber;
            for (j = 1; j < paths.length; j++) {
                subfolder += "/folder" + paths[j];
            }

            if (root || subfolder.indexOf(folderPath) == 0) {
                var keypair = {"folderPath" : subfolder,
                               "folderName" : optionsList[i].text.split("/").pop() };
                subfolders.push(keypair);
            }
        }
    }

    var urlstr = (ApplicationBaseURL + folderPath + "/uids");
    var callbackData = {"folderName" : folderName, "folderPath" : folderPath, "subfolders" : subfolders, "newSearch" : true};
    var object = {"filters":searchParams.filters, "sortingAttributes":{"match":searchParams.filterMatching}};
    var content = Object.toJSON(object);
    document.searchMailsAjaxRequest = triggerAjaxRequest(urlstr, searchMailsCallback, callbackData, content, {"content-type": "application/json"});
}

function searchMailsCallback(http) {
    if (http.readyState == 4 && http.status == 200 && !stopOngoingSearch) {
        var response = http.responseText.evalJSON();
        var table = $("searchMailFooter").down("tbody");

        // Erase all previous entries before proceeding with the current request
        if (http.callbackData.newSearch) {
            var oldEntries = table.rows;
            var count = oldEntries.length - 1;
            for (var x = count; x >= 0; x--){
                $(oldEntries[x]).remove();
            }
        }

        // ["To", "Attachment", "Flagged", "Subject", "From", "Unread", "Priority", "Date", "Size", "rowClasses", "labels", "rowID", "uid"]
        if (response.headers.length > 1) {
            if ($("noSearchResults"))
                $("noSearchResults").remove();

            for (var i = 1; i < response.headers.length; i++) { // Starts at 1 because the position 0 in the array are the headers of the table
                var row = document.createElement("tr");
                Element.addClassName(row, "resultsRow");
                row.setAttribute("uid", response.headers[i][12]);
                row.setAttribute("folderPath", http.callbackData.folderPath);

                var cell1 = document.createElement("td");
                Element.addClassName(cell1, "td_table_1");
                cell1.innerHTML = response.headers[i][3];
                row.appendChild(cell1);

                var cell2 = document.createElement("td");
                Element.addClassName(cell2, "td_table_2");
                cell2.innerHTML = response.headers[i][4];
                row.appendChild(cell2);

                var cell3 = document.createElement("td");
                Element.addClassName(cell3, "td_table_3");
                cell3.innerHTML = response.headers[i][0];
                row.appendChild(cell3);

                var cell4 = document.createElement("td");
                Element.addClassName(cell4, "td_table_4");
                cell4.innerHTML = response.headers[i][7];
                row.appendChild(cell4);

                var cell5 = document.createElement("td");
                Element.addClassName(cell5, "td_table_5");
                cell5.setAttribute("colspan", "2");
                cell5.innerHTML = http.callbackData.folderName;
                row.appendChild(cell5);

                table.appendChild(row);
            }

        }
        else if (http.callbackData.newSearch) {
            if (!table.down("tr")) {
                var row = table.insertRow(0);
                var cell = row.insertCell(0);
                var element = document.createElement("span");

                cell.setAttribute("id", "noSearchResults");
                cell.setAttribute("colspan", "4");
                element.innerHTML = _("No matches found");
                cell.appendChild(element);
            }
        }

        if (http.callbackData.subfolders.length > 0) {
            var folderName = http.callbackData.subfolders[0].folderName;
            var folderPath = http.callbackData.subfolders[0].folderPath;
            var subfolders = http.callbackData.subfolders;
            subfolders.splice(0, 1);

            var urlstr = (ApplicationBaseURL + folderPath + "/uids");
            var callbackData = {"folderName" : folderName, "folderPath" : folderPath, "subfolders" : subfolders, "newSearch" : false};

            // TODO - need to add these following contents ; asc, no-headers, sort
            var object = {"filters":searchParams.filters, "sortingAttributes":{"match":searchParams.filterMatching}};
            var content = Object.toJSON(object);
            document.searchMailsAjaxRequest = triggerAjaxRequest(urlstr, searchMailsCallback, callbackData, content, {"content-type": "application/json"});
        }
        else {
            onSearchEnd();
        }
    }
}

function onSearchEnd() {
    $("searchButton").down().innerHTML = _("Search");
    var nbResults = $$(".resultsRow").length;
    if (nbResults == 1)
        $("resultsFound").innerHTML = nbResults + " " + _("result found");
    else if (nbResults > 0)
        $("resultsFound").innerHTML = nbResults + " " + _("results found");
    else
        $("resultsFound").innerHTML = "";

    TableKit.reloadSortableTable($("searchMailFooter"));
    $("buttonExpandHeader").addClassName("nosort");
}

function onCancelClick() {
    disposeDialog();
    $("searchMailView").remove();
    $("toolbarSearchButton").disabled = false;

}

function onSearchSubfoldersCheck(event) {
    searchParams.subfolder = (event.checked ? true : false);
}

function onMatchFilters(event) {
    searchParams.filterMatching = ((event.getAttribute("id") == "matchAllFilters") ? "AND" : "OR");
}

/**** Search mail body ****/

function onAddFilter() {
    var table = $("searchFiltersList").down("TABLE");
    var searchByList = $("searchByList").getElementsByTagName("li");
    var stringArgumentsList = $("stringArgumentsList").getElementsByTagName("li");

    var rowCount = table.rows.length;
    var row = table.insertRow(rowCount);
    Element.addClassName(row, "filterRow");

    var cell1 = row.insertCell(0);
    var element1 = document.createElement("select");
    Element.addClassName(element1, "searchByList");
    element1.setAttribute("id", "searchByListRow" + rowCount);
    var options = {0:"subject", 1:"from", 2:"to", 3:"cc", 4:"body"};
    for (var i = 0; i < searchByList.length; i++) {
        var option = document.createElement("option");
        option.value = options[i];
        option.innerHTML = searchByList[i].innerHTML;
        element1.appendChild(option);
    }
    cell1.appendChild(element1);

    var cell2 = row.insertCell(1);
    var element2 = document.createElement("select");
    Element.addClassName(element2, "searchArgumentsList");
    element2.setAttribute("id", "searchArgumentsListRow" + rowCount);
    for (var i = 0; i < stringArgumentsList.length; i++) {
        var option = document.createElement("option");
        option.innerHTML = stringArgumentsList[i].innerHTML;
        element2.appendChild(option);
    }
    cell2.appendChild(element2);

    var cell3 = row.insertCell(2);
    Element.addClassName(cell3, "inputsCell");
    var element3 = document.createElement("input");
    Element.addClassName(element3, "searchInput");
    element3.setAttribute("type", "text");
    element3.setAttribute("name", "searchInput");
    element3.setAttribute("id", "searchInputRow" + rowCount);
    cell3.appendChild(element3);

    var cell4 = row.insertCell(3);
    Element.addClassName(cell4, "buttonsCell");
    cell4.setAttribute("align", "center");

    var buttonsDiv = document.createElement("div");
    var imageAddFilter = document.createElement("img");
    var imageRemoveFilter = document.createElement("img");
    imageAddFilter.setAttribute("src", "/SOGo.woa/WebServerResources/add-icon.png");
    imageRemoveFilter.setAttribute("src", "/SOGo.woa/WebServerResources/remove-icon.png");
    Element.addClassName(imageAddFilter, "glow");
    Element.addClassName(imageRemoveFilter, "glow");
    imageAddFilter.setAttribute("name", "addFilter");
    imageAddFilter.setAttribute("id", "addFilterButtonRow" + rowCount);
    $(imageAddFilter).on("click", onAddFilter);
    imageRemoveFilter.setAttribute("name", "removeFilter");
    imageRemoveFilter.setAttribute("id", "removeFilterButtonRow" + rowCount);
    $(imageRemoveFilter).on("click", onRemoveFilter);
    Element.addClassName(buttonsDiv, "filterButtons");

    buttonsDiv.appendChild(imageAddFilter);
    buttonsDiv.appendChild(imageRemoveFilter);

    cell4.appendChild(buttonsDiv);
}

function onRemoveFilter() {
    var rows = $("searchFiltersList").getElementsByTagName("tr");
    var currentRow = this.up(".filterRow");

    if(rows.length > 1)
        $(currentRow).remove();
}

/**** Search mail Footer ****/

function onResultSelectionChange(event) {
    var table = $("searchMailFooter").down("tbody");

    if (event && (event.target.innerHTML != _("No matches found"))) {
        var node = getTarget(event);

        if (node.tagName == "SPAN")
            node = node.parentNode;

        // Update rows selection
        onRowClick(event, node);
    }
}

/**** Search mail optionsButtons ****/

function onOpenClick(event) {
// This function is linked with the openButton and the doubleClick on a message
    var selectedRow = $("searchMailFooter").down("._selected");
    var msguid = selectedRow.getAttribute("uid");
    var folderPath = selectedRow.getAttribute("folderPath");
    var accountUser = userNames[0];

    var url = "/SOGo/so/" + accountUser + "/Mail" + folderPath + "/" + msguid + "/popupview";
    if (selectedRow) {
        openMessageWindow(msguid, url);
    }
}

function onDeleteClick(event) {
    var messageList = $("resultsTable").down("TABLE");
    var row = $(messageList).getSelectedRows()[0];
    if (row) {
        var rowIds = row.getAttribute("uid");
        var uids = new Array(); // message IDs
        var paths = new Array(); // row IDs
        var unseenCount = 0;
        var refreshFolder = false;
        if (rowIds) {
            messageList.deselectAll();
            if (unseenCount < 1) {
                if (row.hasClassName("mailer_unreadmail"))
                    unseenCount--;
                else
                    unseenCount = 1;

                $(row).remove();
            }
            var uid = rowIds;
            var path = Mailer.currentMailbox + "/" + uid;
            uids.push(uid);
            paths.push(path);
            deleteMessageRequestCount++;

            deleteCachedMessage(path);
            if (Mailer.currentMessages[Mailer.currentMailbox] == uid) {
                if (messageContent) messageContent.innerHTML = '';
                Mailer.currentMessages[Mailer.currentMailbox] = null;
            }
            Mailer.dataTable.remove(uid);
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
            triggerAjaxRequest(url, deleteMessageCallback, data, parameters,
                               { "Content-type": "application/x-www-form-urlencoded" });
        }
    }
    return false;

}

function deleteMessageCallback (http){
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
     onSearchEnd();
}

function onResizeClick() {
    var searchFiltersList = jQuery("#searchFiltersList");
    var img = $("listCollapse").select('img').first();
    var dialogWindowHeight = $("searchMailView").getHeight();
    var state = "collapse";

    if (searchFiltersList[0].visible()) {
        state = "rise";
        searchFiltersList.fadeOut(300, function() {
            adjustResultsTable(state);
            img.removeClassName('collapse').addClassName('rise');
        });
    }
    else {
        adjustResultsTable(state);
        searchFiltersList.fadeIn();
        img.removeClassName('rise').addClassName('collapse');
    }
}

function adjustResultsTable(state) {
    var resultsTable = $("resultsTable");
    var height = "innerHeight" in $("searchMailView") ? $("searchMailView").innerHeight : $("searchMailView").offsetHeight;
    if (state == "collapse") {
        height -= 266;
    }
    else
        height -= 152;
    $(resultsTable).style.height = height + "px";
}

/*************** Init ********************/

function initSearchMailView () {

    // Add one filterRow
    onAddFilter();
    adjustResultsTable("collapse");

    // Observers : Event.on(element, eventName[, selector], callback)
    $("searchMailFooter").down("tbody").on("mousedown", "tr", onResultSelectionChange);
    $("searchMailFooter").down("tbody").on("dblclick", "tr", onOpenClick);
    Event.observe(window, "resize", function() {
                  var state = ($("searchFiltersList").visible() ? "collapse": "rise");
                  adjustResultsTable(state);
                  });
}
