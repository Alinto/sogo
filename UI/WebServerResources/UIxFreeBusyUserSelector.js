var resultsDiv;
var searchField;
var running = false;
var address;
var delay = 500;
var requestField;

function onContactKeyUp(node, event)
{
  if (!running && (event.keyCode == 8
                   || event.keyCode == 13
                   || event.keyCode == 32
                   || event.keyCode > 47)) {
    running = true;
    requestField = node;
    setTimeout("triggerRequest()", delay);
  }
}

function triggerRequest() {
  if (document.contactLookupAjaxRequest) {
    document.contactLookupAjaxRequest.aborted = yes;
    document.contactLookupAjaxRequest.abort();
  }
  var urlstr = ( UserFolderURL + "Contacts/contactSearch?search="
                 + requestField.value );
  document.contactLookupAjaxRequest = triggerAjaxRequest(urlstr,
                                                         updateResults,
                                                         requestField);
}

function updateResults(http)
{
  if (http.readyState == 4) {
    if (http.status == 200) {
      var searchField = http.callbackData;
      var start = searchField.value.length;
      var text = http.responseText.split(":");
      if (text[0].length > 0)
        searchField.uid = text[0];
      else
        searchField.uid = null;
      searchField.hasfreebusy = false;
      searchField.value = text[1];
      var end = searchField.value.length;
      searchField.setSelectionRange(start, end);
    }
    running = false;
    document.contactLookupAjaxRequest = null;
  }
}

function resetFreeBusyZone()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var row = table.tHead.rows[2];
  for (var i = 1; i < row.cells.length; i++)
    {
      var nodes = row.cells[i].childNodesWithTag("span");
      for (var j = 0; j < nodes.length; j++)
        nodes[j].removeClassName("busy");
    }
}

function redisplayFreeBusyZone()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var row = table.tHead.rows[2];
  var stHour = parseInt(document.forms['editform']["startTime_time_hour"].value);
  var stMinute
    = parseInt(document.forms['editform']["startTime_time_minute"].value) / 15;
  var etHour = parseInt(document.forms['editform']["endTime_time_hour"].value);
  var etMinute
    = parseInt(document.forms['editform']["endTime_time_minute"].value) / 15;
  if (stHour < 8) {
    stHour = 8;
    stMinute = 0;
  }
  if (stHour > 18) {
    stHour = 18;
    stMinute = 0;
  }
  if (etHour < 8) {
    etHour = 8;
    etMinute = 0;
  }
  if (etHour > 18) {
    etHour = 18;
    etMinute = 0;
  }
  if (stHour > etHour) {
    var swap = etHour;
    etHour = stHour;
    stHour = swap;
    swap = etMinute;
    etMinute = stMinute;
    stMinute = etMinute;
  }

  var deltaCells = (etHour - stHour);
  var deltaSpans = (deltaCells * 4 ) + (etMinute - stMinute);
  var currentCellNbr = stHour - 7;
  var currentCell = row.cells[currentCellNbr];
  var currentSpanNbr = stMinute;
  var spans = currentCell.childNodesWithTag("span");
  resetFreeBusyZone();
  while (deltaSpans > 0) {
    var currentSpan = spans[currentSpanNbr];
    currentSpan.addClassName("busy");
    currentSpanNbr++;
    if (currentSpanNbr > 3) {
      currentSpanNbr = 0;
      currentCellNbr++;
      currentCell = row.cells[currentCellNbr];
      spans = currentCell.childNodesWithTag("span");
    }
    deltaSpans--;
  }
}

function newAttendee(node)
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var tbody = table.childNodesWithTag("tbody")[0];
  var model = tbody.rows[tbody.rows.length - 1];
  var newAttendeeRow = tbody.rows[tbody.rows.length - 2]
  var newRow = model.cloneNode(true);
  newRow.setAttribute("class", "");
  tbody.insertBefore(newRow, newAttendeeRow);
  newRow.childNodesWithTag("td")[0].childNodesWithTag("input")[0].focus();
}

function checkAttendee(node)
{
  var th = node.parentNode.parentNode;
  var tbody = th.parentNode;
  if (node.value.trim().length == 0)
    tbody.removeChild(th);
  else if (!node.hasfreebusy) {
    displayFreeBusyForNode(node);
    node.hasfreebusy = true;
  }
}

function displayFreeBusyForNode(node)
{
  if (node.uid) {
    var nodes = node.parentNode.parentNode.cells;
    for (var i = 1; i < nodes.length; i++) {
      nodes[i].removeClassName("noFreeBusy");
      nodes[i].innerHTML = ('<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>');
    }
    if (document.contactFreeBusyAjaxRequest) {
      document.contactFreeBusyAjaxRequest.aborted = true;
      document.contactFreeBusyAjaxRequest.abort();
    }
    var sd = startDayAsShortString();
    var ed = endDayAsShortString();
    var urlstr = ( UserFolderURL + "../" + node.uid + "/freebusy.ifb/ajaxRead?"
                   + "sday=" + sd + "&eday=" + ed);
    document.contactFreeBusyAjaxRequest = triggerAjaxRequest(urlstr,
                                                             updateFreeBusyData,
                                                             node);
  } else {
    var nodes = node.parentNode.parentNode.cells;
    for (var i = 1; i < nodes.length; i++) {
      nodes[i].addClassName("noFreeBusy");
      nodes[i].innerHTML = '';
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
  if (tdnbr > 7 && tdnbr < 19) {
    var i = (days * 11 + tdnbr - 7);
    var td = tds[i];
    var spans = td.childNodesWithTag("span");
    spans[spannbr].addClassName("busy");
  }
}

function updateFreeBusyData(http)
{
  if (http.readyState == 4) {
    if (http.status == 200) {
      var node = http.callbackData;
      var slots = http.responseText.split(",");
      var tds = node.parentNode.parentNode.cells;
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] != '0')
          setSlot(tds, i, slots[i]);
      }
    }
    document.contactFreeBusyAjaxRequest = null;
  }
}
