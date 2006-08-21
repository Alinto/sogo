var activeAjaxRequests = 0;

var sortOrder = '';
var sortKey = '';
var listFilter = 'view_all';

function triggerAjaxRequest(url, callback, userdata) {
  this.http = createHTTPClient();

  activeAjaxRequests += 1;
  document.animTimer = setTimeout("checkAjaxRequestsState();", 200);

  if (http) {
    http.onreadystatechange
      = function() {
//         log ("state changed (" + http.readyState + "): " + url);
        try {
          if (http.readyState == 4
              && activeAjaxRequests > 0) {
                if (!http.aborted) {
                  http.callbackData = userdata;
                  callback(http);
                }
                activeAjaxRequests -= 1;
                checkAjaxRequestsState();
              }
        }
        catch( e ) {
          activeAjaxRequests -= 1;
          checkAjaxRequestsState();
          alert('AJAX Request, Caught Exception: ' + e.description);
        }
      };
    http.url = url;
    http.open("GET", url, true);
    http.send("");
  }

  return http;
}

function checkAjaxRequestsState()
{
  if (activeAjaxRequests > 0
      && !document.busyAnim) {
    var anim = document.createElement("img");
    document.busyAnim = anim;
    anim.setAttribute("src", ResourcesURL + '/busy.gif');
    anim.style.position = "absolute;";
    anim.style.top = "2.5em;";
    anim.style.right = "1em;";
    anim.style.visibility = "hidden;";
    anim.style.zindex = "1;";
    var folderTree = document.getElementById("toolbar");
    folderTree.appendChild(anim);
    anim.style.visibility = "visible;";
  } else if (activeAjaxRequests == 0
	     && document.busyAnim) {
    document.busyAnim.parentNode.removeChild(document.busyAnim);
    document.busyAnim = null;
  }
}

var currentDay = '';
var currentView = 'day';

function newEvent(sender) {
  var urlstr = ApplicationBaseURL + "new";

  window.open(urlstr, "",
	      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");

  return false; /* stop following the link */
}

function _editEventId(id) {
  var urlstr = ApplicationBaseURL + id + "/edit";

  var win = window.open(urlstr, "SOGo_edit_" + id,
                        "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
                        "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  win.focus();
}

function editEvent() {
  var list = document.getElementById("appointmentsList");
  var nodes = list.getSelectedRowsId();

  if (nodes.length > 0) {
    var row = nodes[0];
    _editEventId(row);
  }

  return false; /* stop following the link */
}

function editDoubleClickedEvent(node)
{
  var id = node.getAttribute("id");
  _editEventId(id);
  
  return false;
}

function displayAppointment(sender) {
  var aptId = sender.getAttribute("aptId");
  var urlstr = ApplicationBaseURL + aptId + "/view";
  
  var win = window.open(urlstr, "SOGo_view_" + aptId,
                        "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
                        "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  win.focus();

  return false; /* stop following the link */
}

function onContactRefresh(node)
{
  var parentNode = node.parentNode;
  var contacts = '';
  var done = false;

  var currentNode = parentNode.firstChild;
  while (currentNode && !done)
    {
      if (currentNode.nodeType == 1
          && currentNode.getAttribute("type") == "hidden")
        {
          contacts = currentNode.value;
          done = true;
        }
      else
        currentNode = currentNode.nextSibling;
    }

  log ('contacts: ' + contacts);
  if (contacts.length > 0)
    window.location = ApplicationBaseURL + '/show?userUIDString=' + contacts;

  return false;
}

function onDaySelect(node)
{
  currentDay = node.getAttribute("day");

  var td = node.getParentWithTagName("td");
  var table = td.getParentWithTagName("table");

//   log ("table.selected: " + table.selected);

  if (document.selectedDate)
    deselectNode(document.selectedDate);

  selectNode(td);
  document.selectedDate = td;

  changeDayDisplay(currentDay, null);
  if (listFilter == 'view_selectedday')
    refreshAppointments();

  return false;
}

function onDateSelectorGotoMonth(node)
{
  var day = node.getAttribute("date");

  changeDateSelectorDisplay(day);

  return false;
}

function onCalendarGotoDay(node)
{
  var day = node.getAttribute("date");

  changeDayDisplay(day);

  return false;
}

function gotoToday()
{
  changeDayDisplay();
  changeDateSelectorDisplay();

  return false;
}

function dateSelectorCallback(http)
{
  var div = document.getElementById("dateSelectorView");

  log ("dateselectorcallback: " + div);

  if (http.readyState == 4
      && http.status == 200) {
    document.dateSelectorAjaxRequest = null;
    div.innerHTML = http.responseText;
    if (currentDay.length > 0)
      restoreCurrentDaySelection(div);
  }
  else
    log ("ajax fuckage");
}

function appointmentsListCallback(http)
{
  var div = document.getElementById("appointmentsListView");

  if (http.readyState == 4
      && http.status == 200) {
//     log ("babla");
    document.dateSelectorAjaxRequest = null;
//     log ("babla");
    div.innerHTML = http.responseText;
//     log ("babla");

//     log ("received " + http.callbackData);
    var params = parseQueryParameters(http.callbackData);
    sortKey = params["sort"];
    sortOrder = params["desc"];

//     log ("sorting = " + sortKey + sortOrder);
  }
  else
    log ("ajax fuckage");
}

function restoreCurrentDaySelection(div)
{
  var elements = div.getElementsByTagName("a");
  var day = null;
  var i = 7;
  while (!day && i < elements.length)
    {
      day = elements[i].getAttribute("day");
      i++;
    }

  if (day
      && day.substr(0, 6) == currentDay.substr(0, 6))
    {
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

function changeDateSelectorDisplay(day, event)
{
  var url = ApplicationBaseURL + "dateselector";
  if (day)
    url += "?day=" + day;

//   if (currentDay.length > 0)
//     url += '&selectedDay=' + currentDay;
  log ("changeDateSelectorDisplay: " + url);

  if (document.dateSelectorAjaxRequest) {
//     log ("aborting dateselector ajaxrq");
    document.dateSelectorAjaxRequest.aborted = true;
    document.dateSelectorAjaxRequest.abort();
  }

  document.dateSelectorAjaxRequest = triggerAjaxRequest(url,
                                                        dateSelectorCallback,
                                                        null);
//   log ('should go to ' + day);
}

function changeDayDisplay(day, event)
{
  var url = ApplicationBaseURL + "dayview";

  if (day)
    url += "?day=" + day;

  log ("changeDayDisplay: " + url);

  if (document.dayDisplayAjaxRequest) {
//     log ("aborting day ajaxrq");
    document.dayDisplayAjaxRequest.aborted = true;
    document.dayDisplayAjaxRequest.abort();
  }
  document.dayDisplayAjaxRequest = triggerAjaxRequest(url,
                                                      dayDisplayCallback,
                                                      null);

  return false;
}

function dayDisplayCallback(http)
{
  var div = document.getElementById("calendarView");

  log ("daydisplaycallback: " + div);
  if (http.readyState == 4
      && http.status == 200) {
    document.dateSelectorAjaxRequest = null;
    div.innerHTML = http.responseText;
  }
  else
    log ("ajax fuckage");
}

function popupCalendar(node)
{
  var inputId = node.getAttribute("inputId");
  var dateFormat = node.getAttribute("dateFormat");

  var calendar = new skycalendar(document.getElementById(inputId));
  calendar.setCalendarPage(ResourcesURL + "/skycalendar.html");
  calendar.setDateFormat(dateFormat);
  calendar.popup();

  return false;
}

function onAppointmentContextMenu(event, element)
{
  var topNode = document.getElementById('appointmentsList');
  log(topNode);

  var menu = document.getElementById('appointmentsListMenu');

  menu.addEventListener("hideMenu", onAppointmentContextMenuHide, false);
  onMenuClick(event, 'appointmentsListMenu');

  var topNode = document.getElementById('appointmentsList');
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    deselectNode (selectedNodes[i]);

  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onAppointmentContextMenuHide(event)
{
  var topNode = document.getElementById('appointmentsList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodeIds = topNode.menuSelectedRows;
    for (var i = 0; i < nodeIds.length; i++) {
      var node = document.getElementById(nodeIds[i]);
      selectNode (node);
    }
    topNode.menuSelectedRows = null;
  }
}

function onAppointmentsSelectionChange()
{
}

function _loadAppointmentHref(href) {
  if (this.document.appointmentsListAjaxRequest) {
    this.document.appointmentsListAjaxRequest.aborted = true;
    this.document.appointmentsListAjaxRequest.abort();
  }
  url = ApplicationBaseURL + href;
//   log ("url: " + url);
  this.document.appointmentsListAjaxRequest
    = triggerAjaxRequest(url, appointmentsListCallback, href);

  return false;
}

function onHeaderClick(node)
{
  var href = node.getAttribute("href");

  return _loadAppointmentHref(href);
}

function refreshAppointments() {
  var href = ("aptlist?desc=" + sortOrder
              + "&sort=" + sortKey
              + "&day=" + currentDay
              + "&filterpopup=" + listFilter);

  return _loadAppointmentHref(href);
}

function onListFilterChange() {
  var node = document.getElementById("filterpopup");

  listFilter = node.value;
//   log ("listFilter = " + listFilter);

  return refreshAppointments();
}
