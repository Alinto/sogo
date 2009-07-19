/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function initializeWindowButtons() {
  var okButton = $("okButton");
  var cancelButton = $("cancelButton");

  okButton.observe("click", onEditorOkClick, false);
  cancelButton.observe("click", onEditorCancelClick, false);
}


function initializeFormValues() {
  $("quantityField").value = parent$("reminderQuantity").value;
	$("unitsList").value = parent$("reminderUnit").value;
	$("relationsList").value = parent$("reminderRelation").value;
	$("referencesList").value = parent$("reminderReference").value;
}

function onEditorOkClick(event) {
  preventDefault(event);
	if (parseInt($("quantityField").value) > 0) {
		parent$("reminderQuantity").value = parseInt($("quantityField").value);
		parent$("reminderUnit").value = $("unitsList").value;
		parent$("reminderRelation").value = $("relationsList").value;
		parent$("reminderReference").value = $("referencesList").value;
		
    window.close();
	}
	else
		alert("heu");
}

function onEditorCancelClick(event) {
  preventDefault(event);
  window.close();
}

function onRecurrenceLoadHandler() {
  initializeFormValues();
  initializeWindowButtons();
}

document.observe("dom:loaded", onRecurrenceLoadHandler);
