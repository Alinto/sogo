function onCancelClick(event) {
   window.close();
}

function initACLButtons() {
   $("cancelButton").addEventListener("click", onCancelClick, false);
}

window.addEventListener("load", initACLButtons, false);
