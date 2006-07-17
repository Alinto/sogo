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

function popupSearchMenu(event, menuId)
{
  var node = event.target;

  superNode = node.parentNode.parentNode.parentNode;
  relX = (event.pageX - superNode.offsetLeft - node.offsetLeft);
  relY = (event.pageY - superNode.offsetTop - node.offsetTop);

  if (event.button == 0
      && relX < 24) {
    log('popup');
    event.cancelBubble = true;
    event.returnValue = false;

    var popup = document.getElementById(menuId);
    hideMenu(popup);

    var menuTop = superNode.offsetTop + node.offsetTop + node.offsetHeight;
    var menuLeft = superNode.offsetLeft + node.offsetLeft;
    var heightDiff = (window.innerHeight
		      - (menuTop + popup.offsetHeight));
    if (heightDiff < 0)
      menuTop += heightDiff;

    var leftDiff = (window.innerWidth
		    - (menuLeft + popup.offsetWidth));
    if (leftDiff < 0)
      menuLeft -= popup.offsetWidth;

    popup.style.top = menuTop + "px";
    popup.style.left = menuLeft + "px";
    popup.style.visibility = "visible";
    menuClickNode = node;
  
    bodyOnClick = "" + document.body.getAttribute("onclick");
    document.body.setAttribute("onclick", "onBodyClick('" + menuId + "');");
  }
}

function setSearchCriteria(event)
{
  searchField = document.getElementById('searchValue');
  searchCriteria = document.getElementById('searchCriteria');
  
  node = event.target;
  searchField.setAttribute("ghost-phrase", node.innerHTML);
  searchCriteria = node.getAttribute('id');
}

function onSearchChange()
{
  log('onSearchChange');
}

function onSearchMouseDown(event)
{
  log('onSearchMouseDown');

  searchField = document.getElementById('searchValue');
  superNode = searchField.parentNode.parentNode.parentNode;
  relX = (event.pageX - superNode.offsetLeft - searchField.offsetLeft);
  relY = (event.pageY - superNode.offsetTop - searchField.offsetTop);

  if (relY < 24) {
    log('menu');
    event.cancelBubble = true;
    event.returnValue = false;
  }
}

function onSearchFocus(event)
{
  log('onSearchFocus');
  searchField = document.getElementById('searchValue');
  ghostPhrase = searchField.getAttribute("ghost-phrase");
  if (searchField.value == ghostPhrase) {
    searchField.value = "";
    searchField.setAttribute("modified", "");
  } else {
    searchField.select();
  }

  searchField.style.color = "#000";
}

function onSearchBlur()
{
  log('onSearchBlur');
  var searchField = document.getElementById('searchValue');
  var ghostPhrase = searchField.getAttribute("ghost-phrase");

  if (searchField.value == "") {
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";
    searchField.value = ghostPhrase;
  } else if (searchField.value == ghostPhrase) {
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";
  } else {
    searchField.setAttribute("modified", "yes");
    searchField.style.color = "#000";
  }
}

function initCriteria()
{
  var searchCriteria = document.getElementById('searchCriteria');
  var searchField = document.getElementById('searchValue');
  var firstOption;
 
  if (searchCriteria.value == ''
      || searchField.value == '') {
    firstOption = document.getElementById('searchOptions').childNodes[1];
    searchCriteria.value = firstOption.getAttribute('id');
    searchField.value = firstOption.innerHTML;
    searchField.setAttribute('ghost-phrase', firstOption.innerHTML);
    searchField.setAttribute("modified", "");
    searchField.style.color = "#aaa";

    log(searchField.value);
  }
}
