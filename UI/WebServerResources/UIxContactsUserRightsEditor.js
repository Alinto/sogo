function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
  var button = $("cancelButton");
   Event.observe(button, "click", onCancelClick);
}

FastInit.addOnLoad(initACLButtons);
