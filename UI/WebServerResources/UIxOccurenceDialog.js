/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onCancelButtonClick(event) {
  window.close();
}

function onThisButtonClick(event) {
  if (action == 'edit')
    window.opener.performEventEdition(calendarFolder, componentName,
																			recurrenceName);
  else if (action == 'delete')
    window.opener.performEventDeletion(calendarFolder, componentName,
																			 recurrenceName);
  else
    window.alert("Invalid action: " + action);

  window.close();
}

function onAllButtonClick(event) {
  if (action == 'edit')
    window.opener.performEventEdition(calendarFolder, componentName);
  else if (action == 'delete')
    window.opener.performEventDeletion(calendarFolder, componentName);
  else
    window.alert("Invalid action: " + action);

  window.close();
}

function onOccurenceDialogLoad() {
  var thisButton = $("thisButton");
  thisButton.observe("click", onThisButtonClick);

  var allButton = $("allButton");
  allButton.observe("click", onAllButtonClick);

  var cancelButton = $("cancelButton");
  cancelButton.observe("click", onCancelButtonClick);
}

document.observe("dom:loaded", onOccurenceDialogLoad);
