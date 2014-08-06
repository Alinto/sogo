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
                    if (filter.searchArgument == "contains")
                        filter.searchArgument = "doesContain";
                    else
                        filter.searchArgument = "NOT doesContain";
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
        $("searchButton").down().innerText = _("Search");
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
        var folderName = accountNumber + "/folder" + searchLocation[1];
        for (i = 2; i < position; i++)
            folderName += accountNumber + "/folder" + searchLocation[i];
        
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
                cell1.innerHTML = response.headers[i][3];
                
                var cell2 = row.insertCell(1);
                cell2.innerHTML = response.headers[i][4];
                
                var cell3 = row.insertCell(2);
                cell3.innerHTML = response.headers[i][7];
                
                var cell4 = row.insertCell(3);
                cell4.innerHTML = response.headers[i][12];
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
            $("searchButton").down().innerText = _("Search");
        }
 
    }
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
    var element4 = document.createElement("a");
    var element5 = document.createElement("a");
    var buttonsDiv = document.createElement("div");
    var spanAddFilter = document.createElement("span");
    var imageAddFilter = document.createElement("img");
    var spanRemoveFilter = document.createElement("span");
    var imageRemoveFilter = document.createElement("img");
    Element.addClassName(element4, "addFilterButton");
    Element.addClassName(buttonsDiv, "bottomToolbar");
    element4.writeAttribute("name", "addFilter");
    element4.writeAttribute("id", "addFilterButtonRow" + rowCount);
    element4.writeAttribute("onclick", "onAddFilter(this)");
    imageAddFilter.writeAttribute("src", "/SOGo.woa/WebServerResources/add-icon.png");
    spanAddFilter.appendChild(imageAddFilter);
    element4.appendChild(spanAddFilter);
    buttonsDiv.appendChild(element4);
    
    Element.addClassName(element5, "removeFilterButton");
    element5.writeAttribute("name", "removeFilter");
    element5.writeAttribute("id", "removeFilterButtonRow" + rowCount);
    element5.writeAttribute("onclick", "onRemoveFilter(this)");
    imageRemoveFilter.writeAttribute("src", "/SOGo.woa/WebServerResources/remove-icon.png");
    spanRemoveFilter.appendChild(imageRemoveFilter);
    element5.appendChild(spanRemoveFilter);
    buttonsDiv.appendChild(element5);
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
    console.debug("deleteButton");
}

function onResizeClick() {
    var resizeAttrribute = $("resizeButton").getAttribute("name");
    if (resizeAttrribute == "resizeUp") {
        $("searchFiltersList").style.display = "none";
        $("searchMailFooter").style.height = "300px";
        $("resultsTable").style.height = "265px";
        $("resizeUp").style.display = "none";
        $("resizeDown").style.display = "block";
        $("resizeButton").writeAttribute("name", "resizeDown");
    }
    else {
        $("searchFiltersList").style.display = "block";
        $("searchMailFooter").style.height = "141px";
        $("resultsTable").style.height = "106px";
        $("resizeUp").style.display = "block";
        $("resizeDown").style.display = "none";
        $("resizeButton").writeAttribute("name", "resizeUp");
    }
    
}

/*************** Init ********************/

function initSearchMailView () {
    
    // Add one filterRow
    onAddFilter();
    
    // Observers : Event.on(element, eventName[, selector], callback)
    $("searchMailFooter").down("tbody").on("mousedown", "tr", onResultSelectionChange);
    $("searchMailFooter").down("tbody").on("dblclick", "tr", onOpenClick);
    
    
}