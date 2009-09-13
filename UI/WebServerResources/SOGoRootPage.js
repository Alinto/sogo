/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function initLogin() {
	var date = new Date();
	date.setTime(date.getTime() - 86400000);
	document.cookie = ("0xHIGHFLYxSOGo=discarded"
                           + "; expires=" + date.toGMTString()
		           + "; path=/");

	var about = $("about");
	if (about) {
		about.observe("click", function(event) { $("aboutBox").show(); });

		var aboutClose = $("aboutClose");
		aboutClose.observe("click", function(event) { $("aboutBox").hide(); });
	}

	var submit = $("submit");
	submit.observe("click", onLoginClick);

	var userName = $("userName");
	userName.focus();

	var image = $("preparedAnimation");
	image.parentNode.removeChild(image);

	var submitBtn = $("submit");
	submitBtn.disabled = false;
}

function onLoginClick(event) {
	var userNameField = $("userName");
	var userName = userNameField.value;
	var password = $("password").value;
	var language = $("language");
	
	if (userName.length > 0) {
		$("loginErrorMessage").hide();
		$("noCookiesErrorMessage").hide();
		this.disabled = true;
		startAnimation($("animation"));

		if (typeof(loginSuffix) != "undefined"
				&& loginSuffix.length > 0
				&& !userName.endsWith(loginSuffix))
			userName += loginSuffix;
		var url = $("connectForm").getAttribute("action");
		var parameters = "userName=" + encodeURIComponent(userName) + 
											"&password=" + encodeURIComponent(password);
		if (language)
			parameters += (language.value == "WONoSelectionString")?"":("&language=" + language.value);
        /// Discarded as it seems to create a cookie for nothing. To discard
        //  a cookie in JS, have a look here: http://www.quirksmode.org/js/cookies.html
	//	document.cookie = "";
		triggerAjaxRequest(url, onLoginCallback, null, (parameters),
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
		var submitBtn = $("submit");

		if (isHttpStatus204(http.status)) {
			// Make sure browser's cookies are enabled
			var cookieExists = 0;
			var ca = document.cookie.split(';');
			for (var i = 0; i < ca.length; i++) {
				var c = ca[i];
				while (c.charAt(0) == ' ') c = c.substring(1, c.length);
				if (c.indexOf("0xHIGHFLYxSOGo=") == 0) {
					cookieExists = 1;
					break;
				}
			}
			if (cookieExists === 0) {
				loginErrorMessage.hide();
				noCookiesErrorMessage.show();
				submitBtn.disabled = false;
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
			submitBtn.disabled = false;
		}
	}
}

document.observe("dom:loaded", initLogin);
