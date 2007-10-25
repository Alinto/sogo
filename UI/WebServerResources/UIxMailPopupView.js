function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

addEvent(window, 'load', resizeMailContent);
