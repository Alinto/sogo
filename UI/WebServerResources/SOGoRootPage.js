/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function initLogin() {
	var date = new Date();
	date.setTime(date.getTime() - 86400000);
	document.cookie = ("0xHIGHFLYxSOGo-0.9=discard; path=/"
										 + "; expires=" + date.toGMTString());
	var submit = $("submit");
	submit.observe("click", onLoginClick);

	var userName = $("userName");
	userName.focus();

	var image = $("preparedAnimation");
	image.parentNode.removeChild(image);
}

function onLoginClick(event) {
	var userNameField = $("userName");
	var userName = userNameField.value;
	var password = $("password").value;
	var language = $("language").value;
	
	if (userName.length > 0) {
		startAnimation($("loginButton"), $("submit"));
		
		if (typeof(loginSuffix) != "undefined"
				&& loginSuffix.length > 0
				&& !userName.endsWith(loginSuffix))
			userName += loginSuffix;
		var url = $("connectForm").getAttribute("action");
		var parameters = ("userName=" + encodeURIComponent(userName) + 
											"&password=" + encodeURIComponent(password) + 
											((language == "WONoSelectionString")?"":("&language=" + language)));
		document.cookie = "";
		triggerAjaxRequest(url, onLoginCallback, null, parameters,
											 { "Content-type": "application/x-www-form-urlencoded",
													 "Content-length": parameters.length,
													 "Connection": "close" });
	}
	else
		userNameField.focus();

	preventDefault(event);
}

function onLoginCallback(http) {
	if (http.readyState == 4) {
		var noCookiesErrorMessage = $("noCookiesErrorMessage");
		var loginErrorMessage = $("loginErrorMessage");

		if (isHttpStatus204(http.status)) {
			// Make sure browser's cookies are enabled
			var cookieExists = 0;
			var ca = document.cookie.split(';');
			for (var i = 0; i < ca.length; i++) {
				var c = ca[i];
				while (c.charAt(0) == ' ') c = c.substring(1, c.length);
				if (c.indexOf("0xHIGHFLYxSOGo-0.9=") == 0) {
					cookieExists = 1;
					break;
				}
			}
			if (cookieExists === 0) {
				loginErrorMessage.hide();
				noCookiesErrorMessage.show();
				return false;
			}
      
			// Redirect to proper page
			var userName = $("userName").value;
			if (typeof(loginSuffix) != "undefined"
					&& loginSuffix.length > 0
					&& !userName.endsWith(loginSuffix))
				userName += loginSuffix;
			var address = "" + window.location.href;
			var baseAddress = ApplicationBaseURL + encodeURIComponent(userName);
			var altBaseAddress;
			if (baseAddress[0] == "/") {
				var parts = address.split("/");
				var hostpart = parts[2];
				var protocol = parts[0];
				baseAddress = protocol + "//" + hostpart + baseAddress;
			}
			var altBaseAddress;
			var parts = baseAddress.split("/");
			parts.splice(3, 0);
			altBaseAddress = parts.join("/");

			var newAddress;
			if ((address.startsWith(baseAddress)
					 || address.startsWith(altBaseAddress))
					&& !address.endsWith("/logoff"))
				newAddress = address;
			else
				newAddress = baseAddress;
			window.location.href = newAddress;
		}
		else {
			loginErrorMessage.show();
			noCookiesErrorMessage.hide();
		}
	}
}

document.observe("dom:loaded", initLogin);
