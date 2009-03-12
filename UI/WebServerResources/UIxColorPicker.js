/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onLoadColorPicker(event) {
  showColorPicker();
}

function onChooseColor(newColor) {
  window.opener.onColorPickerChoice(newColor);
}

document.observe("dom:loaded", onLoadColorPicker);
