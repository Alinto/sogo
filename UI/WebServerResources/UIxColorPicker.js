/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var type;

function onLoadColorPicker(event) {
  showColorPicker();
}

function onChooseColor(newColor) {
  window.opener.onColorPickerChoice(newColor, type);
  window.close();
}

document.observe("dom:loaded", onLoadColorPicker);
