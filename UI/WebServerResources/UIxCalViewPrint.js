/* -*- Mode: js2-mode; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
 Copyright (C) 2006-2014 Inverse
 
 This file is part of SOGo
 
 SOGo is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.
 
 SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with SOGo; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
 */

/******************************** Global variables *******************************************/
var firstDayOfWeek = window.opener.firstDayOfWeek;
var printCompletedTasks=1;
var printNoDueDateTasks=true;
var printColors= { checked:true, style:"borders" };
var eventsBlocks;
var currentPreview;
var currentDay = window.parentvar("currentDay");
var sd, ed;

/****************************************** Ajax Requests, callbacks & events/tasks drawings ***************************************************/

function refreshContent() {
    refreshEvents(); // Get the eventBlocks and draw them
    refreshTasks();  // Get the taskLists and draw them
}

function updateDisplayView(data, newView) {
    newView = ((newView) ? newView : currentPreview);
    var url = ApplicationBaseURL + "/" + newView;
    var day = null;

    if (data)
        day = data['day'];
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
                }
                else
                    document.selectedDate = null;

                setSelectedDayDate(day);

                return false;
            }
            else if (day.length == 6)
                day += "01";
        }
        url += "?day=" + day;
    }
    selectedCalendarCell = null;

    if (document.dayDisplayAjaxRequest) {
        document.dayDisplayAjaxRequest.aborted = true;
        document.dayDisplayAjaxRequest.abort();
    }
    document.dayDisplayAjaxRequest = triggerAjaxRequest(url, previewDisplayCallback,
                                                        { "view": newView, "day": day});
}

function previewDisplayCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        $("rightFrameEvents").innerHTML = http.responseText;
        $("currentViewMenu").remove();
        $("listCollapse").remove();

        if (currentPreview == "multicolumndayview")
            _drawCalendarAllDayEvents(null, null, eventsBlocks);
        else {
            allDayEventsList = eventsBlocks[1];
            if (currentPreview == "monthview") {
                //_drawMonthCalendarEvents(eventsList, eventsBlocks[0], null);
            }
            else
                _drawCalendarAllDayEvents(allDayEventsList, eventsBlocks[0], null);
        }
        // This ensure to diplay working hours checkbox when switching views
        var printHoursCheckBox = $("printHours");
        onPrintWorkingHoursCheck(printHoursCheckBox);
        
        // Add events color for each calendars
        //addCalendarsColor();
    }
    else
        log ("calendarDisplayCallback Ajax error ("+ http.readyState + "/" + http.status + ")");

    return false;
}

function addCalendarsColor () {
    var allCalendars = window.parent$("calendarList");
    var allColors = window.parentvar("UserSettings")['Calendar']['FolderColors'];

    for (var i = 0; i < allCalendars.children.length; i++) {
        if (allCalendars.children[i].down("input").checked){
            owner = allCalendars.children[i].getAttribute("owner");
            folderName = allCalendars.children[i].getAttribute("id").substr(1);

            color = allColors[owner + ":Calendar/" + folderName];
            if (!color) {
                if(folderName.split("_")[1])
                    color = allColors[owner + ":Calendar/" + folderName.split("_")[1]];
                else
                    color = "#AAAAAA";
            }
            appendStyleElement(folderName, color);
        }
    }
}

function refreshEvents() {
    var todayDate = new Date();

    if (!currentDay)
        currentDay = todayDate.getDayString();

    if (currentPreview == "dayview" || currentPreview == "multicolumndayview") {
        sd = currentDay;
        ed = sd;
    }
    else if (currentPreview == "weekview") {
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
    if (document.refreshEventsAjaxRequest) {
        document.refreshEventsAjaxRequest.aborted = true;
        document.refreshEventsAjaxRequest.abort();
    }
    var url = (ApplicationBaseURL + "/eventsblocks?sd=" + sd + "&ed=" + ed
               + "&view=" + currentPreview);

    document.refreshEventsAjaxRequest
    = triggerAjaxRequest(url, refreshEventsCallback,
                         {"startDate": sd, "endDate": ed});
}

function refreshTasks(){
    if (document.tasksListAjaxRequest) {
        document.tasksListAjaxRequest.aborted = true;
        document.tasksListAjaxRequest.abort();
    }

    var taskListFilter = window.parentvar("taskListFilter");
    url = window.parentvar("ApplicationBaseURL") + "/" + "taskslist?show-completed=" + printCompletedTasks
        + "&asc=" + sorting["task-ascending"]
        + "&sort=" + sorting["task-attribute"]
        + "&filterpopup=" + taskListFilter;

    // TODO : Is that really necessary ?
    var tasksList = window.parent$("tasksList");
    var selectedIds;
    if (tasksList)
        selectedIds = tasksList.getSelectedNodesId();
    else
        selectedIds = null;

    document.tasksListAjaxRequest = triggerAjaxRequest(url, refreshTasksListCallback, selectedIds);
}

function refreshEventsCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        if (http.responseText.length > 0) {
            eventsBlocks = http.responseText.evalJSON(true);
            $("rightFrameEvents").innerHTML = "";
            if ($("printLayoutList").value == "0" && eventsBlocks.length > 0) {
                _drawEventsCells(eventsBlocks);
            }
            else {
                updateDisplayView(null, currentPreview);
            }
            adjustFrames();
        }
    }
    else
        log("AJAX error when refreshing calendar events");
}

function refreshTasksListCallback(http) {
    if (http.readyState == 4
        && http.status == 200) {
        if (http.responseText.length > 0) {
            var tasksBlocks = http.responseText.evalJSON(true);
            $("rightFrameTasks").innerHTML = "";
            if (tasksBlocks.length > 0) {
                _drawTasksCells(tasksBlocks);
                adjustFrames();
            }
        }
    }
    else
        log("AJAX error when refreshing calendar events");
}

function _drawEventsCells(eventsBlocks) {
    var events = _("Events");
    $("rightFrameEvents").insert("<h3>"+events+"</h3>");
    if (currentPreview == "multicolumndayview") {
        for(var i=0; i < eventsBlocks.length; i++) { // calendars
            for (var j = 0; j < eventsBlocks[i][0].length; j++) {
                var event = _parseEvent(eventsBlocks[i][0][j]);
                $("rightFrameEvents").insert(event);
            }
        }
    }
    else {
        for(var i=0; i < eventsBlocks[0].length; i++) {
            var event = _parseEvent(eventsBlocks[0][i]);
            $("rightFrameEvents").insert(event);
        }
    }
}

function _drawTasksCells(tasksBlocks) {
    var task = _("Tasks");
    $("rightFrameTasks").insert("<h3>"+task+"</h3>");
    for(var i=0; i < tasksBlocks.length; i++) {
        if (!(printNoDueDateTasks == false && tasksBlocks[i][5] == null)) {
            var task = _parseTask(tasksBlocks[i]);
            $("rightFrameTasks").insert(task);
        }
    }
}

function addColorsOnEvents(eventInside, eventCell) {
    if (printColors.checked == true) {
        if (printColors.style == "borders") {
            var string = "borderC" + eventInside.getAttribute("class").split(" ")[1].substr(1);
            Element.addClassName(eventCell, string);
        }
        else if(printColors.style == "backgrounds") {
            var string = "backgroundC" + eventInside.getAttribute("class").split(" ")[1].substr(1);
            Element.addClassName(eventInside, string);
        }
    }
}

function _drawCalendarEvents(events, eventsData, columnsData) {
    var daysView = $("daysView");
    var subdivs = daysView.childNodesWithTag("div");
    var printHoursCheckBox = $("printHours");
    for (var i = 0; i < subdivs.length; i++) {
        var subdiv = subdivs[i];
        if (subdiv.hasClassName("days")) {
            var days = subdiv.childNodesWithTag("div");
            if (currentPreview == "multicolumndayview") {
                for (var j = 0; j < days.length; j++) {
                    var parentDiv = days[j].childNodesWithTag("div")[0];
                    var calendar = columnsData[j];
                    var calendarEvents = calendar[2][0];
                    var calendarEventsData = calendar[0];
                    if (parentDiv.getElementsByClassName("event").length > 0) {
                        var oldEvents = parentDiv.getElementsByClassName("event");
                        var length = oldEvents.length - 1;
                        for (var x = length; x >= 0; x--)
                            oldEvents[x].remove();
                    }
                    for (var k = 0; k < calendarEvents.length; k++) {
                        var eventRep = calendarEvents[k];
                        var nbr = eventRep.nbr;
                        
                        if (printHoursCheckBox.checked) {
                            var offset = _computeOffset(parentDiv);
                            if ((eventRep.start - offset[0]) > 0 && (eventRep.start - offset[0]) < offset[1]) {
                                var eventCell = newEventDIV(eventRep, calendarEventsData[nbr], offset[0]);
                                var eventInside = eventCell.down(".eventInside");
                                addColorsOnEvents(eventInside, eventCell);
                                parentDiv.appendChild(eventCell);
                            }
                        }
                        else {
                            var eventCell = newEventDIV(eventRep, calendarEventsData[nbr], null);
                            var eventInside = eventCell.down(".eventInside");
                            addColorsOnEvents(eventInside, eventCell);
                            parentDiv.appendChild(eventCell);
                        }
                    }
                }
            }
            else {
                for (var j = 0; j < days.length; j++) {
                    var parentDiv = days[j].childNodesWithTag("div")[0];
                    if (parentDiv.getElementsByClassName("event").length > 0) {
                        var oldEvents = parentDiv.getElementsByClassName("event");
                        var length = oldEvents.length - 1;
                        for (var x = length; x >= 0; x--)
                            oldEvents[x].remove();
                    }
                    for (var k = 0; k < events[j].length; k++) {
                        var eventRep = events[j][k];
                        var nbr = eventRep.nbr;
                        if (printHoursCheckBox.checked) {
                            var offset = _computeOffset(parentDiv);
                            if ((eventRep.start - offset[0]) > 0 && (eventRep.start - offset[0]) < offset[1]) {
                                var eventCell = newEventDIV(eventRep, eventsData[nbr], offset[0]);
                                var eventInside = eventCell.down(".eventInside");
                                addColorsOnEvents(eventInside, eventCell);
                                parentDiv.appendChild(eventCell);
                            }
                        }
                        else {
                            var eventCell = newEventDIV(eventRep, eventsData[nbr], null);
                            var eventInside = eventCell.down(".eventInside");
                            addColorsOnEvents(eventInside, eventCell);
                            parentDiv.appendChild(eventCell);
                        }
                    }
                }
            }
        }
    }
}

function _drawCalendarAllDayEvents(events, eventsData, columnsData) {
    var headerView = $("calendarHeader");
    var subdivs = headerView.childNodesWithTag("div");

    if (currentPreview == "multicolumndayview") {
        var days = subdivs[2].childNodesWithTag("div");
        for (var i = 0; i < days.length; i++) {
            var parentDiv = days[i];
            var calendar = columnsData[i];
            var calendarAllDayEvents = calendar[1][0];
            var calendarAllDayEventsData = calendar[0];
            for (var j = 0; j < calendarAllDayEvents.length; j++) {
                var eventRep = calendarAllDayEvents[j];
                var nbr = eventRep.nbr;
                var eventCell = newAllDayEventDIV(eventRep, calendarAllDayEventsData[nbr]);
                parentDiv.appendChild(eventCell);
            }
        }
    }
    else {
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
    }
    adjustPreviewHeader();
}

// todo : month

function newEventDIV(eventRep, event, offset) {
    var eventCell = newBaseEventDIV(eventRep, event, event[4]);

    var pc = 100 / eventRep.siblings;
    var left = Math.floor(eventRep.position * pc);
    eventCell.style.left = left + "%";
    var right = Math.floor(100 - (eventRep.position + 1) * pc);
    eventCell.style.right = right + "%";
    if (offset != null) {
        eventCell.addClassName("starts" + (eventRep.start - offset));
    }
    else {
        eventCell.addClassName("starts" + eventRep.start);
    }
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

    return eventCell;
}

function appendStyleElement(folderPath, color) {
    if (document.styleSheets) {
        var fgColor = getContrastingTextColor(color);
        var styleElement = document.styleSheets[3];
        
        if (printColors.style == "backgrounds") {
            styleElement.insertRule(".calendarFolder" + folderPath +
                                    "{background-color: " + color + " !important;" +
                                    " color: " + fgColor + " !important;" +
                                    " border: none;}", styleElement.cssRules.length);
        }
        else if (printColors.style == "borders")
            styleElement.insertRule(".calendarFolder" + folderPath +
                                    "{background-color: none" +
                                    " color: none" +
                                    " border:1px solid " + color + " !important;}", styleElement.cssRules.length);
    }
}

function _parseEvent(event) {
    // Localized strings :
    var start = _("Start:");
    var end = _("End:");
    var location = _("Location:");
    var calendar = _("Calendar:");

    var newEvent = document.createElement("div");
    var table = document.createElement("table");
    Element.addClassName(newEvent, "divEventsPreview");

    var row = table.insertRow(0);
    row.insertCell(0);
    var title = row.insertCell(1);
    row = table.insertRow(1);
    var startCell = row.insertCell(0);
    Element.addClassName(startCell, "cellFormat");
    var startCellValue = row.insertCell(1);
    row = table.insertRow(2);
    var endCell = row.insertCell(0);
    Element.addClassName(endCell, "cellFormat");
    var endCellValue = row.insertCell(1);
    row = table.insertRow(3);
    var locationCell = row.insertCell(0);
    Element.addClassName(locationCell, "cellFormat");
    var locationCellValue = row.insertCell(1);
    row = table.insertRow(4);
    var calendarCell = row.insertCell(0);
    Element.addClassName(calendarCell, "cellFormat");
    var calendarCellValue = row.insertCell(1);
    
    title.innerHTML = event[4];
    startCell.innerHTML = start;
    var startDate = new Date(event[5] *1000);
    startCellValue.innerHTML = startDate.toLocaleString();
    endCell.innerHTML = end;
    var endDate = new Date(event[6] *1000);
    endCellValue.innerHTML = endDate.toLocaleString();
    locationCell.innerHTML = location;
    locationCellValue.innerHTML = event[7];
    calendarCell.innerHTML = calendar;
    calendarCellValue.innerHTML = event[2];

    if (printColors.checked) {
        var allColors = window.parentvar("UserSettings")['Calendar']['FolderColors'];
        var owner = event[13];
        var folderName = event[1];
        var color = allColors[owner + ":Calendar/" + folderName];
        var fgColor = getContrastingTextColor(color);
        
        if (printColors.style == "backgrounds") {
            newEvent.writeAttribute("style", "background-color:" + color + "; color:" + fgColor + ";");
            startCell.writeAttribute("style", "color:" + fgColor + ";");
            endCell.writeAttribute("style", "color:" + fgColor + ";");
            locationCell.writeAttribute("style", "color:" + fgColor + ";");
            calendarCell.writeAttribute("style", "color:" + fgColor + ";");
            
        }
        else if (printColors.style == "borders")
            newEvent.writeAttribute("style", "border:2px solid " + color + ";");
    }
    if (event[7] == "") {
        locationCell.hide();
        locationCellValue.hide();
    }
    newEvent.appendChild(table);

    return newEvent;
}

function _parseTask(task) {
    // new code
    var end = _("Due Date:");
    var calendar = _("Calendar:");
    var location = _("Location:");

    var newTask = document.createElement("div");
    var table = document.createElement("table");
    Element.addClassName(newTask, "divTasksPreview");

    var row = table.insertRow(0);
    row.insertCell(0);
    var title = row.insertCell(1);
    row = table.insertRow(1);
    var endCell = row.insertCell(0);
    var endCellValue = row.insertCell(1);
    row = table.insertRow(2);
    var locationCell = row.insertCell(0);
    var locationCellValue = row.insertCell(1);
    row = table.insertRow(3);
    var calendarCell = row.insertCell(0);
    var calendarCellValue = row.insertCell(1);

    title.innerHTML = task[4];
    if (task[5] != null) {
        endCell.innerHTML = end;
        var endDate = new Date(task[5] *1000);
        endCellValue.innerHTML = endDate.toLocaleString();
    }
    else {
        endCell.hide();
        endCellValue.hide();
    }
    if (task[7] != "") {
        locationCell.innerHTML = location;
        locationCellValue.innerHTML = task[7];
    }
    else {
        locationCell.hide();
        locationCellValue.hide();
    }
    calendarCell.innerHTML = calendar;
    calendarCellValue.innerHTML = task[2];
    
    if (task[13] == "overdue")
        Element.addClassName(title, "overdueTasks");
    else if (task[13] == "completed")
        Element.addClassName(title, "completedTasks");
    else
        Element.addClassName(title, "tasksTitle");
    
    if (printColors.checked) {
        var allColors = window.parentvar("UserSettings")['Calendar']['FolderColors'];
        var owner = task[12];
        var folderName = task[1];
        var color = allColors[owner + ":Calendar/" + folderName];
        var fgColor = getContrastingTextColor(color);
        
        if (printColors.style == "backgrounds") {
            newTask.writeAttribute("style", "background-color:" + color + "; color:" + fgColor + ";");
            endCell.writeAttribute("style", "color:" + fgColor + ";");
            locationCell.writeAttribute("style", "color:" + fgColor + ";");
            calendarCell.writeAttribute("style", "color:" + fgColor + ";");
            
        }
        else if (printColors.style == "borders")
            newTask.writeAttribute("style", "border:2px solid " + color + ";");
    }

    newTask.appendChild(table);

    return newTask;
}

function _computeOffset(hoursCells) {
    var outOfDayCells = hoursCells.getElementsByClassName("outOfDay");
    var count = 1;
    var offset = [];
    var buffer;
    var j = 1;
    for (var i = 0; i < outOfDayCells.length; i++) {
        hourCell1 = parseInt(outOfDayCells[i].getAttribute("hour")) + 100;
        hourCell2 = parseInt(outOfDayCells[j].getAttribute("hour"));
        if (hourCell1 == hourCell2)
            count += 1;
        else
            break;
        j ++;
    }
    offset.push(count * 4);
    offset.push((hourCell2 / 100 * 4) - (count * 4));

    return offset;
}

/************************************** Preview Navigation *****************************************/

function onCalendarGotoDay(node) {
    var day = node.getAttribute("date");

    changeDateSelectorDisplay(day);
    updateDisplayView({ "day": day });
    refreshEvents();

    return false;
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

    return false;
}

/*********************** Input Field, listMenu, Checkboxes and Radio *********************************/

function onInputTitleChange(event){
    var inputFieldTitle = $("inputFieldTitle").value;
    if (inputFieldTitle)
        document.getElementById("rightFrameTitle").innerHTML = inputFieldTitle + "<br />";
    else
        document.getElementById("rightFrameTitle").remove();

    return false;
}

function onPrintLayoutListChange() {
    var parentView = window.parentvar("currentView");
    var selectedLayout = $("printLayoutList").value;
    document.getElementById("printHours").disabled = (selectedLayout == 0);
    switch(selectedLayout) {
        case "0": // List view
            window.resizeTo(700,500);
            currentPreview = parentView;
            break;

        case "1": // Day view
            window.resizeTo(1010,500);
            currentPreview = "dayview";
            break;

        case "2": // Multi-columns view
            window.resizeTo(1010,500);
            currentPreview = "multicolumndayview";
            break;

        case "3": // Week view
            window.resizeTo(1010,500);
            currentPreview = "weekview";
            break;

            /*case "4": // Month view
             window.resizeTo(1010,500);
             currentPreview = "monthview";
             break;*/
    }
    refreshContent();
    return false;
}

function adjustPreviewHeader() {
    // 1 - Check if there is any allDay Events. If not reduce the space taken
    var selectedLayout = $("printLayoutList").value;
    if (selectedLayout != 0) {
        var calendarHeader = $("calendarHeader");
        var allDayDisplay = $("calendarHeader").getElementsByClassName("days");
        var allDayEvents = $("calendarHeader").getElementsByClassName("eventInside");
        var eventHeight = 22;
        var headerHeight = 38;
        if (selectedLayout == 1) { // Since there is only one column in day view
            height = allDayEvents.length * eventHeight;
        }
        else { // Applies only on week view and multi-columns view
            var nbEventsMax = 0
            var eventClass = $("calendarHeader").getElementsByClassName("event");
            for (var i = 0; i < allDayDisplay[0].childNodes.length; i++) {
                if (allDayDisplay[0].childNodes[i].firstChild != null) {
                    count = allDayDisplay[0].childNodes[i].getElementsByClassName("event").length;
                    if (count > nbEventsMax) {
                        nbEventsMax = count;
                    }
                }
            }
            height = nbEventsMax * eventHeight;
            if (selectedLayout == 2) {
                headerHeight = 58;
                adjustMultiColumnCalendarHeaderDIV();
            }
        }
        calendarHeader.style.height = (height + headerHeight) + "px";
        allDayDisplay[0].style.height = height + "px";
    }
}

function adjustMultiColumnCalendarHeaderDIV() {
    var ch = $("calendarHeader");
    var calendarLabels = ch.getElementsByClassName("calendarLabels")[0];
    var calendarsToDisplay = calendarLabels.getElementsByClassName("calendarsToDisplay");
    var dayLabels = ch.getElementsByClassName("dayLabels")[0].getElementsByClassName("dayColumn")[0];
    var days = ch.getElementsByClassName("days")[0].getElementsByClassName("dayColumn");
    var daysView = $("daysView").getElementsByClassName("dayColumn");
    var nbCalendars = calendarsToDisplay.length;

    if (nbCalendars > 0) {
        var width = 100/nbCalendars;
        var left = 0;
        var position = "absolute";
        for(var i=0; i < nbCalendars; i++){
            calendarsToDisplay[i].setStyle({ width: width + '%', left: left + '%', position: position}).show();
            days[i].setStyle({ width: width + '%', left: left + '%'}).show();
            daysView[i].setStyle({ width: width + '%', left: left + '%'}).show();
            left += width;
        }
        dayLabels.setStyle({ width: '100%'}).show();
    }
    else {
        $("calendarHeader").remove();
        $("daysView").remove();
        var htmlText = "<div class='alert-box notice'><span>" + _("notice:") + "</span>"+_("Please go ahead and select calendars")+"</div>";
        $("calendarContent").innerHTML = htmlText;
    }
}

function adjustFrames() {
    var view = $("printLayoutList").value;
    if (view == 0) {
        var eventsCheckBox = $("printEvents");
        var tasksCheckBox = $("printTasks");
        onEventsCheck(eventsCheckBox);
        onTasksCheck(tasksCheckBox);
        document.getElementById("rightFrameTasks").style.pageBreakBefore = 'auto';
        document.getElementById("rightFrameTasks").style.pageBreakInside = 'auto';
    }
    else {
        document.getElementById("rightFrameEvents").style.width = '100%';
        document.getElementById("rightFrameTasks").style.width = '100%';
        document.getElementById("rightFrameTasks").style.pageBreakBefore = 'always';
        document.getElementById("rightFrameTasks").style.pageBreakInside = 'avoid';
    }
    return false;
}

function onEventsCheck(checkBox) {
    var printOptions = document.getElementById("printHours");
    var selectedLayout = $("printLayoutList").value;
    if (!checkBox.checked || selectedLayout == 0)
        printOptions.disabled = true;
    else
        printOptions.disabled = false;
    
    var events = $("rightFrameEvents").childNodesWithTag("DIV");
    if(checkBox.checked && events.length > 0){
        $("rightFrameEvents").style.display = 'block';
        if ($("printLayoutList").value == 0){
            $("rightFrameTasks").style.width = '49.5%';
        }
    }
    else {
        $("rightFrameEvents").style.display = 'none';
        if ($("printLayoutList").value == 0){
            $("rightFrameTasks").style.width = '100%';
        }
    }
    return false;
}

function onTasksCheck(checkBox) {
    var printOptions = document.getElementsByName("printOptions");
    for (var i = 0; i < printOptions.length; i++)
        printOptions[i].disabled = !checkBox.checked;

    var tasks = $("rightFrameTasks").childNodesWithTag("DIV");
    if(checkBox.checked && tasks.length > 0) {
        $("rightFrameTasks").style.display = 'block';
        if ($("printLayoutList").value == 0){
            $("rightFrameEvents").style.width = '49.5%';
        }
    }
    else {
        $("rightFrameTasks").style.display = 'none';
        if ($("printLayoutList").value == 0){
            $("rightFrameEvents").style.width = '100%';
        }
    }
    return false;
}

function onPrintWorkingHoursCheck(checkBox) {
    var isCheked = checkBox.checked;
    var outOfDayCells = $$("DIV#daysView .outOfDay");
    var hours = $$("DIV#daysView .hour");
    var hoursOutOfDay = [];
    for (var i = 0; i < outOfDayCells.length; i++) {
        var buffer = outOfDayCells[i].getAttribute("hour").substr(0,1);
        if (buffer != "0") {
            buffer += outOfDayCells[i].getAttribute("hour").substr(1,1);
        }
        else {
            buffer = outOfDayCells[i].getAttribute("hour").substr(1,1);
        }
        if(isCheked) {
            outOfDayCells[i].hide();
            hours[buffer].hide();
        }
        else {
            outOfDayCells[i].show();
            hours[buffer].show();
        }
    }

    if (currentPreview == "multicolumndayview")
        _drawCalendarEvents(null, null, eventsBlocks);
    else {
        eventsList = eventsBlocks[2];
        if (currentPreview == "monthview") {
            //_drawMonthCalendarEvents(eventsList, eventsBlocks[0], null);
        }
        else
            _drawCalendarEvents(eventsList, eventsBlocks[0], null);
    }
    return false;
}

function onPrintColorsCheck(checkBox) {
    printColors.checked = (checkBox.checked ? true : false);
    
    if (printColors.checked) {
        $("printBackgroundColors").disabled = false;
        $("printBorderColors").disabled = false;
    }
    else {
        $("printBackgroundColors").disabled = true;
        $("printBorderColors").disabled = true;
    }
    refreshContent();
}

function onPrintColors(selectedRadioButton) {
    printColors.style = selectedRadioButton.value;
    refreshContent();
}
/*function onPrintDateCheck() {
 var dateRange = document.getElementsByName("dateRange");
 var customDate = document.getElementById("customDate");
 for (var i = 0; i < dateRange.length; i++)
 if (dateRange[i].children[1].children[0].disabled == customDate.checked)
 dateRange[i].children[1].children[0].disabled = !customDate.checked;
 }*/

function onPrintCompletedTasksCheck(checkBox) {
    printCompletedTasks = (checkBox.checked ? 1 : 0);
    refreshContent();
}

function onPrintNoDueDateTasksCheck(checkBox) {
    printNoDueDateTasks = (checkBox.checked ? true : false);
    refreshContent();
}

/************** Date picker functions *************
 this.initTimeWidgets = function (widgets) {
 this.timeWidgets = widgets;
 
 jQuery(widgets['start']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
 jQuery(widgets['end']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
 
 //jQuery(widgets['start']['date']).change(onAdjustTime);
 
 jQuery(widgets['startingDate']['date']).closest('.date').datepicker({autoclose: true,
 weekStart: 0,
 endDate: lastDay,
 startDate: firstDay,
 setStartDate: lastDay,
 startView: 2,
 position: "below-shifted-left"});
 }
 
 this.onAdjustTime = function(event) {
 onAdjustDueTime(event);
 }
 
 this.onAdjustDueTime = function(event) {
 var dateDelta = (window.getStartDate().valueOf() - window.getShadowStartDate().valueOf());
 var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
 window.setDueDate(newDueDate);
 
 window.timeWidgets['start']['date'].updateShadowValue();
 }
 /****************************************************/

/******************************* Buttons ***********************************************/

function onPrintCancelClick(event) {
    this.blur();
    onCloseButtonClick(event);
}

function onPrintClick(event) {
    this.blur();
    window.print();
}
/**************************** Initialization *******************************************/

function init() {
    initializePrintSettings();
    //initializeWhatToPrint();
    //initializeOptions();
    $("cancelButton").observe("click", onPrintCancelClick);
    $("printButton").observe("click", onPrintClick);

    /* TODO : Selected and custom date must be implemented and finished.
     document.getElementById("eventsTasks").disabled=true;
     document.getElementById("customDate").disabled=true;*/

    onPrintLayoutListChange();
}

function initializePrintSettings() {
    $("inputFieldTitle").observe("change", onInputTitleChange);
    $("printLayoutList").observe("change", onPrintLayoutListChange);
}

/*function initializeWhatToPrint() {
 var widgets = {'start': {'date': $("startingDate")},
 'end':   {'date': $("endingDate")}};
 initTimeWidgets(widgets);
 onPrintDateCheck();
 
 }*/

/*function initializeOptions() {
}*/

document.observe("dom:loaded", init);
