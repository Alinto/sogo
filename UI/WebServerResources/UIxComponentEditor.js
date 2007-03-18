window.addEventListener("load", onComponentEditorLoad, false);

function onPopupAttendeesWindow(event) {
   if (event)
      event.preventDefault();
   window.open(ApplicationBaseURL + "editAttendees", null, 
               "width=803,height=573");

   return false;
}

function onSelectPrivacy(event) {
   popupToolbarMenu(event, "privacy-menu");

   return false;
}

function onPopupUrlWindow(event) {
   if (event)
      event.preventDefault();

   var urlInput = document.getElementById("url");
   var newUrl = window.prompt(labels["Target:"].decodeEntities(), urlInput.value);
   if (newUrl != null) {
      var documentHref = $("documentHref");
      var documentLabel = $("documentLabel");
      if (documentHref.childNodes.length > 0) {
	 documentHref.childNodes[0].nodeValue = newUrl;
	 if (newUrl.length > 0)
	    documentLabel.style.display = "block;";
	 else
	    documentLabel.style.display = "none;";
      }
      else {
	 documentHref.appendChild(document.createTextNode(newUrl)); 
	 if (newUrl.length > 0)
	    documentLabel.style.display = "block;";
      }
      urlInput.value = newUrl;
   }

   return false;
}

function onPopupDocumentWindow(event) {
   var documentUrl = $("url");

   event.preventDefault();
   window.open(documentUrl.value, "SOGo_Document");

   return false;
}

function onMenuSetClassification(event, classification) {
   event.cancelBubble = true;

   var node = event.target;
   if (node.tagName != "LI")
      node = node.getParentWithTagName("li");
   if (node.parentNode.chosenNode)
      node.parentNode.chosenNode.removeClassName("_chosen");
   node.addClassName("_chosen");
   node.parentNode.chosenNode = node;

   log("classification: " + classification);
   var privacyInput = document.getElementById("privacy");
   privacyInput.value = classification;
}

function refreshAttendees() {
   var attendeesLabel = $("attendeesLabel");
   var attendeesNames = $("attendeesNames");
   var attendeesHref = $("attendeesHref");

   for (var i = 0; i < attendeesHref.childNodes.length; i++)
     attendeesHref.removeChild(attendeesHref.childNodes[i]);

   if (attendeesNames.value.length > 0) {
      attendeesHref.appendChild(document.createTextNode(attendeesNames.value));
      attendeesLabel.style.display = "block;";
   }
   else
      attendeesLabel.style.display = "none;";
}

function initializeAttendeesHref() {
   var attendeesHref = $("attendeesHref");
   var attendeesLabel = $("attendeesLabel");
   var attendeesNames = $("attendeesNames");

   attendeesHref.addEventListener("click", onPopupAttendeesWindow, false);
   if (attendeesNames.value.length > 0) {
      attendeesHref.style.textDecoration = "underline;";
      attendeesHref.style.color = "#00f;";
      attendeesHref.appendChild(document.createTextNode(attendeesNames.value));
      attendeesLabel.style.display = "block;";
   }
}

function initializeDocumentHref() {
   var documentHref = $("documentHref");
   var documentLabel = $("documentLabel");
   var documentUrl = $("url");

   documentHref.addEventListener("click", onPopupDocumentWindow, false);
   documentHref.style.textDecoration = "underline;";
   documentHref.style.color = "#00f;";
   if (documentUrl.value.length > 0) {
      documentHref.appendChild(document.createTextNode(documentUrl.value));
      documentLabel.style.display = "block;";
   }

   var changeUrlButton = $("changeUrlButton");
   changeUrlButton.addEventListener("click", onPopupUrlWindow, false);
}

function initializePrivacyMenu() {
   var privacy = $("privacy").value.toUpperCase();
   log("privacy: " + privacy);
   if (privacy.length > 0) {
      var privacyMenu = $("privacy-menu").childNodesWithTag("ul")[0];
      var menuEntries = privacyMenu.childNodesWithTag("li");
      var chosenNode;
      if (privacy == "CONFIDENTIAL")
	 chosenNode = menuEntries[1];
      else if (privacy == "PRIVATE")
	 chosenNode = menuEntries[2];
      else
	 chosenNode = menuEntries[0];
      privacyMenu.chosenNode = chosenNode;
      chosenNode.addClassName("_chosen");
   }
}

function onComponentEditorLoad(event) {
   if (!$("statusPercent"))
      initializeAttendeesHref();
   initializeDocumentHref();
   initializePrivacyMenu();
}
