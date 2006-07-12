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

function popupSearchMenu(elem, event, menuName)
{
  relX = (event.pageX
	  - (elem.parentNode.offsetLeft + elem.offsetLeft));
  relY = (event.pageY
	  - elem.parentNode.parentNode.parentNode.offsetTop);
  window.alert(elem.style.height);
//   if (event.button == 1
// && 
//     acceptClick = false;
//   bodyOnClick = "" + document.body.getAttribute("onclick");
//   document.body.setAttribute("onclick", "onBodyClick('" + menuId + "'); return false;");
//   popup = document.getElementById(menuId);
//   popup.setAttribute("style", "visibility: visible; top: " + event.pageY
// 		     + "px; left: " + event.pageX + "px;" );
//   menuClickNode = node;
//   window.alert

  return false;
}
