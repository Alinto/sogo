/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function savePreferences(sender) {
	$("mainForm").submit();

	return false;
}

function _setupEvents(enable) {
  var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
									"timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
									"firstWeek", "messageCheck" ];
  for (var i = 0; i < widgets.length; i++) {
    var widget = $(widgets[i]);
    if (widget) {
      if (enable)
        widget.observe("change", onChoiceChanged);
      else
        widget.stopObserving("change", onChoiceChanged);
    }
  }
}

function onChoiceChanged(event) {
  var hasChanged = $("hasChanged");
  hasChanged.value = "1";

  _setupEvents(false);
}

function initPreferences() {
  _setupEvents(true);
  if (typeof (initAdditionalPreferences) != "undefined")
    initAdditionalPreferences();
}

FastInit.addOnLoad(initPreferences);
