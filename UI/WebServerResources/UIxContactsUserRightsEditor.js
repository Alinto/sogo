function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
  var button = $("cancelButton");
  button.observe("click", onCancelClick);
}

FastInit.addOnLoad(initACLButtons);
