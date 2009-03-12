/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onCancelClick(event) {
	window.close();
}

function initACLButtons() {
  var button = $("cancelButton");
  button.observe("click", onCancelClick);
}

document.observe("dom:loaded", initACLButtons);
