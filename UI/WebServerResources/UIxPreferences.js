function savePreferences(sender) {
   $("mainForm").submit();

   return false;
}

function initPreferences() {
  var identitiesBtn = $("manageIdentitiesBtn");
  Event.observe(identitiesBtn, "click",
		popupIdentitiesWindow.bindAsEventListener(identitiesBtn));
}

function popupIdentitiesWindow(event) {
  var urlstr = UserFolderURL + "identities";
  var w = window.open(urlstr, "identities",
		      "width=430,height=250,resizable=0,scrollbars=0,location=0");
  w.opener = window;
  w.focus();

  preventDefault(event);
}

addEvent(window, 'load', initPreferences);
