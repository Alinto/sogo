/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onLoadCalendarProperties() {
    var tabsContainer = $("propertiesTabs");
    var controller = new SOGoTabsController();
    controller.attachToTabsContainer(tabsContainer);

    var colorButton = $("colorButton");
    var calendarColor = $("calendarColor");
    colorButton.setStyle({ "backgroundColor": colorButton.readAttribute('data-color') });
    colorButton.observe("click", onColorClick);
    
    $('colorPickerDialog').on('click', 'span', onColorPickerChoice);
    $(document.body).on("click", onBodyClickHandler);

    var cancelButton = $("cancelButton");
    cancelButton.observe("click", onCancelClick);
    
    var okButton = $("okButton");
    okButton.observe("click", onOKClick);
  
    Event.observe(document, "keydown", onDocumentKeydown);
}

function onDocumentKeydown(event) {
  var target = Event.element(event);
  if (target.tagName == "INPUT" || target.tagName == "SELECT") {
    if (event.keyCode == Event.KEY_RETURN) {
      onOKClick(event);
    }
  }
  if (event.keyCode == Event.KEY_ESC) {
    onCancelClick();
  }
}

function onCancelClick(event) {
    window.close();
}

function onOKClick(event) {
  var calendarName = $("calendarName");
  var calendarColor = $("calendarColor");
  var calendarID = $("calendarID");
  var save = true;
  var tag = $("calendarSyncTag");
  var originalTag = $("originalCalendarSyncTag");
  var allTags = $("allCalendarSyncTags");

  if (calendarName.value.blank()) {
      alert(_("Please specify a calendar name."));
      save = false;
  }

  if (save
      && allTags)
      allTags = allTags.value.split(",");
  
  if (save
      && tag
      && $("synchronizeCalendar").checked) {
      if (tag.value.blank()) {
          alert(_("tagNotDefined"));
          save = false;
      }
      else if (allTags
               && allTags.indexOf(tag.value) > -1) {
          alert(_("tagAlreadyExists"));
          save = false;
      }
      else if (originalTag
               && !originalTag.value.blank()) {
          if (tag.value != originalTag.value)
              save = confirm(_("tagHasChanged"));
      }
      else
          save = confirm(_("tagWasAdded"));
  }
  else if (save
           && originalTag
           && !originalTag.value.blank())
      save = confirm(_("tagWasRemoved"));
  
  if (save) {
      window.opener.updateCalendarProperties(calendarID.value,
                                             calendarName.value,
                                             calendarColor.value);
      $("propertiesform").submit();
  }
  else
      Event.stop(event);
}

function onBodyClickHandler(event) {
    var target = getTarget(event);
    if (!target.hasClassName('colorBox'))
        $("colorPickerDialog").hide();
}

function onColorClick(event) {
    var cellPosition = this.cumulativeOffset();
    var cellDimensions = this.getDimensions();
    var div = $('colorPickerDialog');
    var divDimensions = div.getDimensions();
    var left = cellPosition[0] + cellDimensions["width"] + 4;
    var top = cellPosition[1] - 5;
    div.setStyle({ left: left + "px", top: top + "px" });
    div.show();

    preventDefault(event);
}

function onColorPickerChoice(event) {
    var span = getTarget(event);
    var newColor = "#" + span.className.substr(4);
    var colorButton = $("colorButton");
    colorButton.setStyle({ "backgroundColor": newColor });
    $("calendarColor").value = newColor;
}

document.observe("dom:loaded", onLoadCalendarProperties);
