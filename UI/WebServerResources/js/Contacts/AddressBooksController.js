/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBooksController.$inject = ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$mdDialog', '$mdToast', 'FileUploader', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'User', 'stateAddressbooks'];
  function AddressBooksController($state, $scope, $rootScope, $stateParams, $timeout, $mdDialog, $mdToast, FileUploader, focus, Card, AddressBook, Dialog, Settings, User, stateAddressbooks) {
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
    vm.exportCards = exportCards;
    vm.showLinks = showLinks;
    vm.showProperties = showProperties;
    vm.share = share;
    vm.subscribeToFolder = subscribeToFolder;

    function select($event, folder) {
      if ($state.params.addressbookId != folder.id &&
          vm.editMode != folder.id) {
        vm.editMode = false;
        AddressBook.$query.value = '';
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
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                       vm.service.selectedFolder.name))
          .then(function() {
            return vm.service.selectedFolder.$delete();
          })
          .then(function() {
            vm.service.selectedFolder = null;
            return true;
          })
          .catch(function(data, status) {
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           vm.service.selectedFolder.name),
                         l(data.error));
          });
      }
    }

    function importCards($event, folder) {
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: $event,
        clickOutsideToClose: true,
        escapeToClose: true,
        template: [
          '<md-dialog flex="40" flex-sm="100" aria-label="' + l('Import Cards') + '">',
          '  <md-toolbar class="sg-padded">',
          '    <div class="md-toolbar-tools">',
          '      <md-icon class="material-icons sg-icon-toolbar-bg">import_export</md-icon>',
          '      <div class="md-flex">',
          '        <div class="sg-md-title">' + l('Import Cards') + '</div>',
          '      </div>',
          '      <md-button class="md-icon-button" ng-click="close()">',
          '        <md-icon aria-label="Close dialog">close</md-icon>',
          '      </md-button>',
          '    </div>',
          '  </md-toolbar>',
          '  <md-dialog-content class="md-dialog-content">',
          '    <div layout="column">',
          '      <div layout="row" layout-align="start center">',
          '        <span>' + l('Select a vCard or LDIF file.') + '</span>',
          '        <label class="md-button" for="file-input">',
          '          <span>' + l('Choose File') + '</span>',
          '        </label>',
          '        <input id="file-input" type="file" nv-file-select="nv-file-select" uploader="uploader" ng-show="false"/>',
          '      </div>',
          '      <span ng-show="uploader.queue.length == 0">' + l('No file chosen') + '</span>',
          '      <span ng-show="uploader.queue.length > 0">{{ uploader.queue[0].file.name }}</span>',
          '    </div>',
          '  </md-dialog-content>',
          '  <div class="md-actions">',
          '    <md-button ng-disabled="uploader.queue.length == 0" ng-click="upload()">' + l('Upload') + '</md-button>',
          '  </div>',
          '</md-dialog>'
        ].join(''),
        controller: CardsImportDialogController,
        locals: {
          folder: folder
        }
      });

      /**
       * @ngInject
       */
      CardsImportDialogController.$inject = ['scope', '$mdDialog', 'folder'];
      function CardsImportDialogController(scope, $mdDialog, folder) {

        scope.uploader = new FileUploader({
          url: ApplicationBaseURL + '/' + folder.id + '/import',
          onProgressItem: function(item, progress) {
            console.debug(item); console.debug(progress);
          },
          onSuccessItem: function(item, response, status, headers) {
            console.debug(item); console.debug('success = ' + JSON.stringify(response, undefined, 2));
            $mdDialog.hide();
            $mdToast.show(
              $mdToast.simple()
                .content(l('A total of %{0} cards were imported in the addressbook.', response.imported))
                .position('top right')
                .hideDelay(3000));
            AddressBook.selectedFolder.$reload();
          },
          onCancelItem: function(item, response, status, headers) {
            console.debug(item); console.debug('cancel = ' + JSON.stringify(response, undefined, 2));
          },
          onErrorItem: function(item, response, status, headers) {
            console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
          }
        });

        scope.close = function() {
          $mdDialog.hide();
        };
        scope.upload = function() {
          scope.uploader.uploadAll();
        };
      }
    }

    function exportCards() {
      window.location.href = ApplicationBaseURL + '/' + vm.service.selectedFolder.id + '/exportFolder';
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
          vm.addressbook.$save();
          // Refresh list instance
          srcAddressBook.init(vm.addressbook.$omit());
          $mdDialog.hide();
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
      AddressBook.$subscribe(addressbookData.owner, addressbookData.name).catch(function(data) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('AddressBooksController', AddressBooksController);
})();
