/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AccountDialogController.$inject = ['$mdDialog', 'defaults', 'account', 'accountId', 'mailCustomFromEnabled'];
  function AccountDialogController($mdDialog, defaults, account, accountId, mailCustomFromEnabled) {
    var vm = this;

    vm.defaults = defaults;
    vm.account = account;
    vm.accountId = accountId;
    vm.customFromIsReadonly = customFromIsReadonly;
    vm.cancel = cancel;
    vm.save = save;

    function customFromIsReadonly() {
      if (accountId > 0)
        return false;

      return !mailCustomFromEnabled;
    }

    function cancel() {
      $mdDialog.cancel();
    }

    function save() {
      $mdDialog.hide();
    }
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('AccountDialogController', AccountDialogController);

})();
