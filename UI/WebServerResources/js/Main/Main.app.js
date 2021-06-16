/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for MainUI (SOGoRootPage) */

(function() {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Common', 'SOGo.Authentication']);

  /**
   * @ngInject
   */
  LoginController.$inject = ['$scope', '$window', '$timeout', 'Dialog', '$mdDialog', 'Authentication'];
  function LoginController($scope, $window, $timeout, Dialog, $mdDialog, Authentication) {
    var vm = this;

    this.$onInit = function() {
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
      this.passwords = { newPassword: null, newPasswordConfirmation: null, oldPassword: null };

      // Show login once everything is initialized
      this.showLogin = false;
      $timeout(function() { vm.showLogin = true; }, 100);
    };

    this.login = function() {
      vm.loginState = 'authenticating';
      Authentication.login(vm.creds)
        .then(function(data) {

          if (data.totpmissingkey) {
            vm.loginState = 'totpcode';
          }
          else {
            vm.loginState = 'logged';
            vm.cn = data.cn;
            vm.url = data.url;

            // Let the user see the succesfull message before reloading the page
            $timeout(function() {
              vm.continueLogin();
            }, 1000);
          }
        }, function(msg) {
          vm.loginState = 'error';

          if (msg.error) {
            vm.errorMessage = msg.error;
          }
          else if (msg.grace > 0) {
            // Password is expired, grace logins limit is not yet reached
            vm.loginState = 'passwordwillexpire';
            vm.cn = msg.cn;
            vm.url = msg.url;
            vm.errorMessage = l('You have %{0} logins remaining before your account is locked. Please change your password in the preference dialog.', msg.grace);
          }
          else if (msg.expire > 0) {
            // Password will soon expire
            var value, string;
            if (msg.expire > 86400) {
              value = Math.round(msg.expire/86400);
              string = l("days");
            }
            else if (msg.expire > 3600) {
              value = Math.round(msg.expire/3600);
              string = l("hours");
            }
            else if (msg.expire > 60) {
              value = Math.round(msg.expire/60);
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
          else if (msg.passwordexpired) {
            vm.loginState = 'passwordexpired';
            vm.url = msg.url;
          }

        });
      return false;
    };

    this.restoreLogin = function() {
      vm.loginState = false;
      delete vm.creds.verificationCode;
    };

    this.continueLogin = function() {
      if ($window.location.href === vm.url)
        $window.location.reload(true);
      else
        $window.location.href = vm.url;
    };

    this.showAbout = function($event) {
      $mdDialog.show({
        targetEvent: $event,
        templateUrl: 'aboutBox.html',
        controller: AboutDialogController,
        controllerAs: 'about'
      });
      AboutDialogController.$inject = ['$mdDialog'];
      function AboutDialogController($mdDialog) {
        this.closeDialog = function() {
          $mdDialog.hide();
        };
      }
    };

    this.changeLanguage = function($event) {
      // Reload page
      $window.location.href = ApplicationBaseURL + 'login?language=' + this.creds.language;
    };

    this.canChangePassword = function(form) {
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
          this.passwords.oldPassword && this.passwords.oldPassword.length > 0)
        return true;

      return false;
    };

    this.changePassword = function() {
      Authentication.changePassword(this.creds.username, this.creds.domain, this.passwords.newPassword, this.passwords.oldPassword).then(function(data) {
        vm.loginState = 'message';
        vm.url = data.url;
        vm.errorMessage = l('The password was changed successfully.');
      }, function(msg) {
        vm.loginState = 'error';
        vm.errorMessage = msg;
      });
    };

  }

  angular
    .module('SOGo.MainUI')
    .controller('LoginController', LoginController);
})();
