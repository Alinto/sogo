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
        '    </md-checkbox>',
        '  </div>',
        '  <p class="sg-item-name"',
        '    ng-click="$ctrl.selectFolder($event)"',
        '    ng-dblclick="$ctrl.editFolder($event)">',
        '    <md-icon ng-class="{ \'sg-opacity-70\': $ctrl.mailbox.isNoSelect() }">{{$ctrl.mailbox.$icon}}</md-icon>',
        '    <span ng-class="{ \'sg-font-medium\': $ctrl.mailbox.unseenCount }" ng-bind="$ctrl.mailbox.$displayName"></span>',
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
        '  <md-icon class="md-menu md-secondary-container" ng-click="$ctrl.showMenu($event)" aria-label="' + l("Options") + '">more_vert</md-icon>'
      ].join(''),
      controller: 'sgMailboxListItemController',
      controllerAs: '$ctrl'
    };
  }

  /**
   * @ngInject
   */
  sgMailboxListItemController.$inject = ['$scope', '$rootScope', '$element', '$state', '$timeout', '$mdToast', '$mdPanel', '$mdMedia', '$mdSidenav', 'sgConstant', 'Dialog', 'Mailbox', 'encodeUriFilter'];
  function sgMailboxListItemController($scope, $rootScope, $element, $state, $timeout, $mdToast, $mdPanel, $mdMedia, $mdSidenav, sgConstant, Dialog, Mailbox, encodeUriFilter) {
    var $ctrl = this;


    this.$onInit = function() {
      this.$element = $element;
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
        this.accountController.selectFolder(this);
      }
    };

    this.childLevel = function() {
      return 'sg-child-level-' + this.mailbox.level;
    };


    this.selectFolder = function($event) {
      $rootScope.$broadcast('resetMailAdvancedSearchPanel'); // Reset advanced search panel (broadcast event to MailboxesController)
      if (this.editMode || this.mailbox == Mailbox.selectedFolder || this.mailbox.isNoSelect())
        return;
      
      this.mailbox.setHighlightWords([]);
      if (Mailbox.selectedFolder) {
        Mailbox.$virtualMode = false;
        Mailbox.selectedFolder.$reset({ filter: true });
      }
      this.accountController.selectFolder(this);
      if ($event) {
        $state.go('mail.account.mailbox', {
          accountId: this.mailbox.$account.id,
          mailboxId: encodeUriFilter(encodeUriFilter(this.mailbox.path))
        });
        $event.stopPropagation();
        $event.preventDefault();
      }
    };


    this.unselectFolder = function() {
      $element[0].classList.remove('md-bg');
    };


    this.editFolder = function($event) {
      $event.stopPropagation();
      $event.preventDefault();
      if (this.mailbox.$isEditable) {
        this.editMode = true;
        this.inputElement.value = this.mailbox.name;
        this.clickableElement.classList.add('ng-hide');
        this.inputContainer.classList.remove('ng-hide');
        if ($event.srcEvent && $event.srcEvent.type == 'touchend') {
          $timeout(function() {
            $ctrl.inputElement.select();
            $ctrl.inputElement.focus();
          }, 200); // delayed focus for iOS
        }
        else {
          this.inputElement.select();
          this.inputElement.focus();
        }
      }
      if (this.panel) {
        this.panel.close();
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


    this.confirmDelete = function() {
      Dialog.confirm(l('Warning'),
                     l('Do you really want to move this folder into the trash ?'),
                     { ok: l('Delete') })
        .then(function() {
          $ctrl.mailbox.$delete()
            .then(function() {
              $state.go('mail.account.inbox');
            }, function(response) {
              Dialog.confirm(l('Warning'),
                             l('The mailbox could not be moved to the trash folder. Would you like to delete it immediately?'),
                             { ok: l('Delete') })
                .then(function() {
                  $ctrl.mailbox.$delete({ withoutTrash: true })
                    .then(function() {
                      $state.go('mail.account.inbox');
                    }, function(response) {
                      Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', $ctrl.mailbox.name),
                                   l(response.error));
                    });
                });
            });
        });
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
          folder: this.mailbox,
          editFolder: angular.bind(this, this.editFolder),
          confirmDelete: angular.bind(this, this.confirmDelete)
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
          $ctrl.panel = panelRef;
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

        this.compactFolder = function() {
          this.folder.$compact().then(function() {
            $mdToast.show(
              $mdToast.simple()
                .textContent(l('Folder compacted'))
                .position(sgConstant.toastPosition)
                .hideDelay(3000));
          });
        };

        this.emptyJunkFolder = function() {
          return this.emptyFolder(l('Junk folder emptied'));
        };

        this.emptyTrashFolder = function() {
          return this.emptyFolder(l('Trash emptied'));
        };

        this.emptyFolder = function(successMsg) {
          this.folder.$empty().then(function() {
            $mdToast.show(
              $mdToast.simple()
                .textContent(successMsg)
                .position(sgConstant.toastPosition)
                .hideDelay(3000));
          });
        };

        this.showAdvancedSearch = function() {
          Mailbox.$virtualPath = this.folder.path;
          // Close sidenav on small devices
          if (!$mdMedia(sgConstant['gt-md']))
            $mdSidenav('left').close();

          $rootScope.$broadcast('showMailAdvancedSearchPanel'); // Show advanced search panel (broadcast event to MailboxesController)
        };

        this.share = function() {
          var encodeURL = angular.bind(this.folder.constructor.$$resource,
                                       this.folder.constructor.$$resource.encodeURL);
          // Fetch list of ACL users
          this.folder.$acl.$users().then(function() {
            // Show ACL editor
            $mdDialog.show({
              templateUrl: encodeURL($menuCtrl.folder.id).join('/') + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
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

        this.isParentOf = function(path) {
          var findChildren;

          // Local recursive function
          findChildren = function(parent) {
            if (parent.children && parent.children.length > 0) {
              for (var i = 0, found = false; !found && i < parent.children.length; i++) {
                var o = parent.children[i];
                if (o.children && o.children.length > 0) {
                  if (findChildren(o)) {
                    return true;
                  }
                }
                else if (o.path == path) {
                  return true;
                }
              }
            }
            else {
              return (parent.path == path);
            }
          };

          return findChildren(this.folder);
        };

        this.moveFolder = function(path) {
          this.folder.$move(path);
          mdPanelRef.close();
        };

      } // MenuController


    };
  }


  angular
    .module('SOGo.MailerUI')
    .controller('sgMailboxListItemController', sgMailboxListItemController)
    .directive('sgMailboxListItem', sgMailboxListItem);
})();
