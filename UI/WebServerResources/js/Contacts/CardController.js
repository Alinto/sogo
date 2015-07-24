/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Controller to view and edit a card
   * @ngInject
   */
  CardController.$inject = ['$scope', '$timeout', 'AddressBook', 'Card', 'Dialog', 'sgFocus', '$state', '$stateParams', 'stateCard'];
  function CardController($scope, $timeout, AddressBook, Card, Dialog, focus, $state, $stateParams, stateCard) {
    var vm = this;

    vm.card = stateCard;

    vm.currentFolder = AddressBook.selectedFolder;
    vm.allEmailTypes = Card.$EMAIL_TYPES;
    vm.allTelTypes = Card.$TEL_TYPES;
    vm.allUrlTypes = Card.$URL_TYPES;
    vm.allAddressTypes = Card.$ADDRESS_TYPES;
    vm.categories = {};
    vm.userFilterResults = [];
    vm.addOrgUnit = addOrgUnit;
    vm.addEmail = addEmail;
    vm.addPhone = addPhone;
    vm.addUrl = addUrl;
    vm.addAddress = addAddress;
    vm.addMember = addMember;
    vm.userFilter = userFilter;
    vm.save = save;
    vm.reset = reset;
    vm.cancel = cancel;
    vm.confirmDelete = confirmDelete;

    function addOrgUnit() {
      var i = vm.card.$addOrgUnit('');
      focus('orgUnit_' + i);
    }
    function addEmail() {
      var i = vm.card.$addEmail('');
      focus('email_' + i);
    }
    function addPhone() {
      var i = vm.card.$addPhone('');
      focus('phone_' + i);
    }
    function addUrl() {
      var i = vm.card.$addUrl('', '');
      focus('url_' + i);
    }
    function addAddress() {
      var i = vm.card.$addAddress('', '', '', '', '', '', '', '');
      focus('address_' + i);
    }
    function addMember() {
      var i = vm.card.$addMember('');
      focus('ref_' + i);
    }
    function userFilter($query, excludedCards) {
      AddressBook.selectedFolder.$filter($query, {dry: true, excludeLists: true}, excludedCards);
      return AddressBook.selectedFolder.$cards;
    }
    function save(form) {
      if (form.$valid) {
        vm.card.$save()
          .then(function(data) {
            var i = _.indexOf(_.pluck(AddressBook.selectedFolder.cards, 'id'), vm.card.id);
            if (i < 0) {
              // New card; reload contacts list and show addressbook in which the card has been created
              AddressBook.selectedFolder.$reload();
            }
            else {
              // Update contacts list with new version of the Card object
              AddressBook.selectedFolder.cards[i] = angular.copy(vm.card);
            }
            $state.go('app.addressbook.card.view', { cardId: vm.card.id });
          })
          .catch(function(err) {
            console.log(err);
          });
      }
    }
    function reset() {
      vm.card.$reset();
    }
    function cancel() {
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
    }
    function confirmDelete(card) {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the card of %{0}?', card.$fullname()))
        .then(function() {
          // User confirmed the deletion
          card.$delete()
            .then(function() {
              // Remove card from list of addressbook
              AddressBook.selectedFolder.cards = _.reject(AddressBook.selectedFolder.cards, function(o) {
                return o.id == card.id;
              });
              // Remove card object from scope
              vm.card = null;
              $state.go('app.addressbook', { addressbookId: AddressBook.selectedFolder.id });
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                           card.$fullname()));
            });
        });
    }
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('CardController', CardController);
})();
