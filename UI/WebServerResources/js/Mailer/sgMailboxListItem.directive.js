/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /**
   * sgMailboxListItem - A directive that defines the content of a md-list-item for a mailbox.
   * @memberof SOGo.MailerUI
  */
  function sgMailboxListItem() {
    return {
      restrict: 'C',
      require: {
        accountController: '^^sgAccountSection'
      },
      scope: {},
      bindToController: {
        mailbox: '=sgMailbox'
      },
      template: [
        '  <div class="sg-child-level-0"',
        '       ng-class="$ctrl.childLevel()">',
        '    <md-checkbox class="sg-folder"',
        '                 ng-class="$ctrl.mailbox.$icon"',
        '                 aria-label="' + l("Expanded") + '"',
        '                 ng-model="$ctrl.mailbox.$expanded"',
        '                 ng-disabled="$ctrl.mailbox.children.length == 0"',
        '                 ng-change="$ctrl.mailbox.$account.$flattenMailboxes({ reload: true, saveState: true })">',
        '    <md-icon>{{$ctrl.mailbox.$icon}}</md-icon></md-checkbox>',
        '  </div>',
        '  <p class="sg-item-name"',
        '    ng-click="$ctrl.selectFolder($event)"',
        '    ng-dblclick="$ctrl.editFolder($event)">',
        '    <span ng-bind="$ctrl.mailbox.$displayName"></span>',
        '    <span class="sg-counter-badge ng-hide"',
        '          ng-show="$ctrl.mailbox.unseenCount"',
        '          ng-bind="$ctrl.mailbox.unseenCount"></span>',
        '  </p>',
        '  <md-input-container class="md-flex ng-hide">',
        '    <input class="sg-item-name" type="text"',
        '           aria-label="' + l("Enter the new name of your folder") + '"',
        '           ng-blur="$ctrl.saveFolder($event)"',
        '           sg-enter="$ctrl.saveFolder($event)"',
        '           sg-escape="$ctrl.revertEditing()" />',
        '  </md-input-container>',
        '  <md-icon class="md-menu" ng-click="$ctrl.showMenu($event)" aria-label="' + l("Options") + '">more_vert</md-icon>'
      ].join(''),
      controller: 'sgMailboxListItemController',
      controllerAs: '$ctrl'
    };
  }

  /**
   * @ngInject
   */
  sgMailboxListItemController.$inject = ['$scope', '$element', '$compile', '$state', '$mdToast', '$mdPanel', '$mdMedia', '$mdSidenav', 'sgConstant', 'Dialog', 'Mailbox', 'encodeUriFilter'];
  function sgMailboxListItemController($scope, $element, $compile, $state, $mdToast, $mdPanel, $mdMedia, $mdSidenav, sgConstant, Dialog, Mailbox, encodeUriFilter) {
    var $ctrl = this;


    this.$onInit = function() {
      this.$element = $element;
      this.service = Mailbox;
      this.editMode = false;
      this.accountController.addMailboxController(this);
    };


    this.$postLink = function() {
      this.selectableElement = $element.find('div')[0];
      this.clickableElement = $element.find('p')[0];
      this.inputContainer = $element.find('md-input-container')[0];
      this.inputElement = $element.find('input')[0];
      this.moreOptionsButton = _.last($element.find('md-icon'));

      // Check if router's state has selected a mailbox
      if (Mailbox.selectedFolder !== null && Mailbox.selectedFolder.id == this.mailbox.id) {
        this.selectFolder();
      }
    };

    this.childLevel = function() {
      return 'sg-child-level-' + this.mailbox.level;
    };


    this.selectFolder = function($event) {
      if (this.editMode || this.mailbox == Mailbox.selectedFolder)
        return;
      Mailbox.$virtualPath = false;
      Mailbox.$virtualMode = false;
      this.accountController.selectFolder(this);
      if ($event) {
        $state.go('mail.account.mailbox', {
          accountId: this.mailbox.$account.id,
          mailboxId: encodeUriFilter(this.mailbox.path)
        });
        $event.stopPropagation();
        $event.preventDefault();
      }
    };


    this.unselectFolder = function() {
      $element[0].classList.remove('md-bg');
    };


    this.editFolder = function($event) {
      this.editMode = true;
      this.inputElement.value = this.mailbox.name;
      this.clickableElement.classList.add('ng-hide');
      this.inputContainer.classList.remove('ng-hide');
      this.inputElement.focus();
      this.inputElement.select();
      if ($event) {
        $event.stopPropagation();
        $event.preventDefault();
      }
    };


    this.saveFolder = function($event) {
      if (this.inputElement.disabled)
        return;

      this.mailbox.name = this.inputElement.value;
      this.inputElement.disabled = true;
      this.mailbox.$rename()
        .then(function(data) {
          $ctrl.editMode = false;
          $ctrl.inputContainer.classList.add('ng-hide');
          $ctrl.clickableElement.classList.remove('ng-hide');
        })
        .finally(function() {
          $ctrl.inputElement.disabled = false;
        });
    };


    this.revertEditing = function() {
      this.editMode = false;
      this.clickableElement.classList.remove('ng-hide');
      this.inputContainer.classList.add('ng-hide');
      this.inputElement.value = this.mailbox.name;
    };


    this.showMenu = function($event) {
      var panelPosition = $mdPanel.newPanelPosition()
          .relativeTo(this.moreOptionsButton)
          .addPanelPosition(
            $mdPanel.xPosition.ALIGN_START,
            $mdPanel.yPosition.ALIGN_TOPS
          );

      var panelAnimation = $mdPanel.newPanelAnimation()
          .openFrom(this.moreOptionsButton)
          .duration(100)
          .withAnimation($mdPanel.animation.FADE);

      var config = {
        attachTo: angular.element(document.body),
        locals: {
          itemCtrl: this,
          folder: this.mailbox
        },
        bindToController: true,
        controller: MenuController,
        controllerAs: '$menuCtrl',
        position: panelPosition,
        animation: panelAnimation,
        targetEvent: $event,
        templateUrl: 'UIxMailFolderMenu',
        trapFocus: true,
        clickOutsideToClose: true,
        escapeToClose: true,
        focusOnOpen: true
      };

      $mdPanel.open(config)
        .then(function(panelRef) {
          // Automatically close panel when clicking inside of it
          panelRef.panelEl.one('click', function() {
            panelRef.close();
          });
        });

      MenuController.$inject = ['mdPanelRef', '$state', '$mdDialog', 'User'];
      function MenuController(mdPanelRef, $state, $mdDialog, User) {
        var $menuCtrl = this;

        this.markFolderRead = function() {
          this.folder.$markAsRead();
        };

        this.newFolder = function() {
          Dialog.prompt(l('New Folder...'),
                        l('Enter the new name of your folder'))
            .then(function(name) {
              $menuCtrl.folder.$newMailbox($menuCtrl.folder.id, name)
                .then(function() {
                  // success
                }, function(data, status) {
                  Dialog.alert(l('An error occured while creating the mailbox "%{0}".', name),
                               l(data.error));
                });
            });
        };

        this.editFolder = function() {
          this.itemCtrl.editFolder();
        };

        this.compactFolder = function() {
          this.folder.$compact().then(function() {
            $mdToast.show(
              $mdToast.simple()
                .content(l('Folder compacted'))
                .position('top right')
                .hideDelay(3000));
          });
        };

        this.emptyTrashFolder = function() {
          this.folder.$emptyTrash().then(function() {
            $mdToast.show(
              $mdToast.simple()
                .content(l('Trash emptied'))
                .position('top right')
                .hideDelay(3000));
          });
        };

        this.confirmDelete = function() {
          Dialog.confirm(l('Warning'),
                         l('Do you really want to move this folder into the trash ?'),
                         { ok: l('Delete') })
            .then(function() {
              $menuCtrl.folder.$delete()
                .then(function() {
                  $state.go('mail.account.inbox');
                }, function(response) {
                  Dialog.confirm(l('Warning'),
                                 l('The mailbox could not be moved to the trash folder. Would you like to delete it immediately?'),
                                 { ok: l('Delete') })
                    .then(function() {
                      $menuCtrl.folder.$delete({ withoutTrash: true })
                        .then(function() {
                          $state.go('mail.account.inbox');
                        }, function(response) {
                          Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', $menuCtrl.folder.name),
                                       l(response.error));
                        });
                    });
                });
            });
        };

        this.showAdvancedSearch = function() {
          Mailbox.$virtualPath = this.folder.path;
          // Close sidenav on small devices
          if (!$mdMedia(sgConstant['gt-md']))
            $mdSidenav('left').close();
        };

        this.share = function() {
          // Fetch list of ACL users
          this.folder.$acl.$users().then(function() {
            // Show ACL editor
            $mdDialog.show({
              templateUrl: $menuCtrl.folder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
              controller: 'AclController', // from the ng module SOGo.Common
              controllerAs: 'acl',
              clickOutsideToClose: true,
              escapeToClose: true,
              locals: {
                usersWithACL: $menuCtrl.folder.$acl.users,
                User: User,
                folder: $menuCtrl.folder
              }
            });
          });
        };

        this.setFolderAs = function(type) {
          this.folder.$setFolderAs(type).then(function() {
            $menuCtrl.folder.$account.$getMailboxes({reload: true});
          });
        };

      } // MenuController


    };
  }


  angular
    .module('SOGo.MailerUI')
    .controller('sgMailboxListItemController', sgMailboxListItemController)
    .directive('sgMailboxListItem', sgMailboxListItem);
})();
