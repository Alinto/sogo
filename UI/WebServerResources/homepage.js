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
/* JavaScript for SOGo Homepage */

function toggleInternetAccessState(sender) {
//    var form = document.getElementById("syncDefaultsForm");
//    document.syncDefaultsForm.action="saveInternetAccessState:method";
//    form.submit();
    this.postInternetAccessState(sender, sender.value);
    return true;
}

function postInternetAccessState(sender, state) {
    var url;
    var http = createHTTPClient();
    
    url = "edit?allowinternet=" + state;
    
    if (http) {
        http.open("POST", url, false);
        http.send("");
        if (http.status != 200) {
            alert("Failed to change state: " + http.statusText);
            window.location.reload();
        }
    }
    else {
        alert("Unable to retrieve HTTPClient object!");
        window.location.href = url;
    }
}
