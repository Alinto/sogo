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
    var searchButton = $("searchButton").down().innerText;
    var mailAccountsList = $("mailAccountsList").options;
    
    if (searchButton == _("Search")) {
        searchParams.filters = [];
        stopOngoingSearch = false;
        
        // Get the mailboxe(s)
        for (i = 0; i < mailAccountsList.length ; i++) {
            if (mailAccountsList[i].selected) {
                searchParams.searchLocation = mailAccountsList[i].innerText;
                break;
            }
        }

        for (i = 0; i < filterRows.length; i++){
            // Get the information from every filter row before triggering the AJAX call
            var filter = {};
            var searchByOptions = filterRows[i].down(".searchByList").options;
            var searchArgumentsOptions = filterRows[i].down(".searchArgumentsList").options;
            var searchInput = filterRows[i].down(".searchInput");
            
            // Get the searchBy
            for (j = 0; j < searchByOptions.length ; j++) {
                if (searchByOptions[j].selected) {
                    filter.searchBy = searchByOptions[j].innerText;
                    break;
                }
            }
            
            // Get the searchArgument
            for (j = 0; j < searchArgumentsOptions.length ; j++) {
                if (searchArgumentsOptions[j].selected) {
                    filter.searchArgument = searchArgumentsOptions[j].innerText;
                    filter.negative = false;
                    if (filter.searchArgument == "contains") {
                        filter.searchArgument = "doesContain";
                    }
                    else if (filter.searchArgument == "does not contain") {
                        filter.searchArgument = "doesContain";
                        filter.negative = true;
                    }
                    break;
                }
            }
            
            // Get the input text
            filter.searchInput = searchInput.getValue();
            
            // Add the filter inside the searchParams.filters if the input is not empty
            if (!filter.searchInput.empty())
                searchParams.filters.push(filter);
        }
        // Send the request only if there is at least one filter
        if (searchParams.filters.length > 0) {
            $("searchButton").down().innerText = _("Stop");
            searchMails();
        }
        // TODO - give the user a warning or a notice that it needs at least one filter
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
  
    var mailAccountIndex = mailAccounts.indexOf(searchParams.searchLocation);
    if (mailAccountIndex != -1) {
        var accountNumber = "/" + mailAccountIndex;
        var folderName = accountNumber + "/folderINBOX";
        var accountUser = userNames[mailAccountIndex];
        var folderPath = accountUser;
    }
    else {
        var searchLocation = searchParams.searchLocation.split("/");
        var accountUser = searchLocation[0];
        var accountNumber = "/" + userNames.indexOf(accountUser);
      
        var position = searchLocation.length;
        var folderName = accountNumber + "/folder" + searchLocation[1].replace(" ", "_SP_");
        for (i = 2; i < position; i++)
            folderName += "/folder" + searchLocation[i];
        
        var folderPath = optionsList[selectedIndex].innerText;
      
    }
    
    var subfolders = [];
    if (searchParams.subfolder == true) {
        for (i = 0; i < nbOptions; i++) {
            if ((optionsList[i].innerText.search(folderPath) != -1) && (i != selectedIndex)) {
                var splitArray = optionsList[i].innerText.split("/");
                // Remove the user information since it is not required
                splitArray.splice(0, 1);
                var subfolder = [];
                var level = splitArray.length;
                for(j = 0; j < level; j++) {
                    subfolder += "/folder" + splitArray[j];
                }
                subfolders.push(accountNumber + subfolder);
            }
        }
    }
    
    var urlstr = (ApplicationBaseURL + folderName + "/uids");
    
    var callbackData = {"folderName" : folderName, "subfolders" : subfolders, "newSearch" : true};
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
            for (x = count; x >= 0; x--)
                oldEntries[x].remove();
        }
        
        // ["To", "Attachment", "Flagged", "Subject", "From", "Unread", "Priority", "Date", "Size", "rowClasses", "labels", "rowID", "uid"]
        if (response.headers.length > 1) {
            if ($("noSearchResults"))
                $("noSearchResults").remove();
          
            for (i = 1; i < response.headers.length; i++) { // Starts at 1 because the position 0 in the array are the headers of the table
                var row = table.insertRow(i - 1);           // This is the reason why row inserting starts at i - 1
                Element.addClassName(row, "resultsRow");
                row.writeAttribute("uid", response.headers[i][12]);
                row.writeAttribute("folderName", http.callbackData.folderName);
                
                var cell1 = row.insertCell(0);
                Element.addClassName(cell1, "td_table_1");
                cell1.innerHTML = response.headers[i][3];
                
                var cell2 = row.insertCell(1);
                Element.addClassName(cell2, "td_table_2");
                cell2.innerHTML = response.headers[i][4];
                
                var cell3 = row.insertCell(2);
                Element.addClassName(cell3, "td_table_3");
                cell3.innerHTML = response.headers[i][0];
                
                var cell4 = row.insertCell(3);
                Element.addClassName(cell4, "td_table_4");
                cell4.innerHTML = response.headers[i][7];
            }

        }
        else if (http.callbackData.newSearch) {
            if (!table.down("tr")) {
                var row = table.insertRow(0);
                var cell = row.insertCell(0);
                var element = document.createElement("span");
              
                cell.writeAttribute("id", "noSearchResults");
                cell.writeAttribute("colspan", "4");
                element.innerText = _("No matches found");
                cell.appendChild(element);
            }
        }
        
        if (http.callbackData.subfolders.length > 0) {
            var folderName = http.callbackData.subfolders[0];
            var subfolders = http.callbackData.subfolders;
            subfolders.splice(0, 1);
        
            var urlstr = (ApplicationBaseURL + folderName + "/uids");
            var callbackData = {"folderName" : folderName, "subfolders" : subfolders, "newSearch" : false};
          
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
    $("searchButton").down().innerText = _("Search");
    var nbResults = $$(".resultsRow").length;
    if (nbResults == 1)
        $("resultsFound").innerHTML = nbResults + " " + _("result found");
    else if (nbResults > 0)
        $("resultsFound").innerHTML = nbResults + " " + _("results found");
    else
        $("resultsFound").innerHTML = "";
    
    TableKit.reloadTable($("searchMailFooter"));
}

function onCancelClick() {
    disposeDialog();
    $("searchMailView").remove();
}

function onSearchSubfoldersCheck(event) {
    searchParams.subfolder = (event.checked ? true : false);
}

function onMatchFilters(event) {
    searchParams.filterMatching = ((event.getAttribute("id") == "matchAllFilters") ? "AND" : "OR");
}

/**** Search mail body ****/

function onAddFilter() {
    var table = $("searchFiltersList").down("tbody");
    var searchByList = $("searchByList").getElementsByTagName("li");
    var stringArgumentsList = $("stringArgumentsList").getElementsByTagName("li");
    
    var rowCount = table.rows.length;
    var row = table.insertRow(rowCount);
    Element.addClassName(row, "filterRow");
    
    var cell1 = row.insertCell(0);
    var element1 = document.createElement("select");
    Element.addClassName(element1, "searchByList");
    element1.writeAttribute("id", "searchByListRow" + rowCount);
    for (i = 0; i < searchByList.length; i++) {
        var option = document.createElement("option");
        option.writeAttribute("value", i);
        option.innerHTML = searchByList[i].innerText;
        element1.appendChild(option);
    }
    cell1.appendChild(element1);
    
    var cell2 = row.insertCell(1);
    var element2 = document.createElement("select");
    Element.addClassName(element2, "searchArgumentsList");
    element2.writeAttribute("id", "searchArgumentsListRow" + rowCount);
    for (i = 0; i < stringArgumentsList.length; i++) {
        var option = document.createElement("option");
        option.writeAttribute("value", i);
        option.innerHTML = stringArgumentsList[i].innerText;
        element2.appendChild(option);
    }
    cell2.appendChild(element2);
    
    var cell3 = row.insertCell(2);
    Element.addClassName(cell3, "inputsCell");
    var element3 = document.createElement("input");
    Element.addClassName(element3, "searchInput");
    element3.writeAttribute("type", "text");
    element3.writeAttribute("name", "searchInput");
    element3.writeAttribute("value", "");
    element3.writeAttribute("id", "searchInputRow" + rowCount);
    cell3.appendChild(element3);
    
    var cell4 = row.insertCell(3);
    Element.addClassName(cell4, "buttonsCell");
    
    var buttonsDiv = document.createElement("div");
    var imageAddFilter = document.createElement("img");
    var imageRemoveFilter = document.createElement("img");
    imageAddFilter.writeAttribute("src", "/SOGo.woa/WebServerResources/add-icon.png");
    imageRemoveFilter.writeAttribute("src", "/SOGo.woa/WebServerResources/remove-icon.png");
    Element.addClassName(imageAddFilter, "addFilterButton");
    Element.addClassName(imageAddFilter, "glow");
    Element.addClassName(imageRemoveFilter, "removeFilterButton");
    Element.addClassName(imageRemoveFilter, "glow");
    imageAddFilter.writeAttribute("name", "addFilter");
    imageAddFilter.writeAttribute("id", "addFilterButtonRow" + rowCount);
    imageAddFilter.writeAttribute("onclick", "onAddFilter(this)");
    imageRemoveFilter.writeAttribute("name", "removeFilter");
    imageRemoveFilter.writeAttribute("id", "removeFilterButtonRow" + rowCount);
    imageRemoveFilter.writeAttribute("onclick", "onRemoveFilter(this)");
    buttonsDiv.writeAttribute("id", "filterButtons");
    
    buttonsDiv.appendChild(imageAddFilter);
    buttonsDiv.appendChild(imageRemoveFilter);
    
    cell4.appendChild(buttonsDiv);

}

function onRemoveFilter(event) {
    var rows = $("searchFiltersList").down("tbody").getElementsByTagName("tr");
    var currentRow = event.up(".filterRow");
    
    if(rows.length > 1)
        currentRow.remove();
}

/**** Search mail Footer ****/

function onResultSelectionChange(event) {
    var table = $("searchMailFooter").down("tbody");
    
    if (event && (event.target.innerText != _("No matches found"))) {
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
    var folderName = selectedRow.getAttribute("folderName");
  
    var url = "/SOGo/so/sogo1/Mail" + folderName + "/" + msguid + "/popupview";
    if (selectedRow) {
        openMessageWindow(msguid, url);
    }
}

function onDeleteClick(event) {
    var messageList = $("resultsTable");
    var row = messageList.getSelectedRows()[0];
    if (row) {
        var rowIds = messageList.getSelectedRows()[0].getAttribute("uid");
        var uids = new Array(); // message IDs
        var paths = new Array(); // row IDs
        var unseenCount = 0;
        var refreshFolder = false;
        
        if (rowIds && rowIds.length > 0) {
            messageList.deselectAll();
            if (unseenCount < 1) {
                row.remove();
                if (row.hasClassName("mailer_unreadmail"))
                    unseenCount--;
                else
                    unseenCount = 1;
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
    var searchMailFooter = jQuery("#searchMailFooter");
    var resultsTable = jQuery("#resultsTable");
    var imgPosition = jQuery("#imgPosition");
    var state = 'collapse';
    var img = $("listCollapse").select('img').first();
    
    
    if (searchFiltersList[0].visible()) {
        searchFiltersList.fadeOut(300, function() {
            searchMailFooter.animate({ top:"120px" }, {queue: false, duration: 100});
            resultsTable.animate({height:"288px"}, 100);
            searchMailFooter.animate({height:"312px" }, {queue: false, duration: 100, complete: function() {
                img.removeClassName('collapse').addClassName('rise');
                $("resultsFound").style.bottom = "40px;";
            }});
            imgPosition.animate({ top:"113px" }, {duration: 100});
        });
    }
    else {
        state = 'rise';
        searchMailFooter.animate({height:"194px"}, {queue: false, duration: 100});
        searchMailFooter.animate({top:"240px" }, {queue: false, duration: 100, complete:function() {
            searchFiltersList.fadeIn();
            img.removeClassName('rise').addClassName('collapse');
            $("resultsFound").style.bottom = "25px;";
        }});
        imgPosition.animate({ top:"233px" }, {duration: 100});
        resultsTable.animate({height:"171px"}, 100);
        
    }
}

/*************** Init ********************/

function initSearchMailView () {
    
    // Add one filterRow
    onAddFilter();
    
    // Observers : Event.on(element, eventName[, selector], callback)
    $("searchMailFooter").down("tbody").on("mousedown", "tr", onResultSelectionChange);
    $("searchMailFooter").down("tbody").on("dblclick", "tr", onOpenClick);
    TableKit.Sortable.init($("searchMailFooter"), {sortable : true});
}