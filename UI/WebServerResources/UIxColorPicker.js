/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onLoadColorPicker(event) {
  showColorPicker();
}

function onChooseColor(newColor) {
  window.opener.onColorPickerChoice(newColor);
  window.close();
}

document.observe("dom:loaded", onLoadColorPicker);
