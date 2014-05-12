var eventListFilter = 'view_today';
var taskListFilter = 'view_today';

var listOfSelection = null;
var selectedCalendarCell = null;

var showCompletedTasks;

var currentDay = '';
var selectedDayNumber = -1;
var selectedDayDate = '';

var cachedDateSelectors = [];

var contactSelectorAction = 'calendars-contacts';

var eventsToDelete = [];
var calendarsOfEventsToDelete = [];

var usersRightsWindowHeight = 215;
var usersRightsWindowWidth = 502;

var calendarEvents = null;

var preventAutoScroll = false;

var userStates = [ "needs-action", "accepted", "declined", "tentative", "delegated" ];

var calendarHeaderAdjusted = false;

var categoriesStyles = new Hash();
var categoriesStyleSheet = null;

var clipboard = null;
var eventsToCopy = [];

function newEvent(type, day, hour, duration) {
    var folder = null;
    if (UserDefaults['SOGoDefaultCalendar'] == 'personal')
        folder = $("calendarList").down("li");
    else if (UserDefaults['SOGoDefaultCalendar'] == 'first') {
        var list = $("calendarList");
        var inputs = list.select("input");
        for (var i = 0; i < inputs.length; i++) {
            var input = inputs[i];
            if (input.checked) {
                folder = input.up();
                break;
            }
        }
        if (!folder)
            folder = list.down("li");
    }
    else
        folder = getSelectedFolder();
    var folderID = folder.readAttribute("id");
    var urlstr = ApplicationBaseURL + folderID + "/new" + type;
    var params = [];
    if (!day)
        day = currentDay;
    params.push("day=" + day);
    if (hour)
        params.push("hm=" + hour);
    if (duration)
        params.push("duration=" + duration);
    if (params.length > 0)
        urlstr += "?" + params.join("&");

    window.open(urlstr, "", "width=490,height=470,resizable=0");

    return false; /* stop following the link */
}

function newEventFromWidget(sender, type) {
    var day = $(sender).readAttribute("day");
    var hour = sender.readAttribute("hour");

    return newEvent(type, day, hour);
}

function minutesToHM(minutes) {
    var hours = Math.floor(minutes / 60);
    if (hours < 10)
        hours = "0" + hours;
    var mins = minutes % 60;
    if (mins < 10)
        mins = "0" + mins;

    return "" + hours + mins;
}

function newEventFromDragging(controller, day, coordinates) {
    var startHm;
    if (controller.eventType == "multiday")
        startHm = minutesToHM(coordinates.start * 15);
    else
        startHm = "allday";
    var lengthHm = minutesToHM(coordinates.duration * 15);
    newEvent("event", day, startHm, lengthHm);
}

function updateEventFromDragging(controller, eventCells, eventDelta) {
    if (eventDelta.dayNumber || eventDelta.start || eventDelta.duration) {
        var params = ("days=" + eventDelta.dayNumber
                      + "&start=" + eventDelta.start * 15
                      + "&duration=" + eventDelta.duration * 15);
        // log("eventCells: " + eventCells.length);
        var eventCell = eventCells[0];
        // log("  time: " + eventCell.recurrenceTime);
        // log("  exception: " + eventCell.isException);

        if (eventCell.recurrenceTime && !eventCell.isException)
            _editRecurrenceDialog(eventCell, "confirmAdjustment", params);
        else {
            var urlstr = (ApplicationBaseURL
                          + "/" + eventCell.calendar + "/" + eventCell.cname);
            if (eventCell.recurrenceTime)
                urlstr += "/occurence" + eventCell.recurrenceTime;
            urlstr += ("/adjust?" + params);
            // log("  urlstr: " + urlstr);
            triggerAjaxRequest(urlstr, updateEventFromDraggingCallback);
        }
    }
}

function performEventAdjustment(folder, event, recurrence, params) {
    var urlstr = ApplicationBaseURL + "/" + folder + "/" + event;
    if (recurrence)
        urlstr += "/" + recurrence;
    urlstr += "/adjust" + generateQueryString(params);
    triggerAjaxRequest(urlstr, updateEventFromDraggingCallback);
}

function updateEventFromDraggingCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            refreshEventsAndDisplay();
        }
        else {
            var response = http.responseText.evalJSON(true);
            showAlertDialog(response['message']);
        }
    }
}

function getSelectedFolder() {
    var folder;
    var list = $("calendarList");
    var nodes = list.getSelectedRows();
    if (nodes.length > 0)
        folder = nodes[0];
    else
        folder = list.down("li"); // personal calendar

    return folder;
}

function onMenuNewEventClick(event) {
    var target = document.menuTarget;
    if (/(minutes\d{2}|dayHeader)/.test(target.className))
        target = target.parentNode;
    newEventFromWidget(target, "event");
}

function onMenuNewTaskClick(event) {
    var target = document.menuTarget;
    if (/(minutes\d{2}|dayHeader)/.test(target.className))
        target = target.parentNode;
    newEventFromWidget(target, "task");
}

function _editEventId(id, calendar, recurrence) {
    var targetname = "SOGo_edit_" + id;
    var urlstr = ApplicationBaseURL + "/" + calendar + "/" + id;
    if (recurrence) {
        urlstr += "/" + recurrence;
        targetname += recurrence;
    }
    urlstr += "/edit";
    var win = window.open(urlstr, "_blank",
                          "width=490,height=470,resizable=0");
    if (win)
        win.focus();
}

function editEvent() {
    if (listOfSelection) {
        var nodes = listOfSelection.getSelectedRows();

        if (nodes.length == 0) {
            showAlertDialog(_("Please select an event or a task."));
            return false;
        }

        for (var i = 0; i < nodes.length; i++)
            _editEventId(nodes[i].cname,
                         nodes[i].calendar);
    } else if (selectedCalendarCell) {
        if (selectedCalendarCell[0].recurrenceTime && !selectedCalendarCell[0].isException)
            _editRecurrenceDialog(selectedCalendarCell[0], "confirmEditing");
        else
            _editEventId(selectedCalendarCell[0].cname,
                         selectedCalendarCell[0].calendar);
    } else {
        showAlertDialog(_("Please select an event or a task."));
    }

    return false; /* stop following the link */
}

function _batchDeleteEvents() {
    // Delete the events of the next calendar
    var calendar = calendarsOfEventsToDelete.shift();
    var events = eventsToDelete.shift();
    var urlstr = (ApplicationBaseURL + "/" + calendar
                  + "/batchDelete?ids=" + events.join(','));
    document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
                                                         deleteEventCallback,
                                                         { calendar: calendar, events: events });
}

function deleteEvent() {
    var label = "";
    var events = [];
    if (listOfSelection) {
        var nodes = listOfSelection.getSelectedRows();
        if (nodes.length > 0) {
            if (listOfSelection.parentNode == $("tasksList"))
                label = _("taskDeleteConfirmation");
            else
                label = _("eventDeleteConfirmation");

            if (nodes.length == 1
                && nodes[0].recurrenceTime) {
                if (nodes[0].erasable)
                    _editRecurrenceDialog(nodes[0], "confirmDeletion");
                else
                    showAlertDialog(_("You don't have the required privileges to perform the operation."));
            }
            else {
                var canDelete;
                var sortedNodes = [];
                var calendars = [];
                for (var i = 0; i < nodes.length; i++) {
                    canDelete = nodes[i].erasable;
                    if (canDelete) {
                        var calendar = nodes[i].calendar;
                        var cname = nodes[i].cname;
                        if (nodes[i].recurrenceTime) {
                            cname += '/occurence' + nodes[i].recurrenceTime;
                        }
                        if (!sortedNodes[calendar]) {
                            sortedNodes[calendar] = [];
                            calendars.push(calendar);
                        }
                        if (sortedNodes[calendar].indexOf(cname) < 0) {
                            // Build list item element for confirmation dialog
                            var itemElement = new Element('li');
                            var colorBox = new Element('div', {'class': 'colorBox calendarFolder' + nodes[i].calendar});
                            var content = '';
                            if (nodes[i].tagName == 'TR') {
                                var cell = nodes[i].down('td span');
                                content = cell.allTextContent(); // extract the first column only
                            }
                            else {
                                content = nodes[i].allTextContent();
                            }
                            itemElement.appendChild(colorBox);
                            itemElement.appendChild(new Element('span').update(content.escapeHTML()));
                            if (nodes[i].startDate) {
                                var startDate = new Date(nodes[i].startDate*1000);
                                var dateElement = new Element('div', {'class': 'muted'});
                                var date;
                                if (typeof nodes[i].hour == 'undefined')
                                    date = startDate.toLocaleDateString(localeCode);
                                else
                                    date = startDate.toLocaleString(localeCode);
                                dateElement.update(date);
                                itemElement.appendChild(dateElement);
                            }
                            events.push(itemElement);
                            sortedNodes[calendar].push(cname);
                        }
                    }
                }
                // Update global arrays
                for (i = 0; i < calendars.length; i++) {
                    calendarsOfEventsToDelete.push(calendars[i]);
                    eventsToDelete.push(sortedNodes[calendars[i]]);
                }
                if (i == 0)
                    showAlertDialog(_("You don't have the required privileges to perform the operation."));
            }
        }
        else
            showAlertDialog(_("Please select an event or a task."));
    }
    else if (selectedCalendarCell) {
        if (selectedCalendarCell.length == 1
            && selectedCalendarCell[0].recurrenceTime) {
            if (selectedCalendarCell[0].erasable)
                _editRecurrenceDialog(selectedCalendarCell[0], "confirmDeletion");
            else
                showAlertDialog(_("You don't have the required privileges to perform the operation."));
        }
        else {
            var canDelete;
            var sortedNodes = [];
            var calendars = [];
            var cname;
            for (var i = 0; i < selectedCalendarCell.length; i++) {
                canDelete = selectedCalendarCell[i].erasable;
                if (canDelete) {
                    var calendar = selectedCalendarCell[i].calendar;
                    var cname = selectedCalendarCell[i].cname;
                    if (selectedCalendarCell[i].recurrenceTime) {
                        cname += '/occurence' + selectedCalendarCell[i].recurrenceTime;
                    }
                    if (!sortedNodes[calendar]) {
                        sortedNodes[calendar] = [];
                        calendars.push(calendar);
                    }
                    if (sortedNodes[calendar].indexOf(cname) < 0) {
                        // Build list item element for confirmation dialog
                        var itemElement = new Element('li');
                        var colorBox = new Element('div', {'class': 'colorBox calendarFolder' + selectedCalendarCell[i].calendar});
                        var content = '';
                        var event = $(selectedCalendarCell[i]).down("DIV.text");
                        for (var j = 0; j < event.childNodes.length; j++) {
                            var node = event.childNodes[j];
                            if (node.nodeType == Node.TEXT_NODE) {
                                content += node.nodeValue;
                            }
                        }
                        itemElement.appendChild(colorBox);
                        itemElement.appendChild(new Element('span').update(content.escapeHTML()));
                        if (selectedCalendarCell[i].startDate) {
                            var startDate = new Date(selectedCalendarCell[i].startDate*1000);
                            var dateElement = new Element('div', {'class': 'muted'});
                            var date;
                            if (selectedCalendarCell[i].readAttribute('hour') == 'allday')
                                date = startDate.toLocaleDateString(localeCode);
                            else
                                date = startDate.toLocaleString(localeCode);
                            dateElement.update(date);
                            itemElement.appendChild(dateElement);
                        }
                        events.push(itemElement);
                        sortedNodes[calendar].push(cname);
                    }
                }
            }
            // Update global arrays
            for (i = 0; i < calendars.length; i++) {
                calendarsOfEventsToDelete.push(calendars[i]);
                eventsToDelete.push(sortedNodes[calendars[i]]);
            }
            if (i == 0)
                showAlertDialog(_("You don't have the required privileges to perform the operation."));
        }
    }
    else
        showAlertDialog(_("Please select an event or a task."));

    if (events.length > 0) {
        // Show confirmation dialog
        var p = new Element('p');
        p.appendChild(document.createTextNode(label));
        var list = new Element('ul');
        for (i = 0; i < events.length; i++) {
            list.appendChild(events[i]);
        }
        p.appendChild(list);
        p.appendChild(document.createTextNode(_("Would you like to continue?")));
        showConfirmDialog(_("Warning"), p, deleteEventFromListConfirm, deleteEventCancel);
    }

    return false;
}

function deleteEventFromListConfirm() {
    if (document.deleteEventAjaxRequest) {
        document.deleteEventAjaxRequest.aborted = true;
        document.deleteEventAjaxRequest.abort();
    }

    _batchDeleteEvents();
    disposeDialog();
}

function deleteEventFromViewConfirm() {
    if (document.deleteEventAjaxRequest) {
        document.deleteEventAjaxRequest.aborted = true;
        document.deleteEventAjaxRequest.abort();
    }

    selectedCalendarCell = null;
    _batchDeleteEvents();
    disposeDialog();
}

function deleteEventCancel(event) {
    calendarsOfEventsToDelete = [];
    eventsToDelete = [];
    disposeDialog();
}

function copyEventToClipboard() {
    if (listOfSelection) {
        clipboard = new Array();
        var nodes = listOfSelection.getSelectedRows();
        for (var i = 0; i < nodes.length; i++)
            clipboard.push(nodes[i].calendar + "/" + nodes[i].cname);
    }
    else if (selectedCalendarCell) {
        clipboard = new Array();
        for (var i = 0; i < selectedCalendarCell.length; i++)
            clipboard.push(selectedCalendarCell[i].calendar + "/" + selectedCalendarCell[i].cname);
    }
    log ("clipboard : " + clipboard.join(", "));
}

function copyEventFromClipboard() {
    if (clipboard && clipboard.length > 0) {
        var folder = getSelectedFolder();
        var folderID = folder.readAttribute("id").substr(1);
        eventsToCopy = [];
        for (var i = 0; i < clipboard.length; i++)
            eventsToCopy[i] = clipboard[i] + "/copy?destination=" + folderID;
        copyEvents();
    }
}

function copyEventToPersonalCalendar(event) {
    var calendar = selectedCalendarCell[0].calendar;
    var cname = selectedCalendarCell[0].cname;
    eventsToCopy = [calendar + "/" + cname + "/copy"];
    copyEvents();
}

function copyEvents() {
    var path = eventsToCopy.shift();
    var urlstr = ApplicationBaseURL + "/" + path; log (urlstr);
    triggerAjaxRequest(urlstr,
                       copyEventCallback);
}

function copyEventCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            if (eventsToCopy.length)
                copyEvents();
            else
                refreshEventsAndDisplay();
        }
        else if (parseInt(http.status) == 403)
            showAlertDialog(_("You don't have the required privileges to perform the operation."));
        else if (parseInt(http.status) == 400)
            showAlertDialog(_("DestinationCalendarError"));
        else
            showAlertDialog(_("EventCopyError"));
    }
}

function onMenuRawEvent(event) {
    if (selectedCalendarCell.length != 1) {
      return;
    }

    var calendar = selectedCalendarCell[0].calendar;
    var cname = selectedCalendarCell[0].cname;

    var url = ApplicationBaseURL + "/" + calendar + "/" + cname + "/raw";
    openGenericWindow(url);
}

function modifyEvent(sender, modification, parameters) {
    var currentLocation = '' + window.location;
    var arr = currentLocation.split("/");
    arr[arr.length-1] = modification;

    document.modifyEventAjaxRequest = triggerAjaxRequest(arr.join("/"),
                                                         modifyEventCallback,
                                                         modification,
                                                         parameters,
                                                         { "Content-type": "application/x-www-form-urlencoded" });

    return false;
}

function closeInvitationWindow() {
    var closeDiv = document.createElement("div");
    document.body.appendChild(closeDiv);
    closeDiv.addClassName("javascriptPopupBackground");

    var closePseudoWin = document.createElement("div");
    document.body.appendChild(closePseudoWin);
    closePseudoWin.addClassName("javascriptMessagePseudoTopWindow");
    closePseudoWin.style.top = "0px;";
    closePseudoWin.style.left = "0px;";
    closePseudoWin.style.right = "0px;";
    closePseudoWin.appendChild(document.createTextNode(_("closeThisWindowMessage")));

    var calLink = document.createElement("a");
    closePseudoWin.appendChild(calLink);
    calLink.href = ApplicationBaseURL;
    calLink.appendChild(document.createTextNode(_("Calendar").toLowerCase()));
}

function modifyEventCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status) || http.status == 200) {
            var mailInvitation = queryParameters["mail-invitation"];
            if (mailInvitation && mailInvitation.toLowerCase() == "yes")
                closeInvitationWindow();
            else {
                window.opener.setTimeout("refreshEventsAndDisplay();", 100);
                window.setTimeout("window.close();", 100);
            }
        }
        else if (http.status == 403) {
            var data = http.responseText;
            var msg;
            if (data.indexOf("An error occurred during object publishing") >
                -1) {
                msg = data.replace(/^(.*\n)*.*<p>((.*\n)*.*)<\/p>(.*\n)*.*$/, "$2");
            } else {
                msg = "delegate is a participant";
            }
            showAlertDialog(_(msg));
        }
        else {
            showAlertDialog(_("eventPartStatModificationError"));
        }
        document.modifyEventAjaxRequest = null;
    }
}

function _deleteCalendarEventBlocks(calendar, cname, occurenceTime) {
    // Delete event (or occurence) from the specified calendar
    var ownerIsOrganizer = false;
    var events = calendarEvents[calendar];
    if (events) {
        var occurences = events[cname];
        if (occurences) {
            for (var i = 0; i < occurences.length; i++) {
                var nodes = occurences[i].blocks;
                for (var j = 0; j < nodes.length; j++) {
                    var node = nodes[j];
                    if (occurenceTime == null
                        || occurenceTime == node.recurrenceTime) {
                        ownerIsOrganizer = node.ownerIsOrganizer;
                        node.parentNode.removeChild(node);
                    }
                }
            }
            if (ownerIsOrganizer)
                // Search for the same event in other calendars (using the cache)
                // only if the delete operation is triggered from the organizer's
                // calendar.
                for (var otherCalendar in calendarEvents) {
                    if (calendar != otherCalendar) {
                        occurences = calendarEvents[otherCalendar][cname];
                        if (occurences) {
                            for (var i = 0; i < occurences.length; i++) {
                                var occurence = occurences[i];
                                if (occurenceTime == null || occurenceTime == occurence[15]) {
                                    var nodes = occurence.blocks;
                                    for (var j = 0; j < nodes.length; j++) {
                                        var node = nodes[j];
                                        if (node.parentNode)
                                            node.parentNode.removeChild(node);
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }

    resizeCalendarHeaderDIV();
}

function _deleteEventFromTables(calendar, cname, occurenceTime) {
    var basename = "-" + cname;
    if (occurenceTime) {
        basename = basename + "-" + occurenceTime;
    }
    if (calendarEvents[calendar]) {
        var occurences = calendarEvents[calendar][cname];
        if (occurences) {
            var occurence = occurences.first();
            var ownerIsOrganizer = occurence[19];

            // Delete event from events list
            var table = $("eventsList");
            var rows = table.tBodies[0].rows;
            for (var j = rows.length; j > 0; j--) {
                var row = $(rows[j - 1]);
                var id = row.getAttribute("id");
                var pos = id.indexOf(basename);
                if (pos > 0) {
                    var otherCalendar = id.substr(0, pos);
                    occurences = calendarEvents[otherCalendar][cname];
                    if (occurences) {
                        for (var k = 0; k < occurences.length; k++) {
                            var occurence = occurences[k];
                            if (calendar == otherCalendar || ownerIsOrganizer) {
                                // This is the specified event or the same event in another
                                // calendar. In this case, remove it only if the delete
                                // operation is triggered from the organizer's calendar.
                                if (occurenceTime == null || occurenceTime == occurence[15]) {
                                    row.parentNode.removeChild(row);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Delete task from tasks list
    var row = $(calendar + basename);
    if (row) {
        row.parentNode.removeChild(row);
    }
}

function _deleteCalendarEventCache(calendar, cname, occurenceTime) {
    var ownerIsOrganizer = false;
    if (calendarEvents[calendar]) {
        var occurences = calendarEvents[calendar][cname];
        if (occurences)
            ownerIsOrganizer = occurences[0][19];
    }

    for (var otherCalendar in calendarEvents) {
        if (calendarEvents[otherCalendar]) {
            var occurences = calendarEvents[otherCalendar][cname];
            if (occurences) {
                var newOccurences = [];
                for (var i = 0; i < occurences.length; i++) {
                    var occurence = occurences[i];
                    if (calendar == otherCalendar || ownerIsOrganizer) {
                        // This is the specified event or the same event in another
                        // calendar. In this case, remove it only if the delete
                        // operation is triggered from the organizer's calendar.
                        if (occurenceTime == null) {
                            delete calendarEvents[otherCalendar][cname];
                        }
                        else if (occurenceTime != occurence[15]) {
                            // || occurenceTime == occurence[15]) {
                            newOccurences.push(occurence);
                        }
                    }
                }
                if (occurenceTime)
                    calendarEvents[otherCalendar][cname] = newOccurences;
            }
        }
    }
}

/**
 * This is the Ajax callback function for _batchDeleteEvents.
 */
function deleteEventCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var isTask = false;
            var calendar = http.callbackData.calendar;
            var events = http.callbackData.events;
            for (var i = 0; i < events.length; i++) {
                var cname = /(.+)\/occurence([0-9]+)/.exec(events[i]) || [null, events[i]];
                _deleteCalendarEventBlocks(calendar, cname[1], cname[2]);
                _deleteEventFromTables(calendar, cname[1], cname[2]);
                _deleteCalendarEventCache(calendar, cname[1], cname[2]);
            }
            if (eventsToDelete.length)
                _batchDeleteEvents();
            else
                document.deleteEventAjaxRequest = null;
        }
        else if (parseInt(http.status) == 403)
            showAlertDialog(_("You don't have the required privileges to perform the operation."));
        else
            log ("deleteEventCallback Ajax error (" + http.status + ")");
    }
}

function getEventById(cname, owner) {
    var event = null;

    if (calendarEvents) {
        if (!owner)
            owner = UserLogin;
        var userEvents = calendarEvents[owner];
        if (userEvents)
            event = userEvents[cname];
    }

    return event;
}

function _editRecurrenceDialog(eventCell, method, params) {
    var targetname = "SOGo_edit_" + eventCell.cname + eventCell.recurrenceTime;
    var urlstr = (ApplicationBaseURL + "/" + eventCell.calendar + "/" + eventCell.cname
                  + "/occurence" + eventCell.recurrenceTime + "/" + method);
    if (params && params.length) {
        urlstr += "?" + params;
    }
    var win = window.open(urlstr, "_blank",
                          "width=490,height=70,resizable=0");
    if (win)
        win.focus();
}

function onViewEvent(event) {
    if (event.detail == 2) return;
    var url = ApplicationBaseURL + "/" + this.calendar + "/" + this.cname;

    if (typeof this.recurrenceTime != "undefined")
        url += "/occurence" + this.recurrenceTime;
    url += "/view";
    if (document.viewEventAjaxRequest) {
        document.viewEventAjaxRequest.aborted = true;
        document.viewEventAjaxRequest.abort();
    }
    document.viewEventAjaxRequest = triggerAjaxRequest(url, onViewEventCallback, this);
}

function onViewEventCallback(http) {
    if (http.readyState == 4 && http.status == 200) {
        if (http.responseText.length > 0) {
            var data = http.responseText.evalJSON(true);
            //      $H(data).keys().each(function(key) {
            //	  log (key + " = " + data[key]);
            //	});
            var cell = http.callbackData;
            var cellPosition = cell.cumulativeOffset();
            var cellDimensions = cell.getDimensions();
            var div = $("eventDialog");
            var divDimensions = div.getDimensions();
            var view;
            var left;
            var top = cellPosition[1] - 5;

            if (currentView != "monthview") {
                view = $("daysView");
                var viewPosition = view.cumulativeOffset();

                if (parseInt(data["isAllDay"]) == 0) {
                    top -= view.scrollTop;
                    if (viewPosition[1] > top + 2) {
                        view.stopObserving("scroll", onBodyClickHandler);
                        view.scrollTop = cell.offsetTop;
                        top = viewPosition[1];
                        Event.observe.delay(0.1, view, "scroll", onBodyClickHandler);
                    }
                }
            }
            else {
                top -= cell.up("DIV.day").scrollTop;
            }

            left = cellPosition[0] + cellDimensions["width"] + 4;
            if (left + divDimensions["width"] > window.width()) {
                left = cellPosition[0] - divDimensions["width"];
                div.removeClassName("left");
                div.addClassName("right");
            }
            else {
                div.removeClassName("right");
                div.addClassName("left");
            }

            // Put the event's data in the DIV
            div.down("h1").update(data["summary"].replace(/\r?\n/g, "<BR/>"));

            var paras = div.getElementsByTagName("p");
            var para = $(paras[0]);
            if (parseInt(data["isAllDay"]) == 0) {
                para.down("SPAN").update(data["startTime"] + " - " + data["endTime"]);
                para.show();
            } else
                para.hide();

            para = $(paras[1]);
            if (data["calendar"].length) {
                para.down("SPAN", 1).update(data["calendar"]);
                para.show();
            } else
                para.hide();

            para = $(paras[2]);
            if (data["location"].length) {
                para.down("SPAN", 1).update(data["location"]);
                para.show();
            } else
                para.hide();

	    para = $(paras[3]);
            if (data["created_by"].length) {
		para.down("SPAN", 1).update(data["created_by"]);
                para.show();
            } else
                para.hide();

            para = $(paras[4]);
            if (data["description"].length) {
                para.update(data["description"].replace(/\r?\n/g, "<BR/>"));
                para.show();
            } else
                para.hide();

            div.setStyle({ left: left + "px", top: top + "px" });
            div.show();
            configureLinks(div);
        }
    }
    else {
        log("onViewEventCallback ajax error (" + http.status + "): " + http.url);
    }
}

function editDoubleClickedEvent(event) {
    if (this.isException && this.recurrenceTime)
        _editEventId(this.cname, this.calendar, "occurence" + this.recurrenceTime);
    else if (this.recurrenceTime)
        _editRecurrenceDialog(this, "confirmEditing");
    else
        _editEventId(this.cname, this.calendar);

    Event.stop(event);
}

function performEventEdition(folder, event, recurrence) {
    _editEventId(event, folder, recurrence);
}

function performEventDeletion(folder, event, recurrence) {
    if (calendarEvents) {
        if (recurrence) {
            // Only one recurrence
            var occurenceTime = recurrence.substring(9);
            var nodes = _eventBlocksMatching(folder, event, occurenceTime);
            var urlstr = ApplicationBaseURL + "/" + folder + "/" + event  + "/" + recurrence + "/delete";

            if (nodes)
                document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
                                                                     performDeleteEventCallback,
                                                                     { nodes: nodes,
                                                                       occurence: occurenceTime });
        }
        else {
            // All recurrences
            if (document.deleteEventAjaxRequest) {
                document.deleteEventAjaxRequest.aborted = true;
                document.deleteEventAjaxRequest.abort();
            }
            eventsToDelete.push([event]);
            calendarsOfEventsToDelete.push(folder);
            _batchDeleteEvents();
        }
    }
}

function performDeleteEventCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var occurenceTime = http.callbackData.occurence;
            var nodes = http.callbackData.nodes;
            var cname = nodes[0].cname;
            var calendar = nodes[0].calendar;

            _deleteCalendarEventBlocks(calendar, cname, occurenceTime);
            _deleteEventFromTables(calendar, cname, occurenceTime);
            _deleteCalendarEventCache(calendar, cname, occurenceTime);
        }
    }
}

/* in dateselector */
function onDaySelect(node) {
    var day = node.getAttribute('day');
    var needRefresh = (eventListFilter == 'view_selectedday'
                       && day != currentDay);

    var td = $(node).getParentWithTagName("td");
    var table = $(td).getParentWithTagName("table");

    //   log ("table.selected: " + table.selected);

    if (document.selectedDate)
        document.selectedDate.deselect();

    td.selectElement();
    document.selectedDate = td;

    changeCalendarDisplay( { "day": day } );
    currentDay = day;
    selectedDayDate = day;
    if (needRefresh)
        refreshEvents();

    return false;
}

function onDateSelectorGotoMonth(event) {
    var day = this.getAttribute("date");

    changeDateSelectorDisplay(day, true);

    Event.stop(event);
}

function onCalendarGotoDay(node) {
    var day = node.getAttribute("date");
    var needRefresh = (eventListFilter == 'view_selectedday' && day != currentDay);

    changeDateSelectorDisplay(day);
    changeCalendarDisplay( { "day": day } );
    if (needRefresh)
        refreshEvents();

    return false;
}

function gotoToday() {
    var todayDate = new Date();
    selectedDayDate = todayDate.getDayString();
    changeDateSelectorDisplay('');
    changeCalendarDisplay();

    return false;
}

function setDateSelectorContent(content) {
    var div = $("dateSelectorView");

    div.update(content);
    if (currentDay.length > 0)
        restoreCurrentDaySelection(div);

    initDateSelectorEvents();
}

function dateSelectorCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        document.dateSelectorAjaxRequest = null;
        var content = http.responseText;
        setDateSelectorContent(content);
        cachedDateSelectors[http.callbackData] = content;
    }
    else
        log ("dateSelectorCallback Ajax error");
}

function eventsListCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        var div = $("eventsListView");
        document.eventsListAjaxRequest = null;
        var table = $("eventsList");
        lastClickedRow = -1; // from generic.js

        var rows = table.select("TBODY TR");
        rows.each(function(e) {
            e.remove();
        });

        if (http.responseText.length > 0) {
            var data = http.responseText.evalJSON(true);
            for (var i = 0; i < data.length; i++) {
                var row = createElement("tr");
                table.tBodies[0].appendChild(row);
                row.addClassName("eventRow");
                var calendar = escape(data[i][1]);
                var rTime = data[i][16];
                var id = escape(data[i][1] + "-" + data[i][0]);
                if (rTime)
                    id += "-" + escape(rTime);
                row.setAttribute("id", id);
                row.cname = escape(data[i][0]);
                row.calendar = calendar;
                if (rTime)
                    row.recurrenceTime = escape(rTime);
                row.isException = data[i][17];
                row.editable = data[i][18] || IsSuperUser;
                row.erasable = data[i][19] || IsSuperUser;
                row.startDate = data[i][5];
                var startDate = new Date(data[i][5]*1000);
                row.day = startDate.getDayString();
                if (!data[i][8])
                    row.hour = startDate.getHourString(); // event is not all day
                row.observe("mousedown", onRowClick);
                row.observe("selectstart", listRowMouseDownHandler);
                if (data[i][3] != null)
                    // Status is defined -- event is readable
                    row.observe("dblclick", editDoubleClickedEvent);

                var td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                var colorDiv = createElement("div", false, "colorBox calendarFolder" + calendar);
                td.appendChild(colorDiv);
                colorDiv.update('&nbsp;');
                var span = createElement("span");
                td.appendChild(span);
                span.update(data[i][4]); // title

                td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.update(data[i][21]); // start date

                td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.update(data[i][22]); // end date

                td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                if (data[i][7])
                    td.update(data[i][7]); // location
              
                td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                if (data[i][10])
                  td.update(data[i][10]); // category
              
                td = createElement("td");
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.update(data[i][2]); // calendar
            }

            if (sorting["event-header"] && sorting["event-header"].length > 0) {
                var sortHeader = $(sorting["event-header"]);

                if (sortHeader) {
                    var sortImages = $(table.tHead).select(".sortImage");
                    $(sortImages).each(function(item) {
                            item.remove();
                        });

                    var sortImage = createElement("img", "messageSortImage", "sortImage");
                    sortHeader.insertBefore(sortImage, sortHeader.firstChild);
                    if (sorting["event-ascending"])
                        sortImage.src = ResourcesURL + "/arrow-up.png";
                    else
                        sortImage.src = ResourcesURL + "/arrow-down.png";
                }
            }
        }
    }
    else
        log ("eventsListCallback Ajax error");
}

function tasksListCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        var div = $("tasksListView");
        document.tasksListAjaxRequest = null;
        var table = $("tasksList");
        lastClickedRow = -1; // from generic.js

        var rows = table.select("TBODY TR");
        rows.each(function(e) {
            e.remove();
        });

        if (http.responseText.length > 0) {
            var data = http.responseText.evalJSON(true);

            // [0] Task ID
            // [1] Calendar ID
            // [2] Calendar name
            // [3] Status (0, 1 = completed, 2)
            // [4] Title
            // [5] Due date (int)
            // [6] Classification (0 = public, 1, = private, 2 = confidential)
            // [7] Location
            // [8] Category
            // [9] Editable?
            // [10] Erasable?
            // [11] Priority (0, 1 = important, 9 = low)
            // [12] Status CSS class (duelater, completed, etc)
            // (13) Due date (formatted)

            for (var i = 0; i < data.length; i++) {
                var row = createElement("tr");
                table.tBodies[0].appendChild(row);

                row.on("dblclick", editDoubleClickedEvent);

                var calendar = escape(data[i][1]);
                var cname = escape(data[i][0]);
                row.setAttribute("id", calendar + "-" + cname);
                //listItem.addClassName(data[i][5]); // Classification
                row.addClassName(data[i][12]); // status
                row.calendar = calendar;
                row.cname = cname;
                row.erasable = data[i][10] || IsSuperUser;
                if (parseInt(data[i][11]) == 1) {
                  row.addClassName("important");
                }
                else if (parseInt(data[i][11]) == 9) {
                  row.addClassName("low");
                }

                var cell = createElement("td");
                row.appendChild(cell);
                var input = createElement("input");
                input.setAttribute("type", "checkbox");
                cell.appendChild(input);
                input.setAttribute("value", "1");
                if (parseInt(data[i][9]) == 0) // editable?
                    input.setAttribute("disabled", true);
                input.addClassName("checkBox");
                if (parseInt(data[i][3]) == 1) // completed?
                    input.setAttribute("checked", "checked");
                input.observe("click", updateTaskStatus, true);

                cell = createElement("td");
                row.appendChild(cell);
                if (data[i][11] != null) {
                    cell.update(_("prio_" + data[i][11])); // Priority
                }
                else {
                    cell.update(""); // Priority
                }

                cell = createElement("td");
                row.appendChild(cell);
                var colorDiv = createElement("div", false, "colorBox calendarFolder" + calendar);
                cell.appendChild(colorDiv);
                colorDiv.update('&nbsp;');
                var t = new Element ("span");
                cell.appendChild(t);
                t.update(data[i][4]); // title

                cell = createElement("td");
                row.appendChild(cell);
                if (data[i][13])
                    cell.update(data[i][13]); // end date

                cell = createElement("td");
                row.appendChild(cell);
                cell.update(data[i][7]); // location

                cell = createElement("td");
                row.appendChild(cell);
                cell.update(data[i][8]); // category

                cell = createElement("td");
                row.appendChild(cell);
                cell.update(data[i][2]); // calendar name
            }

            table.scrollTop = table.previousScroll;

            if (sorting["task-attribute"] && sorting["task-attribute"].length > 0) {
                var sortHeader = $(sorting["task-header"]);

                if (sortHeader) {
                    var sortImages = $(table.tHead).select(".sortImage");
                    $(sortImages).each(function(item) {
                            item.remove();
                        });

                    var sortImage = createElement("img", "messageSortImage", "sortImage");
                    sortHeader.insertBefore(sortImage, sortHeader.firstChild);
                    if (sorting["task-ascending"])
                        sortImage.src = ResourcesURL + "/arrow-up.png";
                    else
                        sortImage.src = ResourcesURL + "/arrow-down.png";
                }
            }
            if (http.callbackData) {
                var selectedNodesId = http.callbackData;
                for (var i = 0; i < selectedNodesId.length; i++) {
                    // 	log(selectedNodesId[i] + " (" + i + ") is selected");
                    var node = $(selectedNodesId[i]);
                    if (node) {
                        node.selectElement();
                    }
                }
            }
            else
                log ("tasksListCallback: no data");
        }
    }
    else
        log ("tasksListCallback Ajax error");
}

/* in dateselector */
function restoreCurrentDaySelection(div) {
    var elements = $(div).select("TD.activeDay SPAN");
    if (elements.size()) {
        var day = elements[0].readAttribute('day');
        if (day.substr(0, 6) == currentDay.substr(0, 6)) {
            for (var i = 0; i < elements.length; i++) {
                day = elements[i].readAttribute('day');
                if (day && day == currentDay) {
                    var td = $(elements[i]).getParentWithTagName("td");
                    if (document.selectedDate)
                        document.selectedDate.deselect();
                    $(td).selectElement();
                    document.selectedDate = td;
                }
            }
        }
    }
}

function loadPreviousView(event) {
    onCalendarGotoDay($("leftNavigationArrow"));
}

function loadNextView(event) {
    onCalendarGotoDay($("rightNavigationArrow"));
}

function changeDateSelectorDisplay(day, keepCurrentDay) {
    var url = ApplicationBaseURL + "/dateselector";
    if (day) {
        if (day.length < 8)
            day += "01";
        url += "?day=" + day;
    }

    if (!keepCurrentDay)
        currentDay = day;

    var month = day.substr(0, 6);
    if (cachedDateSelectors[month]) {
        //       log ("restoring cached selector for month: " + month);
        setDateSelectorContent(cachedDateSelectors[month]);
    }
    else {
        //       log ("loading selector for month: " + month);
        if (document.dateSelectorAjaxRequest) {
            document.dateSelectorAjaxRequest.aborted = true;
            document.dateSelectorAjaxRequest.abort();
        }
        document.dateSelectorAjaxRequest
            = triggerAjaxRequest(url,
                                 dateSelectorCallback,
                                 month);
    }
}

function changeCalendarDisplay(data, newView) {
    newView = ((newView) ? newView : currentView);
    var url = ApplicationBaseURL + "/" + newView;
    var day = null;
    var scrollEvent = null;
    if (data) {
        day = data['day'];
        scrollEvent = data['scrollEvent'];
    }

    if (!day)
        day = currentDay;

    if (day) {
        if (data) {
            var dayDiv = $("day"+day);
            if (dayDiv) {
                // Don't reload the view if the event is present in current view

                // Deselect day in date selector
                if (document.selectedDate)
                    document.selectedDate.deselect();

                // Select day in date selector
                var selectedLink = $$('table#dateSelectorTable span[day='+day+']');
                if (selectedLink.length > 0) {
                    selectedCell = selectedLink[0].getParentWithTagName("td");
                    $(selectedCell).selectElement();
                    document.selectedDate = selectedCell;
                } else
                    document.selectedDate = null;

                // Scroll to event
                if (scrollEvent) {
                    preventAutoScroll = false;
                    scrollDayView(scrollEvent);
                }

                setSelectedDayDate(day);

                return false;
            }
            else if (day.length == 6) {
                day += "01";
            }
        }
        url += "?day=" + day;
    }

    selectedCalendarCell = null;

    if (document.dayDisplayAjaxRequest) {
        document.dayDisplayAjaxRequest.aborted = true;
        document.dayDisplayAjaxRequest.abort();
    }
    document.dayDisplayAjaxRequest
        = triggerAjaxRequest(url, calendarDisplayCallback,
                             { "view": newView,
                               "day": day,
                               "scrollEvent": scrollEvent });

    return false;
}

function _ensureView(view) {
    if (currentView != view)
        changeCalendarDisplay(null, view);

    return false;
}

function onDayOverview() {
    return _ensureView("dayview");
}

function onMulticolumnDayOverview() {
    return _ensureView("multicolumndayview");
}

function onWeekOverview() {
    return _ensureView("weekview");
}

function onMonthOverview() {
    return _ensureView("monthview");
}

function refreshEventsAndTasks() {
    refreshEvents();
    refreshTasks();
}

function onCalendarReload() {
    if (!reloadWebCalendars()) {
        refreshEventsAndTasks();
        changeCalendarDisplay();
    }

    return false;
}

function reloadWebCalendars() {
    var remaining = [];
    var refreshOperations = { "remaining": remaining };
    if (UserSettings['Calendar']
        && UserSettings['Calendar']['WebCalendars']) {
        var webCalendars = UserSettings['Calendar']['WebCalendars'];

        var folders = $("calendarList");
        var calendarNodes = folders.childNodesWithTag("li");
        for (var i = 0; i < calendarNodes.length; i++) {
            var current = calendarNodes[i];
            var calendarID = current.getAttribute("id");
            var owner = current.getAttribute("owner");
            var realID = owner + ":Calendar/" + calendarID.substr(1);
            if (webCalendars[realID]) { /* is web calendar ? */
                remaining.push(realID);
                reloadWebCalendar(realID, refreshOperations);
            }
        }
    }

    return (remaining.length > 0);
}

var calendarReloadErrors = { "invalid-calendar-content":
                             _("the returned content was not valid calendar"
                               + " data"),
                             "http-error": _("an unknown http error occurred"
                                             + " during the load operation"),
                             "bad-url": _("the url in use is invalid or the"
                                          + " host is currently unreachable"),
                             "invalid-url": _("the url being used is invalid"
                                              + " or not handled") };

function reloadWebCalendar(folderID, refreshOperations) {
    var url = URLForFolderID(folderID) + "/reload";
    var cbData = { "folderID": folderID };
    if (refreshOperations) {
        cbData["refreshOperations"] = refreshOperations;
    }
    triggerAjaxRequest(url, reloadWebCalendarCallback, cbData);
}

function reloadWebCalendarCallback(http) {
    var cbData = http.callbackData;
    if (http.status == 200) {
        var result = http.responseText.evalJSON(true);
        var requireAuth = false;
        var success = false;
        if (result.status) {
            if (result.status == 401) {
                requireAuth = true;
            }
            else {
                if (result.status == 200) {
                    success = true;
                }
                else {
                    var errorMessage = _("An error occurred while importing calendar.");
                    if (result["error"]) {
                        var message = calendarReloadErrors[result["error"]];
                        errorMessage = (_("An error occurred while loading remote"
                                          + " calendar: %{0}.").formatted(message));
                    }
                    showAlertDialog (errorMessage);
                }
            }
        }
        else {
            var errorMessage = _("An error occurred while importing calendar.");
            if (result["error"]) {
                var message = calendarReloadErrors[result["error"]];
                errorMessage = (_("An error occurred while loading remote"
                                  + " calendar: %{0}.").formatted(message));
            }
            showAlertDialog (errorMessage);
        }

        if (requireAuth) {
            reauthenticateWebCalendar(cbData["folderID"], cbData);
        }
        else {
            var refreshOperations = cbData["refreshOperations"];
            if (refreshOperations) {
                var remaining = refreshOperations["remaining"];
                var calIdx = remaining.indexOf(cbData["folderID"]);
                remaining.splice(calIdx, 1);
                if (remaining.length == 0) {
                    refreshEventsAndTasks();
                    changeCalendarDisplay();
                }
            }
            else {
                if (success) {
                    refreshEventsAndTasks();
                    changeCalendarDisplay();
                }
            }
        }
    }
    else {
        showAlertDialog(_("An error occurred while importing calendar."));
        var refreshOperations = cbData["refreshOperations"];
        if (refreshOperations) {
            var remaining = refreshOperations["remaining"];
            var calIdx = remaining.indexOf(cbData["folderID"]);
            remaining.splice(calIdx, 1);
            if (remaining.length > 0) {
                var newFolderID = remaining[0];
                reloadWebCalendar(newFolderID, refreshOperations);
            }
        }
    }
}

function reauthenticateWebCalendar(folderID, refreshCBData) {
    var remoteURL = null;
    if (UserSettings['Calendar'] && UserSettings['Calendar']['WebCalendars']) {
        var webCalendars = UserSettings['Calendar']['WebCalendars'];
        remoteURL = webCalendars[folderID];
    }
    var parts = remoteURL.split("/");
    var hostname = parts[2];
    function authenticate(username, password) {
        disposeDialog();
        var url = URLForFolderID(folderID) + "/set-credentials";
        var parameters = ("username=" + encodeURIComponent(username)
                          + "&password=" + encodeURIComponent(password));
        triggerAjaxRequest(url, authenticateWebCalendarCallback, refreshCBData, parameters,
                           { "Content-type": "application/x-www-form-urlencoded" });
    }
    showAuthenticationDialog(_("Please identify yourself to %{0}")
                             .formatted(hostname),
                             authenticate);
}

function authenticateWebCalendarCallback(http) {
    var cbData = http.callbackData;
    var folderID = cbData["folderID"];
    var refreshOperations = cbData["refreshOperations"];
    if (isHttpStatus204(http.status)) {
        reloadWebCalendar(folderID, refreshOperations);
    }
    else {
        if (refreshOperations) {
            var remaining = refreshOperations["remaining"];
            var calIdx = remaining.indexOf(folderID);
            remaining.splice(calIdx, 1);
            if (remaining.length > 0) {
                var newFolderID = remaining[0];
                reloadWebCalendar(newFolderID, refreshOperations);
            }
        }
    }
}

function scrollDayView(scrollEvent) {
    if (!preventAutoScroll) {
        if (scrollEvent) {
            var contentView;
            var eventRow = $(scrollEvent);
            if (eventRow) {
                var eventBlocks = selectCalendarEvent(eventRow.calendar, eventRow.cname, eventRow.recurrenceTime);
                if (eventBlocks) {
                    var firstEvent = eventBlocks.first();

                    if (currentView == "monthview")
                        contentView = firstEvent.up("DIV.day");
                    else
                        contentView = $("daysView");

                    // Don't scroll to an all-day event
                    if (typeof eventRow.hour != "undefined") {
                        var top = firstEvent.cumulativeOffset()[1] - contentView.scrollTop;
                        // Don't scroll if the event is visible to the user
                        if (top < contentView.cumulativeOffset()[1])
                            contentView.scrollTop = firstEvent.cumulativeOffset()[1] - contentView.cumulativeOffset()[1];
                        else if (top > contentView.cumulativeOffset()[1] + contentView.getHeight() - firstEvent.getHeight())
                            contentView.scrollTop = firstEvent.cumulativeOffset()[1] - contentView.cumulativeOffset()[1];
                    }
                }
            }
        }
        else if (currentView != "monthview") {
            var contentView = $("daysView");
            var hours = (contentView.childNodesWithTag("div")[0]).childNodesWithTag("div");
            contentView.scrollTop = hours[dayStartHour].offsetTop;
        }
    }
}

function onClickableCellsDblClick(event) {
    var target = getTarget(event);
    // Hack to ignore double-click in the scrollbar
    if (target.hasClassName("dayHeader") || (this.scrollHeight - this.clientHeight <= 1)) {
        newEventFromWidget(this, 'event');
        Event.stop(event);
    }
}

function refreshCalendarEvents(scrollEvent) {
    var todayDate = new Date();
    var sd;
    var ed;

    if (!currentDay)
        currentDay = todayDate.getDayString();

    if (currentView == "dayview") {
        sd = currentDay;
        ed = sd;
    }
    else if (currentView == "weekview") {
        var startDate;
        startDate = currentDay.asDate();
        startDate = startDate.beginOfWeek();
        sd = startDate.getDayString();
        var endDate = new Date();
        endDate.setTime(startDate.getTime());
        endDate.addDays(6);
        ed = endDate.getDayString();
    }
    else {
        var monthDate;
        monthDate = currentDay.asDate();
        monthDate.setDate(1);
        sd = monthDate.beginOfWeek().getDayString();

        var lastMonthDate = new Date();
        lastMonthDate.setTime(monthDate.getTime());
        lastMonthDate.setMonth(monthDate.getMonth() + 1);
        lastMonthDate.addDays(-1);
        ed = lastMonthDate.endOfWeek().getDayString();
    }
    if (document.refreshCalendarEventsAjaxRequest) {
        document.refreshCalendarEventsAjaxRequest.aborted = true;
        document.refreshCalendarEventsAjaxRequest.abort();
    }
    var url = (ApplicationBaseURL + "/eventsblocks?sd=" + sd + "&ed=" + ed
               + "&view=" + currentView);
    document.refreshCalendarEventsAjaxRequest
        = triggerAjaxRequest(url, refreshCalendarEventsCallback,
                             {"startDate": sd, "endDate": ed,
                              "scrollEvent": scrollEvent});
}

function _parseEvents(list) {
    var newCalendarEvents = {};

    for (var i = 0; i < list.length; i++) {
        var event = list[i];
        var cname = event[0];
        var calendar = event[1];
        // log("parsed cname: " + cname + "; calendar: " + calendar);
        var calendarDict = newCalendarEvents[calendar];
        if (!calendarDict) {
            calendarDict = {};
            newCalendarEvents[calendar] = calendarDict;
        }
        var occurences = calendarDict[cname];
        if (!occurences) {
            occurences = [];
            calendarDict[cname] = occurences;
        }
        event.blocks = [];
        occurences.push(event);
    }

    return newCalendarEvents;
}

function _setupEventsDragAndDrop(events) {
    /* We setup the drag controllers for all the events.
       Since the same events may be listed more than once per calendar
       (repeating events), we must keep account of those that have already
       been setup. */
    var setupFlags = {};

    for (var i = 0; i < events.length; i++) {
        var cname = events[i][0];
        var calendar = events[i][1];
        var setupId = calendar + "_" + cname;
        if (!setupFlags[setupId]) {
            var occurrences = calendarEvents[calendar][cname];
            for (var j = 0; j < occurrences.length; j++) {
                var blocks = occurrences[j].blocks;
                var dragController = new SOGoEventDragController();
                dragController.updateDropCallback = updateEventFromDragging;
                dragController.attachToEventCells(blocks);
            }
            setupFlags[setupId] = true;
        }
    }
}

function refreshCalendarEventsCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        if (http.responseText.length > 0) {
            var eventsBlocks = http.responseText.evalJSON(true);
            calendarEvents = _parseEvents(eventsBlocks[0]);
            if (currentView == "monthview")
                _drawMonthCalendarEvents(eventsBlocks[2], eventsBlocks[0]);
            else {
                _drawCalendarAllDayEvents(eventsBlocks[1], eventsBlocks[0]);
                _drawCalendarEvents(eventsBlocks[2], eventsBlocks[0]);
            }
            _setupEventsDragAndDrop(eventsBlocks[0]);
            resetCategoriesStyles();
            onWindowResize(null);
        }
        if (http.callbackData["scrollEvent"])
            preventAutoScroll = false;
        scrollDayView(http.callbackData["scrollEvent"]);
    }
    else
        log("AJAX error when refreshing calendar events");
}

function resetCategoriesStyles() {
    if (categoriesStyleSheet == null) {
        categoriesStyleSheet = document.createElement("style");
        categoriesStyleSheet.type = "text/css";
        document.getElementsByTagName("head")[0].appendChild(categoriesStyleSheet);
    }
    else {
        if (Prototype.Browser.IE)
            while (categoriesStyleSheet.styleSheet.rules.length)
                categoriesStyleSheet.styleSheet.removeRule();
        else
            while (categoriesStyleSheet.firstChild)
                categoriesStyleSheet.removeChild(categoriesStyleSheet.firstChild);
    }

    if (UserDefaults['SOGoCalendarCategoriesColors']) {
        // Update stylesheet with new categories colors
        var selectors = [];
        var rules = [];
        categoriesStyles.keys().each(function(category) {
            var color = UserDefaults['SOGoCalendarCategoriesColors'][category];
            if (color) {
                rules[rules.length] = '{ border-right: 8px solid ' + color + '; }';
                selectors[selectors.length] = 'DIV.' + categoriesStyles.get(category);
            }
        });

        if (selectors.length > 0) {
            if (categoriesStyleSheet.styleSheet && categoriesStyleSheet.styleSheet.addRule) {
                // IE
                for (var i = 0; i < selectors.length; i++)
                    categoriesStyleSheet.styleSheet.addRule(selectors[i],
                                                            rules[i]);
            }
            else {
                // Mozilla + Safari
                for (var i = 0; i < selectors.length; i++)
                    categoriesStyleSheet.appendChild(document.createTextNode(selectors[i] +
                                                                             ' ' + rules[i]));
            }
        }
    }
}

function newBaseEventDIV(eventRep, event, eventText) {
    //	log ("0 cname = " + event[0]);
    //	log ("1 calendar = " + event[1]);
    //  log ("2 calendar name = " + event[2]);
    //	log ("3 status = " + event[3]);
    //	log ("4 title = " + event[4]);
    //	log ("5 start = " + event[5]);
    //	log ("6 end = " + event[6]);
    //	log ("7 location = " + event[7]);
    //	log ("8 isallday = " + event[8]);
    //	log ("9 classification = " + event[9]); // 0 = public, 1 = private, 2 = confidential
    //	log ("10 category = " + event[10]);
    //	log ("11 participants emails = " + event[11]);
    //	log ("12 participants states = " + event[12]);
    //	log ("13 owner = " + event[13]);
    //	log ("14 iscycle = " + event[14]);
    //	log ("15 nextalarm = " + event[15]);
    //	log ("16 recurrenceid = " + event[16]);
    //	log ("17 isexception = " + event[17]);
    //  log ("18 editable = " + event[18]);
    //  log ("19 erasable = " + event[19]);
    //  log ("20 ownerisorganizer = " + event[20]);

    var eventCell = createElement("div");
    eventCell.cname = event[0];
    eventCell.calendar = event[1];
    var startDate = new Date(event[5]*1000);
    if (startDate) {
        eventCell.startDate = event[5];
        eventCell.writeAttribute('day', startDate.getDayString());
        eventCell.writeAttribute('hour', event[8]? 'allday' : startDate.getHourString());
    }
//    if (event[8] == 1)
//        eventCell.addClassName("private");
//    else if (event[8] == 2)
//        eventCell.addClassName("confidential");
    if (eventRep.recurrenceTime)
        eventCell.recurrenceTime = eventRep.recurrenceTime;
    //eventCell.owner = event[12];
    eventCell.isException = event[17];
    eventCell.editable = event[18];
    eventCell.erasable = event[19] || IsSuperUser;
    eventCell.ownerIsOrganizer = event[20];
    eventCell.addClassName("event");
//    if (event[14] > 0)
//        eventCell.addClassName("alarm");

    var innerDiv = createElement("div");
    eventCell.appendChild(innerDiv);
    innerDiv.addClassName("eventInside");
    innerDiv.addClassName("calendarFolder" + event[1]);
    if (eventRep.userState >= 0 && userStates[eventRep.userState])
        innerDiv.addClassName(userStates[eventRep.userState]);

    var gradientDiv = createElement("div");
    innerDiv.appendChild(gradientDiv);
    gradientDiv.addClassName("gradient");

    var gradientImg = createElement("img");
    gradientDiv.appendChild(gradientImg);
    gradientImg.src = ResourcesURL + "/event-gradient.png";

    var textDiv = createElement("div");
    innerDiv.appendChild(textDiv);
    textDiv.addClassName("text");
    var iconSpan = createElement("span", null, "icons");
    textDiv.update(eventText.replace(/(\\r)?\\n/g, "<BR/>"));
    textDiv.appendChild(iconSpan);

    // Add alarm and classification icons
    if (event[9] == 1)
        createElement("img", null, null, {src: ResourcesURL + "/private.png"}, null, iconSpan);
    else if (event[9] == 2)
        createElement("img", null, null, {src: ResourcesURL + "/confidential.png"}, null, iconSpan);
    if (event[15] > 0)
        createElement("img", null, null, {src: ResourcesURL + "/alarm.png"}, null, iconSpan);

    if (event[10] != null) {
        var category = event[10].decodeEntities();
        var categoryStyle = categoriesStyles.get(category);
        if (!categoryStyle) {
            categoryStyle = 'category_' + categoriesStyles.keys().length;
            categoriesStyles.set([category], categoryStyle);
        }
        innerDiv.addClassName(categoryStyle);
    }
    eventCell.observe("contextmenu", onMenuCurrentView);

    if (event[3] == null) {
        // Status field is not defined -- user can't read event
        eventCell.observe("selectstart", listRowMouseDownHandler);
        eventCell.observe("click", onCalendarSelectEvent);
        eventCell.observe("dblclick", Event.stop);
    }
    else {
        // Status field is defined -- user can read event
        eventCell.observe("mousedown", listRowMouseDownHandler);
        eventCell.observe("click", onCalendarSelectEvent);
        eventCell.observe("dblclick", editDoubleClickedEvent);
        eventCell.observe("click", onViewEvent);
    }

    event.blocks.push(eventCell);

    return eventCell;
}

function _drawCalendarAllDayEvents(events, eventsData) {
    var headerView = $("calendarHeader");
    var subdivs = headerView.childNodesWithTag("div");
    var days = subdivs[1].childNodesWithTag("div");
    for (var i = 0; i < days.length; i++) {
        var parentDiv = days[i];
        for (var j = 0; j < events[i].length; j++) {
            var eventRep = events[i][j];
            var nbr = eventRep.nbr;
            var eventCell = newAllDayEventDIV(eventRep, eventsData[nbr]);
            parentDiv.appendChild(eventCell);
        }
    }

    resizeCalendarHeaderDIV();
}

/* When the list of all day events overflows, we resize it in order to contain
   at least 6 or 7 items. Afterwards we restore the regular scrollbar
   mechanism. */
function resizeCalendarHeaderDIV() {
    var headerView = $("calendarHeader");
    var daysView = $("daysView");
    if (headerView && daysView) {
        /* consts */
        var headerViewBaseHeight = 70;
        var daysViewBaseTop = 120;
        var maxDelta = 80;
        /* /consts */

        var maxEventPerDay = 0;

        var subdivs = headerView.childNodesWithTag("div");
        var days = subdivs[1].childNodesWithTag("div");
        for (var i = 0; i < days.length; i++) {
            var parentDiv = days[i];
            var divs = parentDiv.childNodesWithTag("div");
            if (divs.length > maxEventPerDay) {
                maxEventPerDay = divs.length;
            }
        }

        if (maxEventPerDay > 2) {
            var delta = ((maxEventPerDay - 2) * 22) + 10;
            if (delta > maxDelta) {
                delta = maxDelta;
            }
            daysView.style.top = String(delta + daysViewBaseTop) + "px";
            headerView.style.height = String(delta + headerViewBaseHeight) + "px";
        }
        else {
            daysView.style.top = null;
            headerView.style.height = null;
        }
    }
}

function newAllDayEventDIV(eventRep, event) {
    // cname, calendar, starts, lasts,
    // 		     startHour, endHour, title) {
    var eventCell = newBaseEventDIV(eventRep, event, event[4]);

    return eventCell;
}

function _drawCalendarEvents(events, eventsData) {
    var daysView = $("daysView");
    var subdivs = daysView.childNodesWithTag("div");
    for (var i = 0; i < subdivs.length; i++) {
        var subdiv = subdivs[i];
        if (subdiv.hasClassName("days")) {
            var days = subdiv.childNodesWithTag("div");
            for (var j = 0; j < days.length; j++) {
                var parentDiv = days[j].childNodesWithTag("div")[0];
                for (var k = 0; k < events[j].length; k++) {
                    var eventRep = events[j][k];
                    var nbr = eventRep.nbr;
                    var eventCell = newEventDIV(eventRep, eventsData[nbr]);
                    parentDiv.appendChild(eventCell);
                }
            }
        }
    }
}

function newEventDIV(eventRep, event) {
    var eventCell = newBaseEventDIV(eventRep, event, event[4]);

    var pc = 100 / eventRep.siblings;
    var left = Math.floor(eventRep.position * pc);
    eventCell.style.left = left + "%";
    var right = Math.floor(100 - (eventRep.position + 1) * pc);
    eventCell.style.right = right + "%";
    eventCell.addClassName("starts" + eventRep.start);
    eventCell.addClassName("lasts" + eventRep.length);

    if (event[7]) {
        var inside = eventCell.childNodesWithTag("div")[0];
        var textDiv = inside.childNodesWithTag("div")[1];
        textDiv.appendChild(createElement("br"));
        var span = createElement("span", null, "location");
        var text = _("Location:") + " " + event[7];
        span.update(text);
        textDiv.appendChild(span);
    }

    return eventCell;
}

function _drawMonthCalendarEvents(events, eventsData) {
    var daysView = $("monthDaysView");
    var days = daysView.childNodesWithTag("div");
    for (var i = 0; i < days.length; i++) {
        var parentDiv = days[i];
        for (var j = 0; j < events[i].length; j++) {
            var eventRep = events[i][j];
            var nbr = eventRep.nbr;
            var eventCell = newMonthEventDIV(eventRep, eventsData[nbr]);
            parentDiv.appendChild(eventCell);
        }
    }
}

function newMonthEventDIV(eventRep, event) {
    var eventText;
    if (event[8]) // all-day event
        eventText = event[4];
    else
        eventText = eventRep.starthour + " - " + event[4];

    var eventCell = newBaseEventDIV(eventRep, event,
                                    eventText);

    return eventCell;
}

function attachDragControllers(contentView) {
    var dayNodes = contentView.select("DIV.days DIV.day");
    for (var j = 0; j < dayNodes.length; j++) {
        var dayNode = dayNodes[j];
        if (dayNode.hasClassName("day")) {
            var dragController = new SOGoEventDragController();
            dragController.createDropCallback = newEventFromDragging;
            dragController.attachToDayNode(dayNode);
        }
    }
}

/* On IE, the scroll bar is part of the last element. For other browsers, we
   execute this method so that the "right" style attribute of the
   "calendarHeader" element can be computed. This is execute only once. */
function adjustCalendarHeaderDIV() {
    var dv = $("daysView");
    if (dv) {
        var ch = $("calendarHeader");
        var delta = ch.clientWidth - dv.clientWidth - 1;
        var styleElement = document.createElement("style");
        styleElement.type = "text/css";
        var selectors = ["DIV#calendarHeader DIV.dayLabels",
                         "DIV#calendarHeader DIV.days"];
        var rule = ("right: " + delta + "px");
        if (styleElement.styleSheet && styleElement.styleSheet.addRule) {
            // IE
            styleElement.styleSheet.addRule(selectors[0], rule);
            styleElement.styleSheet.addRule(selectors[1], rule);
        } else {
            // Mozilla + Firefox
            var styleText = selectors.join(",") + " { " + rule + "; }";
            styleElement.appendChild(document.createTextNode(styleText));
        }
        document.getElementsByTagName("head")[0].appendChild(styleElement);
        calendarHeaderAdjusted = true;
    }
}

function calendarDisplayCallback(http) {
    var div = $("calendarView");
    var daysView = $("daysView");
    var position = -1;

    // Check the previous view to restore the scrolling position
    if (daysView)
      position = daysView.scrollTop;
    preventAutoScroll = (position != -1);

    if (http.readyState == 4
        && http.status == 200) {
        document.dayDisplayAjaxRequest = null;
        div.update(http.responseText);

        // DOM has changed
        daysView = $("daysView");
        if (daysView) {
            if (preventAutoScroll)
                daysView.scrollTop = position;
            if (!calendarHeaderAdjusted)
                adjustCalendarHeaderDIV();
        }

        if (http.callbackData["view"])
            currentView = http.callbackData["view"];
        if (http.callbackData["day"])
            currentDay = http.callbackData["day"];

        // Initialize contextual menu
        var menu = new Array(onMenuNewEventClick,
                             onMenuNewTaskClick,
                             "-",
                             loadPreviousView,
                             loadNextView,
                             "-",
                             deleteEvent,
                             copyEventToPersonalCalendar,
                             onMenuRawEvent
                            );
        var observer;
        if (currentView == 'dayview') {
            observer = $("daysView");
        }
        else if (currentView == 'weekview') {
            observer = $("daysView");
        }
        else {
            observer = $("monthDaysView");
        }

        var contentView;
        if (currentView == "monthview")
            contentView = $("calendarContent");
        else {
            contentView = $("daysView");
            contentView.observe("scroll", onBodyClickHandler);
            attachDragControllers($("calendarHeader"));

            // Create a clone of the contextual menu for the all-day
            // events area
            var allDayViewMenu = Element.clone($("currentViewMenu"), true);
            allDayViewMenu.id = "allDayViewMenu";
            var newEventMenuItem = allDayViewMenu.select("LI").first();
            newEventMenuItem.writeAttribute("hour", "allday");
            $("currentViewMenu").parentNode.appendChild(allDayViewMenu);
            initMenu($("allDayViewMenu"), menu);
            var allDayArea = $$("DIV#calendarHeader DIV.days").first();
            allDayArea.observe("contextmenu", onMenuAllDayView);
        }
        attachDragControllers(contentView);

        // Attach contextual menu
        var currentViewMenu = $("currentViewMenu");
        initMenu(currentViewMenu, menu);
        observer.observe("contextmenu", onMenuCurrentView);
        currentViewMenu.prepareVisibility = onMenuCurrentViewPrepareVisibility;

        restoreSelectedDay();

        refreshCalendarEvents(http.callbackData.scrollEvent);

        var days = contentView.select("DIV.day");

        if (currentView == "monthview")
            for (var i = 0; i < days.length; i++) {
                days[i].observe("click", onCalendarSelectDay);
                days[i].observe("dblclick", onClickableCellsDblClick);
                days[i].observe("selectstart", listRowMouseDownHandler);
                //days[i].down(".dayHeader").observe("selectstart", listRowMouseDownHandler);
                if (currentView == "monthview")
                    days[i].observe("scroll", onBodyClickHandler);
            }
        else {
            var calendarHeader = $("calendarHeader");
            var headerDaysLabels = calendarHeader.select("DIV.dayLabels DIV.day");
            var headerDays = calendarHeader.select("DIV.days DIV.day");
            for (var i = 0; i < days.length; i++) {
                headerDays[i].hour = "allday";
                headerDaysLabels[i].observe("mousedown", listRowMouseDownHandler);
                headerDays[i].observe("click", onCalendarSelectDay);
                headerDays[i].observe("dblclick", onClickableCellsDblClick);
                days[i].observe("click", onCalendarSelectDay);

                var clickableCells = days[i].select("DIV.clickableHourCell");
                for (var j = 0; j < clickableCells.length; j++)
                    clickableCells[j].observe("dblclick", onClickableCellsDblClick);
            }
        }
    }
    else
        log ("calendarDisplayCallback Ajax error ("
             + http.readyState + "/" + http.status + ")");
}

function onEventsSelectionChange() {
    listOfSelection = this;
    this.removeClassName("_unfocused");

    var tasksList = $("tasksList");
    tasksList.addClassName("_unfocused");
    deselectAll(tasksList);

    var rows = $(this).getSelectedNodes();
    if (rows.length == 1) {
        var row = rows[0];
        changeCalendarDisplay( { "day": row.day,
                    "scrollEvent": row.getAttribute("id") } );
        changeDateSelectorDisplay(row.day, true);
    }
    else {
        // Select visible events cells
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            selectCalendarEvent(row.calendar, row.cname, row.recurrenceTime);
        }
    }
}

function onTasksSelectionChange(event) {
    listOfSelection = this;
    this.removeClassName("_unfocused");

    var target = Event.element(event);
    if (target.tagName == 'SPAN')
        target = target.parentNode;
    // Update selection
    onRowClick(event, target);

    var eventsList = $("eventsList");
    eventsList.addClassName("_unfocused");
    eventsList.deselectAll();
}

function _loadEventHref(href) {
    if (document.eventsListAjaxRequest) {
        document.eventsListAjaxRequest.aborted = true;
        document.eventsListAjaxRequest.abort();
    }
    var url = ApplicationBaseURL + "/" + href;
    document.eventsListAjaxRequest
        = triggerAjaxRequest(url, eventsListCallback, href);

    return false;
}

function _loadTasksHref(href) {
    if (document.tasksListAjaxRequest) {
        document.tasksListAjaxRequest.aborted = true;
        document.tasksListAjaxRequest.abort();
    }
    url = ApplicationBaseURL + "/" + href;

    var tasksList = $("tasksList");
    var selectedIds;
    if (tasksList)
        selectedIds = tasksList.getSelectedNodesId();
    else
        selectedIds = null;
    document.tasksListAjaxRequest
        = triggerAjaxRequest(url, tasksListCallback, selectedIds);

    return true;
}

function onHeaderClick(event) {
    var newSortAttribute;
    var headerId;

    headerId = this.getAttribute("id");

    if (headerId.startsWith('event'))
    {
        // This is needed to get the dom object and flip the triangle
        sorting["event-header"] = headerId;
        // Take away the 'events' and 'Header' and lowercase the result
        newSortAttribute = headerId.sub("Header", "").sub("event", "").toLowerCase();
        if (sorting["event-attribute"] == newSortAttribute)
            sorting["event-ascending"] = !sorting["event-ascending"];
        else
            sorting["event-ascending"] = true;
        sorting["event-attribute"] = newSortAttribute;
        refreshEvents();
    }
    else // Tasks
    {
        // This is needed to get the dom object and flip the triangle
        sorting["task-header"] = headerId;
        // Take away the 'tasks' and 'Header' and lowercase the result
        newSortAttribute = headerId.sub("Header", "").sub("task", "").toLowerCase();
        if (sorting["task-attribute"] == newSortAttribute)
            sorting["task-ascending"] = !sorting["task-ascending"];
        else
            sorting["task-ascending"] = true;
        sorting["task-attribute"] = newSortAttribute;
        refreshTasks();
    }

    Event.stop(event);
}

function refreshCurrentFolder(id) {
    if (id == 'tasks')
        refreshTasks();
    else
        refreshEvents();
}

/* refreshes the "unifinder" list */
function refreshEvents() {
    var specificSearch;
    var value = search["events"]["value"];

    if (value && value.length)
        specificSearch = ("&search=" + search["events"]["criteria"]
                          + "&value=" + escape(value.utf8encode()));
    else
        specificSearch = "";

    refreshAlarms();

    return _loadEventHref("eventslist?asc=" + sorting["event-ascending"]
                          + "&sort=" + sorting["event-attribute"]
                          + "&day=" + currentDay
                          + specificSearch
                          + "&filterpopup=" + eventListFilter);
}

function refreshTasks(setUserDefault) {
    var specificSearch;
    var value = search["tasks"]["value"];

    if (value && value.length)
      specificSearch = ("&search=" + search["tasks"]["criteria"]
                        + "&value=" + escape(value.utf8encode()));
    else
        specificSearch = "";

    if (setUserDefault == 1)
      specificSearch += "&setud=1";

    refreshAlarms();

    return _loadTasksHref("taskslist?show-completed=" + showCompletedTasks
                          + "&asc=" + sorting["task-ascending"]
                          + "&sort=" + sorting["task-attribute"]
                          + specificSearch
                          + "&filterpopup=" + taskListFilter);
}

function refreshEventsAndDisplay() {
    refreshEvents();
    changeCalendarDisplay();
}

function onEventsListFilterChange() {
    var node = $("filterpopup");

    eventListFilter = node.value;

    return refreshEvents();
}

function onTasksListFilterChange() {
  var node = $("tasksFilterpopup");
  
  taskListFilter = node.value;
  
  $("showHideCompletedTasks").disabled = taskListFilter == "view_overdue"     ||
                                         taskListFilter == "view_incomplete"  ||
                                         taskListFilter == "view_not_started";
  
  return refreshTasks();
}

function selectMonthInMenu(menu, month) {
    var entries = $(menu).select("LI");
    for (i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var entryMonth = entry.getAttribute("month");
        if (entryMonth == month)
            entry.addClassName("currentMonth");
        else
            entry.removeClassName("currentMonth");
    }
}

function selectYearInMenu(menu, year) {
    var entries = $(menu).select("LI");
    for (i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var entryYear = entry.innerHTML.strip();
        if (entryYear == year)
            entry.addClassName("currentMonth");
        else
            entry.removeClassName("currentMonth");
    }
}

function popupMonthMenu(event) {
    if (event.button == 0) {
        var id = this.getAttribute("id");
        if (id == "monthLabel")
            menuId = "monthListMenu";
        else
            menuId = "yearListMenu";

        var popup = $(menuId);
        if (id == "monthLabel")
            selectMonthInMenu(popup, this.getAttribute("month"));
        else
            selectYearInMenu(popup, this.innerHTML);

        popupToolbarMenu(this, menuId);
        Event.stop(event);
    }
}

function onMonthMenuItemClick(event) {
    var month = '' + this.getAttribute("month");
    var year = '' + $("yearLabel").innerHTML.strip();

    changeDateSelectorDisplay(year + month + "01", true);
}

function onYearMenuItemClick(event) {
    var month = '' + $("monthLabel").getAttribute("month");;
    var year = '' + this.innerHTML.strip();

    changeDateSelectorDisplay(year + month + "01", true);
}

function _eventBlocksMatching(calendar, cname, recurrenceTime) {
    var blocks = null;
    var events = calendarEvents[calendar];
    if (events) {
        var occurences = events[cname];
        if (occurences) {
            if (recurrenceTime) {
                for (var i = 0; i < occurences.length; i++) {
                    var occurence = occurences[i];
                    if (occurence[16] == recurrenceTime)
                        blocks = occurence.blocks;
                }
            }
            else {
                blocks = [];
                for (var i = 0; i < occurences.length; i++) {
                    var occurence = occurences[i];
                    blocks = blocks.concat(occurence.blocks);
                }
            }
        }
    }

    return blocks;
}

/** Select event in calendar view */
function selectCalendarEvent(calendar, cname, recurrenceTime) {
    var selection = _eventBlocksMatching(calendar, cname, recurrenceTime);
    if (selection) {
        for (var i = 0; i < selection.length; i++)
            selection[i].selectElement();
        if (selectedCalendarCell) {
            selectedCalendarCell = selectedCalendarCell.concat(selection);
        }
        else
            selectedCalendarCell = selection;
    }

    return selection;
}

function onSelectAll(event) {
    if (listOfSelection)
        listOfSelection.selectAll();
    else {
        // Select events cells
        var selectedBlocks = [];
        for (var c in calendarEvents) {
            var events = calendarEvents[c];
            for (var e in events) {
                var occurrences = events[e];
                for (var i = 0; i < occurrences.length; i++)
                    selectedBlocks = selectedBlocks.concat(occurrences[i].blocks);
            }
        }
        for (var i = 0; i < selectedBlocks.length; i++)
            selectedBlocks[i].selectElement();

        selectedCalendarCell = selectedBlocks;
    }

    return false;
}

function deselectAll(list) {
    if (list) {
        list.deselectAll();
    }
    else {
        $("eventsList").deselectAll();
        $("tasksList").deselectAll();
    }
    if (selectedCalendarCell) {
        for (var i = 0; i < selectedCalendarCell.length; i++)
            selectedCalendarCell[i].deselect();
        selectedCalendarCell = null;
    }
}

/** Click on an event in the calendar view */
function onCalendarSelectEvent(event, willShowContextualMenu) {
    var alreadySelected = false;

    // Look for event in events list
    // TODO: event will likely not be found if an Ajax query is refreshing
    // the events list.
    var rowID = this.calendar + "-" + this.cname;
    if (this.recurrenceTime)
        rowID += "-" + this.recurrenceTime;
    var row = $(rowID);

    // Check if event is already selected
    if (selectedCalendarCell)
        for (var i = 0; i < selectedCalendarCell.length; i++)
            if (selectedCalendarCell[i] == this) {
                alreadySelected = true;
                break;
            }

    if ((isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1)) {
        // If meta or ctrl key is pressed, inverse the selection
        if (alreadySelected) {
            this.deselect();
            selectedCalendarCell.splice(i, 1);
            if (row)
                row.deselect();

            return true;
        }
    }
    else if (!(alreadySelected && willShowContextualMenu)
             && event.shiftKey == 0) {
        // Unselect entries in events list and calendar view, unless :
        // - Shift key is pressed;
        // - Or right button is clicked and event is already selected.
        deselectAll();
        listOfSelection = null;
        this.selectElement();
        if (alreadySelected)
            selectedCalendarCell = [this];
    }

    if (!alreadySelected) {
        // Select event in calendar view
        selectCalendarEvent(this.calendar, this.cname, this.recurrenceTime);
    }
    // Select event in events list
    if (row) {
        var div = row.parentNode.parentNode.parentNode;
        div.scrollTop = row.offsetTop - (div.offsetHeight / 2);
        row.selectElement();
    }
}

function onCalendarSelectDay(event) {
    var day = this.getAttribute("day");
    var needRefresh = (eventListFilter == 'view_selectedday' && day != currentDay);

    setSelectedDayDate(day);
    changeDateSelectorDisplay(day);

    if (needRefresh)
        refreshEvents();

    var target = Event.findElement(event);
    var div = target.up('div');
    if (div && !div.hasClassName('event') && !div.hasClassName('eventInside') && !div.hasClassName('text') && !div.hasClassName('gradient')) {
        // Target is not an event -- unselect all events.
        listOfSelection = $("eventsList");
        deselectAll();
        return true;
    }

    if (listOfSelection) {
        listOfSelection.addClassName("_unfocused");
    }

    changeCalendarDisplay( { "day": currentDay } );
}

function setSelectedDayDate(dayDate) {
    if (selectedDayDate != dayDate) {
        var day = $("day" + selectedDayDate);
        if (day)
            day.removeClassName("selectedDay");
        var allDay = $("allDay" + selectedDayDate);
        if (allDay)
            allDay.removeClassName("selectedDay");

        selectedDayDate = dayDate;

        day = $("day" + selectedDayDate);
        day.addClassName("selectedDay");
        selectedDayNumber = day.readAttribute("day-number");
        allDay = $("allDay" + selectedDayDate);
        if (allDay)
            allDay.addClassName("selectedDay");
    }
}

/* after loading a new view, to reselect the currently selected day */
function restoreSelectedDay() {
    var day = null;
    if (selectedDayDate.length > 0)
        day = $("day" + selectedDayDate);
    if (!day) {
        if (selectedDayNumber > -1)
            selectedDayDate = findDateFromDayNumber(selectedDayNumber);
        else
            selectedDayDate = currentDay;
        if (selectedDayDate && selectedDayDate.length > 0)
            day = $("day" + selectedDayDate);
    }
    if (day) {
        selectedDayDate = null;
        setSelectedDayDate(day.id.substr(3));
    }
}

function findDateFromDayNumber(dayNumber) {
    var view;
    if (currentView == "monthview")
        view = $("monthDaysView");
    else
        view = $("daysView");
    var days = view.select(".day");
    return (dayNumber < days.size()) ? days[dayNumber].readAttribute("day") : null;
}

function onShowCompletedTasks(event) {
    showCompletedTasks = (this.checked ? 1 : 0);

    return refreshTasks(1);
}

function updateTaskStatus(event) {
    var newStatus = (this.checked ? 1 : 0);
    _updateTaskCompletion (this.up("tr"), newStatus);
    return false;
}

function updateCalendarStatus(event) {
    var list = [];
    var newStatus = (this.checked ? 1 : 0);

    var nodes = $("calendarList").childNodesWithTag("li");
    for (var i = 0; i < nodes.length; i++) {
        var input = $(nodes[i]).childNodesWithTag("input")[0];
        if (input.checked) {
            var folderId = nodes[i].getAttribute("id");
            var elems = folderId.split(":");
            if (elems.length > 1)
                list.push(elems[0]);
            else
                list.push(UserLogin);
        }
    }

    //   if (!list.length) {
    //      list.push(UserLogin);
    //      nodes[0].childNodesWithTag("input")[0].checked = true;
    //   }

    //   ApplicationBaseURL = (UserFolderURL + "Groups/_custom_"
    // 			+ list.join(",") + "/Calendar/");

    if (event) {
        var folderID = this.parentNode.getAttribute("id");
        var urlstr = URLForFolderID(folderID);
        if (newStatus)
            urlstr += "/activateFolder";
        else
            urlstr += "/deactivateFolder";
        //log("updateCalendarStatus: ajax request = " + urlstr + ", folderID = " + folderID);
        triggerAjaxRequest(urlstr, calendarStatusCallback, folderID);
    }
    else {
        updateCalendarsList();
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();
    }

    if (event) {
        event.returnValue = true;
    }
}

function calendarStatusCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            refreshEvents();
            refreshTasks();
            changeCalendarDisplay();
        }
        else {
            var folder = $(http.callbackData);
            var input = folder.childNodesWithTag("input")[0];
            input.checked = (!input.checked);
        }
    }
    else
        log("calendarStatusCallback Ajax error");
}

function calendarEntryCallback(http) {
    if (http.readyState == 4) {
        var denied = !isHttpStatus204(http.status);
        var entry = $(http.callbackData);
        if (denied)
            entry.addClassName("denied");
        else
            entry.removeClassName("denied");
    }
}

function updateCalendarsList(method) {
    var list = $("calendarList").childNodesWithTag("li");
    for (var i = 0; i < list.length; i++) {
        var folderID = list[i].getAttribute("id");
        var url = URLForFolderID(folderID) + "/canAccessContent";
        triggerAjaxRequest(url, calendarEntryCallback, folderID);
    }
}

//function validateBrowseURL(input) {
//    var button = $("browseURLBtn");
//
//    if (input.value.length) {
//        if (!button.enabled)
//            enableAnchor(button);
//    } else if (!button.disabled)
//        disableAnchor(button);
//}

//function browseURL(anchor, event) {
//    if (event.button == 0) {
//        var input = $("url");
//        var url = input.value;
//        if (url.length)
//            window.open(url, '_blank');
//    }
//
//    return false;
//}

function onCalendarsMenuPrepareVisibility() {
    var folders = $("calendarList");
    var selected = folders.getSelectedNodes();
    if (selected.length > 0) {
        var folderOwner = selected[0].getAttribute("owner");

        var lis = $(this).down("ul").childElements();

        /* distance: sharing = length - 1, export = length - 7 */
        var endDists = [ 1, 7 ];
        for (var i = 0; i < endDists.length; i++) {
            var dist = lis.length - endDists[i];
            var option = $(lis[dist]);
            if (folderOwner == UserLogin || IsSuperUser)
                option.removeClassName("disabled");
            else
                option.addClassName("disabled");
        }

        var deleteCalendarOption = $("deleteCalendarMenuItem");
        // Swith between Delete and Unsubscribe
        if (folderOwner == UserLogin)
            deleteCalendarOption.update(_("Delete Calendar"));
        else
            deleteCalendarOption.update(_("Unsubscribe Calendar"));

        return true;
    }
    return false;
}

function onMenuCurrentViewPrepareVisibility() {
    var options = $(this).down("ul");
    var deleteOption = options.down("li", 6);
    var copyOption = options.down("li", 7);
    var rawOption = options.down("li", 8);
    if (!selectedCalendarCell) {
        deleteOption.addClassName("disabled");
        copyOption.addClassName("disabled");
        rawOption.addClassName("disabled");
    }
    else {
        deleteOption.removeClassName("disabled");
        var calendarEntry = $("/" + selectedCalendarCell[0].calendar);
        if (calendarEntry.getAttribute("owner") == UserLogin)
            copyOption.addClassName("disabled");
        else
            copyOption.removeClassName("disabled");
	if (selectedCalendarCell.length == 1) {
	    // show raw content is only allowed for single event
            rawOption.removeClassName("disabled");
        }
	else
            rawOption.addClassName("disabled");
    }

    return true;
}

function onTasksListMenuPrepareVisibility() {
    var options = $(this).down("ul");
    var rawOption = options.down("li", 6);

    var selectedTasks = $$("#tasksList ._selected");
    if (selectedTasks.length == 1)
        rawOption.removeClassName("disabled");
    else
        rawOption.addClassName("disabled");

    return true;
}
function getMenus() {
  var menus = {};
  
  var dateMenu = [];
  for (var i = 0; i < 12; i++)
    dateMenu.push(onMonthMenuItemClick);
  menus["monthListMenu"] = dateMenu;
  
  dateMenu = [];
  for (var i = 0; i < 11; i++)
    dateMenu.push(onYearMenuItemClick);
  menus["yearListMenu"] = dateMenu;
  
  menus["eventsListMenu"] = new Array(onMenuNewEventClick, "-",
                                      onMenuNewTaskClick,
                                      editEvent, deleteEvent, "-",
                                      onSelectAll, "-",
                                      null, null);
  menus["calendarsMenu"] = new Array(onCalendarModify,
                                     "-",
                                     onCalendarNew, onCalendarRemove,
                                     "-", onCalendarExport, onCalendarImport,
                                     null, "-", null, "-", onMenuSharing);
  menus["eventSearchMenu"] = new Array(setSearchCriteria, setSearchCriteria, setSearchCriteria);
  
  menus["tasksListMenu"] = new Array (editEvent, newTask, "-",
                                      marksTasksAsCompleted, deleteEvent, "-",
                                      onMenuRawTask);
  menus["taskSearchMenu"] = new Array(setSearchCriteria, setSearchCriteria, setSearchCriteria);
  
  var calendarsMenu = $("calendarsMenu");
  if (calendarsMenu)
    calendarsMenu.prepareVisibility = onCalendarsMenuPrepareVisibility;
  
  var tasksListMenu = $("tasksListMenu");
  if (tasksListMenu)
    tasksListMenu.prepareVisibility = onTasksListMenuPrepareVisibility;
  
  return menus;
}

function newTask () {
    return newEventFromWidget(this, 'task');
}

function marksTasksAsCompleted () {
    var selectedTasks = $$("#tasksList ._selected");

    for (var i = 0; i < selectedTasks.length; i++) {
        var task = selectedTasks[i];
        _updateTaskCompletion (task, 1);
    }
}

function _updateTaskCompletion (task, value) {
    url = (ApplicationBaseURL + "/" + task.calendar
           + "/" + task.cname + "/changeStatus?status=" + value);

    triggerAjaxRequest(url, refreshTasks, null);

    return false;
}

function onMenuRawTask(event) {
    var selectedTasks = $$("#tasksList ._selected");
    if (selectedTasks.length != 1) {
      return;
    }

    var url = ApplicationBaseURL + "/" + selectedTasks[0].calendar  + "/" + selectedTasks[0].cname + "/raw"
    openGenericWindow(url);
}


function onMenuSharing(event) {
    if ($(this).hasClassName("disabled"))
        return;

    var folders = $("calendarList");
    var selected = folders.getSelectedNodes()[0];
    /* FIXME: activation of the context menu should preferably select the entry
       above which the event has occurred */
    if (selected) {
        var folderID = selected.getAttribute("id");
        var urlstr = URLForFolderID(folderID) + "/acls";

        openAclWindow(urlstr);
    }
}

function onMenuCurrentView(event) {
    var target = getTarget(event);
    $("eventDialog").hide();
    if (this.hasClassName('event')) {
        // Select event cell
        var onClick = onCalendarSelectEvent.bind(this);
        onClick(event, true);
        target = this;
    }
    popupMenu(event, 'currentViewMenu', target);
}

function onMenuAllDayView(event) {
    $("eventDialog").hide();
    popupMenu(event, 'allDayViewMenu', getTarget(event));
}

function configureDragHandles() {
    var handle = $("verticalDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.leftBlock = $("leftPanel");
        handle.rightBlock = $("rightPanel");
    }

    handle = $("rightDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.upperBlock = $("schedulerTabs");
        handle.lowerBlock = $("calendarView");
    }
}

function initCalendarSelector() {
    var selector = $("calendarSelector");
    updateCalendarStatus(); // triggers the initial events refresh
    selector.changeNotification = updateCalendarsList;

    var list = $("calendarList");
    list.on("mousedown", onCalendarSelectionChange);
    list.on("dblclick", onCalendarModify);
    list.on("selectstart", listRowMouseDownHandler);
    list.attachMenu("calendarsMenu");

    var items = list.childNodesWithTag("li");
    for (var i = 0; i < items.length; i++) {
        var input = items[i].childNodesWithTag("input")[0];
        $(input).observe("click", clickEventWrapper(updateCalendarStatus));
    }

    var links = $("calendarSelectorButtons").childNodesWithTag("a");
    $(links[0]).observe("click", clickEventWrapper(onCalendarNew));
    $(links[1]).observe("click", clickEventWrapper(onCalendarWebAdd));
    $(links[2]).observe("click", clickEventWrapper(onCalendarAdd));
    $(links[3]).observe("click", clickEventWrapper(onCalendarRemove));
}

function onCalendarSelectionChange(event) {
    var target = Event.element(event);
    if (target.tagName == 'DIV') {
        target = target.parentNode;
    }

    onRowClick(event, target);
}

function onCalendarModify(event) {
    var folders = $("calendarList");
    var selected = folders.getSelectedNodes()[0];
    var calendarID = selected.getAttribute("id");
    var owner = selected.getAttribute("owner");
    var url = ApplicationBaseURL + calendarID + "/properties";
    var windowID = sanitizeWindowName(calendarID + " properties");
    var width = 410;
    var height = 410;
    var isWebCalendar = false;
    if (UserSettings['Calendar']
        && UserSettings['Calendar']['WebCalendars']) {
        var webCalendars = UserSettings['Calendar']['WebCalendars'];
        var realID = owner + ":Calendar/" + calendarID.substr (1, calendarID.length - 1);
        if (webCalendars[realID]) {
            isWebCalendar = true;
        }
    }
    if (Prototype.Browser.IE) height += 10;

    if (owner == UserLogin) {
        height += 20;
    }
    if (isWebCalendar) {
        height += 26;
    }
    else if (calendarID == "/personal") {
        height -= 26;
    }

    var properties = window.open(url, windowID,
                                 "width="+width+",height="+height+",resizable=0");
    properties.focus();
}

function updateCalendarProperties(calendarID, calendarName, calendarColor) {
    var idParts = calendarID.split(":");
    var folderName = idParts[1].split("/")[1];
    var nodeID;

    if (idParts[0] != UserLogin)
        nodeID = "/" + idParts[0].asCSSIdentifier() + "_" + folderName;
    else
        nodeID = "/" + folderName;
	//   log("nodeID: " + nodeID);
    var calendarNode = $(nodeID);
    var childNodes = calendarNode.childNodes;
    var textNode = childNodes[childNodes.length-1];
    if (textNode.tagName == 'DIV')
        calendarNode.appendChild(document.createTextNode(calendarName));
    else
        childNodes[childNodes.length-1].nodeValue = calendarName;

    appendStyleElement(nodeID, calendarColor);
}

function onCalendarNew(event) {
    showPromptDialog(_("New Calendar..."), _("Name of the Calendar"), onCalendarNewConfirm);
    preventDefault(event);
}

function onCalendarNewConfirm() {
    createFolder(this.value, appendCalendar);
    disposeDialog();
}

function onCalendarAdd(event) {
    openUserFolderSelector(onFolderSubscribeCB, "calendar");
    preventDefault(event);
}

function onCalendarWebAdd(event) {
    showPromptDialog(_("Subscribe to a web calendar..."), _("URL of the Calendar"), onCalendarWebAddConfirm);
}

function onCalendarWebAddConfirm() {
    disposeDialog();
    var calendarUrl = this.value;
    if (calendarUrl) {
        var url = ApplicationBaseURL + "/addWebCalendar";
        var parameters = "url=" + encodeURIComponent(calendarUrl);
        triggerAjaxRequest(url, addWebCalendarCallback, calendarUrl, parameters,
                           { "Content-type": "application/x-www-form-urlencoded" });
    }
}

function addWebCalendarCallback(http) {
    if (http.status == 200) {
        var data = http.responseText.evalJSON(true);
        if (!data || data["error"] || !data["name"] || !data["folderID"]) {
            showAlertDialog (_("An error occurred while importing calendar."));
        }
        else {
            if (UserSettings['Calendar']) {
                var webCalendars = UserSettings['Calendar']['WebCalendars'];
                if (!webCalendars) {
                    webCalendars = {};
                    UserSettings['Calendar']['WebCalendars'] = webCalendars;
                }
                webCalendars[data["folderID"]] = http.callbackData;
            }

            appendCalendar(data["name"], data["folderID"]);
            reloadWebCalendar(data["folderID"]);
        }
    }
    else {
        showAlertDialog (_("An error occurred while importing calendar."));
    }

    // if (data.imported) {
    //     appendCalendar(data.displayname, "/" + data.name);
    //     refreshEvents();
    //     refreshTasks();
    //     changeCalendarDisplay();
    // }
    // else if (data.status && data.status == 401) {
    //     reauthenticateWebCalendar(data.name, data.url);
    // }
    // else {
    // }
}

function onCalendarExport(event) {
    var node = $("calendarList").getSelectedNodes().first();
    var folderId = node.getAttribute("id");
    var url = URLForFolderID(folderId) + ".ics/export";
    window.location.href = url;
}

function onCalendarImport(event) {
    var list = $("calendarList");
    var node = list.getSelectedNodes().first();
    var folderId = node.getAttribute("id");

    var url = ApplicationBaseURL + folderId + "/import";
    $("uploadForm").action = url;
    $("calendarFile").value = "";

    var cellPosition = node.cumulativeOffset();
    var cellDimensions = node.getDimensions();
    var left = cellDimensions['width'] - 20;
    var top = cellPosition[1];
    top -= list.scrollTop;

    var div = $("uploadDialog");
    var res = $("uploadResults");
    res.setStyle({ top: top + "px", left: left + "px" });
    div.setStyle({ top: top + "px", left: left + "px" });
    div.show();
}
function hideCalendarImport(event) {
    $("uploadDialog").hide();
}
function hideImportResults(event) {
    $("uploadResults").hide();
}
function validateUploadForm() {
    rc = false;
    if ($("calendarFile").value.length) {
      var btn = jQuery('#uploadSubmit');
      jQuery('#uploadCancel').fadeOut('fast');
      btn.addClass("disabled");
      btn.children('span').text(_('Uploading'));
      rc = true;
    }
    return rc;
}
function uploadCompleted(response) {
    jQuery('#uploadCancel').show();
    var btn = jQuery('#uploadSubmit');
    btn.removeClass("disabled");
    btn.children('span').text(_('Upload'));
    var div = $("uploadResults");

    try {
	data = response.evalJSON(true);

	if (data.imported < 0)
            $("uploadResultsContent").update(_("An error occurred while importing calendar."));
	else if (data.imported == 0)
            $("uploadResultsContent").update(_("No event was imported."));
	else {
            $("uploadResultsContent").update(_("A total of %{0} events were imported in the calendar.").formatted(data.imported));
            refreshEventsAndDisplay();
	}
    } catch (e) {
	$("uploadResultsContent").update(_("An error occurred while importing calendar."));
    }

    hideCalendarImport();
    $("uploadResults").show();
}

function appendCalendar(folderName, folderPath) {
    var owner;

    if (folderPath) {
        owner = getSubscribedFolderOwner(folderPath);
        folderPath = accessToSubscribedFolder(folderPath);
    }
    else
        folderPath = "/" + folderName;

    if (!owner)
        owner = UserLogin;

    //log ("append name: " + folderName + "; path: " + folderPath + "; owner: " + owner);

    if ($(folderPath))
        showAlertDialog(_("You have already subscribed to that folder!"));
    else {
        var calendarList = $("calendarList");
        var items = calendarList.select("li");
        var li = document.createElement("li");

        // Add the calendar to the proper place
        var i = getListIndexForFolder(items, owner, folderName);
        if (i != items.length) // User is subscribed to other calendars of the same owner
            calendarList.insertBefore(li, items[i]);
        else
            calendarList.appendChild(li);
        $(li).writeAttribute("id", folderPath);
        $(li).writeAttribute("owner", owner);

        var checkBox = createElement("input", null, "checkBox", { checked: 1 },
                                     { type: "checkbox" }, li);

        li.appendChild(document.createTextNode(" "));

        var colorBox = document.createElement("div");
        li.appendChild(colorBox);
        li.appendChild(document.createTextNode(folderName));
        colorBox.appendChild(document.createTextNode("\u00a0"));

        $(colorBox).addClassName("colorBox");
        $(colorBox).addClassName('calendarFolder' + folderPath.substr(1));

        // Check the checkbox (required for IE)
        li.getElementsByTagName("input")[0].checked = true;

        // Register event on checkbox
        $(checkBox).on("click", clickEventWrapper(updateCalendarStatus));

        var url = URLForFolderID(folderPath) + "/canAccessContent";
        triggerAjaxRequest(url, calendarEntryCallback, folderPath);

        // Update CSS for events color
        appendStyleElement(folderPath, "#AAAAAA");
    }
}

function appendStyleElement(folderPath, color) {
    if (document.styleSheets) {
        var fgColor = getContrastingTextColor(color);
        var styleElement = document.createElement("style");
        styleElement.type = "text/css";

        var styles = ' .calendarFolder' + folderPath.substr(1)
            + ' { background-color: ' + color + ' !important;' + ' color: ' + fgColor + ' !important; }'
            + ' div.colorBox.calendarFolder' + folderPath.substr(1)
            + ' { color: ' + color + ' !important; }';

        if (styleElement.styleSheet) styleElement.styleSheet.cssText = styles; // IE
        else styleElement.appendChild(document.createTextNode(styles));        // Mozilla + Webkit

        document.getElementsByTagName("head")[0].appendChild(styleElement);
    }
}

function onFolderSubscribeCB(folderData) {
    var folder = $(folderData["folder"]);
    if (!folder) {
        appendCalendar(folderData["folderName"].unescapeHTML(), folderData["folder"]);
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();
    }
}

function onFolderUnsubscribeCB(folderId) {
    var node = $(folderId);
    var list = $(node.parentNode);
    node.deselect();
    list.removeChild(node);
    if (removeFolderRequestCount == 0) {
        list.down("li").selectElement(); // personal calendar
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();
    }
}

function onCalendarRemove(event) {
    if (removeFolderRequestCount == 0) {
        var nodes = $("calendarList").getSelectedNodes();
        for (var i = 0; i < nodes.length; i++) {
            var owner = nodes[i].getAttribute("owner");
            var folderId = nodes[i].getAttribute("id");
            if (owner == UserLogin) {
                if (folderId == "/personal") {
                    var label = labels["You cannot remove nor unsubscribe from your"
                                       + " personal calendar."];
                    showAlertDialog(label);
                }
                else {
                    deletePersonalCalendar(nodes[i]);
                }
            }
            else {
                var folderUrl = ApplicationBaseURL + folderId;
                nodes[i].deselect();
                unsubscribeFromFolder(folderUrl, owner,
                                      onFolderUnsubscribeCB, folderId);
            }
        }
    }

    preventDefault(event);
}

function deletePersonalCalendar(folderElement) {
    showConfirmDialog(_("Confirmation"),
                      _("Are you sure you want to delete the calendar \"%{0}\"?").formatted(folderElement.lastChild.nodeValue.strip()),
                      deletePersonalCalendarConfirm.bind(folderElement));
}

function deletePersonalCalendarConfirm() {
    var folderId = this.getAttribute("id").substr(1);
    this.deselect();
    this.hide();
    removeFolderRequestCount++;
    var url = ApplicationBaseURL + "/" + folderId + "/delete";
    triggerAjaxRequest(url, deletePersonalCalendarCallback, this);
    disposeDialog();
}

function deletePersonalCalendarCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var folderElement = http.callbackData;
            if (folderElement) {
                var list = folderElement.parentNode;
                list.removeChild(folderElement);
            }
            removeFolderRequestCount--;
            if (removeFolderRequestCount == 0) {
                refreshEvents();
                refreshTasks();
                changeCalendarDisplay();
            }
        }
    }
    else {
        log ("ajax problem 5: " + http.status);
        var folderElement = http.callbackData;
        folderElement.show();
    }
}

function configureLists() {
    // Move calendar view if lists are collapsed
    if (!$("schedulerTabs").visible()) {
        $('calendarView').setStyle({ top: '0' }).show();
    }

    // TASK LIST
    var list = $("tasksList");
    list.multiselect = true;
    configureSortableTableHeaders(list);
    TableKit.Resizable.init(list, {'trueResize' : true, 'keepWidth' : true});
    list.down("tbody").on("mousedown", onTasksSelectionChange);
    list.down("tbody").on("selectstart", listRowMouseDownHandler);
    list.down("tbody").attachMenu("tasksListMenu");

    var input = $("showHideCompletedTasks");
    input.observe("click", onShowCompletedTasks);

    if (showCompletedTasks)
      input.checked = true;
  
    // EVENT LIST
    list = $("eventsList");
    list.multiselect = true;
    configureSortableTableHeaders(list);
    TableKit.Resizable.init(list, {'trueResize' : true, 'keepWidth' : true});
    list.down("tbody").on("mousedown", onEventsSelectionChange);
    list.down("tbody").attachMenu("eventsListMenu");
}

function initDateSelectorEvents() {
    var arrow = $("rightArrow");
    arrow.observe("click", onDateSelectorGotoMonth);
    arrow = $("leftArrow");
    arrow.observe("click", onDateSelectorGotoMonth);

    var menuButton = $("monthLabel");
    menuButton.observe("click", popupMonthMenu);
    menuButton = $("yearLabel");
    menuButton.observe("click", popupMonthMenu);
}

function onBodyClickHandler(event) {
    $("eventDialog").hide();
}

function onWindowResize(event) {
    var handle = $("verticalDragHandle");
    if (handle)
        handle.adjust();
    handle = $("rightDragHandle");
    if (handle)
        handle.adjust();

    if (!$(document.body).hasClassName("popup"))
        drawNowLine();
}

function drawNowLine() {
    var d = new Date();
    var hours = d.getHours();
    var minutes = d.getMinutes();

    if (currentView == "dayview") {
        var today = new Date();
        var m = parseInt(today.getMonth()) + 1;
        var d = today.getDate();
        if (m < 10)
            m = "0" + m;
        if (d < 10)
            d = "0" + d;
        var day = today.getFullYear() + "" + m + "" + d;
        var targets = $$("DIV#daysView DIV.days DIV.day[day=" + day
                         + "] DIV.clickableHourCell");
    }
    else if (currentView == "weekview")
        var targets = $$("DIV#daysView DIV.days DIV.dayOfToday DIV.clickableHourCell");

    if (targets) {
        var target = targets[hours];

        if (target) {
            var div = $("nowLineDisplay");
            if (!div)
                div = new Element("div", {'id': 'nowLineDisplay'});

            div.style.top = parseInt((minutes * target.offsetHeight / 60) - 1) + "px";
            target.insertBefore(div, target.firstChild);

            setTimeout("drawNowLine ();", 60000); // 1 min.
        }
    }
}

function onListCollapse(event, element) {
    var img = element.select('img').first();
    var tabs = $("schedulerTabs");
    var handle = $("rightDragHandle");
    var view = jQuery("#calendarView");
    var state = 'collapse';

    if (tabs.visible()) {
        img.removeClassName('collapse').addClassName('rise');
        handle.hide();
        view.animate({ top: '0' }, 200, function() {
            tabs.hide();
        });
    }
    else {
        state = 'rise';
        img.removeClassName('rise').addClassName('collapse');
        tabs.show();
        tabs.controller.onWindowResize();
        view.animate({ top: handle.getStyle('top') }, 200, function() {
            handle.show();
        });
    }

    var url =  ApplicationBaseURL + "/saveListState";
    var params = "state=" + state;
    triggerAjaxRequest(url, null, null, params,
                       { "Content-type": "application/x-www-form-urlencoded" });

}

function onDocumentKeydown(event) {
    var target = Event.element(event);
    if (target.tagName != "INPUT") {
        var keyCode = event.keyCode;
        if (!keyCode) {
            keyCode = event.charCode;
            if (keyCode == "a".charCodeAt(0))
                keyCode = "A".charCodeAt(0);
            else if (keyCode == "c".charCodeAt(0))
                keyCode = "C".charCodeAt(0);
            else if (keyCode == "v".charCodeAt(0))
                keyCode = "V".charCodeAt(0);
        }
        if (keyCode == Event.KEY_DELETE
            || (keyCode == Event.KEY_BACKSPACE)) {
            $("eventDialog").hide();
            deleteEvent();
            event.stop();
        }
        else if (((isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1))
                 && keyCode == "A".charCodeAt(0)) {  // Ctrl-A
            onSelectAll(event);
            Event.stop(event);
         }
        else if (((isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1))
                 && keyCode == "C".charCodeAt(0)) {  // Ctrl-C
            copyEventToClipboard();
        }
        else if (((isMac() && event.metaKey == 1) || (!isMac() && event.ctrlKey == 1))
                 && keyCode == "V".charCodeAt(0)) {  // Ctrl-V
            copyEventFromClipboard();
        }
    }
}

function saveTabState(event) {
    var tab = $(event).memo;

    var url =  ApplicationBaseURL + "/saveSelectedList";
    var params = "list=" + tab;
    triggerAjaxRequest(url, null, null, params,
                       { "Content-type": "application/x-www-form-urlencoded" });
}

function initScheduler() {
    sorting["event-header"] = "";
    sorting["task-header"] = "";
    sorting["event-attribute"] = "start";
    sorting["task-attribute"] = "end";
    sorting["event-ascending"] = true;
    sorting["task-ascending"] = true;

    if (!$(document.body).hasClassName("popup")) {
        var node = $("filterpopup");
        eventListFilter = node.value;

        var tabsContainer = $("schedulerTabs");
        var controller = new SOGoTabsController();
        controller.attachToTabsContainer(tabsContainer);
        tabsContainer.on("tabs:click", saveTabState);
      
        if (UserSettings['ShowCompletedTasks']) {
            showCompletedTasks = parseInt(UserSettings['ShowCompletedTasks']);
        }
        else {
            showCompletedTasks = 0;
        }
      
        initDateSelectorEvents();
        initCalendarSelector();
        configureSearchField();
        configureLists();
        $(document.body).observe("click", onBodyClickHandler);
        // Calendar import form
        $("uploadCancel").observe("click", hideCalendarImport);
        $("uploadOK").observe("click", hideImportResults);
        $("calendarView").on("click", "#listCollapse", onListCollapse);
        Event.observe(document, "keydown", onDocumentKeydown);
    }

    onWindowResize.defer();
    Event.observe(window, "resize", onWindowResize);
}

document.observe("generic:loaded", initScheduler);
