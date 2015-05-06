/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AccountDialogController.$inject = ['$scope', '$mdDialog', 'account', 'accountId', 'mailCustomFromEnabled'];
  function AccountDialogController($scope, $mdDialog, account, accountId, mailCustomFromEnabled) {
    $scope.account = account;
    $scope.accountId = accountId;
    $scope.customFromIsReadonly = function() {
      if (accountId > 0)
        return false;

      return !mailCustomFromEnabled;
    };
    $scope.cancel = function() {
      $mdDialog.cancel();
    };
    $scope.save = function() {
      $mdDialog.hide();
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('AccountDialogController', AccountDialogController);

})();
