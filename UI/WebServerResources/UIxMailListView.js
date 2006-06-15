var rowSelectionCount = 0;

validateControls();

function showElement(e, shouldShow) {
	e.style.display = shouldShow ? "" : "none";
}

function enableElement(e, shouldEnable) {
  if(!e)
    return;
  if(shouldEnable) {
    if(e.hasAttribute("disabled"))
      e.removeAttribute("disabled");
  }
  else {
    e.setAttribute("disabled", "1");
  }
}

function toggleRowSelectionStatus(sender) {
  rowID = sender.value;
  tr = document.getElementById(rowID);
  if(sender.checked) {
    tr.className = "tableview_selected";
    rowSelectionCount += 1;
  }
  else {
    tr.className = "tableview";
    rowSelectionCount -= 1;
  }
  this.validateControls();
}

function validateControls() {
  var e = document.getElementById("moveto");
  this.enableElement(e, rowSelectionCount > 0);
}

function moveTo(uri) {
  alert("MoveTo: " + uri);
}
