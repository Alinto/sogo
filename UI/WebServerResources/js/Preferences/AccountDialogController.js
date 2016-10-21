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

    vm.defaultPort = 143;
    vm.defaults = defaults;
    vm.account = account;
    vm.accountId = accountId;
    vm.customFromIsReadonly = customFromIsReadonly;
    vm.cancel = cancel;
    vm.save = save;

    if (!vm.account.encryption)
      vm.account.encryption = "none";
    else if (vm.account.encryption == "ssl")
      vm.defaultPort = 993;

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
