/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for Authentication */

(function() {
  /* jshint validthis: true */
  'use strict';

  angular.module('SOGo.Authentication', ['ngCookies'])

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

  .provider('Authentication', Authentication);

  function Authentication() {
    function redirectUrl(username, domain) {
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
      if ((address.startsWith(baseAddress) || address.startsWith(altBaseAddress)) &&
          !address.endsWith('/logoff')) {
        newAddress = address;
      }
      else {
        newAddress = baseAddress;
      }

      return newAddress;
    }

    this.$get = getService;

    /**
     * @ngInject
     */
    getService.$inject = ['$q', '$http', '$cookies', 'passwordPolicyConfig'];
    function getService($q, $http, $cookies, passwordPolicyConfig) {
      var service;

      function readLoginCookie() {
        var loginValues = null,
            cookie = $cookies.get('0xHIGHFLYxSOGo'),
            value;
        if (cookie && cookie.length > 8) {
          value = decodeURIComponent(cookie.substr(8));
          loginValues = value.base64decode().split(':');
        }

        return loginValues;
      }

      service = {
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
          }).then(function(response) {
            var data = response.data;
            // Make sure browser's cookies are enabled
            var loginCookie = readLoginCookie();
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
                  d.resolve(redirectUrl(username, domain));
                }
              }
              else {
                d.resolve(redirectUrl(username, domain));
              }
            }
          }, function(response) {
            var msg, perr, data = response.data;
            if (data && data.LDAPPasswordPolicyError) {
              perr = data.LDAPPasswordPolicyError;
              if (perr == passwordPolicyConfig.PolicyNoError) {
                msg = l('Wrong username or password.');
              }
              else if (perr == passwordPolicyConfig.PolicyAccountLocked) {
                msg = l('Your account was locked due to too many failed attempts.');
              }
              else {
                msg = l('Login failed due to unhandled error case: ') + perr;
              }
            }
            else {
              msg = l('Unhandled error response');
            }
            d.reject({error: msg});
          });
          return d.promise;
        }, // login: function(data) { ...

        changePassword: function(newPassword) {
          var d = $q.defer(),
              loginCookie = readLoginCookie(),
              xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', {path: '/SOGo/'});

          $http({
            method: 'POST',
            url: '/SOGo/so/changePassword',
            headers: {
              'X-XSRF-TOKEN' : xsrfCookie
            },
            data: {
              userName: loginCookie[0],
              password: loginCookie[1],
              newPassword: newPassword }
          }).then(d.resolve, function(response) {
            var error,
                data = response.data,
                perr = data.LDAPPasswordPolicyError;

            if (!perr) {
              perr = passwordPolicyConfig.PolicyPasswordSystemUnknown;
              error = _("Unhandled error response");
            }
            else if (perr == passwordPolicyConfig.PolicyNoError) {
              error = l("Password change failed");
            } else if (perr == passwordPolicyConfig.PolicyPasswordModNotAllowed) {
              error = l("Password change failed - Permission denied");
            } else if (perr == passwordPolicyConfig.PolicyInsufficientPasswordQuality) {
              error = l("Password change failed - Insufficient password quality");
            } else if (perr == passwordPolicyConfig.PolicyPasswordTooShort) {
              error = l("Password change failed - Password is too short");
            } else if (perr == passwordPolicyConfig.PolicyPasswordTooYoung) {
              error = l("Password change failed - Password is too young");
            } else if (perr == passwordPolicyConfig.PolicyPasswordInHistory) {
              error = l("Password change failed - Password is in history");
            } else {
              error = l("Unhandled policy error: %{0}").formatted(perr);
              perr = passwordPolicyConfig.PolicyPasswordUnknown;
            }

            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, {path: '/SOGo/'});
            d.reject(error);
          });
          return d.promise;
        }
      };
      return service;
    }
  }

})();
