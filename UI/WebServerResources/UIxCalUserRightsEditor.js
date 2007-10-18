function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
  Event.observe($("cancelButton"), "click", onCancelClick);
}

addEvent(window, "load", initACLButtons);
