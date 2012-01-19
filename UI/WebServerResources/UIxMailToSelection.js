/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
	Copyright (C) 2005 SKYRIX Software AG
 
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

/* Dependencies:
 * It's required that "currentIndex" is defined in a top level context.
 *
 * Exports:
 * defines hasRecipients() returning a bool for the
 * surrounding context to check.
 */

var lastIndex = currentIndex;

function sanitizedCn(cn) {
    var parts;
    parts = cn.split(', ');
    if(parts.length == 1)
        return cn;
    return parts[0];
}

function hasAddress(email) {
    var e = $(email);
    if(e)
        return true;
    return false;
}

function checkAddresses() {
    alert("addressCount: " + this.getAddressCount() + " currentIndex: " + currentIndex + " lastIndex: " + lastIndex);
}

function fancyAddRow(text, type) {
    var addr = $('addr_' + lastIndex);
    if (addr && addr.value == '') {
        var sub = $('subjectField');
        if (sub && sub.value != '') {
            sub.focus();
            sub.select();
            return;
        }
    }
    var addressList = $("addressList").tBodies[0];
    var lastChild = $("lastRow");
  
    currentIndex++;
    var proto = lastChild.previous("tr");
    var row = proto.cloneNode(true);
    row.writeAttribute("id", 'row_' + currentIndex);
    var rowNodes = row.childNodesWithTag("td");
    var select = $(rowNodes[0]).childNodesWithTag("select")[0];
    select.name = 'popup_' + currentIndex;
    select.value = (type? type : proto.down("select").value);
    var cell = $(rowNodes[1]);
    var input = cell.childNodesWithTag("input")[0];
    if (Prototype.Browser.IE) {
        cell.removeChild(input);
        input = new Element("input");
        cell.appendChild(input);
    }
    
    input.name  = 'addr_' + currentIndex;
    input.id = 'addr_' + currentIndex;
    input.value = text;
    input.stopObserving();
    input.addInterface(SOGoAutoCompletionInterface);
    addressList.insertBefore(row, lastChild);
    input.observe("focus", addressFieldGotFocus.bind(input));
    input.observe("blur", addressFieldLostFocus.bind(input));
    input.observe("autocompletion:changedlist", expandContactList);
    input.on("autocompletion:changed", addressFieldChanged.bind(input));
    input.focus();

    return input;
}

function expandContactList (e) {
    var container = $(e).memo;
    var url = UserFolderURL + "Contacts/" + container + "/"
        + this.readAttribute("uid") + "/properties";
    triggerAjaxRequest (url, expandContactListCallback, this);
}

function expandContactListCallback (http) {
    if (http.readyState == 4) {
        var input = http.callbackData;
        if (http.status == 200) {
            var data = http.responseText.evalJSON(true);
            // TODO: Should check for duplicated entries
            for (var i = data.length - 1; i >= 0; i--)
                // Remove contacts with no email address
                if (data[i][2].length == 0) data.splice(i, 1);
            if (data.length >= 1) {
                var text = data[0][2];
                if (data[0][1].length)
                  text = data[0][1] + " <" + data[0][2] + ">";
                input.value = text;
                input.writeAttribute("container", null);
            }
            if (data.length > 1) {
                for (var i = 1; i < data.length; i++) {
                    var text = data[i][2];
                    if (data[i][1].length)
                      text = data[i][1] + " <" + data[i][2] + ">";
                    fancyAddRow(text, $(input).up("tr").down("select").value);
                }
            }
        }
    }
}

function addressFieldGotFocus(event) {
    var idx;
  
    idx = getIndexFromIdentifier(this.id);
    if (lastIndex == idx) return;
    removeLastEditedRowIfEmpty();
    if (Prototype.Browser.IE && this.value.length == 0)
        $(this).setCaretTo(0); // IE hack
    onWindowResize(null);

    return false;
}

function addressFieldLostFocus(event) {
    lastIndex = getIndexFromIdentifier(this.id);
    addressFieldChanged.bind(this, event)();
}

function addressFieldChanged(event) {
    // We first split by semi-colon and then by comma only if there's no
    // email address detected.
    // Examples: 
    //   "dude, buddy dude@domain.com; bro" => "dude, buddy <dude@domain.com>" + "bro"
    //   "dude, buddy, bro <bro@domain.com>" => "dude, buddy, bro <bro@domain.com>"
    //   "dude, buddy, bro" => "dude" + "buddy" + "bro"
    //   "dude@domain.com, <buddy@domain.com>" => "<dude@domain.com>" + "<buddy@domain.com>"
    var addresses = this.value.split(';');
    if (addresses.length > 0) {
        var first = true;
        for (var i = 0; i < addresses.length; i++) {
            var words = addresses[i].split(' ');
            var phrase = new Array();
            for (var j = 0; j < words.length; j++) {
                var word = words[j].strip().replace(/<(.+)>/, "$1").replace(',', '');
                if (word.length > 0) {
                    // Use the regexp defined in generic.js
                    if (emailRE.test(word)) {
                        phrase.push('<' + word + '>');
                        if (first) {
                            this.value = phrase.join(' ');
                            first = false;
                        }
                        else
                            fancyAddRow(phrase.join(' '), $(this).up("tr").down("select").value);
                    
                        phrase = new Array();
                    }
                    else
                        phrase.push(words[j].strip());
                }
            }
            if (phrase.length > 0) {
                words = phrase.join(' ').split(',');
                for (var j = 0; j < words.length; j++) {
                    word = words[j];
                    if (first) {
                        this.value = word;
                        first = false;
                    }
                    else
                        fancyAddRow(word, $(this).up("tr").down("select").value);
                }
                
                phrase = new Array();
            }
        }
    }

    // Verify if a new row should be created
    var keyCode = event.memo;
    if (keyCode == Event.KEY_RETURN) {
        var input = fancyAddRow("");
        if (Prototype.Browser.IE)
            $(input.id).focus();
        else
            input.focus();
    }
    
    onWindowResize(null);
}

function removeLastEditedRowIfEmpty() {
    var addr, addressList, senderRow;
  
    addressList = $("addressList").tBodies[0];
  
    if (lastIndex == 0 && addressList.childNodes.length <= 2) return;
    addr = $('addr_' + lastIndex);
    if (!addr) return;
    if (addr.value.strip() != '') return;
    senderRow = $("row_" + lastIndex);
    addressList.removeChild(senderRow);
}

function getIndexFromIdentifier(id) {
    return id.split('_')[1];
}

function getAddressIDs() {
    var addressList, rows, i, count, addressIDs;

    addressIDs = new Array();

    addressList = $("addressList").tBodies[0];
    rows  = addressList.childNodes;
    count = rows.length;

    for (i = 0; i < count; i++) {
        var row, rowId;
    
        row = rows[i];
        rowId = row.id;
        if (rowId && rowId != 'lastRow') {
            var idx;

            idx = this.getIndexFromIdentifier(rowId);
            addressIDs.push(idx);
        }
    }
    return addressIDs;
}

function getAddressCount() {
    var addressCount, addressIDs, i, count;
  
    addressCount = 0;
    addressIDs   = this.getAddressIDs();
    count        = addressIDs.length;
    for (i = 0; i < count; i++) {
        var idx, input;

        idx   = addressIDs[i];
        input = $('addr_' + idx);
        if (input && input.value != '')
            addressCount++;
    }
    return addressCount;
}

function hasRecipients() {
    var count;
  
    count = this.getAddressCount();

    return (count > 0);
}

function initMailToSelection() {
    currentIndex = lastIndex = $$("table#addressList tr").length - 2;
}

document.observe("dom:loaded", initMailToSelection);
