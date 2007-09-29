function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
  var button = $("cancelButton");
   Event.observe(button, "click", onCancelClick);
}

addEvent(window, "load", initACLButtons);
