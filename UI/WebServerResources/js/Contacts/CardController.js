/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Controller to view and edit a card
   * @ngInject
   */
  CardController.$inject = ['$scope', '$timeout', '$window', '$mdDialog', 'sgSettings', 'AddressBook', 'Card', 'Dialog', 'sgHotkeys', 'sgFocus', '$state', '$stateParams', 'stateCard'];
  function CardController($scope, $timeout, $window, $mdDialog, sgSettings, AddressBook, Card, Dialog, sgHotkeys, focus, $state, $stateParams, stateCard) {
    var vm = this, hotkeys = [];

    vm.card = stateCard;

    vm.currentFolder = AddressBook.selectedFolder;
    vm.allEmailTypes = Card.$EMAIL_TYPES;
    vm.allTelTypes = Card.$TEL_TYPES;
    vm.allUrlTypes = Card.$URL_TYPES;
    vm.allAddressTypes = Card.$ADDRESS_TYPES;
    vm.categories = {};
    vm.userFilterResults = [];
    vm.showRawSource = false;


    _registerHotkeys(hotkeys);
    _loadCertificate();

    $scope.$on('$destroy', function() {
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


    function _registerHotkeys(keys) {
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          description: l('Delete'),
          callback: function($event) {
            if (vm.currentFolder.acls.objectEraser && vm.currentFolder.$selectedCount() === 0)
              vm.confirmDelete();
            $event.preventDefault();
          }
        }));
      });

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function _loadCertificate() {
      if (vm.card.hasCertificate)
        vm.card.$certificate().then(function(crt) {
          vm.certificate = crt;
        }, function() {
          delete vm.card.hasCertificate;
        });
    }

    this.transformCategory = function (input) {
      if (angular.isString(input))
        return { value: input };
      else
        return input;
    };

    this.removeAttribute = function (form, attribute, index) {
      this.card.$delete(attribute, index);
      form.$setDirty();
    };

    this.addOrg = function () {
      var i = this.card.$addOrg({ value: '' });
      focus('org_' + i);
    };

    this.addBirthday = function () {
      this.card.birthday = new Date();
    };

    this.addScreenName = function () {
      this.card.$addScreenName('');
    };

    this.addEmail = function () {
      var i = this.card.$addEmail('');
      focus('email_' + i);
    };

    this.addPhone = function () {
      var i = this.card.$addPhone('');
      focus('phone_' + i);
    };

    this.addUrl = function () {
      var i = this.card.$addUrl('', 'https://www.fsf.org/');
      focus('url_' + i);
    };

    this.canAddCustomField = function () {
      return _.keys(this.card.customFields).length < 4;
    };

    this.addCustomField = function () {
      if (!angular.isDefined(this.card.customFields))
        this.card.customFields = {};

      // Find the first 'available' custom field
      var availableKeys = _.pullAll(['1', '2', '3', '4'], _.keys(this.card.customFields));
      this.card.customFields[availableKeys[0]] = "";
    };

    this.deleteCustomField = function (key) {
      delete this.card.customFields[key];
    };

    this.addAddress = function () {
      var i = this.card.$addAddress('', '', '', '', '', '', '', '');
      focus('address_' + i);
    };

    this.userFilter = function ($query, excludedCards) {
      if ($query.length < sgSettings.minimumSearchLength())
        return [];

      return AddressBook.selectedFolder.$filter($query, {dry: true, excludeLists: true}, excludedCards).then(function(cards) {
        return cards;
      });
    };

    this.save = function (form, options) {
      if (form.$valid) {
        this.card.$save(options)
          .then(function(data) {
            var i = _.indexOf(_.map(AddressBook.selectedFolder.$cards, 'id'), vm.card.id);
            if (i < 0) {
              // New card; reload contacts list and show addressbook in which the card has been created
              AddressBook.selectedFolder.$reload();
            }
            else {
              // Update contacts list with new version of the Card object
              AddressBook.selectedFolder.$cards[i] = angular.copy(vm.card);
            }
            $state.go('app.addressbook.card.view', { cardId: vm.card.id });
          }, function(response) {
            vm.duplicatedCard = new Card(response.data);
          });
      }
    };

    this.close = function () {
      $state.go('app.addressbook').then(function() {
        vm.card = null;
        delete AddressBook.selectedFolder.selectedCard;
      });
    };

    this.edit = function (form) {
      this.duplicatedCard = false;
      form.$setPristine();
      form.$setDirty();
    };

    this.reset = function (form) {
      vm.card.$reset();
      form.$setPristine();
    };

    this.cancel = function () {
      vm.card.$reset();
      if (vm.card.isNew) {
        // Cancelling the creation of a card
        vm.card = null;
        delete AddressBook.selectedFolder.selectedCard;
        $state.go('app.addressbook', { addressbookId: AddressBook.selectedFolder.id });
      }
      else {
        // Cancelling the edition of an existing card
        $state.go('app.addressbook.card.view', { cardId: vm.card.id });
      }
    };

    this.confirmDelete = function () {
      var card = stateCard;

      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the card of %{0}?', '<b>' + card.$fullname() + '</b>'),
                     { ok: l('Delete') })
        .then(function() {
          // User confirmed the deletion
          AddressBook.selectedFolder.$deleteCards([card])
            .then(function() {
              close();
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                           card.$fullname()));
            });
        });
    };

    this.toggleRawSource = function ($event) {
      if (!this.showRawSource && !this.rawSource) {
        Card.$$resource.post(this.currentFolder.id + '/' + this.card.id, "raw").then(function(data) {
          vm.rawSource = data;
          vm.showRawSource = true;
        });
      }
      else {
        this.showRawSource = !this.showRawSource;
      }
    };
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('CardController', CardController);
})();
