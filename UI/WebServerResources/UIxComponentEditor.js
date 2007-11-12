function onPopupAttendeesWindow(event) {
   if (event)
      preventDefault(event);
   window.open(ApplicationBaseURL + "/editAttendees", null, 
               "width=803,height=573");

   return false;
}

function onSelectPrivacy(event) {
   if (event.button == 0 || (isSafari() && event.button == 1)) {
      var node = getTarget(event);
      if (node.tagName != 'A')
	node = $(node).getParentWithTagName("a");
      node = $(node).childNodesWithTag("span")[0];
      popupToolbarMenu(node, "privacy-menu");
      Event.stop(event);
//       preventDefault(event);
   }
}

function onPopupUrlWindow(event) {
   if (event)
      preventDefault(event);

   var urlInput = document.getElementById("url");
   var newUrl = window.prompt(labels["Target:"], urlInput.value);
   if (newUrl != null) {
      var documentHref = $("documentHref");
      var documentLabel = $("documentLabel");
      if (documentHref.childNodes.length > 0) {
	 documentHref.childNodes[0].nodeValue = newUrl;
	 if (newUrl.length > 0)
	    documentLabel.setStyle({ display: "block" });
	 else
	    documentLabel.setStyle({ display: "none" });
      }
      else {
	 documentHref.appendChild(document.createTextNode(newUrl)); 
	 if (newUrl.length > 0)
	    documentLabel.setStyle({ display: "block" });
      }
      urlInput.value = newUrl;
   }

   return false;
}

function onPopupDocumentWindow(event) {
   var documentUrl = $("url");

   preventDefault(event);
   window.open(documentUrl.value, "SOGo_Document");

   return false;
}

function onMenuSetClassification(event) {
   event.cancelBubble = true;

   var classification = this.getAttribute("classification");
   if (this.parentNode.chosenNode)
      this.parentNode.chosenNode.removeClassName("_chosen");
   this.addClassName("_chosen");
   this.parentNode.chosenNode = this;

//    log("classification: " + classification);
   var privacyInput = document.getElementById("privacy");
   privacyInput.value = classification;
}

function onChangeCalendar(event) {
   var calendars = $("calendarFoldersList").value.split(",");
   var form = document.forms["editform"];
   var urlElems = form.getAttribute("action").split("/");
   var choice = calendars[this.value];
   urlElems[urlElems.length-3] = choice;
   form.setAttribute("action", urlElems.join("/"));
}

function refreshAttendees() {
   var attendeesLabel = $("attendeesLabel");
   var attendeesNames = $("attendeesNames");
   var attendeesHref = $("attendeesHref");

   for (var i = 0; i < attendeesHref.childNodes.length; i++)
     attendeesHref.removeChild(attendeesHref.childNodes[i]);

   if (attendeesNames.value.length > 0) {
      attendeesHref.appendChild(document.createTextNode(attendeesNames.value));
      attendeesLabel.setStyle({ display: "block" });
   }
   else
      attendeesLabel.setStyle({ display: "none" });
}

function initializeAttendeesHref() {
   var attendeesHref = $("attendeesHref");
   var attendeesLabel = $("attendeesLabel");
   var attendeesNames = $("attendeesNames");

   Event.observe(attendeesHref, "click", onPopupAttendeesWindow, false);
   if (attendeesNames.value.length > 0) {
      attendeesHref.setStyle({ textDecoration: "underline", color: "#00f" });
      attendeesHref.appendChild(document.createTextNode(attendeesNames.value));
      attendeesLabel.setStyle({ display: "block" });
   }
}

function initializeDocumentHref() {
   var documentHref = $("documentHref");
   var documentLabel = $("documentLabel");
   var documentUrl = $("url");

   Event.observe(documentHref, "click", onPopupDocumentWindow, false);
   documentHref.setStyle({ textDecoration: "underline", color: "#00f" });
   if (documentUrl.value.length > 0) {
      documentHref.appendChild(document.createTextNode(documentUrl.value));
      documentLabel.setStyle({ display: "block" });
   }

   var changeUrlButton = $("changeUrlButton");
   Event.observe(changeUrlButton, "click", onPopupUrlWindow, false);
}

function initializePrivacyMenu() {
   var privacy = $("privacy").value.toUpperCase();
   if (privacy.length > 0) {
      var privacyMenu = $("privacy-menu").childNodesWithTag("ul")[0];
      var menuEntries = $(privacyMenu).childNodesWithTag("li");
      var chosenNode;
      if (privacy == "CONFIDENTIAL")
	 chosenNode = menuEntries[1];
      else if (privacy == "PRIVATE")
	 chosenNode = menuEntries[2];
      else
	 chosenNode = menuEntries[0];
      privacyMenu.chosenNode = chosenNode;
      $(chosenNode).addClassName("_chosen");
   }
}

function onComponentEditorLoad(event) {
   if (!$("statusPercent"))
      initializeAttendeesHref();
   initializeDocumentHref();
   initializePrivacyMenu();
   var list = $("calendarList");
   Event.observe(list, "mousedown",
		 onChangeCalendar.bindAsEventListener(list),
		 false);
   list.fire("mousedown");

   var menuItems = $("itemPrivacyList").childNodesWithTag("li");
   for (var i = 0; i < menuItems.length; i++)
      Event.observe(menuItems[i], "mousedown",
		    onMenuSetClassification.bindAsEventListener(menuItems[i]),
		    false);
}

addEvent(window, 'load', onComponentEditorLoad);
