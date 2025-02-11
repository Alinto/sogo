/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for MainUI (SOGoRootPage) */
(function () {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Common', 'SOGo.Authentication']);
  const PASSWORD_RECOVERY_TIMER_MS = 2000;

  /**
   * @ngInject
   */
  LoginController.$inject = ['$scope', '$window', '$timeout', 'Dialog', '$mdDialog', 'Authentication', 'sgFocus', 'sgRippleClick', 'sgConstant', '$mdToast'];
  function LoginController($scope, $window, $timeout, Dialog, $mdDialog, Authentication, focus, rippleDo, sgConstant, $mdToast) {
    var vm = this;

    this.$onInit = function () {
      this.creds = {
        username: $window.cookieUsername,
        password: null,
        domain: null,
        rememberLogin: angular.isDefined($window.cookieUsername) && $window.cookieUsername.length > 0
      };
      // Send selected language only if user has changed it
      if (/\blanguage=/.test($window.location.search))
        this.creds.language = $window.language;
      this.loginState = false;

      // Code pattern for TOTP verification code
      this.verificationCodePattern = '\\d{6}';

      // Password policy - change expired password
      this.passwords = { newPassword: null, newPasswordConfirmation: null, oldPassword: null, visible: false };

      // Password recovery
      this.passwordRecovery = {
        passwordRecoveryEnabled: false,
        passwordRecoveryQuestionKey: null,
        passwordRecoveryQuestion: null,
        passwordRecoveryMode: null,
        passwordRecoveryQuestionAnswer: null,
        passwordRecoveryToken: null,
        passwordRecoveryLinkTimer: null,
        passwordRecoverySecondaryEmailText: null,
        passwordRecoveryMailDomain: null,
        showLoader: false
      };

      // Show login once everything is initialized
      this.showLogin = false;
      $timeout(function () {
        vm.showLogin = true;

        const queryString = window.location.search;
        const urlParams = new URLSearchParams(queryString);
        let token = urlParams.get('token');

        if (0 < window.location.pathname.indexOf("passwordRecoveryEmail") && token) {
          token = token.replace(/\//g, ''); // remove trailing '/'
          const tokenArray = token.split(".");

          // Retrieve info from token
          if (3 === tokenArray.length) {
            vm.passwordRecovery.passwordRecoveryToken = token;
            const info = JSON.parse(atob(tokenArray[1]));
            vm.creds.username = info.username;
            vm.creds.domain = info.domain;
            vm.passwordRecovery.passwordRecoveryToken = token;
            vm.passwordRecovery.passwordRecoveryMode = "SecondaryEmail";
            vm.passwordRecovery.passwordRecoveryEnabled = true;

            vm.loginState = 'passwordchange';
            rippleDo('loginContent');
          }

        } else {
          vm.retrievePasswordRecoveryEnabled();
        }

        // Manage autofill 
        if (document.querySelectorAll('*:autofill').length > 0) {
          document.querySelectorAll('*:autofill').forEach((el) => {
            el.parentElement.classList.add("md-input-has-value");
          });
        }
      }, 100);

    };

    this.login = function () {
      vm.loginState = 'authenticating';
      Authentication.login(vm.creds)
        .then(function (data) {

          if (data.totpmissingkey) {
            vm.loginState = 'totpcode';
            focus('totpcode');
          }
          else if (data.totpdisabled) {
            vm.loginState = 'totpdisabled';
            vm.cn = data.cn;
            vm.url = data.url;
          }
          else {
            vm.loginState = 'logged';
            vm.cn = data.cn;
            vm.url = data.url;

            // Let the user see the succesfull message before reloading the page
            $timeout(function () {
              vm.continueLogin();
            }, 1000);
          }
        }, function (msg) {
          vm.loginState = 'error';

          if (msg.error) {
            vm.errorMessage = msg.error;
          }
          else if (msg.grace > 0) {
            // Password is expired, grace logins limit is not yet reached
            vm.loginState = 'passwordwillexpire';
            vm.cn = msg.cn;
            vm.url = msg.url;
            vm.passwordPolicy = msg.userPolicies ? msg.userPolicies : [];
            vm.errorMessage = l('You have %{0} logins remaining before your account is locked. Please change your password in the preference dialog.', msg.grace);
          }
          else if (msg.expire > 0) {
            // Password will soon expire
            var value, string;
            if (msg.expire > 86400) {
              value = Math.round(msg.expire / 86400);
              string = l("days");
            }
            else if (msg.expire > 3600) {
              value = Math.round(msg.expire / 3600);
              string = l("hours");
            }
            else if (msg.expire > 60) {
              value = Math.round(msg.expire / 60);
              string = l("minutes");
            }
            else {
              value = msg.expire;
              string = l("seconds");
            }
            vm.loginState = 'passwordwillexpire';
            vm.cn = msg.cn;
            vm.url = msg.url;
            vm.errorMessage = l('Your password is going to expire in %{0} %{1}.', value, string);
          }
          else if (msg.passwordexpired && msg.passwordexpired == 2) {
            vm.loginState = 'passwordchange';
            vm.passwordPolicy = msg.userPolicies ? msg.userPolicies : [];
            vm.url = msg.url;
            vm.passwordexpired = msg.passwordexpired;
          } else if (msg.passwordexpired) {
            vm.loginState = 'passwordchange';
            vm.passwordPolicy = msg.userPolicies ? msg.userPolicies : [];
            vm.url = msg.url;
            vm.passwordexpired = msg.passwordexpired;
          }

        });
      return false;
    };

    this.restoreLogin = function () {
      if ('SecretQuestion' === vm.passwordRecovery.passwordRecoveryMode) {
        rippleDo('loginContent');
        vm.passwordRecoveryAbort();
      } else {
        delete vm.creds.verificationCode;
        vm.passwordRecoveryAbort();
      }
    };

    this.continueLogin = function () {
      if ($window.location.href === vm.url)
        $window.location.reload(true);
      else
        $window.location.href = vm.url;
    };

    this.showAbout = function ($event) {
      $mdDialog.show({
        targetEvent: $event,
        templateUrl: 'aboutBox.html',
        controller: AboutDialogController,
        controllerAs: 'about'
      });
      AboutDialogController.$inject = ['$mdDialog'];
      function AboutDialogController($mdDialog) {
        this.closeDialog = function () {
          $mdDialog.hide();
        };
      }
    };

    this.changeLanguage = function ($event) {
      // Reload page
      $window.location.href = ApplicationBaseURL + 'changeLanguage?language=' + this.creds.language;
    };

    this.canChangePassword = function (form) {
      if (this.passwords.newPasswordConfirmation && this.passwords.newPasswordConfirmation.length &&
        this.passwords.newPassword != this.passwords.newPasswordConfirmation) {
        form.newPasswordConfirmation.$setValidity('newPasswordMismatch', false);
        return false;
      }
      else {
        form.newPasswordConfirmation.$setValidity('newPasswordMismatch', true);
      }
      if (this.passwords.newPassword && this.passwords.newPassword.length > 0 &&
        this.passwords.newPasswordConfirmation && this.passwords.newPasswordConfirmation.length &&
        this.passwords.newPassword == this.passwords.newPasswordConfirmation &&
        ((this.isInPasswordRecoveryMode()) ||
          (!this.loginState && this.passwords.oldPassword && this.passwords.oldPassword.length > 0) ||
          ('passwordchange' == this.loginState && this.passwords.oldPassword && this.passwords.oldPassword.length > 0)
        ))
        return true;

      return false;
    };

    this.changePassword = function () {
      Authentication.changePassword(this.creds.username, this.creds.domain, this.passwords.newPassword, this.passwords.oldPassword, this.passwordRecovery.passwordRecoveryToken).then(function (data) {
        vm.loginState = 'message';
        vm.url = data.url;
        vm.errorMessage = l('The password was changed successfully.');
      }, function (msg) {
        $mdToast.show(
          $mdToast.simple()
            .textContent(msg)
            .position(sgConstant.toastPosition)
            .hideDelay(2000)
        );
      });
    };

    this.passwordRecoveryInfo = function () {
      vm.loginState = 'passwordrecovery';
      vm.passwordRecovery.showLoader = true;
      Authentication.passwordRecovery(this.creds.username, this.creds.domain).then(function (data) {
        vm.passwordRecovery.passwordRecoveryMode = data.mode;
        if ('SecretQuestion' === data.mode) {
          vm.passwordRecovery.passwordRecoveryQuestion = data.secretQuestionLabel;
          vm.passwordRecovery.passwordRecoveryQuestionKey = data.secretQuestion;
        } else if ('SecondaryEmail' === data.mode) {
          vm.passwordRecovery.passwordRecoverySecondaryEmailText = l("A link will be sent to %{0}", data.obfuscatedRecoveryEmail);
        } else if ('Disabled' === data.mode) {
          vm.loginState = 'error';
          vm.errorMessage = l('No password recovery method has been defined for this user');
        }
        vm.passwordRecovery.showLoader = false;
      }, function (msg) {
        vm.loginState = 'error';
        vm.errorMessage = msg;
        vm.passwordRecovery.showLoader = false;
      });
    };

    this.passwordRecoveryEmail = function () {
      vm.passwordRecovery.showLoader = true;
      Authentication.passwordRecoveryEmail(this.creds.username, this.creds.domain
        , this.passwordRecovery.passwordRecoveryMode
        , this.passwordRecovery.passwordRecoveryMailDomain).then(function () {
          vm.loginState = 'sendrecoverymail';
          vm.passwordRecovery.showLoader = false;
        }, function (msg) {
          vm.loginState = 'error';
          vm.errorMessage = msg;
          vm.passwordRecovery.showLoader = false;
        });
    };

    this.passwordRecoveryCheck = function () {
      vm.passwordRecovery.showLoader = true;
      Authentication.passwordRecoveryCheck(this.creds.username, this.creds.domain
        , this.passwordRecovery.passwordRecoveryMode
        , this.passwordRecovery.passwordRecoveryQuestionKey
        , this.passwordRecovery.passwordRecoveryQuestionAnswer
        , this.passwordRecovery.passwordRecoveryMailDomain).then(function (token) {
          if ("SecretQuestion" == vm.passwordRecovery.passwordRecoveryMode) {
            vm.passwordRecovery.passwordRecoveryToken = token;
            vm.loginState = 'passwordchange';
          } else if ("SecondaryEmail" == vm.passwordRecovery.passwordRecoveryMode) {
            vm.loginState = 'sendrecoverymail';
          }
          vm.passwordRecovery.showLoader = false;
        }, function (msg) {
          vm.loginState = 'error';
          vm.errorMessage = msg;
          vm.passwordRecovery.showLoader = false;
        });
    };

    this.isPasswordExpiredSecurity = function () {
      return (this.passwordexpired && 2 === this.passwordexpired);
    };

    this.isInPasswordRecoveryMode = function () {
      return (("SecretQuestion" == this.passwordRecovery.passwordRecoveryMode) ||
        ("SecondaryEmail" == this.passwordRecovery.passwordRecoveryMode &&
        this.passwordRecovery.passwordRecoveryToken)) ? true : false;
    };

    this.passwordRecoveryAbort = function () {
      this.passwords = { newPassword: null, newPasswordConfirmation: null, oldPassword: null };
      this.loginState = false;
      this.passwordRecovery.passwordRecoveryEnabled = false;
      this.passwordRecovery.passwordRecoveryQuestion = null;
      this.passwordRecovery.passwordRecoveryMode = null;
      this.passwordRecovery.passwordRecoveryQuestionAnswer = null;
      this.passwordRecovery.passwordRecoveryToken = null;
      this.passwordRecovery.passwordRecoverySecondaryEmailText = null;
      this.passwordRecovery.passwordRecoveryMailDomain = null;
      this.passwordRecovery.showLoader = false;
      $window.location.reload(true);
    };

    this.usernameChanged = function () {
      if (this.passwordRecovery.passwordRecoveryLinkTimer) {
        clearTimeout(this.passwordRecovery.passwordRecoveryLinkTimer);
      }

      this.passwordRecovery.passwordRecoveryLinkTimer = setTimeout(() => {
        vm.retrievePasswordRecoveryEnabled();
        this.passwordRecovery.passwordRecoveryLinkTimer = null;
      }, PASSWORD_RECOVERY_TIMER_MS);
    };

    this.retrievePasswordRecoveryEnabled = function () {
      if (this.creds.username || this.creds.domain) {
        Authentication.passwordRecoveryEnabled(this.creds.username, this.creds.domain).then(function (mailDomain) {
          vm.passwordRecovery.passwordRecoveryMailDomain = mailDomain;
          vm.passwordRecovery.passwordRecoveryEnabled = true;
        }, function () {
          vm.passwordRecovery.passwordRecoveryEnabled = false;
        });
      }
    };

    this.changePasswordVisibility = function () {
      this.passwords.visible = !this.passwords.visible;
      var field = document.getElementById("passwordField");
      if (this.passwords.visible) {
        field.type = "text";
        document.getElementById("password-visibility-icon").innerHTML = 'visibility_off';
      } else {
        field.type = "password";
        document.getElementById("password-visibility-icon").innerHTML = 'visibility';
      }
    }
  }

  angular
    .module('SOGo.MainUI')
    .controller('LoginController', LoginController);
})();
