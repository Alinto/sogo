function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
   $("cancelButton").addEventListener("click", onCancelClick, false);
}

FastInit.addOnLoad(initACLButtons);
