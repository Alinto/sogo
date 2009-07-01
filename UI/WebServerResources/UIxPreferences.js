/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function savePreferences(sender) {
  var sigList = $("signaturePlacementList");
  if (sigList)
    sigList.disabled=false;
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

  if ($("signature")) {
    CKEDITOR.replace('signature',
                     {
                        skin: "v2",
                        height: "90px",
                        toolbar :
                        [['Bold', 'Italic', '-', 'Link', 
                          'Font','FontSize','-','TextColor',
                          'BGColor']
                        ] 
                     }
                    );

    $("replyPlacementList").observe ("change", onReplyPlacementListChange);
    onReplyPlacementListChange();

    $("composeMessagesType").observe ("change", onComposeMessagesTypeChange);

    if (!UserDefaults["ComposeMessagesType"])
      UserDefaults["ComposeMessagesType"] = "text";

    onComposeMessagesTypeChange ();
  }
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
  var editor = $('cke_signature');

  if (!editor) {
    setTimeout ("onComposeMessagesTypeChange ()", 10);
    return;
  }
 
  if ($("composeMessagesType").value == 0) {
    textArea.style.display = 'block';
    textArea.style.visibility = '';
    editor.style.display = 'none';
  }
  else {
    textArea.style.display = 'none';
    editor.style.display = 'block';
  }
}

document.observe("dom:loaded", initPreferences);
