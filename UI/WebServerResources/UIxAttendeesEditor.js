/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var OwnerLogin = "";

var resultsDiv;
var address;
var additionalDays = 2;

var isAllDay = parent$("isAllDay").checked + 0;
var displayStartHour = 0;
var displayEndHour = 23;

var attendeesEditor = {
    delay: 500,
    selectedIndex: -1
};

function handleAllDay () {
    window.timeWidgets['end']['hour'].value = 17;
    window.timeWidgets['end']['minute'].value = 0;
    window.timeWidgets['start']['hour'].value = 9;
    window.timeWidgets['start']['minute'].value = 0;

    $("startTime_time_hour").disabled = true;
    $("startTime_time_minute").disabled = true;
    $("endTime_time_hour").disabled = true;
    $("endTime_time_minute").disabled = true;
}

/* address completion */

function resolveListAttendees(input, append) {
    var urlstr = (UserFolderURL
                  + "Contacts/"
                  + escape(input.container) + "/"
                  + escape(input.cname) + "/properties");
    triggerAjaxRequest(urlstr, resolveListAttendeesCallback,
                       { "input": input, "append": append });
}

function resolveListAttendeesCallback(http) {
    if (http.readyState == 4 && http.status == 200) {
        var input = http.callbackData["input"];
        var append = http.callbackData["append"];
        var contacts = http.responseText.evalJSON(true);
        for (var i = 0; i < contacts.length; i++) {
            var contact = contacts[i];
            var fullName = contact[1];
            if (fullName && fullName.length > 0) {
                fullName += " <" + contact[2] + ">";
            }
            else {
                fullName = contact[2];
            }
            input.uid = null;
            input.cname = null;
            input.container = null;
            input.isList = false;
            input.value = contact[2];
            input.confirmedValue = null;
            input.hasfreebusy = false;
            input.modified = true;
            // input.focussed = true;
            // input.activate();
            input.checkAfterLookup = true;
            performSearch(input);
            if (i < (contacts.length - 1)) {
                var nextRow = newAttendee(input.parentNode.parentNode);
                input = nextRow.down("input");
            } else if (append) {
                var row = input.parentNode.parentNode;
                var tBody = row.parentNode;
                if (row.rowIndex == (tBody.rows.length - 3)) {
                    if (input.selectText) {
                        input.selectText(0, 0);
                    } else if (input.createTextRange) {
                        input.createTextRange().moveStart();
                    }
                    newAttendee();
                } else {
                    var nextRow = tBody.rows[row.rowIndex + 1];
                    var input = nextRow.down("input");
                    input.selectText(0, input.value.length);
                    input.focussed = true;
                }
            } else {
                if (input.selectText) {
                    input.selectText(0, 0);
                } else if (input.createTextRange) {
                    input.createTextRange().moveStart();
                }
                input.blur();
            }
        }
    }
}

function onContactKeydown(event) {
    if (event.ctrlKey || event.metaKey) {
        this.focussed = true;
        return;
    }
    if (event.keyCode == 9 || event.keyCode == 13) { // Tab
        preventDefault(event);
        if (this.confirmedValue)
            this.value = this.confirmedValue;
        this.hasfreebusy = false;
        var row = $(this).up("tr").next();
        if (this.isList) {
            resolveListAttendees(this, true);
            event.stop();
        } else {
            checkAttendee(this);
            // this.blur(); // triggers checkAttendee function call
            var input = row.down("input");
            if (input) {
                input.focussed = true;
                input.activate();
            }
            else
                newAttendee();
        }
    }
    else if (event.keyCode == 0
             || event.keyCode == 8 // Backspace
             || event.keyCode == 32  // Space
             || event.keyCode > 47) {
        this.modified = true;
        this.confirmedValue = null;
        this.cname = null;
        this.uid = null;
        this.container = null;
        this.hasfreebusy = false;
        if (this.searchTimeout) {
            window.clearTimeout(this.searchTimeout);
        }
        if (this.value.length > 0) {
            var thisInput = this;
            this.searchTimeout = setTimeout(function()
                                            {performSearch(thisInput);
                                             thisInput = null;},
                                            attendeesEditor.delay);
        }
        else if (this.value.length == 0) {
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
        }
    }
    else if ($('attendeesMenu').getStyle('visibility') == 'visible') {
        if (event.keyCode == Event.KEY_UP) { // Up arrow
            if (attendeesEditor.selectedIndex > 0) {
                var attendees = $('attendeesMenu').select("li");
                attendees[attendeesEditor.selectedIndex--].removeClassName("selected");
                var attendee = attendees[attendeesEditor.selectedIndex];
                attendee.addClassName("selected");
                this.value = this.confirmedValue = attendee.address;
                this.uid = attendee.uid;
                this.isList = attendee.isList;
                this.cname = attendee.cname;
                this.container = attendee.container;
            }
        }
        else if (event.keyCode == Event.KEY_DOWN) { // Down arrow
            var attendees = $('attendeesMenu').select("li");
            if (attendees.size() - 1 > attendeesEditor.selectedIndex) {
                if (attendeesEditor.selectedIndex >= 0)
                    attendees[attendeesEditor.selectedIndex].removeClassName("selected");
                attendeesEditor.selectedIndex++;
                var attendee = attendees[attendeesEditor.selectedIndex];
                attendee.addClassName("selected");
                this.value = this.confirmedValue = attendee.address;
                this.isList = attendee.isList;
                this.uid = attendee.uid;
                this.cname = attendee.cname;
                this.container = attendee.container;
            }
        }
    }
}

function performSearch(input) {
    // Perform address completion
    if (input.value.trim().length > 0) {
        var urlstr = (UserFolderURL
                      + "Contacts/allContactSearch?excludeGroups=1&search="
                      + escape(input.value));
        triggerAjaxRequest(urlstr, performSearchCallback, input);
    }
    input.searchTimeout = null;
}

function performSearchCallback(http) {
    if (http.readyState == 4) {
        var menu = $('attendeesMenu');
        var list = menu.down("ul");
    
        var input = http.callbackData;

        if (http.status == 200) {
            var start = input.value.length;
            var data = http.responseText.evalJSON(true);

            if (data.contacts.length > 1) {
                list.input = input;
                $(list.childNodesWithTag("li")).each(function(item) {
                        item.remove();
                    });
	
                // Populate popup menu
                for (var i = 0; i < data.contacts.length; i++) {
                    var contact = data.contacts[i];
                    var isList = (contact["c_component"] &&
                                  contact["c_component"] == "vlist");
                    var completeEmail = contact["c_cn"].trim();
                    if (!isList) {
                        if (completeEmail)
                            completeEmail += " <" + contact["c_mail"] + ">";
                        else
                            completeEmail = contact["c_mail"];
                    }
                    var node = createElement('li');
                    list.appendChild(node);
                    node.address = completeEmail;
                    log("node.address: " + node.address);
                    node.uid = contact["c_uid"];
                    node.isList = isList;
                    if (isList) {
                        node.cname = contact["c_name"];
                        node.container = contact["container"];
                    }
                    var matchPosition = completeEmail.toLowerCase().indexOf(data.searchText.toLowerCase());
                    var matchBefore = completeEmail.substring(0, matchPosition);
                    var matchText = completeEmail.substring(matchPosition, matchPosition + data.searchText.length);
                    var matchAfter = completeEmail.substring(matchPosition + data.searchText.length);
                    node.appendChild(document.createTextNode(matchBefore));
                    node.appendChild(new Element('strong').update(matchText));
                    node.appendChild(document.createTextNode(matchAfter));
                    if (contact["contactInfo"])
                        node.appendChild(document.createTextNode(" (" +
                                                                 contact["contactInfo"] + ")"));
                    node.observe("mousedown",
                                 onAttendeeResultClick.bindAsEventListener(node));
                }

                // Show popup menu
                var offsetScroll = Element.cumulativeScrollOffset(input);
                var offset = Element.cumulativeOffset(input);
                var top = offset[1] - offsetScroll[1] + node.offsetHeight + 3;
                var height = 'auto';
                var heightDiff = window.height() - offset[1];
                var nodeHeight = node.getHeight();

                if ((data.contacts.length * nodeHeight) > heightDiff)
                    // Limit the size of the popup to the window height, minus 12 pixels
                    height = parseInt(heightDiff/nodeHeight) * nodeHeight - 12 + 'px';

                menu.setStyle({ top: top + "px",
                            left: offset[0] + "px",
                            height: height,
                            visibility: "visible" });
                menu.scrollTop = 0;

                document.currentPopupMenu = menu;
                $(document.body).observe("click", onBodyClickMenuHandler);
            }
            else {
                if (document.currentPopupMenu)
                    hideMenu(document.currentPopupMenu);

                if (data.contacts.length == 1) {
                    // Single result
                    var contact = data.contacts[0];
                    input.uid = contact["c_uid"];
                    var row = $(input.parentNode.parentNode);
                    if (input.uid == OwnerLogin) {
                        row.removeAttribute("role");
                        row.setAttribute("partstat", "accepted");
                        row.addClassName("organizer-row");
                        row.removeClassName("attendee-row");
                        row.isOrganizer = true;
                    } else {
                        row.removeAttribute("partstat");
                        row.setAttribute("role", "req-participant");
                        row.addClassName("attendee-row");
                        row.removeClassName("organizer-row");
                        row.isOrganizer = false;
                    }
                    var isList = (contact["c_component"] &&
                                  contact["c_component"] == "vlist");
                    if (isList) {
                        input.cname = contact["c_name"];
                        input.container = contact["container"];
                    }
                    var completeEmail = contact["c_cn"].trim();
                    if (!isList) {
                        if (completeEmail)
                            completeEmail += " <" + contact["c_mail"] + ">";
                        else
                            completeEmail = contact["c_mail"];
                    }
                    if ((input.value == contact["c_mail"])
                        || (contact["c_cn"].substring(0, input.value.length).toUpperCase()
                            == input.value.toUpperCase())) {
                        input.value = completeEmail;
                    }
                    else
                        // The result matches email address, not user name
                        input.value += ' >> ' + completeEmail;
                    input.isList = isList;
                    input.confirmedValue = completeEmail;
                    var end = input.value.length;
                    $(input).selectText(start, end);

                    attendeesEditor.selectedIndex = -1;

                    if (input.checkAfterLookup) {
                        input.checkAfterLookup = false;
                        input.modified = true;
                        input.hasfreebusy = false;
                        checkAttendee(input);
                    }
                }
            }
        }
        else
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
    }
}

function onAttendeeResultClick(event) {
    var input = this.parentNode.input;
    input.uid = this.uid;
    input.cname = this.cname;
    input.container = this.container;
    input.isList = this.isList;
    input.confirmedValue = input.value = this.address;
    checkAttendee(input);
    this.parentNode.input = null;
}

function resetFreeBusyZone() {
    var table = $("freeBusyHeader");
    var row = table.rows[2];
    for (var i = 0; i < row.cells.length; i++) {
        var nodes = $(row.cells[i]).childNodesWithTag("span");
        for (var j = 0; j < nodes.length; j++)
            nodes[j].removeClassName("busy");
    }
}

function redisplayFreeBusyZone() {
    var table = $("freeBusyHeader");
    var row = table.rows[2];
    var stDay = $("startTime_date").valueAsDate();
    var etDay = $("endTime_date").valueAsDate();

    var days = stDay.daysUpTo(etDay);
    var addDays = days.length - 1;
    var stHour = parseInt($("startTime_time_hour").value);
    var stMinute = parseInt($("startTime_time_minute").value) / 15;
    var etHour = parseInt($("endTime_time_hour").value);
    var etMinute = parseInt($("endTime_time_minute").value) / 15;

    if (stHour < displayStartHour) {
        stHour = displayStartHour;
        stMinute = 0;
    }
    if (stHour > displayEndHour + 1) {
        stHour = displayEndHour + 1;
        stMinute = 0;
    }
    if (etHour < displayStartHour) {
        etHour = displayStartHour;
        etMinute = 0;
    }
    if (etHour > displayEndHour + 1) {
        etHour = displayEndHour;
        etMinute = 0;
    }

    var deltaCells = (etHour - stHour) + ((displayEndHour - displayStartHour + 1) * addDays);
    var deltaSpans = (deltaCells * 4 ) + (etMinute - stMinute);
    var currentCellNbr = stHour - displayStartHour;
    var currentCell = row.cells[currentCellNbr];
    var currentSpanNbr = stMinute;
    var spans = $(currentCell).childNodesWithTag("span");
    resetFreeBusyZone();
    while (deltaSpans > 0) {
        var currentSpan = spans[currentSpanNbr];
        currentSpan.addClassName("busy");
        currentSpanNbr++;
        if (currentSpanNbr > 3) {
            currentSpanNbr = 0;
            currentCellNbr++;
            currentCell = row.cells[currentCellNbr];
            spans = $(currentCell).childNodesWithTag("span");
        }
        deltaSpans--;
    }
    scrollToEvent();
}

function onAttendeeStatusClick(event) {
    rotateAttendeeStatus(this);
}

function rotateAttendeeStatus(row) {
    var values;
    var attributeName;
    if (row.isOrganizer) {
        values = [ "accepted", "declined", "tentative", "needs-action" ];
        attributeName = "partstat";
    } else {
        values = [ "req-participant", "opt-participant",
                   "chair", "non-participant" ];
        attributeName = "role";
    }
    var value = row.getAttribute(attributeName);
    var idx = (value ? values.indexOf(value) : -1);
    if (idx == -1 || idx > (values.length - 2)) {
        idx = 0;
    } else {
        idx++;
    }
    row.setAttribute(attributeName, values[idx]);
    if (Prototype.Browser.IE) {
        /* This hack enables a refresh of the row element right after the
           click. Otherwise, this occurs only when leaving the element with
           them mouse cursor. */
        row.className = row.className;
    }
}

function onNewAttendeeClick(event) {
    newAttendee();
    event.stop();
}

function newAttendee(previousAttendee) {
    var table = $("freeBusyAttendees");
    var tbody = table.tBodies[0];
    var model = tbody.rows[tbody.rows.length - 1];
    var nextRowIndex = tbody.rows.length - 2;
    if (previousAttendee) {
        nextRowIndex = previousAttendee.rowIndex + 1;
    }
    var nextRow = tbody.rows[nextRowIndex];
    var newRow = $(model.cloneNode(true));
    tbody.insertBefore(newRow, nextRow);
    var result = newRow;

    var statusTD = newRow.down(".attendeeStatus");
    if (statusTD) {
        var boundOnStatusClick = onAttendeeStatusClick.bindAsEventListener(newRow);
        statusTD.observe("click", boundOnStatusClick, false);
    }

    $(newRow).removeClassName("attendeeModel");
 
    var input = newRow.down("input");
    input.observe("keydown", onContactKeydown.bindAsEventListener(input));
    input.observe("blur", onInputBlur);

    input.focussed = true;
    input.activate();

    table = $("freeBusyData");
    tbody = table.tBodies[0];
    model = tbody.rows[tbody.rows.length - 1];
    nextRow = tbody.rows[nextRowIndex];
    newRow = $(model.cloneNode(true));
    tbody.insertBefore(newRow, nextRow);
    newRow.removeClassName("dataModel");

    var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
   
    dataDiv.scrollTop = attendeesDiv.scrollTop;

    return result;
}

function checkAttendee(input) {
    var row = $(input.parentNode.parentNode);
    var tbody = row.parentNode;
    if (tbody && input.value.trim().length == 0) {
        var dataTable = $("freeBusyData").tBodies[0];
        var dataRow = dataTable.rows[row.sectionRowIndex];
        tbody.removeChild(row);
        dataTable.removeChild(dataRow);
   } 
    else if (input.modified) {
        if (!row.hasClassName("needs-action")) {
            row.addClassName("needs-action");
            row.removeClassName("declined");
            row.removeClassName("accepted");
        }
        if (!input.hasfreebusy) {
            if (input.uid && input.confirmedValue) {
                input.value = input.confirmedValue;
            }
            displayFreeBusyForNode(input);
            input.hasfreebusy = true;
        }
        input.modified = false;
    }
}

function onInputBlur(event) {
    if (document.currentPopupMenu && !this.confirmedValue) {
        // Hack for IE7; blur event is triggered on input field when
        // selecting a menu item
        var visible = $(document.currentPopupMenu).getStyle('visibility') != 'hidden';
        if (visible) {
            log("XXX we return");
            return;
        }
    }

    if (document.currentPopupMenu)
        hideMenu(document.currentPopupMenu);

    if (this.isList) {
        resolveListAttendees(this, false);
    } else {
        checkAttendee(this);
    }
}

function displayFreeBusyForNode(input) {
    var rowIndex = input.parentNode.parentNode.sectionRowIndex;
    var nodes = $("freeBusyData").tBodies[0].rows[rowIndex].cells;
    log ("displayFreeBusyForNode index " + rowIndex + " (" + nodes.length + " cells)");
    if (input.uid) {
        for (var i = 0; i < nodes.length; i++) {
            var node = $(nodes[i]);
            node.removeClassName("noFreeBusy");
            while (node.firstChild) {
                node.removeChild(node.firstChild);
            }
            for (var j = 0; j < 4; j++) {
                createElement("span", null, "freeBusyZoneElement",
                              null, null, node);
            }
        }
        var sd = $('startTime_date').valueAsShortDateString();
        var ed = $('endTime_date').valueAsShortDateString();
        var urlstr = (UserFolderURL + "../" + input.uid
                      + "/freebusy.ifb/ajaxRead?"
                      + "sday=" + sd + "&eday=" + ed + "&additional=" +
                      additionalDays);
        triggerAjaxRequest(urlstr,
                           updateFreeBusyDataCallback,
                           input);
    } else {
        for (var i = 0; i < nodes.length; i++) {
            var node = $(nodes[i]);
            node.addClassName("noFreeBusy");
            while (node.firstChild) {
                node.removeChild(node.firstChild);
            }
        }
    }
}

function setSlot(tds, nbr, status) {
    var tdnbr = Math.floor(nbr / 4);
    var spannbr = nbr - (tdnbr * 4);
    var days = 0;
    if (tdnbr > 24) {
        days = Math.floor(tdnbr / 24);
        tdnbr -= (days * 24);
    }
    if (tdnbr > (displayStartHour - 1) && tdnbr < (displayEndHour + 1)) {
        var i = (days * (displayEndHour - displayStartHour + 1) + tdnbr - (displayStartHour - 1));
        var td = tds[i - 1];
        var spans = $(td).childNodesWithTag("span");
        if (status == '2')
            $(spans[spannbr]).addClassName("maybe-busy");
        else
            $(spans[spannbr]).addClassName("busy");
    }
}

function updateFreeBusyDataCallback(http) {
    if (http.readyState == 4) {
        if (http.status == 200) {
            var input = http.callbackData;
            var slots = http.responseText.split(",");
            var rowIndex = input.parentNode.parentNode.sectionRowIndex;
            var nodes = $("freeBusyData").tBodies[0].rows[rowIndex].cells;
            // log ("received " + slots.length + " slots for " + rowIndex + " with " + nodes.length + " cells");
            for (var i = 0; i < slots.length; i++) {
                if (slots[i] != '0')
                    setSlot(nodes, i, slots[i]);
            }
        }
    }
}

function resetAllFreeBusys() {
    var table = $("freeBusy");
    var inputs = table.getElementsByTagName("input");

    for (var i = 0; i < inputs.length - 1; i++) {
        var currentInput = inputs[i];
        currentInput.hasfreebusy = false;
        displayFreeBusyForNode(currentInput);
    }
}

function initializeWindowButtons() {
    var okButton = $("okButton");
    var cancelButton = $("cancelButton");
    
    okButton.observe("click", onEditorOkClick, false);
    cancelButton.observe("click", onEditorCancelClick, false);
    
    $("previousSlot").observe ("click", onPreviousSlotClick, false);
    $("nextSlot").observe ("click", onNextSlotClick, false);
}

function findSlot(direction) {
    var userList = UserLogin;
    var table = $("freeBusy");
    var inputs = table.getElementsByTagName("input");
    var sd = window.timeWidgets['start']['date'].valueAsShortDateString();
    var st = window.timeWidgets['start']['hour'].value
        + ":" + window.timeWidgets['start']['minute'].value;
    var ed = window.timeWidgets['end']['date'].valueAsShortDateString();
    var et = window.timeWidgets['end']['hour'].value
        + ":" + window.timeWidgets['end']['minute'].value;

    for (var i = 0; i < inputs.length - 1; i++) {
        if (inputs[i].uid)
            userList += "," + inputs[i].uid;
    }

    // Abort any pending request
    if (document.findSlotAjaxRequest) {
        document.findSlotAjaxRequest.aborted = true;
        document.findSlotAjaxRequest.abort();
    }
    var urlstr = (ApplicationBaseURL
                  + "findPossibleSlot?direction=" + direction
                  + "&uids=" + escape(userList)
                  + "&startDate=" + escape(sd)
                  + "&startTime=" + escape(st)
                  + "&endDate=" + escape(ed)
                  + "&endTime=" + escape(et)
                  + "&isAllDay=" + isAllDay
                  + "&onlyOfficeHours=" + ($("onlyOfficeHours").checked + 0));
    document.findSlotAjaxRequest = triggerAjaxRequest(urlstr,
                                                      updateSlotDisplayCallback,
                                                      userList);
}

function cleanInt(data) {
    var rc = data;
    if (rc.substr (0, 1) == "0")
        rc = rc.substr (1, rc.length - 1);
    return parseInt (rc);
}

function scrollToEvent () {
    var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
  
    var scroll = 0;
    var spans = $$('TR#currentEventPosition TH SPAN');
    for (var i = 0; i < spans.length; i++) {
        scroll += spans[i].getWidth (spans[i]);
        if (spans[i].hasClassName("busy")) {
            scroll -= 20 * spans[i].getWidth (spans[i]);
            break;
        }
    }

    headerDiv.scrollLeft = scroll;
    dataDiv.scrollLeft = headerDiv.scrollLeft;
}

function toggleOfficeHours () {
    var endDate = window.getEndDate();
    var startDate = window.getStartDate();

    if (startDate.getHours () < dayStartHour
        || startDate.getHours () > dayEndHour
        || endDate.getHours () > dayEndHour
        || endDate.getHours () < dayStartHour)
        $("onlyOfficeHours").checked = false;
}

function updateSlotDisplayCallback(http) {
    var data = http.responseText.evalJSON(true);
    var start = new Date();
    var end = new Date();
    var cb = redisplayFreeBusyZone;

    start.setFullYear(parseInt (data[0]['startDate'].substr(0, 4)),
                      parseInt (data[0]['startDate'].substr(4, 2)) - 1,
                      parseInt (data[0]['startDate'].substr(6, 2)));
    end.setFullYear(parseInt (data[0]['endDate'].substr(0, 4)),
                    parseInt (data[0]['endDate'].substr(4, 2)) - 1,
                    parseInt (data[0]['endDate'].substr(6, 2)));
    
    window.timeWidgets['end']['date'].setValueAsDate(end);
    window.timeWidgets['end']['hour'].value = cleanInt(data[0]['endHour']);
    window.timeWidgets['end']['minute'].value = cleanInt(data[0]['endMinute']);

    if (window.timeWidgets['start']['date'].valueAsShortDateString() !=
        data[0]['startDate']) {
        cb = onTimeDateWidgetChange;
    }

    window.timeWidgets['start']['date'].setValueAsDate(start);
    window.timeWidgets['start']['hour'].value = cleanInt(data[0]['startHour']);
    window.timeWidgets['start']['minute'].value = cleanInt(data[0]['startMinute']);
    
    cb();
}

function onPreviousSlotClick(event) {
    findSlot(-1);
    this.blur(); // required by IE
}

function onNextSlotClick(event) {
    findSlot(1);
    this.blur(); // required by IE
}

function onEditorOkClick(event) {
    preventDefault(event);

    var attendees = window.opener.attendees;
    var newAttendees = new Hash();
    var table = $("freeBusy");
    var inputs = table.getElementsByTagName("input");
    for (var i = 0; i < inputs.length - 1; i++) {
        var row = $(inputs[i]).up("tr");
        var name = extractEmailName(inputs[i].value);
        var email = extractEmailAddress(inputs[i].value);
        var uid = "";
        if (inputs[i].uid)
            uid = inputs[i].uid;
        if (!(name && name.length > 0))
            if (uid.length > 0)
                name = uid;
            else
                name = email;
        var attendee = attendees["email"];
        if (!attendee) {
            attendee = {"email": email,
                        "name": name,
                        "role": "req-participant",
                        "partstat": "needs-action",
                        "uid": uid};
        }
        var partstat = row.getAttribute("partstat");
        if (partstat)
            attendee["partstat"] = partstat;
        var role = row.getAttribute("role");
        if (role)
            attendee["role"] = role;
        newAttendees.set(email, attendee);
    }
    window.opener.refreshAttendees(newAttendees.toJSON());

    updateParentDateFields("startTime", "startTime");
    updateParentDateFields("endTime", "endTime");

    window.close();
}

function onEditorCancelClick(event) {
    preventDefault(event);
    window.close();
}

function synchronizeWithParent(srcWidgetName, dstWidgetName) {
    var srcDate = parent$(srcWidgetName + "_date");
    var dstDate = $(dstWidgetName + "_date");
    dstDate.value = srcDate.value;
    dstDate.updateShadowValue(srcDate);

    var srcHour = parent$(srcWidgetName + "_time_hour");
    var dstHour = $(dstWidgetName + "_time_hour");
    dstHour.value = srcHour.value;
    dstHour.updateShadowValue(srcHour);

    var srcMinute = parent$(srcWidgetName + "_time_minute");
    var dstMinute = $(dstWidgetName + "_time_minute");
    dstMinute.value = srcMinute.value;
    dstMinute.updateShadowValue(dstMinute);
}

function updateParentDateFields(srcWidgetName, dstWidgetName) {
    var srcDate = $(srcWidgetName + "_date");
    var dstDate = parent$(dstWidgetName + "_date");
    dstDate.value = srcDate.value;

    var srcHour = $(srcWidgetName + "_time_hour");
    var dstHour = parent$(dstWidgetName + "_time_hour");
    dstHour.value = srcHour.value;

    var srcMinute = $(srcWidgetName + "_time_minute");
    var dstMinute = parent$(dstWidgetName + "_time_minute");
    dstMinute.value = srcMinute.value;
}

function onTimeWidgetChange() {
    redisplayFreeBusyZone();
}

function onTimeDateWidgetChange() {
    var table = $("freeBusyHeader");
    var rows = table.select("tr");
    for (var i = 0; i < rows.length; i++) {
        for (var j = rows[i].cells.length - 1; j > -1; j--) {
            rows[i].deleteCell(j);
        }
    }
  
    table = $("freeBusyData");
    rows = table.select("tr");
    for (var i = 0; i < rows.length; i++) {
        for (var j = rows[i].cells.length - 1; j > -1; j--) {
            rows[i].deleteCell(j);
        }
    }

    prepareTableHeaders();
    prepareTableRows();
    redisplayFreeBusyZone();
    resetAllFreeBusys();
}

function prepareTableHeaders() {
    var startTimeDate = $("startTime_date");
    var startDate = startTimeDate.valueAsDate();

    var endTimeDate = $("endTime_date");
    var endDate = endTimeDate.valueAsDate();
    endDate.setTime(endDate.getTime() + (additionalDays * 86400000));

    var rows = $("freeBusyHeader").rows;
    var days = startDate.daysUpTo(endDate);
    for (var i = 0; i < days.length; i++) {
        var header1 = document.createElement("th");
        header1.colSpan = ((displayEndHour - displayStartHour) + 1)/2;
        header1.appendChild(document.createTextNode(days[i].toLocaleDateString()));
        rows[0].appendChild(header1);
        var header1b = document.createElement("th");
        header1b.colSpan = ((displayEndHour - displayStartHour) + 1)/2;
        header1b.appendChild(document.createTextNode(days[i].toLocaleDateString()));
        rows[0].appendChild(header1b);
        for (var hour = displayStartHour; hour < (displayEndHour + 1); hour++) {
            var header2 = document.createElement("th");
            var text = hour + ":00";
            if (hour < 10)
                text = "0" + text;
            if (hour >= dayStartHour && hour <= dayEndHour)
                $(header2).addClassName ("officeHour");
            header2.appendChild(document.createTextNode(text));
            rows[1].appendChild(header2);

            var header3 = document.createElement("th");
            for (var span = 0; span < 4; span++) {
                var spanElement = document.createElement("span");
                $(spanElement).addClassName("freeBusyZoneElement");
                header3.appendChild(spanElement);
            }
            rows[2].appendChild(header3);
        }
    }
}

function prepareTableRows() {
    var startTimeDate = $("startTime_date");
    var startDate = startTimeDate.valueAsDate();

    var endTimeDate = $("endTime_date");
    var endDate = endTimeDate.valueAsDate();
    endDate.setTime(endDate.getTime() + (additionalDays * 86400000));

    var rows = $("freeBusyData").tBodies[0].rows;
    var days = startDate.daysUpTo(endDate);
    var width = $('freeBusyHeader').getWidth();
    $("freeBusyData").setStyle({ width: width + 'px' });
    for (var i = 0; i < days.length; i++)
        for (var rowNbr = 0; rowNbr < rows.length; rowNbr++)
            for (var hour = displayStartHour; hour < (displayEndHour + 1); hour++)
                rows[rowNbr].appendChild(document.createElement("td"));
}

function prepareAttendees() {
    var tableAttendees = $("freeBusyAttendees");
    var tableData = $("freeBusyData");
    var attendees = window.opener.attendees;

    if (attendees && attendees.keys()) {
        var tbodyAttendees = tableAttendees.tBodies[0];
        var modelAttendee = tbodyAttendees.rows[tbodyAttendees.rows.length - 1];
        var newAttendeeRow = tbodyAttendees.rows[tbodyAttendees.rows.length - 2];

        var tbodyData = tableData.tBodies[0];
        var modelData = tbodyData.rows[tbodyData.rows.length - 1];
        var newDataRow = tbodyData.rows[tbodyData.rows.length - 2];

        attendees.keys().each(function(atKey) {
            var attendee = attendees.get(atKey);
            var row = $(modelAttendee.cloneNode(true));
            tbodyAttendees.insertBefore(row, newAttendeeRow);
            row.removeClassName("attendeeModel");
            row.setAttribute("partstat", attendee["partstat"]);
            row.setAttribute("role", attendee["role"]);
            var uid = attendee["uid"];
            if (uid && uid == OwnerLogin) {
                row.addClassName("organizer-row");
                row.removeClassName("attendee-row");
                row.isOrganizer = true;
            } else {
                row.addClassName("attendee-row");
                row.removeClassName("organizer-row");
                row.isOrganizer = false;
            }
            var statusTD = row.down(".attendeeStatus");
            if (statusTD) {
                var boundOnStatusClick
                    = onAttendeeStatusClick.bindAsEventListener(row);
                statusTD.observe("click", boundOnStatusClick, false);
            }

            var input = row.down("input");
            var value = attendee["name"];
            if (value)
                value += " ";
            else
                value = "";
            value += "<" + attendee["email"] + ">";
            input.value = value;
            input.uid = attendee["uid"];
            input.cname = attendee["cname"];
            input.setAttribute("name", "");
            input.modified = false;
            input.observe("blur", onInputBlur);
            input.observe("keydown", onContactKeydown.bindAsEventListener(input)
);

            row = $(modelData.cloneNode(true));
            tbodyData.insertBefore(row, newDataRow);
            row.removeClassName("dataModel");
            displayFreeBusyForNode(input);
        });
    }

    // Activate "Add attendee" button
    var links = tableAttendees.select("TR.futureAttendee TD A");
    links.first().observe("click", onNewAttendeeClick);
}

function onWindowResize(event) {
    var view = $('freeBusyView');
    var attendeesCell = $$('TABLE#freeBusy TD.freeBusyAttendees').first();
    var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
    var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
    var width = view.getWidth() - attendeesCell.getWidth();
    var height = view.getHeight() - headerDiv.getHeight();

    attendeesDiv.setStyle({ height: (height - 20) + 'px' });
    headerDiv.setStyle({ width: (width - 20) + 'px' });
    dataDiv.setStyle({ width: (width - 4) + 'px',
                height: (height - 2) + 'px' });
}

function onScroll(event) {
    var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
    var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();

    headerDiv.scrollLeft = dataDiv.scrollLeft;
    attendeesDiv.scrollTop = dataDiv.scrollTop;
}

function onFreeBusyLoadHandler() {
    var widgets = {'start': {'date': $("startTime_date"),
                             'hour': $("startTime_time_hour"),
                             'minute': $("startTime_time_minute")},
                   'end': {'date': $("endTime_date"),
                           'hour': $("endTime_time_hour"),
                           'minute': $("endTime_time_minute")}};

    OwnerLogin = window.opener.getOwnerLogin();

    synchronizeWithParent("startTime", "startTime");
    synchronizeWithParent("endTime", "endTime");

    initTimeWidgets(widgets);
    initializeWindowButtons();
    prepareTableHeaders();
    prepareTableRows();
    redisplayFreeBusyZone();
    prepareAttendees();
    onWindowResize(null);
    Event.observe(window, "resize", onWindowResize);
    $$('TABLE#freeBusy TD.freeBusyData DIV').first().observe("scroll", onScroll);
    scrollToEvent ();
    toggleOfficeHours ();
}

document.observe("dom:loaded", onFreeBusyLoadHandler);

/* Functions related to UIxTimeDateControl widget */

function initTimeWidgets(widgets) {
    this.timeWidgets = widgets;

    assignCalendar('startTime_date');
    assignCalendar('endTime_date');

    widgets['start']['date'].observe("change",
                                     this.onAdjustTime, false);
    widgets['start']['hour'].observe("change",
                                     this.onAdjustTime, false);
    widgets['start']['minute'].observe("change",
                                       this.onAdjustTime, false);

    widgets['end']['date'].observe("change",
                                   this.onAdjustTime, false);
    widgets['end']['hour'].observe("change",
                                   this.onAdjustTime, false);
    widgets['end']['minute'].observe("change",
                                     this.onAdjustTime, false);

    var allDayLabel = $("allDay");
    if (allDayLabel) {
        var input = $(allDayLabel).childNodesWithTag("input")[0];
        input.observe("change", onAllDayChanged.bindAsEventListener(input));
        if (input.checked) {
            for (var type in widgets) {
                widgets[type]['hour'].disabled = true;
                widgets[type]['minute'].disabled = true;
            }
        }
    }

    if (isAllDay)
        handleAllDay ();
}

function onAdjustTime(event) {
    var endDate = window.getEndDate();
    var startDate = window.getStartDate();
    if (this.id.startsWith("start")) {
        // Start date was changed
        var delta = window.getShadowStartDate().valueOf() -
            startDate.valueOf();
        var newEndDate = new Date(endDate.valueOf() - delta);
        window.setEndDate(newEndDate);
        window.timeWidgets['end']['date'].updateShadowValue();
        window.timeWidgets['end']['hour'].updateShadowValue();
        window.timeWidgets['end']['minute'].updateShadowValue();
        window.timeWidgets['start']['date'].updateShadowValue();
        window.timeWidgets['start']['hour'].updateShadowValue();
        window.timeWidgets['start']['minute'].updateShadowValue();
    }
    else {
        // End date was changed
        var delta = endDate.valueOf() - startDate.valueOf();  
        if (delta < 0) {
            alert(labels.validate_endbeforestart);
            var oldEndDate = window.getShadowEndDate();
            window.setEndDate(oldEndDate);

            window.timeWidgets['end']['date'].updateShadowValue();
            window.timeWidgets['end']['hour'].updateShadowValue();
            window.timeWidgets['end']['minute'].updateShadowValue();
        }
    }

    // Specific function for the attendees editor
    onTimeDateWidgetChange();
    toggleOfficeHours ();
}

function _getDate(which) {
    var date = window.timeWidgets[which]['date'].valueAsDate();
    date.setHours( window.timeWidgets[which]['hour'].value );
    date.setMinutes( window.timeWidgets[which]['minute'].value );

    return date;
}

function getStartDate() {
    return this._getDate('start');
}

function getEndDate() {
    return this._getDate('end');
}

function _getShadowDate(which) {
    var date = window.timeWidgets[which]['date'].getAttribute("shadow-value").asDate();
    var intValue = parseInt(window.timeWidgets[which]['hour'].getAttribute("shadow-value"));
    date.setHours(intValue);
    intValue = parseInt(window.timeWidgets[which]['minute'].getAttribute("shadow-value"));
    date.setMinutes(intValue);

    return date;
}

function getShadowStartDate() {
    return this._getShadowDate('start');
}

function getShadowEndDate() {
    return this._getShadowDate('end');
}

function _setDate(which, newDate) {
    window.timeWidgets[which]['date'].setValueAsDate(newDate);
    window.timeWidgets[which]['hour'].value = newDate.getHours();
    var minutes = newDate.getMinutes();
    if (minutes % 15)
        minutes += (15 - minutes % 15);
    window.timeWidgets[which]['minute'].value = minutes;
}

function setStartDate(newStartDate) {
    this._setDate('start', newStartDate);
}

function setEndDate(newEndDate) {
    this._setDate('end', newEndDate);
}
