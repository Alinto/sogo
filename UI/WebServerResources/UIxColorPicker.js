function onLoadColorPicker(event) {
  showColorPicker();
}

function onChooseColor(newColor) {
  window.opener.onColorPickerChoice(newColor);
}

FastInit.addOnLoad(onLoadColorPicker);
