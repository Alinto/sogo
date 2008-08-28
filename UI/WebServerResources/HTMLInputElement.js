/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

Form.Element.Methods._replicate = function(element) {
  element = $(element);
  if (element.replica) {
    element.replica.value = $F(element);
    var onReplicaChangeEvent = document.createEvent("UIEvents");
    onReplicaChangeEvent.initEvent("change", true, true);
    element.replica.dispatchEvent(onReplicaChangeEvent);
  }
};

Form.Element.Methods.assignReplica = function(element, otherInput) {
	element = $(element);
	if (!element._onChangeBound) {
		element.observe("change", element._replicate, false);
		element._onChangeBound = true;
	}
	element.replica = otherInput;
};

Form.Element.Methods.valueAsDate = function(element) {
	return $F(element).asDate();
};

Form.Element.Methods.setValueAsDate = function(element, dateValue) {
	element = $(element);
	if (!element.dateSeparator)
		element._detectDateSeparator();
	element.value = dateValue.stringWithSeparator(element.dateSeparator);
};

Form.Element.Methods.updateShadowValue = function(element) {
	element = $(element);
	element.setAttribute("shadow-value", $F(element));
};

Form.Element.Methods._detectDateSeparator = function(element) {
	element = $(element);
	var date = $F(element).split("/");
	if (date.length == 3)
		element.dateSeparator = "/";
	else
		element.dateSeparator = "-";
};

Form.Element.Methods.valueAsShortDateString = function(element) {
	element = $(element);
	var dateStr = '';
  
	if (!element.dateSeparator)
		element._detectDateSeparator();
  
	var date = $F(element).split(element.dateSeparator);
	if (element.dateSeparator == '/')
		dateStr += date[2] + date[1] + date[0];
	else
		dateStr += date[0] + date[1] + date[2];
  
	return dateStr;
};

Element.addMethods();
