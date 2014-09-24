/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.Authentication', [])

    .constant('passwordPolicyConfig', {
      PolicyPasswordChangeUnsupported: -3,
      PolicyPasswordSystemUnknown: -2,
      PolicyPasswordUnknown: -1,
      PolicyPasswordExpired: 0,
      PolicyAccountLocked: 1,
      PolicyChangeAfterReset: 2,
      PolicyPasswordModNotAllowed: 3,
      PolicyMustSupplyOldPassword: 4,
      PolicyInsufficientPasswordQuality: 5,
      PolicyPasswordTooShort: 6,
      PolicyPasswordTooYoung: 7,
      PolicyPasswordInHistory: 8,
      PolicyNoError: 65535
    })

  // TODO: convert to a Factory recipe?
    .provider('Authentication', function(passwordPolicyConfig) {
      this.readCookie = function(name) {
        var foundCookie, prefix, pairs, i, currentPair, start;
        foundCookie = null;
        prefix = name + '=';
        pairs = document.cookie.split(';');
        for (i = 0; !foundCookie && i < pairs.length; i++) {
          currentPair = pairs[i];
          start = 0;
          while (currentPair.charAt(start) == ' ')
            start++;
          if (start > 0)
            currentPair = currentPair.substr(start);
          if (currentPair.indexOf(prefix) == 0)
            foundCookie = currentPair.substr(prefix.length);
        }

        return foundCookie;
      };

      this.readLoginCookie = function() {
        var loginValues = null,
            cookie = this.readCookie('0xHIGHFLYxSOGo'),
            value;
        if (cookie && cookie.length > 8) {
          value = decodeURIComponent(cookie.substr(8));
          loginValues = value.base64decode().split(':');
        }

        return loginValues;
      };

      this.redirectUrl = function(username, domain) {
        var userName, address, baseAddress, altBaseAddress, parts, hostpart, protocol, newAddress;

        userName = username;
        if (domain)
          userName += '@' + domain.value;
        address = '' + window.location.href;
        baseAddress = ApplicationBaseURL + '/' + encodeURIComponent(userName);
        if (baseAddress[0] == '/') {
          parts = address.split('/');
          hostpart = parts[2];
          protocol = parts[0];
          baseAddress = protocol + '//' + hostpart + baseAddress;
        }
        parts = baseAddress.split('/');
        parts.splice(0, 3);
        altBaseAddress = parts.join('/');
        newAddress;
        if ((address.startsWith(baseAddress)
             || address.startsWith(altBaseAddress))
            && !address.endsWith('/logoff')) {
          newAddress = address;
        } else {
          newAddress = baseAddress;
        }

        if (/theme=mobile/.test(window.location.search)) {
          newAddress = baseAddress + '/Contacts' + '?theme=mobile';
        }
        else {
          newAddress = baseAddress + '/Contacts';
        }

        return newAddress;
      };

      this.$get = ['$q', '$http', function($q, $http) {
        var _this = this, service;

        service = {
          // login: function(username, password, domain, language, rememberLogin) {
          //     var d = $q.defer();
          login: function(data) {
            var d = $q.defer(),
                username = data.username,
                password = data.password,
                domain = data.domain,
                language,
                rememberLogin = data.rememberLogin ? 1 : 0;

            if (data.loginSuffix && !username.endsWith(data.loginSuffix)) {
              username += loginSuffix;
              domain = false;
            }
            if (data.language && data.language != 'WONoSelectionString') {
              language = data.language;
            }

            $http({
              method: 'POST',
              url: '/SOGo/connect',
              data: {
                userName: username,
                password: password,
                domain: domain,
                language: language,
                rememberLogin: rememberLogin
              }
            }).success(function(data, status) {
              // Make sure browser's cookies are enabled
              var loginCookie = _this.readLoginCookie();
              if (!loginCookie) {
                d.reject(l('cookiesNotEnabled'));
              }
              else {
                // Check password policy
                if (typeof data.expire != 'undefined' && typeof data.grace != 'undefined') {
                  if (data.expire < 0 && data.grace > 0) {
                    d.reject({grace: data.grace});
                    //showPasswordDialog('grace', createPasswordGraceDialog, data['grace']);
                  } else if (data.expire > 0 && data.grace == -1) {
                    d.reject({expire: data.expire});
                    //showPasswordDialog('expiration', createPasswordExpirationDialog, data['expire']);
                  }
                  else {
                    d.resolve(_this.redirectUrl(username, domain));
                  }
                }
                else {
                  d.resolve(_this.redirectUrl(username, domain));
                }
              }
            }).error(function(data, status) {
              var msg, perr;
              if (data && data.LDAPPasswordPolicyError) {
                perr = data.LDAPPasswordPolicyError;
                if (perr == passwordPolicyConfig.PolicyNoError) {
                  msg = l('Wrong username or password.');
                }
                else {
                  msg = l('Login failed due to unhandled error case: ' + perr);
                }
              }
              else {
                msg = l('Unhandled error response');
              }
              d.reject({error: msg});
            });
            return d.promise;
          }
        };
        return service;
      }];
    });

})();
