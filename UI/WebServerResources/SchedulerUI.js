var sortOrder = '';
var sortKey = '';
var listFilter = 'view_today';

var CalendarBaseURL = ApplicationBaseURL;

var listOfSelection = null;

var hideCompletedTasks = 0;

var currentDay = '';
var currentView = 'dayview';

var cachedDateSelectors = new Array();

var contactSelectorAction = 'calendars-contacts';

var eventsToDelete = new Array();
var ownersOfEventsToDelete = new Array();

function newEvent(sender, type) {
  var day = sender.getAttribute("day");
  if (!day)
    day = currentDay;

  var hour = sender.getAttribute("hour");
  var urlstr = ApplicationBaseURL + "new" + type;
  var params = new Array();
  if (day)
    params.push("day=" + day);
  if (hour)
    params.push("hm=" + hour);
  if (params.length > 0)
    urlstr += "?" + params.join("&");

  window.open(urlstr, "", "width=620,height=600,resizable=0");

  return false; /* stop following the link */
}

function _editEventId(id, owner) {
  var urlBase;
  if (owner)
    urlBase = UserFolderURL + "../" + owner + "/";
  urlBase += "Calendar/"

  var urlstr = urlBase + id + "/edit";

  var win = window.open(urlstr, "SOGo_edit_" + id,
                        "width=620,height=600,resizable=0,scrollbars=0,toolbar=0," +
                        "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  win.focus();
}

function editEvent() {
  if (listOfSelection) {
    var nodes = listOfSelection.getSelectedRows();

    for (var i = 0; i < nodes.length; i++)
      _editEventId(nodes[i].getAttribute("id"),
                   nodes[i].getAttribute("owner"));
  }


  return false; /* stop following the link */
}

function _batchDeleteEvents() {
  var events = eventsToDelete.shift();
  var owner = ownersOfEventsToDelete.shift();
  var urlstr = (UserFolderURL + "../" + owner + "/Calendar/batchDelete?ids="
                + events.join('/'));
  document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
                                                       deleteEventCallback,
                                                       events);
}

function deleteEvent()
{
  if (listOfSelection) {
    var nodes = listOfSelection.getSelectedRows();

    if (nodes.length > 0) {
      var label = "";
      if (listOfSelection == $("tasksList"))
        label = labels["taskDeleteConfirmation"].decodeEntities();
      else
        label = labels["appointmentDeleteConfirmation"].decodeEntities();
      
      if (confirm(label)) {
        if (document.deleteEventAjaxRequest) {
          document.deleteEventAjaxRequest.aborted = true;
          document.deleteEventAjaxRequest.abort();
        }
        var sortedNodes = new Array();
        var owners = new Array();

        for (var i = 0; i < nodes.length; i++) {
          var owner = nodes[i].getAttribute("owner");
          if (!sortedNodes[owner]) {
              sortedNodes[owner] = new Array();
              owners.push(owner);
          }
          sortedNodes[owner].push(nodes[i].getAttribute("id"));
        }
        for (var i = 0; i < owners.length; i++) {
          ownersOfEventsToDelete.push(owners[i]);
          eventsToDelete.push(sortedNodes[owners[i]]);
        }
        _batchDeleteEvents();
      }
    }
  }

  return false;
}

function modifyEvent(sender, modification) {
  var currentLocation = '' + window.location;
  var arr = currentLocation.split("/");
  arr[arr.length-1] = modification;
  window.location = arr.join("/");
  window.close();
}

function deleteEventCallback(http)
{
  if (http.readyState == 4
      && http.status == 200) {
    var nodes = $(http.callbackData);
    for (var i = 0; i < nodes.length; i++) {
      var node = $(nodes[i]);
      node.parentNode.removeChild(node);
    }
    if (eventsToDelete.length)
      _batchDeleteEvents();
    else {
      document.deleteEventAjaxRequest = null;
      refreshAppointments();
      refreshTasks();
      changeCalendarDisplay();
    }
  }
  else
    log ("ajax fuckage");
}

function editDoubleClickedEvent(node)
{
  _editEventId(node.getAttribute("id"),
               node.getAttribute("owner"));
  
  return false;
}

function onSelectAll() {
  var list = $("appointmentsList");
  list.selectRowsMatchingClass("appointmentRow");

  return false;
}

function displayAppointment(event, sender) {
  _editEventId(sender.getAttribute("aptCName"),
               sender.getAttribute("owner"));

  event.cancelBubble = true;
  event.returnValue = false;
}

function onDaySelect(node)
{
  var day = node.getAttribute("day");

  var td = node.getParentWithTagName("td");
  var table = td.getParentWithTagName("table");

//   log ("table.selected: " + table.selected);

  if (document.selectedDate)
    deselectNode(document.selectedDate);

  selectNode(td);
  document.selectedDate = td;

  changeCalendarDisplay( { "day": day } );
  if (listFilter == 'view_selectedday')
    refreshAppointments();

  return false;
}

function onDateSelectorGotoMonth(node)
{
  var day = node.getAttribute("date");

  changeDateSelectorDisplay(day, true);

  return false;
}

function onCalendarGotoDay(node)
{
  var day = node.getAttribute("date");

  changeDateSelectorDisplay(day);
  changeCalendarDisplay( { "day": day } );

  return false;
}

function gotoToday()
{
  changeDateSelectorDisplay('');
  changeCalendarDisplay();

  return false;
}

function setDateSelectorContent(content)
{
  var div = $("dateSelectorView");

  div.innerHTML = content;
  if (currentDay.length > 0)
    restoreCurrentDaySelection(div);
}

function dateSelectorCallback(http)
{
  if (http.readyState == 4
      && http.status == 200) {
    document.dateSelectorAjaxRequest = null;
    var content = http.responseText;
    setDateSelectorContent(content);
    cachedDateSelectors[http.callbackData] = content;
  }
  else
    log ("ajax fuckage");
}

function appointmentsListCallback(http)
{
  var div = $("appointmentsListView");

  if (http.readyState == 4
      && http.status == 200) {
    document.appointmentsListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var params = parseQueryParameters(http.callbackData);
    sortKey = params["sort"];
    sortOrder = params["desc"];
    configureSortableTableHeaders();
  }
  else
    log ("ajax fuckage");
}

function tasksListCallback(http)
{
  var div = $("tasksListView");

  if (http.readyState == 4
      && http.status == 200) {
    document.tasksListAjaxRequest = null;
    div.innerHTML = http.responseText;
    if (http.callbackData) {
      var selectedNodesId = http.callbackData;
      for (var i = 0; i < selectedNodesId.length; i++)
        selectNode($(selectedNodesId[i]));
    }
  }
  else
    log ("ajax fuckage");
}

function calendarsListCallback(http)
{
//   var div = $("calendarSelectorView");

  if (http.readyState == 4
      && http.status == 200) {
//     document.calendarsListAjaxRequest = null;
//     div.innerHTML = http.responseText;
  }
  else
    log ("ajax fuckage");
}

function restoreCurrentDaySelection(div)
{
  var elements = div.getElementsByTagName("a");
  var day = null;
  var i = 9;
  while (!day && i < elements.length)
    {
      day = elements[i].getAttribute("day");
      i++;
    }

  if (day
      && day.substr(0, 6) == currentDay.substr(0, 6)) {
      for (i = 0; i < elements.length; i++) {
        day = elements[i].getAttribute("day");
        if (day && day == currentDay) {
          var td = elements[i].getParentWithTagName("td");
          if (document.selectedDate)
            deselectNode(document.selectedDate);
          selectNode(td);
          document.selectedDate = td;
        }
      }
    }
}

function changeDateSelectorDisplay(day, keepCurrentDay)
{
  var url = ApplicationBaseURL + "dateselector";
  if (day)
    url += "?day=" + day;

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

function changeCalendarDisplay(time, newView)
{
  var url = CalendarBaseURL + ((newView) ? newView : currentView);

  var day = null;
  var hour = null;
  if (time) {
    day = time['day'];
    hour = time['hour'];
  }

  if (!day)
    day = currentDay;
  if (day)
    url += "?day=" + day;

//   if (newView)
//     log ("switching to view: " + newView);
//   log ("changeCalendarDisplay: " + url);

  if (document.dayDisplayAjaxRequest) {
//     log ("aborting day ajaxrq");
    document.dayDisplayAjaxRequest.aborted = true;
    document.dayDisplayAjaxRequest.abort();
  }
  document.dayDisplayAjaxRequest = triggerAjaxRequest(url,
                                                      calendarDisplayCallback,
                                                      { "view": newView,
                                                        "day": day,
                                                        "hour": hour });

  return false;
}

function _ensureView(view) {
  if (currentView != view)
    changeCalendarDisplay(null, view);

  return false;
}

function onDayOverview()
{
  return _ensureView("dayview");
}

function onWeekOverview()
{
  return _ensureView("weekview");
}

function onMonthOverview()
{
  return _ensureView("monthview");
}

function scrollDayView(hour)
{
  var rowNumber;
  if (hour) {
    if (hour.length == 3)
      rowNumber = parseInt(hour.substr(0, 1));
    else {
      if (hour.substr(0, 1) == "0")
        rowNumber = parseInt(hour.substr(1, 1));
      else
        rowNumber = parseInt(hour.substr(0, 2));
    }
  } else
    rowNumber = 8;

  var calContent = $("calendarContent");
  var tables = calContent.getElementsByTagName("table");
  if (tables.length > 0) {
    var row = tables[0].rows[rowNumber + 1];
    var cell = row.cells[1];

    calContent.scrollTop = cell.offsetTop;
  }
}

function calendarDisplayCallback(http)
{
  var div = $("calendarView");

//   log ("calendardisplaycallback: " + div);
  if (http.readyState == 4
      && http.status == 200) {
    document.dateSelectorAjaxRequest = null;
    div.innerHTML = http.responseText;
    if (http.callbackData["view"])
      currentView = http.callbackData["view"];
    if (http.callbackData["day"])
      currentDay = http.callbackData["day"];
    var hour = null;
    if (http.callbackData["hour"])
      hour = http.callbackData["hour"];
    if (currentView != 'monthview')
      scrollDayView(hour);
  }
  else
    log ("ajax fuckage");
}

function assignCalendar(name)
{
  var node = $(name);

  node.calendar = new skycalendar(node);
  node.calendar.setCalendarPage(ResourcesURL + "/skycalendar.html");
  var dateFormat = node.getAttribute("dateFormat");
  if (dateFormat)
    node.calendar.setDateFormat(dateFormat);
}

function popupCalendar(node)
{
  var nodeId = node.getAttribute("inputId");
  var input = $(nodeId);
  input.calendar.popup();

  return false;
}

function onAppointmentContextMenu(event, element)
{
  var topNode = $('appointmentsList');
//   log(topNode);

  var menu = $('appointmentsListMenu');

  menu.addEventListener("hideMenu", onAppointmentContextMenuHide, false);
  onMenuClick(event, 'appointmentsListMenu');

  var topNode = $('appointmentsList');
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    deselectNode (selectedNodes[i]);

  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onAppointmentContextMenuHide(event)
{
  var topNode = $('appointmentsList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodeIds = topNode.menuSelectedRows;
    for (var i = 0; i < nodeIds.length; i++) {
      var node = $(nodeIds[i]);
      selectNode (node);
    }
    topNode.menuSelectedRows = null;
  }
}

function onAppointmentsSelectionChange() {
  listOfSelection = $("appointmentsList");
  listOfSelection.removeClassName("_unfocused");
  $("tasksList").addClassName("_unfocused");
}

function onTasksSelectionChange() {
  listOfSelection = $("tasksList");
  listOfSelection.removeClassName("_unfocused");
  $("appointmentsList").addClassName("_unfocused");
}

function _loadAppointmentHref(href) {
  if (document.appointmentsListAjaxRequest) {
    document.appointmentsListAjaxRequest.aborted = true;
    document.appointmentsListAjaxRequest.abort();
  }
  var url = CalendarBaseURL + href;
  document.appointmentsListAjaxRequest
    = triggerAjaxRequest(href, appointmentsListCallback, href);

  return false;
}

function _loadTasksHref(href) {
  if (document.tasksListAjaxRequest) {
    document.tasksListAjaxRequest.aborted = true;
    document.tasksListAjaxRequest.abort();
  }
  url = CalendarBaseURL + href;

  var selectedIds = $("tasksList").getSelectedNodesId();
  document.tasksListAjaxRequest
    = triggerAjaxRequest(url, tasksListCallback, selectedIds);

  return false;
}

function onHeaderClick(event) {
  log("onHeaderClick: " + this.link);
  _loadAppointmentHref(this.link);

  event.preventDefault();
}

function refreshAppointments() {
  return _loadAppointmentHref("aptlist?desc=" + sortOrder
                              + "&sort=" + sortKey
                              + "&day=" + currentDay
                              + "&filterpopup=" + listFilter);
}

function refreshTasks() {
  return _loadTasksHref("taskslist?hide-completed=" + hideCompletedTasks);
}

function refreshAppointmentsAndDisplay()
{
  refreshAppointments();
  changeCalendarDisplay();
}

function onListFilterChange() {
  var node = $("filterpopup");

  listFilter = node.value;
//   log ("listFilter = " + listFilter);

  return refreshAppointments();
}

function onAppointmentClick(event)
{
  var node = event.target.getParentWithTagName("tr");
  var day = node.getAttribute("day");
  var hour = node.getAttribute("hour");

  changeCalendarDisplay( { "day": day, "hour": hour} );
  changeDateSelectorDisplay(day);

  return onRowClick(event);
}

function selectMonthInMenu(menu, month)
{
  var entries = menu.childNodes[1].childNodesWithTag("LI");
  for (i = 0; i < entries.length; i++) {
    var entry = entries[i];
    var entryMonth = entry.getAttribute("month");
    if (entryMonth == month)
      entry.addClassName("currentMonth");
    else
      entry.removeClassName("currentMonth");
  }
}

function selectYearInMenu(menu, month)
{
  var entries = menu.childNodes[1].childNodes;
  for (i = 0; i < entries.length; i++) {
    var entry = entries[i];
    if (entry instanceof HTMLLIElement) {
      var entryMonth = entry.innerHTML;
      if (entryMonth == month)
        entry.addClassName("currentMonth");
      else
        entry.removeClassName("currentMonth");
    }
  }
}

function popupMonthMenu(event, menuId)
{
  var node = event.target;

  if (event.button == 0) {
    event.cancelBubble = true;
    event.returnValue = false;

    if (document.currentPopupMenu)
      hideMenu(event, document.currentPopupMenu);

    var popup = $(menuId);
    var id = node.getAttribute("id");
    if (id == "monthLabel")
      selectMonthInMenu(popup, node.getAttribute("month"));
    else
      selectYearInMenu(popup, node.innerHTML);

    var diff = (popup.offsetWidth - node.offsetWidth) /2;

    popup.style.top = (node.offsetTop + 95) + "px";
    popup.style.left = (node.offsetLeft - diff) + "px";
    popup.style.visibility = "visible";

    bodyOnClick = "" + document.body.getAttribute("onclick");
    document.body.setAttribute("onclick", "onBodyClick('" + menuId + "');");
    document.currentPopupMenu = popup;
  }
}

function onMonthMenuItemClick(node)
{
  var month = '' + node.getAttribute("month");
  var year = '' + $("yearLabel").innerHTML;
  
  changeDateSelectorDisplay(year+month+"01", true);

  return false;
}

function onYearMenuItemClick(node)
{
  var month = '' + $("monthLabel").getAttribute("month");;
  var year = '' + node.innerHTML;

  changeDateSelectorDisplay(year+month+"01", true);

  return false;
}

function onSearchFormSubmit()
{
  log ("search not implemented");

  return false;
}

function onCalendarSelectAppointment(event, node)
{
  var list = $("appointmentsList");
  list.deselectAll();

  var aptCName = node.getAttribute("aptCName");
  var row = $(aptCName);
  if (row) {
    var div = row.parentNode.parentNode.parentNode;
    div.scrollTop = row.offsetTop - (div.offsetHeight / 2);
    selectNode(row);
  }

  event.cancelBubble = false;
  event.returnValue = false;
}

function onCalendarSelectDay(event, node)
{
  var day = node.getAttribute("day");

  if (currentView == 'weekview')
    changeWeekCalendarDisplayOfSelectedDay(node);
  else if (currentView == 'monthview')
    changeMonthCalendarDisplayOfSelectedDay(node);
  changeDateSelectorDisplay(day);

  event.cancelBubble = true;
  event.returnValue = false;
}

function changeWeekCalendarDisplayOfSelectedDay(node)
{
  var tr = node.parentNode;
  var tbody = tr.parentNode;

  var oldSelected = -1;
  if (tbody.parentNode.selectedCell)
    oldSelected = tbody.parentNode.selectedCell.cellIndex;
  else {
    var cells = tr.cells;
    var i = 0;
    while (i < cells.length && oldSelected == -1)
      if (cells[i].hasClassName("selectedDay"))
        oldSelected = i;
      else
        i++;
  }
  tbody.parentNode.selectedCell = node;
  var newSelected = node.cellIndex;

  var rows = tbody.rows;
  for (i = 1; i < rows.length; i++) {
    rows[i].cells[oldSelected].removeClassName("selectedDay");
    rows[i].cells[newSelected].addClassName("selectedDay");
  }
}

function findMonthCalendarSelectedCell(table) {
  var tbody = table.tBodies[0];
  var rows = tbody.rows;

  var i = 1;
  while (i < rows.length && !table.selectedCell) {
    var cells = rows[i].cells;
    var j = 0;
    while (j < cells.length && !table.selectedCell) {
      if (cells[j].hasClassName("selectedDay"))
        table.selectedCell = cells[j];
      else
        j++;
    }
    i++;
  }
}

function changeMonthCalendarDisplayOfSelectedDay(node)
{
  var tr = node.parentNode;
  var table = tr.parentNode.parentNode;

  if (!table.selectedCell)
    findMonthCalendarSelectedCell(table);

  if (table.selectedCell)
    table.selectedCell.removeClassName("selectedDay");
  table.selectedCell = node;
  node.addClassName("selectedDay");
}

function onHideCompletedTasks(node)
{
  hideCompletedTasks = (node.checked ? 1 : 0);

  return refreshTasks();
}

function updateTaskStatus(node)
{
  var taskId = node.parentNode.getAttribute("id");
  var taskOwner = node.parentNode.getAttribute("owner");
  var newStatus = (node.checked ? 1 : 0);
//   log ("update task status: " + taskId);

  var http = createHTTPClient();

  url = (UserFolderURL + "../" + taskOwner + "/Calendar/"
         + taskId + "/changeStatus?status=" + newStatus);

  if (http) {
//     log ("url: " + url);
    // TODO: add parameter to signal that we are only interested in OK
    http.url = url;
    http.open("GET", url, false /* not async */);
    http.send("");
    if (http.status == 200)
      refreshTasks();
  } else
    log ("no http client?");

  return false;
}

function updateCalendarStatus()
{
  var list = new Array();

  var clist = $("calendarsList");
  var nodes = clist.childNodesWithTag("ul")[0].childNodesWithTag("li");
  for (var i = 0; i < nodes.length; i++) {
    var input = nodes[i].childNodesWithTag("input")[0];
    if (input.checked)
      list.push(nodes[i].getAttribute("uid"));
  }

  if (!list.length) {
    list.push(nodes[0].getAttribute("uid"));
    nodes[0].childNodesWithTag("input")[0].checked = true;
  }
  CalendarBaseURL = (UserFolderURL + "Groups/_custom_"
                     + list.join(",") + "/Calendar/");

  refreshAppointments();
  refreshTasks();
  changeCalendarDisplay();
  updateCalendarsList();

  return false;
}

function calendarUidsList()
{
  var list = "";

  var clist = $("calendarsList");
  var nodes = clist.childNodes[5].childNodesWithTag("li");
  for (var i = 0; i < nodes.length; i++) {
    var currentNode = nodes[i];
    var input = currentNode.childNodesWithTag("input")[0];
    if (!input.checked)
      list += "-";
    list += currentNode.getAttribute("uid") + ",";
  }

  return list.substr(0, list.length - 1);
}

// function updateCalendarContacts(contacts)
// {
//   var list = contacts.split(",");

//   var clist = $("calendarsList");
//   var nodes = clist.childNodes[5].childNodes;
//   for (var i = 0; i < nodes.length; i++) {
//     var currentNode = nodes[i];
//     if (currentNode instanceof HTMLLIElement) {
//       var input = currentNode.childNodes[3];
//       if (!input.checked)
//         list += "-";
//       list += currentNode.getAttribute("uid") + ",";
//     }
//   }
// }

function inhibitMyCalendarEntry()
{
  var clist = $("calendarsList");
  var nodes = clist.childNodes[5].childNodes;
  var done = false;

  var i = 0;
  while (!done && i < nodes.length) {
    var currentNode = nodes[i];
    if (currentNode instanceof HTMLLIElement) {
      var input = currentNode.childNodes[3];
      if (currentNode.getAttribute("uid") == UserLogin) {
        done = true;
        currentNode.style.color = "#999;";
        currentNode.style.fontWeight = "bold;";
        currentNode.setAttribute("onclick", "");
      }
    }
    i++;
  }
}

function updateCalendarsList(method)
{
  var url = (ApplicationBaseURL + "updateCalendars?ids="
             + calendarUidsList());
  if (document.calendarsListAjaxRequest) {
    document.calendarsListAjaxRequest.aborted = true;
    document.calendarsListAjaxRequest.abort();
  }
  document.calendarsListAjaxRequest
    = triggerAjaxRequest(url, calendarsListCallback);
  if (method == "removal")
    updateCalendarStatus();
}

function initCalendarContactsSelector(selId)
{
  var selector = $(selId);
  inhibitMyCalendarEntry();
  updateCalendarStatus();
  selector.changeNotification = updateCalendarsList;
}

function addContact(tag, fullContactName, contactId, contactName, contactEmail)
{
  var uids = $('uixselector-calendarsList-uidList');
//   log("addContact");
  if (contactId)
    {
      var re = new RegExp("(^|,)" + contactId + "($|,)");

      if (!re.test(uids.value))
        {
          if (uids.value.length > 0)
            uids.value += ',' + contactId;
          else
            uids.value = contactId;
          var names = $('uixselector-calendarsList-display');
          var listElems = names.childNodesWithTag("li");
          var colorDef = indexColor(listElems.length);
          names.innerHTML += ('<li onmousedown="return false;"'
                              + ' uid="' + contactId + '"'
                              + ' onclick="onRowClick(event);">'
                              + ' <span class="colorBox"'
                              + ' style="background-color: '
                              + colorDef + ';"></span>'
                              + ' <input class="checkBox" type="checkbox"'
                              + ' onchange="return updateCalendarStatus(this);"'
                              + ' />'
                              + contactName + '</li>');

          var styles = document.getElementsByTagName("style");
          styles[0].innerHTML += ('.ownerIs' + contactId + ' {'
                                  + ' background-color: ' + colorDef
                                  + ' !important; }');
        }
    }

  return false;
}

function onChangeCalendar(list) {
   var form = document.forms.editform;
   var urlElems = form.getAttribute("action").split("/");
   urlElems[urlElems.length-4]
      = list.childNodesWithTag("option")[list.value].innerHTML;
   form.setAttribute("action", urlElems.join("/"));
}

function validateBrowseURL(input) {
  var button = $("browseUrlBtn");

  if (input.value.length) {
    if (!button.enabled)
      enableAnchor(button);
  } else if (!button.disabled)
    disableAnchor(button);
}

function browseUrl(anchor, event) {
  if (event.button == 0) {
    var input = $("url");
    var url = input.value;
    if (url.length)
      window.open(url, '_blank');
  }

  return false;
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
    handle.upperBlock=$("appointmentsListView");
    handle.lowerBlock=$("calendarView");
  }
}
