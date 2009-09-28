/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/* JavaScript for SOGoCalendar */

var listFilter = 'view_today';

var listOfSelection = null;
var selectedCalendarCell;

var showCompletedTasks;;

var currentDay = '';

var cachedDateSelectors = [];

var contactSelectorAction = 'calendars-contacts';

var eventsToDelete = [];
var calendarsOfEventsToDelete = [];

var usersRightsWindowHeight = 215;
var usersRightsWindowWidth = 502;

var calendarEvents = null;

var preventAutoScroll = false;

var userStates = [ "needs-action", "accepted", "declined", "tentative" ];

function newEvent(sender, type) {
    var day = $(sender).readAttribute("day");
    if (!day)
        day = currentDay;
    var hour = sender.readAttribute("hour");
    var folder = getSelectedFolder();
    var folderID = folder.readAttribute("id");
    var urlstr = ApplicationBaseURL + folderID + "/new" + type;
    var params = [];
    if (day)
        params.push("day=" + day);
    if (hour)
        params.push("hm=" + hour);
    if (params.length > 0)
        urlstr += "?" + params.join("&");

    window.open(urlstr, "", "width=490,height=470,resizable=0");
   
    return false; /* stop following the link */
}

function getSelectedFolder() {
    var folder;
    var list = $("calendarList");
    var nodes = list.getSelectedRows();
    if (nodes.length > 0)
        folder = nodes[0];
    else
        folder = list.down("li");

    return folder;
}

function onMenuNewEventClick(event) {
    newEvent(this, "event");
}

function onMenuNewTaskClick(event) {
    newEvent(this, "task");
}

function _editEventId(id, calendar, recurrence) {
    var targetname = "SOGo_edit_" + id;
    var urlstr = ApplicationBaseURL + calendar + "/" + id;
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
            window.alert(getLabel("Please select an event or a task."));
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
        window.alert(getLabel("Please select an event or a task."));
    }

    return false; /* stop following the link */
}

function _batchDeleteEvents() {
    var events = eventsToDelete.shift();
    var calendar = calendarsOfEventsToDelete.shift();
    var urlstr = (ApplicationBaseURL + calendar
                  + "/batchDelete?ids=" + events.join('/'));
    document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
                                                         deleteEventCallback,
                                                         { calendar: calendar,
                                                           events: events });
}

function deleteEvent() {
    if (listOfSelection) {
        var nodes = listOfSelection.getSelectedRows();
        if (nodes.length > 0) {
            var label = "";
            if (listOfSelection == $("tasksList"))
                label = getLabel("taskDeleteConfirmation");
            else
                label = getLabel("eventDeleteConfirmation");

            if (nodes.length == 1
                && nodes[0].recurrenceTime) {
                _editRecurrenceDialog(nodes[0], "confirmDeletion");
            }
            else {
                if (confirm(label)) {
                    if (document.deleteEventAjaxRequest) {
                        document.deleteEventAjaxRequest.aborted = true;
                        document.deleteEventAjaxRequest.abort();
                    }
                    var sortedNodes = [];
                    var calendars = [];

                    for (var i = 0; i < nodes.length; i++) {
                        var calendar = nodes[i].calendar;
                        if (!sortedNodes[calendar]) {
                            sortedNodes[calendar] = [];
                            calendars.push(calendar);
                        }
                        sortedNodes[calendar].push(nodes[i].cname);
                    }
                    for (var i = 0; i < calendars.length; i++) {
                        calendarsOfEventsToDelete.push(calendars[i]);
                        eventsToDelete.push(sortedNodes[calendars[i]]);
                    }
                    _batchDeleteEvents();
                }
            }
        } else {
            window.alert(getLabel("Please select an event or a task."));
        }
    }
    else if (selectedCalendarCell) {
        if (selectedCalendarCell[0].recurrenceTime) {
            _editRecurrenceDialog(selectedCalendarCell[0], "confirmDeletion");
        }
        else {
            var label = getLabel("eventDeleteConfirmation");
            if (confirm(label)) {
                if (document.deleteEventAjaxRequest) {
                    document.deleteEventAjaxRequest.aborted = true;
                    document.deleteEventAjaxRequest.abort();
                }
                eventsToDelete.push([selectedCalendarCell[0].cname]);
                calendarsOfEventsToDelete.push(selectedCalendarCell[0].calendar);
                _batchDeleteEvents();
            }
        }
    }
    else
        window.alert(getLabel("Please select an event or a task."));

    return false;
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
    closePseudoWin.appendChild(document.createTextNode(getLabel("closeThisWindowMessage")));

    var calLink = document.createElement("a");
    closePseudoWin.appendChild(calLink);
    calLink.href = ApplicationBaseURL;
    calLink.appendChild(document.createTextNode(getLabel("Calendar").toLowerCase()));
}

function modifyEventCallback(http) {
    if (http.readyState == 4) {
        if (http.status == 200) {
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
            var msg = data.replace(/^(.*\n)*.*<p>((.*\n)*.*)<\/p>(.*\n)*.*$/, "$2");
            window.alert(clabels[msg]?clabels[msg]:msg);
        }
        else {
            // 	 log("showing alert...");
            window.alert(getLabel("eventPartStatModificationError"));
        }
        document.modifyEventAjaxRequest = null;
    }
}

function _deleteCalendarEventBlocks(calendar, cname) {
    var events = calendarEvents[calendar];
    if (events) {
        var occurences = events[cname];
        if (occurences)
            for (var i = 0; i < occurences.length; i++) {
                var nodes = occurences[i].blocks;
                for (var j = 0; j < nodes.length; j++) {
                    var node = nodes[j];
                    node.parentNode.removeChild(node);
                }
            }
    }
}

function _deleteEventFromTables(basename) {
    var tables = [ $("eventsList"), $("tasksList") ];
    for (var i = 0; i < 2; i++) {
        var table = tables[i];
        if (table.tBodies)
            rows = table.tBodies[0].rows;
        else
            rows = $(table).childNodesWithTag("li");
        for (var j = rows.length; j > 0; j--) {
            var row = $(rows[j - 1]);
            var id = row.getAttribute("id");
            if (id.indexOf(basename) == 0)
                row.parentNode.removeChild(row);
        }
    }
}

function deleteEventCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var isTask = false;
            var calendar = http.callbackData.calendar;
            var events = http.callbackData.events;

            //       log("calendar: " + calendar + "\n");
            //       log("events: " + events.join(", " ) + "\n");
            for (var i = 0; i < events.length; i++) {
                var cname = events[i];
                _deleteCalendarEventBlocks(calendar, cname);
                _deleteEventFromTables(calendar + "-" + cname);
                delete calendarEvents[calendar][cname];
            }

            if (eventsToDelete.length)
                _batchDeleteEvents();
            else {
                document.deleteEventAjaxRequest = null;
            }
        }
        else if (parseInt(http.status) == 403)
            window.alert(getLabel("You don't have the required privileges to perform the operation."));
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

function _editRecurrenceDialog(eventDiv, method) {
    var targetname = "SOGo_edit_" + eventDiv.cname + eventDiv.recurrenceTime;
    var urlstr = (ApplicationBaseURL + eventDiv.calendar + "/" + eventDiv.cname
                  + "/occurence" + eventDiv.recurrenceTime + "/" + method);
    var win = window.open(urlstr, "_blank",
                          "width=490,height=70,resizable=0");
    if (win)
        win.focus();
}

function onViewEvent(event) {
    if (event.detail == 2) return;
    var url = ApplicationBaseURL + this.calendar + "/" + this.cname;

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
    if (http.readyState == 4
        && http.status == 200) {
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
            var left = cellPosition[0];
            var top = cellPosition[1];
      
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
                view = $("calendarView");
                top -= cell.up("DIV.day").scrollTop;
            }
      
            if (left > parseInt(window.width()*0.75)) {
                left = left - divDimensions["width"] + 10;
                div.removeClassName("left");
                div.addClassName("right");
            }
            else {
                left = left + cellDimensions["width"] - parseInt(cellDimensions["width"]/3);
                div.removeClassName("right");
                div.addClassName("left");
            }

            // Put the event's data in the DIV
            div.down("h1").update(data["summary"].replace(/\r?\n/g, "<BR/>"));
            if (parseInt(data["isAllDay"]) == 0) {
                div.down("P", 0).down("SPAN", 1).update(data["startTime"]);
                div.down("P", 0).show();
            } else
                div.down("P", 0).hide();
            if (data["location"].length) {
                div.down("P", 1).down("SPAN", 1).update(data["location"]);
                div.down("P", 1).show();
            } else
                div.down("P", 1).hide();

            if (data["description"].length) {
                div.down("P", 2).update(data["description"].replace(/\r?\n/g, "<BR/>"));
                div.down("P", 2).show();
            } else
                div.down("P", 2).hide();
      
            div.setStyle({ left: left + "px",
                        top: top + "px" });
            div.show();
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
            var urlstr = ApplicationBaseURL + folder + "/" + event  + "/" + recurrence + "/delete";
			
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
            for (var i = 0; i < nodes.length; i++) {
                var node = nodes[i];
                node.parentNode.removeChild(node);
            }
            var basename = calendar + "-" + cname;
            if (occurenceTime) {
                var row = $(basename + "-" + occurenceTime);
                // 	log("rowID: " + basename + "-" + occurenceTime);
                if (row)
                    row.parentNode.removeChild(row);

                // Update calendar events cache
                var occurences = calendarEvents[calendar][cname];
                var newOccurences = [];
                for (var i = 0; i < occurences.length; i++) {
                    var occurence = occurences[i];
                    if (occurence[14] != occurenceTime)
                        newOccurences.push(occurence);
                }
                calendarEvents[calendar][cname] = newOccurences;
            }
            else {
                // 	log("basename: " + basename);
                _deleteEventFromTables(basename);
                delete calendarEvents[calendar][cname];
            }
        }
    }
}

function onSelectAll() {
    var list = $("eventsList");
    list.selectRowsMatchingClass("eventRow");

    return false;
}

function onDaySelect(node) {
    var day = node.getAttribute('day');
    var needRefresh = (listFilter == 'view_selectedday'
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
    var needRefresh = (listFilter == 'view_selectedday'
                       && day != currentDay);

    changeDateSelectorDisplay(day);
    changeCalendarDisplay( { "day": day } );
    if (needRefresh)
        refreshEvents();

    return false;
}

function gotoToday() {
    changeDateSelectorDisplay('');
    changeCalendarDisplay();

    return false;
}

function setDateSelectorContent(content) {
    var div = $("dateSelectorView");

    div.innerHTML = content;
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

        if (http.responseText.length > 0) {
            var data = http.responseText.evalJSON(true);
            for (var i = 0; i < data.length; i++) {
                var row = $(document.createElement("tr"));
                table.tBodies[0].appendChild(row);
                row.addClassName("eventRow");
                var rTime = data[i][14];
                var id = escape(data[i][1] + "-" + data[i][0]);
                if (rTime)
                    id += "-" + escape(rTime);
                row.setAttribute("id", id);
                row.cname = escape(data[i][0]);
                row.calendar = escape(data[i][1]);
                if (rTime)
                    row.recurrenceTime = escape(rTime);
                row.isException = data[i][15];
                var startDate = new Date();
                startDate.setTime(data[i][4] * 1000);
                row.day = startDate.getDayString();
                row.hour = startDate.getHourString();
                row.observe("mousedown", onRowClick);
                row.observe("selectstart", listRowMouseDownHandler);
                row.observe("dblclick", editDoubleClickedEvent);
                row.attachMenu("eventsListMenu");

                var td = $(document.createElement("td"));
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.appendChild(document.createTextNode(data[i][3]));

                td = $(document.createElement("td"));
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.appendChild(document.createTextNode(data[i][16]));

                td = $(document.createElement("td"));
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.appendChild(document.createTextNode(data[i][17]));
      
                td = $(document.createElement("td"));
                row.appendChild(td);
                td.observe("mousedown", listRowMouseDownHandler, true);
                td.appendChild(document.createTextNode(data[i][6]));
            }

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
    }
    else
        log ("eventsListCallback Ajax error");
}

function tasksListCallback(http) {
    var div = $("tasksListView");

    if (http.readyState == 4
        && http.status == 200) {
        document.tasksListAjaxRequest = null;
        var list = $("tasksList");
 
        if (http.responseText.length > 0) {
            var data = http.responseText.evalJSON(true);

            for (var i = 0; i < data.length; i++) {
                var listItem = $(document.createElement("li"));
                list.appendChild(listItem);
                listItem.observe("mousedown", listRowMouseDownHandler);
                listItem.observe("click", onRowClick);
                listItem.observe("dblclick", editDoubleClickedEvent);

                var calendar = escape(data[i][1]);
                var cname = escape(data[i][0]);
                listItem.setAttribute("id", calendar + "-" + cname);
                //listItem.addClassName(data[i][5]); // Classification
                listItem.addClassName(data[i][8]);
                listItem.calendar = calendar;
                listItem.addClassName("calendarFolder" + calendar);
                listItem.cname = cname;
                var input = $(document.createElement("input"));
                input.setAttribute("type", "checkbox");
                if (parseInt(data[i][6]) == 0)
                  input.setAttribute ("disabled", true);
                if (parseInt(data[i][7]) == 1) {
                  listItem.addClassName ("important");
                }
                listItem.appendChild(input);
                input.observe("click", updateTaskStatus, true);
                input.setAttribute("value", "1");
                if (data[i][2] == 1)
                    input.setAttribute("checked", "checked");
                $(input).addClassName("checkBox");

                var t = new Element ("span");
                t.update (data[i][3]);
                listItem.appendChild (t);

                listItem.attachMenu ("tasksListMenu");
            }

            list.scrollTop = list.previousScroll;

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

function restoreCurrentDaySelection(div) {
    var elements = $(div).getElementsByTagName("a");
    var day = null;
    var i = 9;
    while (!day && i < elements.length)
        {
            day = elements[i].day;
            i++;
        }

    if (day
        && day.substr(0, 6) == currentDay.substr(0, 6)) {
        for (i = 0; i < elements.length; i++) {
            day = elements[i].day;
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

function loadPreviousView(event) {
    var previousArrow = $$("A.leftNavigationArrow").first();
    onCalendarGotoDay(previousArrow);
}

function loadNextView(event) {
    var nextArrow = $$("A.rightNavigationArrow").first();
    onCalendarGotoDay(nextArrow);
}

function changeDateSelectorDisplay(day, keepCurrentDay) {
    var url = ApplicationBaseURL + "dateselector";
    if (day) {
        if (day.length < 8)
            day += "01";
        url += "?day=" + day;
    }

    if (day != currentDay) {
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
}

function changeCalendarDisplay(data, newView) {
    newView = ((newView) ? newView : currentView);
    var url = ApplicationBaseURL + newView;
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
            var divs = $$('div.day[day='+day+']');
            if (divs.length) {
                // Don't reload the view if the event is present in current view

                // Deselect previous day
                var selectedDivs = $$('div.day.selectedDay');
                selectedDivs.each(function(div) {
                        div.removeClassName('selectedDay');
                    });

                // Select new day
                divs.each(function(div) {
                        div.addClassName('selectedDay');
                    });
	
                // Deselect day in date selector
                if (document.selectedDate)
                    document.selectedDate.deselect();
	
                // Select day in date selector
                var selectedLink = $$('table#dateSelectorTable span[day='+day+']');
                if (selectedLink.length > 0) {
                    selectedCell = selectedLink[0].getParentWithTagName("td");
                    selectedCell.selectElement();
                    document.selectedDate = selectedCell;
                }
	
                // Scroll to event
                if (scrollEvent)
                    scrollDayView(scrollEvent);

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

function onCalendarReload() {
    reloadWebCalendars ();
    return false;
}

function reloadWebCalendars () {
    var url = ApplicationBaseURL + "reloadWebCalendars";
    if (document.reloadWebCalAjaxRequest) {
        document.reloadWebCalAjaxRequest.aborted = true;
        document.reloadWebCalAjaxRequest.abort();
    }
    document.reloadWebCalAjaxRequest
        = triggerAjaxRequest(url, reloadWebCalendarsCallback);
}
function reloadWebCalendarsCallback (http) {
    changeCalendarDisplay(null, currentView);
}

function scrollDayView(scrollEvent) {
    if (!preventAutoScroll) {
        if (scrollEvent) {
            var contentView;
            var eventRow = $(scrollEvent);
            var eventBlocks = selectCalendarEvent(eventRow.calendar, eventRow.cname, eventRow.recurrenceTime);
            var firstEvent = eventBlocks.first();

            if (currentView == "monthview")
              contentView = firstEvent.up("DIV.day");
            else
              contentView = $("daysView");

            var top = firstEvent.cumulativeOffset()[1] - contentView.scrollTop;

            // Don't scroll if the event is visible to the user
            if (top < contentView.cumulativeOffset()[1])
              contentView.scrollTop = firstEvent.cumulativeOffset()[1] - contentView.cumulativeOffset()[1];
            else if (top > contentView.cumulativeOffset()[1] + contentView.getHeight() - firstEvent.getHeight())
              contentView.scrollTop = firstEvent.cumulativeOffset()[1] - contentView.cumulativeOffset()[1];
        }
        else if (currentView != "monthview") {
            var contentView = $("daysView");
            var hours = (contentView.childNodesWithTag("div")[0]).childNodesWithTag("div");
            contentView.scrollTop = hours[dayStartHour].offsetTop;
        }
    }
}

function onClickableCellsDblClick(event) {
    newEvent(this, 'event');

    Event.stop(event);
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
    var url = (ApplicationBaseURL + "eventsblocks?sd=" + sd + "&ed=" + ed
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
        //		log("parsed cname: " + cname + "; calendar: " + calendar);
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
            onWindowResize(null);
        }
        scrollDayView(http.callbackData["scrollEvent"]);
    }
    else
        log("AJAX error when refreshing calendar events");
}

function newBaseEventDIV(eventRep, event, eventText) {
    //	log ("0 cname = " + event[0]);
    //	log ("1 calendar = " + event[1]);
    //	log ("2 status = " + event[2]);
    //	log ("3 title = " + event[3]);
    //	log ("4 start = " + event[4]);
    //	log ("5 end = " + event[5]);
    //	log ("6 location = " + event[6]);
    //	log ("7 isallday = " + event[7]);
    //	log ("8 classification = " + event[8]);
    //	log ("9 participants emails = " + event[9]);
    //	log ("10 participants states = " + event[10]);
    //	log ("11 owner = " + event[11]);
    //	log ("12 iscycle = " + event[12]);
    //	log ("13 nextalarm = " + event[13]);
    //	log ("14 recurrenceid = " + event[14]);
    //	log ("15 isexception = " + event[15]);

    var eventDiv = $(document.createElement("div"));
    eventDiv.cname = event[0];
    eventDiv.calendar = event[1];
    if (eventRep.recurrenceTime)
        eventDiv.recurrenceTime = eventRep.recurrenceTime;
    eventDiv.isException = event[15];
    eventDiv.addClassName("event");
    if (event[13] > 0)
        eventDiv.addClassName("alarm");

    var innerDiv = $(document.createElement("div"));
    eventDiv.appendChild(innerDiv);
    innerDiv.addClassName("eventInside");
    innerDiv.addClassName("calendarFolder" + event[1]);
    if (eventRep.userState >= 0 && userStates[eventRep.userState])
        innerDiv.addClassName(userStates[eventRep.userState]);

    var gradientDiv = $(document.createElement("div"));
    innerDiv.appendChild(gradientDiv);
    gradientDiv.addClassName("gradient");

    var gradientImg = $(document.createElement("img"));
    gradientDiv.appendChild(gradientImg);
    gradientImg.src = ResourcesURL + "/event-gradient.png";

    var textDiv = $(document.createElement("div"));
    innerDiv.appendChild(textDiv);
    textDiv.addClassName("text");
    textDiv.update(eventText.replace(/(\\r)?\\n/g, "<BR/>"));

    if (event[2] == null) {
        eventDiv.observe("selectstart", listRowMouseDownHandler);
        eventDiv.observe("click", onCalendarSelectEvent);
    }
    else {
        // Status field is defined -- user can read event
        eventDiv.observe("mousedown", listRowMouseDownHandler);
        eventDiv.observe("click", onCalendarSelectEvent);
        eventDiv.observe("dblclick", editDoubleClickedEvent);
        eventDiv.observe("click", onViewEvent);
    }
    event.blocks.push(eventDiv);

    return eventDiv;
}

function _drawCalendarAllDayEvents(events, eventsData) {
    var daysView = $("calendarHeader");
    var subdivs = daysView.childNodesWithTag("div");
    var days = subdivs[1].childNodesWithTag("div");
    for (var i = 0; i < days.length; i++) {
        var parentDiv = days[i];
        for (var j = 0; j < events[i].length; j++) {
            var eventRep = events[i][j];
            var nbr = eventRep.nbr;
            var eventDiv = newAllDayEventDIV(eventRep, eventsData[nbr]);
            parentDiv.appendChild(eventDiv);
        }
    }
}

function newAllDayEventDIV(eventRep, event) {
    // cname, calendar, starts, lasts,
    // 		     startHour, endHour, title) {
    var eventDiv = newBaseEventDIV(eventRep, event, event[3]);

    return eventDiv;
}
			     
function _drawCalendarEvents(events, eventsData) {
    var daysView = $("daysView");
    var subdivs = daysView.childNodesWithTag("div");
    var days = subdivs[1].childNodesWithTag("div");
    for (var i = 0; i < days.length; i++) {
        var parentDiv = days[i].childNodesWithTag("div")[0];
        for (var j = 0; j < events[i].length; j++) {
            var eventRep = events[i][j];
            var nbr = eventRep.nbr;
            var eventDiv = newEventDIV(eventRep, eventsData[nbr]);
            parentDiv.appendChild(eventDiv);
        }
    }
}

function newEventDIV(eventRep, event) {
    var eventDiv = newBaseEventDIV(eventRep, event, event[3]);

    var pc = 100 / eventRep.siblings;
    eventDiv.style.width = pc + "%";
    var left = eventRep.position * pc;
    eventDiv.style.left = left + "%";
    eventDiv.addClassName("starts" + eventRep.start);
    eventDiv.addClassName("lasts" + eventRep.length);

    return eventDiv;
}

function _drawMonthCalendarEvents(events, eventsData) {
    var daysView = $("monthDaysView");
    var days = daysView.childNodesWithTag("div");
    for (var i = 0; i < days.length; i++) {
        var parentDiv = days[i];
        for (var j = 0; j < events[i].length; j++) {
            var eventRep = events[i][j];
            var nbr = eventRep.nbr;
            var eventDiv = newMonthEventDIV(eventRep, eventsData[nbr]);
            parentDiv.appendChild(eventDiv);
        }
    }
}

function newMonthEventDIV(eventRep, event) {
    var eventText;
    if (event[7]) // all-day event
        eventText = event[3];
    else
        eventText = eventRep.starthour + " - " + event[3];

    var eventDiv = newBaseEventDIV(eventRep, event,
                                   eventText);

    return eventDiv;
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
        if (preventAutoScroll && daysView)
          daysView.scrollTop = position;

        if (http.callbackData["view"])
            currentView = http.callbackData["view"];
        if (http.callbackData["day"])
            currentDay = http.callbackData["day"];

        // Initialize contextual menu
        var menu;
        var observer;
        if (currentView == 'dayview') {
            menu = new Array(onMenuNewEventClick,
                             onMenuNewTaskClick,
                             "-",
                             loadPreviousView,
                             loadNextView);
            observer = $("daysView");
        }
        else if (currentView == 'weekview') {
            menu = new Array(onMenuNewEventClick,
                             onMenuNewTaskClick,
                             "-",
                             loadPreviousView,
                             loadNextView);
            observer = $("daysView");
        }
        else {
            menu = new Array(onMenuNewEventClick,
                             onMenuNewTaskClick,
                             "-",
                             loadPreviousView,
                             loadNextView);
            observer = $("monthDaysView");
        }
        initMenu($("currentViewMenu"), menu);
        observer.observe("contextmenu", onMenuCurrentView);
		
        var contentView;
        if (currentView == "monthview")
            contentView = $("calendarContent");
        else {
            contentView = $("daysView");
            contentView.observe("scroll", onBodyClickHandler);
        }
    
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

function assignCalendar(name) {
    if (typeof(skycalendar) != "undefined") {
        var node = $(name);
        if (node) {
          node.calendar = new skycalendar(node);
          node.calendar.setCalendarPage(ResourcesURL + "/skycalendar.html");
          var dateFormat = node.getAttribute("dateFormat");
          if (dateFormat)
            node.calendar.setDateFormat(dateFormat);
        }
    }
}

function popupCalendar(node) {
    var nodeId = $(node).readAttribute("inputId");
    var input = $(nodeId);
    input.calendar.popup();

    return false;
}

function onEventsSelectionChange() {
    listOfSelection = this;
    this.removeClassName("_unfocused");
    $("tasksList").addClassName("_unfocused");

    var rows = $(this.tBodies[0]).getSelectedNodes();
    if (rows.length == 1) {
        var row = rows[0];
        changeCalendarDisplay( { "day": row.day,
                    "scrollEvent": row.getAttribute("id") } );
        changeDateSelectorDisplay(row.day);
    }
}

function onTasksSelectionChange() {
    listOfSelection = this;
    this.removeClassName("_unfocused");
    $("eventsList").addClassName("_unfocused");
}

function _loadEventHref(href) {
    if (document.eventsListAjaxRequest) {
        document.eventsListAjaxRequest.aborted = true;
        document.eventsListAjaxRequest.abort();
    }
    var url = ApplicationBaseURL + href;
    document.eventsListAjaxRequest
        = triggerAjaxRequest(url, eventsListCallback, href);

    var table = $("eventsList").tBodies[0];
    while (table.rows.length > 0)
        table.removeChild(table.rows[0]);

    return false;
}

function _loadTasksHref(href) {
    if (document.tasksListAjaxRequest) {
        document.tasksListAjaxRequest.aborted = true;
        document.tasksListAjaxRequest.abort();
    }
    url = ApplicationBaseURL + href;

    var tasksList = $("tasksList");
    var selectedIds;
    if (tasksList)
        selectedIds = tasksList.getSelectedNodesId();
    else
        selectedIds = null;
    document.tasksListAjaxRequest
        = triggerAjaxRequest(url, tasksListCallback, selectedIds);

    tasksList.previousScroll = tasksList.scrollTop;
    while (tasksList.childNodes.length)
        tasksList.removeChild(tasksList.childNodes[0]);

    return true;
}

function onHeaderClick(event) {
    var headerId = this.getAttribute("id");
    var newSortAttribute;
    if (headerId == "titleHeader")
        newSortAttribute = "title";
    else if (headerId == "startHeader")
        newSortAttribute = "start";
    else if (headerId == "endHeader")
        newSortAttribute = "end";
    else if (headerId == "locationHeader")
        newSortAttribute = "location";
    else
        newSortAttribute = "start";
  
    if (sorting["attribute"] == newSortAttribute)
        sorting["ascending"] = !sorting["ascending"];
    else {
        sorting["attribute"] = newSortAttribute;
        sorting["ascending"] = true;
    }
    refreshEvents();

    Event.stop(event);
}

function refreshCurrentFolder() {
    refreshEvents();
}

function refreshEvents() {
    var titleSearch;
    var value = search["value"];
    if (value && value.length)
        titleSearch = "&search=" + escape(value.utf8encode());
    else
        titleSearch = "";
	
    refreshAlarms();

    return _loadEventHref("eventslist?asc=" + sorting["ascending"]
                          + "&sort=" + sorting["attribute"]
                          + "&day=" + currentDay
                          + titleSearch
                          + "&filterpopup=" + listFilter);
}

function refreshTasks(setUserDefault) {
    var url = "taskslist?show-completed=" + showCompletedTasks;
    if (setUserDefault == 1)
      url += "&setud=1";
    refreshAlarms();
    return _loadTasksHref(url);
}

function refreshEventsAndDisplay() {
    refreshEvents();
    changeCalendarDisplay();
}

function onListFilterChange() {
    var node = $("filterpopup");

    listFilter = node.value;
    //   log ("listFilter = " + listFilter);

    return refreshEvents();
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
                    if (occurence[14] == recurrenceTime)
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

function selectCalendarEvent(calendar, cname, recurrenceTime) {
    // Select event in calendar view
    if (selectedCalendarCell)
        for (var i = 0; i < selectedCalendarCell.length; i++)
            selectedCalendarCell[i].deselect();

    var selection = _eventBlocksMatching(calendar, cname, recurrenceTime);
    if (selection) {
        for (var i = 0; i < selection.length; i++)
            selection[i].selectElement();
        selectedCalendarCell = selection;
    }
  
    return selection;
}

function onCalendarSelectEvent() {
    selectCalendarEvent(this.calendar, this.cname, this.recurrenceTime);

    // Select event in events list
    var list = $("eventsList");
    $(list.tBodies[0]).deselectAll();
    var rowID = this.calendar + "-" + this.cname;
    if (this.recurrenceTime)
        rowID += "-" + this.recurrenceTime;
    var row = $(rowID);
    if (row) {
        var div = row.parentNode.parentNode.parentNode;
        div.scrollTop = row.offsetTop - (div.offsetHeight / 2);
        row.selectElement();
    }
}

function onCalendarSelectDay(event) {
    var day = this.getAttribute("day");
    var needRefresh = (listFilter == 'view_selectedday'
                       && day != currentDay);

    if (currentView == 'weekview')
        changeWeekCalendarDisplayOfSelectedDay(this);
    else if (currentView == 'monthview')
        changeMonthCalendarDisplayOfSelectedDay(this);
    changeDateSelectorDisplay(day);

    if (listOfSelection) {
        listOfSelection.addClassName("_unfocused");
        listOfSelection = null;
    }

    if (needRefresh)
        refreshEvents();

    changeCalendarDisplay( { "day": currentDay } );
}

function changeWeekCalendarDisplayOfSelectedDay(node) {
    var daysView = $("daysView");
    var daysDiv = daysView.childNodesWithTag("div");
    var days = daysDiv[1].childNodesWithTag("div");
    var headerDiv = $($("calendarHeader").childNodesWithTag("div")[1]);
    var headerDays = headerDiv.childNodesWithTag("div");

    for (var i = 0; i < days.length; i++) {
        if (days[i] == node
            || headerDays[i] == node) {
            headerDays[i].addClassName("selectedDay");
            days[i].addClassName("selectedDay");
        }
        else {
            headerDays[i].removeClassName("selectedDay");
            days[i].removeClassName("selectedDay");
        }
    }
}

function findMonthCalendarSelectedCell(daysContainer) {
    var found = false;
    var i = 0;

    while (!found && i < daysContainer.childNodes.length) {
        var currentNode = daysContainer.childNodes[i];
        if (currentNode.tagName == 'DIV'
            && currentNode.hasClassName("selectedDay")) {
            daysContainer.selectedCell = currentNode;
            found = true;
        }
        else
            i++;
    }
}

function changeMonthCalendarDisplayOfSelectedDay(node) {
    var daysContainer = node.parentNode;
    if (!daysContainer.selectedCell)
        findMonthCalendarSelectedCell(daysContainer);
   
    if (daysContainer.selectedCell)
        daysContainer.selectedCell.removeClassName("selectedDay");
    daysContainer.selectedCell = node;
    node.addClassName("selectedDay");
}

function onShowCompletedTasks(event) {
    showCompletedTasks = (this.checked ? 1 : 0);

    return refreshTasks(1);
}

function updateTaskStatus(event) {
    var newStatus = (this.checked ? 1 : 0);

    if (isSafari() && !isSafari3()) {
        newStatus = (newStatus ? 0 : 1);
    }
    _updateTaskCompletion (this.parentNode, newStatus);
    return false;
}

function updateCalendarStatus(event) {
    var list = [];
    var newStatus = (this.checked ? 1 : 0);
  
    if (isSafari() && !isSafari3()) {
        newStatus = (newStatus ? 0 : 1);
        this.checked = newStatus;
    }

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

    return false;
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

function validateBrowseURL(input) {
    var button = $("browseURLBtn");

    if (input.value.length) {
        if (!button.enabled)
            enableAnchor(button);
    } else if (!button.disabled)
        disableAnchor(button);
}

function browseURL(anchor, event) {
    if (event.button == 0) {
        var input = $("url");
        var url = input.value;
        if (url.length)
            window.open(url, '_blank');
    }

    return false;
}

function onCalendarsMenuPrepareVisibility() {
    var folders = $("calendarList");
    var selected = folders.getSelectedNodes();  
    if (selected.length > 0) {
        var folderOwner = selected[0].getAttribute("owner");
        var sharingOption = $(this).down("ul").childElements().last();
        // Disable the "Sharing" option when calendar is not owned by user
        if (folderOwner == UserLogin || IsSuperUser)
            sharingOption.removeClassName("disabled");
        else
            sharingOption.addClassName("disabled");
        return true;
    }
    return false;
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
    menus["searchMenu"] = new Array(setSearchCriteria);

    menus["tasksListMenu"] = new Array (editEvent, newTask, "-", 
                                        marksTasksAsCompleted, deleteEvent);

    var calendarsMenu = $("calendarsMenu");
    if (calendarsMenu)
        calendarsMenu.prepareVisibility = onCalendarsMenuPrepareVisibility;

    return menus;
}

function newTask () {
    return newEvent(this, 'task');
}

function marksTasksAsCompleted () {
    var selectedTasks = $$("UL#tasksList LI._selected");

    for (var i = 0; i < selectedTasks.length; i++) {
        var task = selectedTasks[i];
        _updateTaskCompletion (task, 1);
    }
}

function _updateTaskCompletion (task, value) {
    var checkBox = task.down ("INPUT");
    url = (ApplicationBaseURL + task.calendar
           + "/" + task.cname + "/changeStatus?status=" + value);

    triggerAjaxRequest(url, refreshTasks, null);

    return false;
}

function onMenuSharing(event) {
    if ($(this).hasClassName("disabled"))
        return;

    var folders = $("calendarList");
    var selected = folders.getSelectedNodes()[0];
    /* FIXME: activation of the context menu should preferably select the entry
       above which the event has occured */
    if (selected) {
        var folderID = selected.getAttribute("id");
        var urlstr = URLForFolderID(folderID) + "/acls";

        openAclWindow(urlstr);
    }
}

function onMenuCurrentView(event) {
    popupMenu(event, 'currentViewMenu', this);
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
        handle.upperBlock = $("eventsListView");
        handle.lowerBlock = $("calendarView");
    }
}

function initCalendarSelector() {
    var selector = $("calendarSelector");
    updateCalendarStatus(); // triggers the initial events refresh
    selector.changeNotification = updateCalendarsList;

    var list = $("calendarList");
    list.multiselect = true;
    var items = list.childNodesWithTag("li");
    for (var i = 0; i < items.length; i++) {
        var input = items[i].childNodesWithTag("input")[0];
        $(input).observe("click", updateCalendarStatus);
        items[i].observe("mousedown", listRowMouseDownHandler);
        items[i].observe("selectstart", listRowMouseDownHandler);
        items[i].observe("click", onRowClick);
        items[i].observe("dblclick", onCalendarModify);
    }

    var links = $("calendarSelectorButtons").childNodesWithTag("a");
    $(links[0]).observe("click", onCalendarNew);
    $(links[1]).observe("click", onCalendarWebAdd);
    $(links[2]).observe("click", onCalendarAdd);
    $(links[3]).observe("click", onCalendarRemove);
}

function onCalendarModify(event) {
    var folders = $("calendarList");
    var selected = folders.getSelectedNodes()[0];
    var calendarID = selected.getAttribute("id");
    var url = ApplicationBaseURL + calendarID + "/properties";
    var windowID = sanitizeWindowName(calendarID + " properties");
    var width = 310;
    var height = 270;
    if (UserSettings['Calendar'] 
        && UserSettings['Calendar']['WebCalendars']) {
        var webCalendars = UserSettings['Calendar']['WebCalendars'];
        var realID = calendarID.substr (1, calendarID.length - 1);
        if (webCalendars[realID]) {
            width = 500;
            height = 360;
        }
    }
    if (calendarID == "/personal")
      height = 250;

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
    else {
        nodeID = "/" + folderName;
	//   log("nodeID: " + nodeID);
        var calendarNode = $(nodeID);
        var childNodes = calendarNode.childNodes;
        childNodes[childNodes.length-1].nodeValue = calendarName;
    }

    appendStyleElement(nodeID, calendarColor);
}

function onCalendarNew(event) {
    createFolder(window.prompt(getLabel("Name of the Calendar"), ""),
                 appendCalendar);
    preventDefault(event);
}

function onCalendarAdd(event) {
    openUserFolderSelector(onFolderSubscribeCB, "calendar");
    preventDefault(event);
}

function onCalendarWebAdd(event) {
    var calendarUrl = window.prompt(getLabel("URL of the Calendar"), "");
    if (calendarUrl) {
        if (document.addWebCalendarRequest) {
            document.addWebCalendarRequest.aborted = true;
            document.addWebCalendarRequest.abort ();
        }
        var url = ApplicationBaseURL + "/addWebCalendar?url=" + escape (calendarUrl);
        document.addWebCalendarRequest = 
          triggerAjaxRequest (url, addWebCalendarCallback);
    }
}
function addWebCalendarCallback (http) {
    var data = http.responseText.evalJSON(true);
    if (data.imported >= 0) {
        appendCalendar(data.displayname, "/" + data.name);
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();
    }
    else {
        alert (getLabel("An error occured while importing calendar."));
    }
}

function onCalendarExport(event) {
    var node = $("calendarList").getSelectedNodes().first();
    var owner = node.getAttribute("owner");
    var folderId = node.getAttribute("id");
    if (owner == UserLogin) {
        var folderIdElements = folderId.split(":");
        var id = folderIdElements[0].replace (/^\/+/g, '');
        var url = ApplicationBaseURL + "/" + id + "/export";
        window.location.href = url;
    }
}

function onCalendarImport(event) {
    var node = $("calendarList").getSelectedNodes().first();
    var folderId = node.getAttribute("id");

    var url = ApplicationBaseURL + folderId + "/import";
    $("uploadForm").action = url;
    $("uploadCancel").onclick = hideCalendarImport;
    $("calendarFile").value = "";

    var cellPosition = node.cumulativeOffset();
    var cellDimensions = node.getDimensions();
    var left = cellDimensions['width'] - 20;
    var top = cellPosition[1];

    var div = $("uploadDialog");
    var res = $("uploadResults");
    div.style.top = top + "px";
    res.style.top = top + "px";
    div.style.left = left + "px";
    res.style.left = left + "px";
    div.style.display = "block";
}
function hideCalendarImport () {
    $("uploadDialog").style.display = "none";
}
function hideImportResults () {
    $("uploadResults").style.display = "none";
}
function validateUploadForm () {
    rc = false;
    if ($("calendarFile").value.length)
      rc = true;
    return rc;
}
function uploadCompleted (response) {
    data = response.evalJSON (true);

    var div = $("uploadResults");
    $("uploadOK").onclick = hideImportResults;
    if (data.imported <= 0)
      $("uploadResultsContent").update (getLabel("An error occured while importing calendar."));
    else {
        $("uploadResultsContent").update (getLabel("Imported events:") + " " + data.imported);
        refreshEventsAndDisplay ();
    }

    hideCalendarImport ();
    $("uploadResults").style.display = "block";
}

function setEventsOnCalendar(checkBox, li) {
    li.observe("mousedown", listRowMouseDownHandler);
    li.observe("selectstart", listRowMouseDownHandler);
    li.observe("click", onRowClick);
    li.observe("dblclick", onCalendarModify);
    checkBox.observe("click", updateCalendarStatus);
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
        window.alert(getLabel("You have already subscribed to that folder!"));
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
        li.appendChild(document.createTextNode(folderName
                                               .replace("&lt;", "<", "g")
                                               .replace("&gt;", ">", "g")));
        colorBox.appendChild(document.createTextNode("OO"));

        $(colorBox).addClassName("colorBox");
        $(colorBox).addClassName('calendarFolder' + folderPath.substr(1));
		
        // Check the checkbox (required for IE)
        li.getElementsByTagName("input")[0].checked = true;

        // Register events (doesn't work with Safari)
        setEventsOnCalendar($(checkBox), $(li));

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
        var selectors = [
                         'DIV.calendarFolder' + folderPath.substr(1),
                         'LI.calendarFolder' + folderPath.substr(1),
                         'UL#calendarList DIV.calendarFolder' + folderPath.substr(1)
                         ];
        var rules = [
                     ' { background-color: ' + color + ' !important;' + ' color: ' + fgColor + ' !important; }',
                     ' { background-color: ' + color + ' !important;' + ' color: ' + fgColor + ' !important; }',
                     ' { color: ' + color + ' !important; }'
                     ];
        for (var i = 0; i < rules.length; i++)
            if (styleElement.styleSheet && styleElement.styleSheet.addRule)
                styleElement.styleSheet.addRule(selectors[i], rules[i]); // IE
            else
                styleElement.appendChild(document.createTextNode(selectors[i] + rules[i])); // Mozilla + Safari
        document.getElementsByTagName("head")[0].appendChild(styleElement);
    }
}

function onFolderSubscribeCB(folderData) {
    var folder = $(folderData["folder"]);
    if (!folder) {
        appendCalendar(folderData["folderName"], folderData["folder"]);
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();		
    }
}

function onFolderUnsubscribeCB(folderId) {
    var node = $(folderId);
    node.parentNode.removeChild(node);
    if (removeFolderRequestCount == 0) {
        refreshEvents();
        refreshTasks();
        changeCalendarDisplay();
    }
}

function onCalendarRemove(event) {
    if (removeFolderRequestCount == 0) {
        var nodes = $("calendarList").getSelectedNodes();
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].deselect();
            var owner = nodes[i].getAttribute("owner");
            var folderId = nodes[i].getAttribute("id");
            if (owner == UserLogin) {
                if (folderId == "/personal") {
                    var label = labels["You cannot remove nor unsubscribe from your"
                                       + " personal calendar."];
                    window.alert(label);
                }
                else {
                    var folderIdElements = folderId.split(":");
                    deletePersonalCalendar(folderIdElements[0]);
                }
            }
            else {
                var folderUrl = ApplicationBaseURL + folderId;
                unsubscribeFromFolder(folderUrl, owner,
                                      onFolderUnsubscribeCB, folderId);
            }
        }
    }
  
    preventDefault(event);
}

function deletePersonalCalendar(folderElement) {
    var folderId = folderElement.substr(1);
    var label
        = labels["Are you sure you want to delete the calendar \"%{0}\"?"].formatted($(folderElement).lastChild.nodeValue.strip());
    if (window.confirm(label)) {
        removeFolderRequestCount++;
        var url = ApplicationBaseURL + "/" + folderId + "/delete";
        triggerAjaxRequest(url, deletePersonalCalendarCallback, folderId);
    }
}

function deletePersonalCalendarCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var ul = $("calendarList");
            var children = ul.childNodesWithTag("li");
            var i = 0;
            var done = false;
            while (!done && i < children.length) {
                var currentFolderId = children[i].getAttribute("id").substr(1);
                if (currentFolderId == http.callbackData) {
                    ul.removeChild(children[i]);
                    done = true;
                }
                else
                    i++;
            }
            removeFolderRequestCount--;
            if (removeFolderRequestCount == 0) {
                refreshEvents();
                refreshTasks();
                changeCalendarDisplay();
            }
        }
    }
    else
        log ("ajax problem 5: " + http.status);
}

function configureLists() {
    var list = $("tasksList");
    list.multiselect = true;
    list.observe("mousedown", onTasksSelectionChange);
    list.observe("selectstart", listRowMouseDownHandler);

    var input = $("showHideCompletedTasks");
    input.observe("click", onShowCompletedTasks);
    if (showCompletedTasks)
      input.checked = true;

    list = $("eventsList");
    list.multiselect = true;
    configureSortableTableHeaders(list);
    TableKit.Resizable.init(list, {'trueResize' : true, 'keepWidth' : true});
    list.observe("mousedown", onEventsSelectionChange);
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

    if (Prototype.Browser.IE) {
        var days = $$("DIV#daysView DIV.days");
        var labels = $$("DIV#calendarHeader DIV.days");
        if (days.length && labels.length) {
            var day = days[0];
            var label = labels[0];
            day.setStyle({ width: (label.getWidth()-1) + "px" });
        }
    }
    if (!$(document.body).hasClassName("popup"))
        drawNowLine ();
}

function drawNowLine () {
  var d = new Date();
  var hours = d.getHours();
  var minutes = d.getMinutes();

  if (currentView == "dayview") {
    var today = new Date ();
    var m = parseInt(today.getMonth ()) + 1;
    var d = today.getDate ();
    if (m < 10)
      m = "0" + m;
    if (d < 10)
      d = "0" + d;
    var day = today.getFullYear () + "" + m + "" + d;
    var targets = $$("DIV#daysView DIV.days DIV.day[day=" + day 
                     + "] DIV.events DIV.clickableHourCell");
  }
  else if (currentView == "weekview")
    var targets = $$("DIV#daysView DIV.days DIV.dayOfToday DIV.events DIV.clickableHourCell");
  
  if (targets) {
    var target = targets[hours];

    if (target) {
      var div = $("nowLineDisplay");
      if (!div)
        div = new Element ("div", {'id': 'nowLineDisplay'});
    
      div.style.top = parseInt (((minutes * target.offsetHeight) / 60) - 1) + "px";
      target.appendChild (div);
    
      setTimeout ("drawNowLine ();", 60000); // 1 min.
    }
  }
}

function initCalendars() {
    sorting["attribute"] = "start";
    sorting["ascending"] = true;
    showCompletedTasks = UserDefaults['ShowCompletedTasks'];
  
    if (!$(document.body).hasClassName("popup")) {
        var node = $("filterpopup");
        listFilter = node.value;
        initDateSelectorEvents();
        initCalendarSelector();
        configureSearchField();
        configureLists();
        $("calendarList").attachMenu("calendarsMenu");
        $(document.body).observe("click", onBodyClickHandler);
    }

    onWindowResize.defer();
    Event.observe(window, "resize", onWindowResize);
}

document.observe("dom:loaded", initCalendars);
