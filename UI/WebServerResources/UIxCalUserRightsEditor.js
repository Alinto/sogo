function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
  Event.observe($("cancelButton"), "click", onCancelClick);
}

FastInit.addOnLoad(initACLButtons);
