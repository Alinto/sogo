/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

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
  var save = true;
  var tag = $("calendarSyncTag").value;
  var originalTag = $("originalCalendarSyncTag");
  var allTags = $("allCalendarSyncTags");

  if (allTags)
      allTags = allTags.value.split(",");
  
  if ($("synchronizeCalendar").checked) {
      if (tag.blank()) {
          alert(labels["tagNotDefined"]);
          save = false;
      }
      else if (allTags
               && allTags.indexOf(tag) > -1) {
          alert(labels["tagAlreadyExists"]);
          save = false;
      }
      else if (originalTag
               && !originalTag.value.blank()) {
          if (tag != originalTag.value)
              save = confirm(labels["tagHasChanged"]);
      }
      else
          save = confirm(labels["tagWasAdded"]);
  }
  else if (originalTag
           && !originalTag.value.blank())
      save = confirm(labels["tagWasRemoved"]);
  
  if (save)
      window.opener.updateCalendarProperties(calendarID.value,
                                             calendarName.value,
                                             calendarColor.value);
  else
      Event.stop(event);
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

document.observe("dom:loaded", onLoadCalendarProperties);
