/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function savePreferences(sender) {
  $("signaturePlacementList").disabled=false;
	$("mainForm").submit();

	return false;
}

function _setupEvents(enable) {
  var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
									"timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
									"firstWeek", "messageCheck", "subscribedFoldersOnly" ];
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
  $("replyPlacementList").observe ("change", onReplyPlacementListChange);
  onReplyPlacementListChange();

  var oFCKeditor = new FCKeditor ('signature');
  oFCKeditor.BasePath = "/SOGo.woa/WebServerResources/fckeditor/";
  oFCKeditor.ToolbarSet	= 'Basic';
  oFCKeditor.ReplaceTextarea ();
  $('signature___Frame').style.height = "150px";
  $('signature___Frame').height = "150px";

  if (UserDefaults["ComposeMessagesType"] != "html") {
    $("signature").style.display = 'inline';
    $('signature___Frame').style.display = 'none';
  }

  $("composeMessagesType").observe ("change", onComposeMessagesTypeChange);
}

function onReplyPlacementListChange() {
  // above = 0
  if ($("replyPlacementList").value == 0) {
    $("signaturePlacementList").disabled=false;
  }
  else {
    $("signaturePlacementList").value=1;
    $("signaturePlacementList").disabled=true;
  }
}

function onComposeMessagesTypeChange () {
  var textArea = $('signature');
  var oEditor = FCKeditorAPI.GetInstance('signature');
  var editor = $('signature___Frame');
 
  if ($("composeMessagesType").value == 0) {
    textArea.style.display = 'inline';
    editor.style.display = 'none';
    textArea.value = oEditor.GetData();
  }
  else {
    textArea.style.display = 'none';
    editor.style.display = '';
    oEditor.SetHTML(textArea.value);
  }
}

document.observe("dom:loaded", initPreferences);
