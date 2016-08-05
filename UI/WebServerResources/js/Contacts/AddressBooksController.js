/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBooksController.$inject = ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$window', '$mdDialog', '$mdToast', '$mdMedia', '$mdSidenav', 'FileUploader', 'sgConstant', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'User', 'stateAddressbooks'];
  function AddressBooksController($state, $scope, $rootScope, $stateParams, $timeout, $window, $mdDialog, $mdToast, $mdMedia, $mdSidenav, FileUploader, sgConstant, focus, Card, AddressBook, Dialog, Settings, User, stateAddressbooks) {
    var vm = this;

    vm.activeUser = Settings.activeUser;
    vm.service = AddressBook;
    vm.select = select;
    vm.newAddressbook = newAddressbook;
    vm.edit = edit;
    vm.revertEditing = revertEditing;
    vm.save = save;
    vm.confirmDelete = confirmDelete;
    vm.importCards = importCards;
    vm.showLinks = showLinks;
    vm.showProperties = showProperties;
    vm.share = share;
    vm.subscribeToFolder = subscribeToFolder;
    vm.isDroppableFolder = isDroppableFolder;
    vm.dragSelectedCards = dragSelectedCards;

    function select($event, folder) {
      if ($state.params.addressbookId != folder.id &&
          vm.editMode != folder.id) {
        vm.editMode = false;
        AddressBook.$query.value = '';
        // Close sidenav on small devices
        if (!$mdMedia(sgConstant['gt-md']))
          $mdSidenav('left').close();
        $state.go('app.addressbook', {addressbookId: folder.id});
      }
      else {
        $event.preventDefault();
        $event.stopPropagation();
      }
    }

    function newAddressbook() {
      Dialog.prompt(l('New addressbook'),
                    l('Name of new addressbook'))
        .then(function(name) {
          var addressbook = new AddressBook(
            {
              name: name,
              isEditable: true,
              isRemote: false,
              owner: UserLogin
            }
          );
          AddressBook.$add(addressbook);
        });
    }

    function edit(folder) {
      if (!folder.isRemote) {
        vm.editMode = folder.id;
        vm.originalAddressbook = angular.extend({}, folder.$omit());
        focus('addressBookName_' + folder.id);
      }
    }

    function revertEditing(folder) {
      folder.name = vm.originalAddressbook.name;
      vm.editMode = false;
    }

    function save(folder) {
      var name = folder.name;
      if (name && name.length > 0 && name != vm.originalAddressbook.name) {
        folder.$rename(name)
          .then(function(data) {
            vm.editMode = false;
          }, function(data, status) {
            Dialog.alert(l('Warning'), data);
          });
      }
    }

    function confirmDelete() {
      if (vm.service.selectedFolder.isSubscription) {
        // Unsubscribe without confirmation
        vm.service.selectedFolder.$delete()
          .then(function() {
            vm.service.selectedFolder = null;
            $state.go('app.addressbook', { addressbookId: 'personal' });
          }, function(data, status) {
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           vm.service.selectedFolder.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook "%{0}"?',
                                       vm.service.selectedFolder.name),
                       { ok: l('Delete') })
          .then(function() {
            return vm.service.selectedFolder.$delete();
          })
          .then(function() {
            vm.service.selectedFolder = null;
            $state.go('app.addressbook', { addressbookId: 'personal' });
            return true;
          })
          .catch(function(response) {
            var message = response.data.message || response.statusText;
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           vm.service.selectedFolder.name),
                        message);
          });
      }
    }

    function importCards($event, folder) {
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: $event,
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: 'UIxContactsImportDialog',
        controller: CardsImportDialogController,
        controllerAs: '$CardsImportDialogController',
        locals: {
          folder: folder
        }
      });

      /**
       * @ngInject
       */
      CardsImportDialogController.$inject = ['scope', '$mdDialog', 'folder'];
      function CardsImportDialogController(scope, $mdDialog, folder) {
        var vm = this;

        vm.uploader = new FileUploader({
          url: ApplicationBaseURL + [folder.id, 'import'].join('/'),
          autoUpload: true,
          queueLimit: 1,
          filters: [{ name: filterByExtension, fn: filterByExtension }],
          onSuccessItem: function(item, response, status, headers) {
            var msg;

            $mdDialog.hide();

            if (response.imported === 0)
              msg = l('No card was imported.');
            else {
              msg = l('A total of %{0} cards were imported in the addressbook.', response.imported);
              AddressBook.selectedFolder.$reload();
            }

            $mdToast.show(
              $mdToast.simple()
                .content(msg)
                .position('top right')
                .hideDelay(3000));
          },
          onErrorItem: function(item, response, status, headers) {
            $mdToast.show({
              template: [
                '<md-toast>',
                '  <div class="md-toast-content">',
                '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
                '    <span>' + l('An error occured while importing contacts.') + '</span>',
                '  </div>',
                '</md-toast>'
              ].join(''),
              position: 'top right',
              hideDelay: 3000
            });
          }
        });

        vm.close = function() {
          $mdDialog.hide();
        };

        function filterByExtension(item) {
          var isTextFile = item.type.indexOf('text') === 0 ||
              /\.(ldif|vcf|vcard)$/.test(item.name);

          if (!isTextFile)
            $mdToast.show({
              template: [
                '<md-toast>',
                '  <div class="md-toast-content">',
                '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
                '    <span>' + l('Select a vCard or LDIF file.') + '</span>',
                '  </div>',
                '</md-toast>'
              ].join(''),
              position: 'top right',
              hideDelay: 3000
            });

          return isTextFile;
        }
      }
    }

    function showLinks(addressbook) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: addressbook.id + '/links',
        controller: LinksDialogController,
        controllerAs: 'links',
        locals: {
          addressbook: addressbook
        }
      });

      /**
       * @ngInject
       */
      LinksDialogController.$inject = ['$mdDialog', 'addressbook'];
      function LinksDialogController($mdDialog, addressbook) {
        var vm = this;
        this.addressbook = addressbook;
        this.close = close;

        function close() {
          $mdDialog.hide();
        }
      }
    }

    function showProperties(addressbook) {
      $mdDialog.show({
        templateUrl: addressbook.id + '/properties',
        controller: PropertiesDialogController,
        controllerAs: 'properties',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          srcAddressBook: addressbook
        }
      }).catch(function() {
        // Do nothing
      });

      /**
       * @ngInject
       */
      PropertiesDialogController.$inject = ['$scope', '$mdDialog', 'srcAddressBook'];
      function PropertiesDialogController($scope, $mdDialog, srcAddressBook) {
        var vm = this;

        vm.addressbook = new AddressBook(srcAddressBook.$omit());
        vm.saveProperties = saveProperties;
        vm.close = close;

        function saveProperties() {
          vm.addressbook.$save().then(function() {
            // Refresh list instance
            srcAddressBook.init(vm.addressbook.$omit());
            $mdDialog.hide();
          });
        }

        function close() {
          $mdDialog.cancel();
        }
      }
    }

    function share(addressbook) {
      // Fetch list of ACL users
      addressbook.$acl.$users().then(function() {
        // Show ACL editor
        $mdDialog.show({
          templateUrl: addressbook.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: 'AclController', // from the ng module SOGo.Common
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: addressbook.$acl.users,
            User: User,
            folder: addressbook
          }
        });
      });
    }

    /**
     * subscribeToFolder - Callback of sgSubscribe directive
     */
    function subscribeToFolder(addressbookData) {
      console.debug('subscribeToFolder ' + addressbookData.owner + addressbookData.name);
      AddressBook.$subscribe(addressbookData.owner, addressbookData.name).then(function(data) {
         $mdToast.show(
           $mdToast.simple()
             .content(l('Successfully subscribed to address book'))
             .position('top right')
             .hideDelay(3000));
      });
    }

    function isDroppableFolder(srcFolder, dstFolder) {
      return (dstFolder.id != srcFolder.id) && (dstFolder.isOwned || dstFolder.acls.objectCreator);
    }

    /**
     * @see AddressBookController._selectedCardsOperation
     */
    function dragSelectedCards(srcFolder, dstFolder, mode) {
      var dstId, cards, ids, clearCardView, promise, success;

      dstId = dstFolder.id;
      clearCardView = false;
      cards = srcFolder.$selectedCards();
      if (cards.length === 0)
        cards = [srcFolder.$selectedCard()];

      if (_.find(cards, function(card) {
        return card.$isList();
      })) {
        $mdToast.show(
          $mdToast.simple()
            .content(l("Lists can't be moved or copied."))
            .position('top right')
            .hideDelay(2000));
        return;
      }

      if (mode == 'copy') {
        promise = srcFolder.$copyCards(cards, dstId);
        success = l('%{0} card(s) copied', cards.length);
      }
      else {
        promise = srcFolder.$moveCards(cards, dstId);
        success = l('%{0} card(s) moved', cards.length);
        // Check if currently displayed card will be moved
        ids = _.map(cards, 'id');
        clearCardView = (srcFolder.selectedCard && ids.indexOf(srcFolder.selectedCard) >= 0);
      }

      // Show success toast when action succeeds
      promise.then(function() {
        if (clearCardView)
          $state.go('app.addressbook');
        $mdToast.show(
          $mdToast.simple()
            .content(success)
            .position('top right')
            .hideDelay(2000));
      });
    }

  }

  angular
    .module('SOGo.ContactsUI')
    .controller('AddressBooksController', AddressBooksController);
})();
