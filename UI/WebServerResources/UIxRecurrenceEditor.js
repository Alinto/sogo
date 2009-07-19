/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var RecurrenceEditor = {
 types: new Array("Daily", "Weekly", "Monthly", "Yearly"),
 currentRepeatType: 0
};

function onRepeatTypeChange(event) {
	setRepeatType(parseInt(this.value));
}

function setRepeatType(type) {
  var elements;

  RecurrenceEditor.currentRepeatType = type;

  for (var i = 0; i <= 3; i++) {
    elements = $$("TABLE TR.recurrence" + RecurrenceEditor.types[i]);
    if (i != type)
      elements.each(function(row) {
					row.hide();
				});
  }
  elements = $$("TABLE TR.recurrence" + RecurrenceEditor.types[type]);
  elements.each(function(row) {
      row.show();
    });
}

function getSelectedDays(periodType) {
  var element = $(periodType);
  var elementsArray = $A(element.getElementsByTagName('DIV'));
  var days = new Array();
  var dayPrefix = periodType + "Day";
  elementsArray.each(function(item) {
      if (isNodeSelected(item)) {
				var label = ""  + item.getAttribute("id");
				days.push(label.substr(dayPrefix.length));
      }
    });
  return days.join(",");
}

function onDayClick(event) {
  var element = $(this);
  if (isNodeSelected(element))
    this.removeClassName("_selected");
  else
    this.addClassName("_selected");
}

function onRangeChange(event) {
  $('endDate_date').disabled = (this.value != 2);
}

function onAdjustTime(event) {
  // must be defined for date picker widget
}

function initializeSelectors() {
  $$("DIV#week SPAN.week DIV").each(function(element) {
      element.observe("click", onDayClick, false);
    });

  $$("DIV#month SPAN.week DIV").each(function(element) {
      element.observe("click", onDayClick, false);
    });
}

function initializeWindowButtons() {
  var okButton = $("okButton");
  var cancelButton = $("cancelButton");

  okButton.observe("click", onEditorOkClick, false);
  cancelButton.observe("click", onEditorCancelClick, false);

  var repeatType = $("repeatType");
  setRepeatType(parseInt(repeatType.value));
  repeatType.observe("change", onRepeatTypeChange, false);
}

function initializeFormValues() {
  var repeatType = parent$("repeatType").value;

  // Select repeat type
  $("repeatType").value = repeatType;

  // Default values
	var startTimeDate = parent$("startTime_date").value.asDate();
	$('yearlyDayField').value = startTimeDate.getDate();
	$('yearlyMonth1').value = startTimeDate.getMonth();
	$("weekDay"+startTimeDate.getDay()).addClassName("_selected");
	$("monthDay"+startTimeDate.getDate()).addClassName("_selected");

  $('recurrence_form').setRadioValue('dailyRadioButtonName', 0);
  $('recurrence_form').setRadioValue('monthlyRadioButtonName', 1);
  $('recurrence_form').setRadioValue('yearlyRadioButtonName', 0);
  $('endDate_date').disabled = true;
	$('dailyDaysField').value = "1";
	$('weeklyWeeksField').value = "1";
	$('monthlyMonthsField').value = "1";
	$('yearlyYearsField').value = "1";
  
  if (repeatType == 0) {
    // Repeat daily
    $('recurrence_form').setRadioValue('dailyRadioButtonName', parent$("repeat1").value);
    $('dailyDaysField').value = parent$("repeat2").value;
  }
  else if (repeatType == 1) {
    // Repeat weekly
    $('weeklyWeeksField').value = parent$("repeat1").value;
		//     log ("div: " + weekDiv);
		//     log ("days: " + parent$("repeat2").value);
		for (var i = 0; i < 7; i++) {
			$("weekDay" + i).removeClassName("_selected");
		}
    var days = "" + parent$("repeat2").value;
    if (days.length > 0) {
      var daysArray = days.split(",");
      daysArray.each(function(index) {
					$("weekDay"+index).addClassName("_selected");
				});
    }
  }
  else if (repeatType == 2) {
    // Repeat monthly
    $('monthlyMonthsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('monthlyRadioButtonName', parent$("repeat2").value);
    $('monthlyRepeat').value = parent$("repeat3").value;
    $('monthlyDay').value = parent$("repeat4").value;
    var days = "" + parent$("repeat5").value;
		for (var i = 0; i < 31; i++) {
			$("monthDay" + (i + 1)).removeClassName("_selected");
		}

    if (days.length > 0) {
      var daysArray = days.split(",");
      daysArray.each(function(index) {
					$("monthDay" + index).addClassName("_selected");
				});
    }
  }
  else if (repeatType == 3) {
    // Repeat yearly
    $('yearlyYearsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('yearlyRadioButtonName', parent$("repeat2").value);
    $('yearlyDayField').value = parent$("repeat3").value;
    $('yearlyMonth1').value = parent$("repeat4").value;
    $('yearlyRepeat').value = parent$("repeat5").value;
    $('yearlyDay').value = parent$("repeat6").value;
    $('yearlyMonth2').value = parent$("repeat7").value;
  }
  else
    repeatType = 0;
  
  setRepeatType(repeatType);

  var range = parent$("range1").value;
  $('recurrence_form').setRadioValue('rangeRadioButtonName', range);

  if (range == 1) {
    $('rangeAppointmentsField').value = parent$("range2").value;
  }
  else if (range == 2) {
		$('endDate_date').value = parent$("range2").value;
		$('endDate_date').disabled = false;
  }

	$('rangeAppointmentsField').observe("click", function(event) {
			// Set the range to a fixed number of appointments if user
			// clicks in the range field.
			$('recurrence_form').setRadioValue('rangeRadioButtonName', 1);
		});

  // Observe change of range radio buttons to activate the date picker when required
  Form.getInputs($('recurrence_form'), 'radio', 'rangeRadioButtonName').each(function(input) {
      input.observe("change", onRangeChange);
    });

  // Show page
  $("recurrence_pattern").show();
  $("range_of_recurrence").show();
}

function handleDailyRecurrence() {
  var validate = false;

  var radioValue = $('recurrence_form').getRadioValue('dailyRadioButtonName');

  // We check if the dailyDaysField really contains an integer
  if (radioValue == 0) {
    var showError = true;

    var v = "" + $('dailyDaysField').value;
    if (v.length > 0) {
      v = parseInt(v);
			//       log("v: " + v);
      if (!isNaN(v) && v > 0) {
				validate = true;
				showError = false;
				parent$("repeat1").value = radioValue;
				parent$("repeat2").value = v;
      }
    }

    if (showError)
      window.alert("Please specify a numerical value in the Days field greater or equal to 1.");
  }
  else {
    validate = true;
    parent$("repeat1").value = radioValue;
  }

  return validate;
}

function handleWeeklyRecurrence() {
  var validate = false;

  var showError = true;
  var fieldValue = "" + $('weeklyWeeksField').value;
  if (fieldValue.length > 0) {
    // We check if the weeklyWeeksField really contains an integer
    var v = parseInt(fieldValue);
    if (!isNaN(v) && v > 0) {
      validate = true;
      showError = false;
      parent$("repeat1").value = fieldValue;
      parent$("repeat2").value = getSelectedDays("week");
    }
  }

  if (showError)
    window.alert("Please specify a numerical value in the Week(s) field greater or equal to 1.");

  return validate;
}

function handleMonthlyRecurrence() {
  var validate = false;

  var radioValue = $('recurrence_form').getRadioValue('monthlyRadioButtonName');

  // FIXME - right now we do not support rules
  //         such as The Second Tuesday...
  if (radioValue == 0)
    window.alert("This type of recurrence is currently unsupported.");
  else {
    // We check if the monthlyMonthsField really contains an integer
    var showError = true;

    var fieldValue = "" + $('monthlyMonthsField').value;
    if (fieldValue.length > 0) {
      var v = parseInt(fieldValue);
      if (!isNaN(v) && v > 0) {
				validate = true;
				showError = false;
				parent$("repeat1").value = fieldValue;
				parent$("repeat2").value = radioValue;
				parent$("repeat3").value = $('monthlyRepeat').value;
				parent$("repeat4").value = $('monthlyDay').value;
				parent$("repeat5").value = getSelectedDays("month");
      }
    }

    if (showError)
      window.alert("Please specify a numerical value in the Month(s) field greater or equal to 1.");
  }

  return validate;
}

function validateYearlyRecurrence() {
	var errors = ["Please specify a numerical value in the Year(s)"
								+ " field greater or equal to 1.",
								"Please specify a numerical value in the month day"
								+ " field greater or equal to 1."];

	var errorToShow = 0;
	var fieldValue = "" + $('yearlyYearsField').value;
	if (fieldValue.length > 0) {
		// We check if the yearlyYearsField really contains an integer
		var v = parseInt(fieldValue);
		if (!isNaN(v) && v > 0) {
			errorToShow = 1;
			fieldValue = "" + $('yearlyDayField').value;
			if (fieldValue.length > 0) {
				// We check if the yearlyYearsField really contains an integer
				var v = parseInt(fieldValue);
				if (!isNaN(v) && v > 0) {
					errorToShow = -1;
				}
			}
		}
	}

	if (errorToShow > -1)
		window.alert(errors[errorToShow]);

	return (errorToShow == -1);
}

function handleYearlyRecurrence() {
  var validate = false;

  var radioValue = $('recurrence_form').getRadioValue('yearlyRadioButtonName');
  // FIXME - right now we do not support rules
  //         such as Every Second Tuesday of February
  if (radioValue == 1)
    window.alert("This type of recurrence is currently unsupported.");
  else {
		if (validateYearlyRecurrence()) {
			var fieldValue = "" + $('yearlyYearsField').value;
			if (fieldValue.length > 0) {
				// We check if the yearlyYearsField really contains an integer
				var v = parseInt(fieldValue);
				if (!isNaN(v) && v > 0) {
					validate = true;
					showError = false;
					parent$("repeat1").value = fieldValue;
					parent$("repeat2").value = radioValue;
					parent$("repeat3").value = $('yearlyDayField').value;
					parent$("repeat4").value = $('yearlyMonth1').value;
					parent$("repeat5").value = $('yearlyRepeat').value;
					parent$("repeat6").value = $('yearlyDay').value;
					parent$("repeat7").value = $('yearlyMonth2').value;
				}
			}
		}
		else
			validate = false;
  }

  return validate;
}

function handleRange() {
  var validate = false;

  var radioValue = $('recurrence_form').getRadioValue('rangeRadioButtonName');
  if (radioValue == 0)
    validate = true;
  else if (radioValue == 1) {
    var showError = true;

    var fieldValue = "" + $('rangeAppointmentsField').value;
    if (fieldValue.length > 0) {
      // We check if the rangeAppointmentsField really contains an integer
      var v = parseInt(fieldValue);
      if (!isNaN(v) && v > 0) {
				validate = true;
				showError = false;
				parent$("range2").value = fieldValue;
      }
    }

    if (showError)
      window.alert("Please specify a numerical value in the Appointment(s) field  greater or equal to 1.");
  }
  else if (radioValue == 2) {
    validate = true;
    parent$("range2").value = $('endDate_date').value;
  }

  if (validate)
    parent$("range1").value = radioValue;

  return validate;
}

function onEditorOkClick(event) {
  preventDefault(event);
  var repeatType = $("repeatType").value;
  parent$("repeatType").value = repeatType;

  var validate;
  if (repeatType == 0)
    validate = handleDailyRecurrence();
  else if (repeatType == 1)
    validate = handleWeeklyRecurrence();
  else if (repeatType == 2)
    validate = handleMonthlyRecurrence();
  else
    validate = handleYearlyRecurrence();

  if (validate && handleRange())
    window.close();
}

function onEditorCancelClick(event) {
  preventDefault(event);
  window.close();
}

function onRecurrenceLoadHandler() {
  initializeFormValues();
  initializeSelectors();
  initializeWindowButtons();
  assignCalendar('endDate_date');
}

document.observe("dom:loaded", onRecurrenceLoadHandler);
