/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AccountDialogController.$inject = ['$timeout', '$window', '$mdDialog', 'FileUploader', 'Dialog', 'sgSettings', 'defaults', 'account', 'accountId', 'mailCustomFromEnabled', 'maxSize'];
  function AccountDialogController($timeout, $window, $mdDialog, FileUploader, Dialog, Settings, defaults, account, accountId, mailCustomFromEnabled, maxSize) {
    var vm = this, usesSSO = $window.usesCASAuthentication || $window.usesSAML2Authentication;

    this.defaultPort = 143;
    this.smtpDefaultPort = 25;
    this.defaults = defaults;
    this.account = account;
    this.maxSize = maxSize;
    this.accountId = accountId;
    this.hostnameRE = usesSSO && accountId > 0 ? /^(?!(127\.0\.0\.1|localhost(?:\.localdomain)?)$)/ : /./;
    this.emailRE = String.emailRE;
    this.addressesSearchText = '';
    this.ckConfig = {
      'autoGrow_minHeight': 70,
      toolbar: {
        "items": [
          "bold", "italic", "|",
          "fontColor", "fontFamily", "fontSize", "|",
          "link", "|",
          "specialCharacters", "imageUpload", "|",
          "sourceEditing"
        ],
        "shouldNotGroupWhenFull": true
      },
      language: defaults.ckLocaleCode
    };

    if (!this.account.encryption)
      this.account.encryption = "none";
    else if (this.account.encryption == "ssl")
      this.defaultPort = 993;

    if (!this.account.smtpEncryption)
      this.account.smtpEncryption = "none";
    else
      this.smtpDefaultPort = 465;

    _loadCertificate();

    this.uploader = new FileUploader({
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
          _.assign(vm.account, {security: {hasCertificate: true}, $$certificate: response});
        });
        _loadCertificate();
      },
      onErrorItem: function(item, response, status, headers) {
        Dialog.alert(l('Error'), l('An error occurred while importing the certificate. Verify your password.'));
      }
    });

    this.hasIdentities = function () {
      return _.filter(this.account.identities, this.isEditableIdentity).length > 0;
    };

    this.isEditableIdentity = function (identity) {
      return !identity.isReadOnly;
    };

    this.selectIdentity = function (index) {
      if (this.selectedIdentity == index) {
        this.selectedIdentity = null;
      } else {
        this.selectedIdentity = index;
      }
    };

    this.hasDefaultIdentity = function() {
      return _.findIndex(this.account.identities, function(identity) { return !!identity.isDefault; }) >= 0;
    };

    this.setDefaultIdentity = function ($event, $index) {
      _.forEach(this.account.identities, function(identity, i) {
        if (i == $index)
          identity.isDefault = !identity.isDefault;
        else
          delete identity.isDefault;
      });
      $event.stopPropagation();
      return false;
    };

    this.canRemoveIdentity = function (index) {
      return (index == this.selectedIdentity) && this.hasIdentities();
    };

    this.removeIdentity = function (index) {
      this.account.identities.splice(index, 1);
      this.selectedIdentity = null;
    };

    this.addIdentity = function () {
      var firstReadonlyIndex = _.findIndex(this.account.identities, { isReadOnly: 1 });
      var identity = {};

      if (firstReadonlyIndex < 0)
        firstReadonlyIndex = this.account.identities.length;
      if (this.customFromIsReadonly())
        identity.fullName = this.account.identities[0].fullName;
      this.account.identities.splice(Math.max(firstReadonlyIndex, 0), 0, identity);
      this.selectedIdentity = firstReadonlyIndex;
    };

    this.showCkEditor = function ($index) {
      return this.selectedIdentity == $index && this.defaults.SOGoMailComposeMessageType == 'html';
    };

    this.filterEmailAddresses = function ($query) {
      return _.filter($window.defaultEmailAddresses, function (address) {
        return address.toLowerCase().indexOf($query.toLowerCase()) >= 0;
      });
    };

    function _loadCertificate() {
      if (vm.account.security && vm.account.security.hasCertificate)
        vm.account.$certificate().then(function(crt) {
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

    this.customFromIsReadonly = function () {
      if (accountId > 0)
        return false;
      return !mailCustomFromEnabled;
    };

    this.importCertificate = function () {
      this.uploader.queue[0].formData = [{ password: this.certificatePassword }];
      this.uploader.uploadItem(0);
    };

    this.onBeforeUploadCertificate = function (form) {
      this.form = form;
      this.uploader.clearQueue();
    };

    this.removeCertificate = function () {
      this.account.$removeCertificate();
    };

    this.cancel = function () {
      $mdDialog.cancel();
    };

    this.save = function () {
      // Check if the size of the content os not too big. Otherwise it will fail while storing in database.
      // This usually happens when using image signature 
      var data = JSON.stringify(this.account);
      if (data.length > this.maxSize) {
        Dialog.alert(l('Error'), l('Data too big. Please contact technical support.'));
      } else {
        $mdDialog.hide();
      }
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('AccountDialogController', AccountDialogController);

})();
