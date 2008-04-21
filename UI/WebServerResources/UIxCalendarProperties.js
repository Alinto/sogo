function onLoadCalendarProperties() {
  var colorButton = $("colorButton");
  var calendarColor = $("calendarColor");
  colorButton.setStyle({ "backgroundColor": calendarColor.value, display: "inline" });
  colorButton.observe("click", onColorClick);

  var cancelButton = $("cancelButton");
  cancelButton.observe("click", onCancelClick);

  var okButton = $("okButton");
  okButton.observe("click", onOKClick);
}

function onCancelClick(event) {
  window.close();
}

function onOKClick(event) {
  var calendarName = $("calendarName");
  var calendarColor = $("calendarColor");
  var calendarID = $("calendarID");

  window.opener.updateCalendarProperties(calendarID.value,
					 calendarName.value,
					 calendarColor.value);
}

function onColorClick(event) {
  var cPicker = window.open(ApplicationBaseURL + "colorPicker", "colorPicker",
			    "width=250,height=200,resizable=0,scrollbars=0"
			    + "toolbar=0,location=0,directories=0,status=0,"
			    + "menubar=0,copyhistory=0", "test"
			    );
  cPicker.focus();

  preventDefault(event);
}

function onColorPickerChoice(newColor) {
  var colorButton = $("colorButton");
  colorButton.setStyle({ "backgroundColor": newColor });
  var calendarColor = $("calendarColor");
  calendarColor.value = newColor;
}

FastInit.addOnLoad(onLoadCalendarProperties);
