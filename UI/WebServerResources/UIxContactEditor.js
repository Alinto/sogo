/* -*- Mode: js2-mode; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
	Copyright (C) 2005 SKYRIX Software AG
	Copyright (C) 2006-2011 Inverse

	This file is part of OpenGroupware.org.

	OGo is free software; you can redistribute it and/or modify it under
	the terms of the GNU Lesser General Public License as published by the
	Free Software Foundation; either version 2, or (at your option) any
	later version.

	OGo is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or
	FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
	License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with OGo; see the file COPYING.  If not, write to the
	Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
	02111-1307, USA.
*/

var dateRegex = /^(([0-9]{2})?[0-9])?[0-9]-[0-9]?[0-9]-[0-9]?[0-9]$/;

var displaynameChanged = false;

var tabIndex = 0;

function unescapeCallbackParameter(s) {
    if(!s || s.length == 0)
        return s;
    s = s.replace(/&apos;/g, "'");
    s = s.replace(/&quot;/g, '"');
    return s;
}

function copyContact(type, email, uid, sn,
                     displayname, givenname, telephonenumber, facsimiletelephonenumber,
		             mobile, postalAddress, homePostalAddress,
		             departmentnumber, l)
{
    //  var type = arguments[0];
    //  var email = arguments[1];
    //  var uid = arguments[2];
    //  var sn = arguments[3];
    //  var givenname = arguments[4];
    //  var telephonenumber = arguments[5];
    //  var facsimiletelephonenumber = arguments[6];
    //  var mobile = arguments[7];
    //  var postaladdress = arguments[8];
    //  var homepostaladdress = arguments[9];
    //  var departmentnumber = arguments[10];
    //  var l = arguments[11];
    var e;
    e = $('displayname');
    e.setAttribute('value', unescapeCallbackParameter(displayname));
    e = $('email');
    e.setAttribute('value', email);
    e = $('sn');
    e.setAttribute('value', unescapeCallbackParameter(sn));
    e = $('givenname');
    e.setAttribute('value', unescapeCallbackParameter(givenname));
    e = $('telephonenumber');
    e.setAttribute('value', telephonenumber);
    e = $('facsimiletelephonenumber');
    e.setAttribute('value', facsimileTelephonenumber);
    e = $('mobile');
    e.setAttribute('value', mobile);
    e = $('postaladdress');
    e.setAttribute('value', unescapeCallbackParameter(postalAddress));
    e = $('homepostaladdress');
    e.setAttribute('value', unescapeCallbackParameter(homePostalAddress));
    e = $('departmentnumber');
    e.setAttribute('value', unescapeCallbackParameter(departmentnumber));
    e = $('l');
    e.setAttribute('value', unescapeCallbackParameter(l));
};

function validateContactEditor() {
    var rc = true;

    var e = $('mail');
    if (e.value.length > 0
        && !emailRE.test(e.value)) {
        alert(_("invalidemailwarn"));
        rc = false;
    }

    e = $('mozillasecondemail');
    if (e.value.length > 0
        && !emailRE.test(e.value)) {
        alert(_("invalidemailwarn"));
        rc = false;
    }

    var byear = $('birthyear');
    var bmonth = $('birthmonth');
    var bday = $('birthday');
    var bdayValue = byear.value + "-" + bmonth.value + "-" + bday.value;
    if (bdayValue != "--" && !dateRegex.test(bdayValue)) {
        alert(_("invaliddatewarn"));
        rc = false;
    }

    return rc;
}

function onDisplaynameKeyDown() {
    var fn = $("displayname");
    fn.onkeydown = null;
    displaynameChanged = true;

    return true;
}

function onDisplaynameNewValue(event) {
    if (!displaynameChanged) {
        var sn = $("sn").value.trim();
        var givenname = $("givenname").value.trim();

        var fullname = givenname;
        if (fullname && sn)
            fullname += ' ';
        fullname += sn;

        $("displayname").value = fullname;
    }

    return true;
}

function onEditorCancelClick(event) {
    this.blur();
    onCloseButtonClick(event);
}

function onEditorSubmitClick(event) {
    if (validateContactEditor()) {
        saveCategories();
        $('mainForm').submit();
    }
    this.blur();
}

function saveCategories() {
    var container = $("categoryContainer");
    var catsInput = $("jsonContactCategories");
    if (container && catsInput) {
        var newCategories = $([]);
        var inputs = container.select("INPUT");
        for (var i = 0; i < inputs.length; i++) {
            var newValue = inputs[i].value.trim();
            if (newValue.length > 0 && newValue != _("New category")
                && newCategories.indexOf(newValue) == -1) {
                newCategories.push(newValue);
            }
        }
        var json = Object.toJSON(newCategories);
        catsInput.value = json;
    }
}

function onDocumentKeydown(event) {
    var target = Event.element(event);
    if (target.tagName == "INPUT" || target.tagName == "SELECT") {
        if (event.keyCode == Event.KEY_RETURN) {
            var fdisplayname = onEditorSubmitClick.bind($("submitButton"));
            fdisplayname();
            Event.stop(event);
        }
    }
}

function appendCategoryInput(label) {
    var container = $("categoryContainer");

    var inputContainer = createElement("div");
    var textInput = createElement("input", null, "comboBoxField", null,
                                  { type: "text"}, inputContainer);
    textInput.observe("change", onCategoryInputChange);
    textInput.observe("focus", onCategoryInputFocus);
    textInput.value = label;
    textInput.tabIndex = tabIndex;
    tabIndex++;
    var button = createElement("button", null, "comboBoxButton");
    inputContainer.appendChild(button);
    button.observe("click", onComboButtonClick);
    button.textInput = textInput;
    button.menuName = "categoriesMenu";

    container.appendChild(inputContainer);

    return textInput;
}

function onComboButtonClick(event) {
    var menu = $(this.menuName);
    popupMenu(event, this.menuName, this.textInput);
    var container = $("categoryContainer");
    var menuTop = (container.cascadeTopOffset()
                   - container.scrollTop
                   + this.textInput.offsetTop
                   + this.textInput.clientHeight);
    var menuLeft = this.textInput.cascadeLeftOffset() + 1;
    var width = this.textInput.clientWidth;
    menu.setStyle({ "top": menuTop + "px",
                    "left": menuLeft + "px",
                    "width": width + "px" });

    return false;
}

function onCategoryInputChange(event) {
    var newValue = this.value.trim();
    if (newValue == "") {
        var inputContainer = this.parentNode;
        inputContainer.parentNode.removeChild(inputContainer);
    }
    else {
        if (gCategories.indexOf(newValue) == -1) {
            gCategories.push(newValue);
            gCategories.sort(function (a, b)
                             { return a.toLowerCase() > b.toLowerCase(); } );
            regenerateCategoriesMenu();
        }
    }
}

function onCategoryInputFocus(event) {
    this.select();
}

function regenerateCategoriesMenu() {
    var menu = $("categoriesMenu");
    if (menu) {
        while (menu.lastChild) {
            menu.removeChild(menu.lastChild);
        }
        var list = createElement("ul");
        for (var i = 0; i < gCategories.length; i++) {
            var label = gCategories[i];
            var entry = createElement("li");
            entry.label = label;
            entry.menuCallback = onCategoryMenuEntryClick;
            entry.on("mousedown", onMenuClickHandler);
            entry.appendChild(document.createTextNode(label));
            list.appendChild(entry);
        }
        menu.appendChild(list);
    }
}

function onCategoryMenuEntryClick(event) {
    document.menuTarget.value = this.label;
    document.menuTarget.focus();
}

function onEmptyCategoryClick(event) {
    var textInput = appendCategoryInput(_("New category"));
    window.setTimeout(function() {textInput.focus();},
                      100);
    event.preventDefault();
}

function initEditorForm() {
    var tabsContainer = $("editorTabs");
    var controller = new SOGoTabsController();
    controller.attachToTabsContainer(tabsContainer);

    displaynameChanged = ($("displayname").value.length > 0);
    $("displayname").onkeydown = onDisplaynameKeyDown;
    $("sn").onkeyup = onDisplaynameNewValue;
    $("givenname").onkeyup = onDisplaynameNewValue;

    $("cancelButton").observe("click", onEditorCancelClick);
    var submitButton = $("submitButton");
    if (submitButton) {
        submitButton.observe("click", onEditorSubmitClick);
    }

    Event.observe(document, "keydown", onDocumentKeydown);

    if (typeof(gCategories) != "undefined") {
        regenerateCategoriesMenu();
    }
    var catsInput = $("jsonContactCategories");
    if (catsInput && catsInput.value.length > 0) {
        var contactCats = $(catsInput.value.evalJSON(false));
        for (var i = 0; i < contactCats.length; i++) {
            appendCategoryInput(contactCats[i]);
        }
    }

    var emptyCategory = $("emptyCategory");
    if (emptyCategory) {
        emptyCategory.tabIndex = 10000;
        emptyCategory.observe("click", onEmptyCategoryClick);
    }
}

document.observe("dom:loaded", initEditorForm);
