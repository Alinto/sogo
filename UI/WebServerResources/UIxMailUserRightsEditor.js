function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
   $("cancelButton").observe("click", onCancelClick)
}

FastInit.addOnLoad(initACLButtons);
