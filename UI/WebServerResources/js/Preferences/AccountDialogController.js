/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AccountDialogController.$inject = ['$timeout', '$mdDialog', 'FileUploader', 'Dialog', 'sgSettings', 'Account', 'defaults', 'account', 'accountId', 'mailCustomFromEnabled'];
  function AccountDialogController($timeout, $mdDialog, FileUploader, Dialog, Settings, Account, defaults, account, accountId, mailCustomFromEnabled) {
    var vm = this,
        accountObject = new Account({ id: accountId, security: account.security });

    vm.defaultPort = 143;
    vm.defaults = defaults;
    vm.account = account;
    vm.accountId = accountId;
    vm.customFromIsReadonly = customFromIsReadonly;
    vm.onBeforeUploadCertificate = onBeforeUploadCertificate;
    vm.removeCertificate = removeCertificate;
    vm.importCertificate = importCertificate;
    vm.cancel = cancel;
    vm.save = save;
    vm.hostnameRE = accountId > 0 ? /^(?!(127\.0\.0\.1|localhost(?:\.localdomain)?)$)/ : /./;

    if (!vm.account.encryption)
      vm.account.encryption = "none";
    else if (vm.account.encryption == "ssl")
      vm.defaultPort = 993;

    _loadCertificate();

    vm.uploader = new FileUploader({
      url: [Settings.activeUser('folderURL') + 'Mail', accountId, 'importCertificate'].join('/'),
      autoUpload: false,
      queueLimit: 1,
      filters: [{ name: filterByExtension, fn: filterByExtension }],
      onAfterAddingFile: function(item) {
        vm.certificateFilename = item.file.name;
      },
      onSuccessItem: function(item, response, status, headers) {
        this.clearQueue();
        $timeout(function() {
          _.assign(vm.account, {security: {hasCertificate: true}});
        });
        _loadCertificate();
      },
      onErrorItem: function(item, response, status, headers) {
        Dialog.alert(l('Error'), l('An error occurred while importing the certificate. Verify your password.'));
      }
    });

    function _loadCertificate() {
      if (vm.account.security && vm.account.security.hasCertificate)
        accountObject.$certificate().then(function(crt) {
          vm.certificate = crt;
        }, function() {
          delete vm.account.security.hasCertificate;
        });
    }

    function filterByExtension(item) {
      var isP12File = item.type.indexOf('pkcs12') > 0 || /\.(p12|pfx)$/.test(item.name);
      vm.form.certificateFilename.$setValidity('fileformat', isP12File);
      return isP12File;
    }

    function customFromIsReadonly() {
      if (accountId > 0)
        return false;
      return !mailCustomFromEnabled;
    }

    function importCertificate() {
      vm.uploader.queue[0].formData = [{ password: vm.certificatePassword }];
      vm.uploader.uploadItem(0);
    }

    function onBeforeUploadCertificate(form) {
      vm.form = form;
      vm.uploader.clearQueue();
    }

    function removeCertificate() {
      accountObject.$removeCertificate().then(function() {
        delete vm.account.security.hasCertificate;
      });
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
