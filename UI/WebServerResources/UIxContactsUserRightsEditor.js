/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onCancelClick(event) {
	window.close();
}

function initACLButtons() {
  var button = $("cancelButton");
  button.observe("click", onCancelClick);
}

document.observe("dom:loaded", initACLButtons);
