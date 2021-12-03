/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /**
   * sgCalendarListItem - A directive that defines the content of a md-list-item for a calendar.
   * @memberof SOGo.SchedulerUI
  */
  function sgCalendarListItem() {
    return {
      restrict: 'C',
      scope: {},
      bindToController: {
        calendar: '=sgCalendar'
      },
      template: [
        '<md-switch ng-model="$ctrl.calendar.active"',
        '           ng-class="$ctrl.calendar.getClassName(\'md-switch\')"',
        '           ng-true-value="1"',
        '           ng-false-value="0"',
        '           aria-label="' + l('Enable') + '"></md-switch>',
        '<p class="sg-item-name"',
        '   ng-dblclick="$ctrl.editFolder($event)">',
        '  <span ng-bind="$ctrl.calendar.name"></span>',
        '  <md-icon ng-if="$ctrl.calendar.$error" class="md-warn">error</md-icon>',
        '  <md-tooltip md-delay="1000"',
        '              md-autohide="true"',
        '              ng-bind="$ctrl.calendar.name"></md-tooltip>',
        '  <span class="sg-counter-badge ng-hide"',
        '        ng-show="calendar.activeTasks"',
        '        ng-bind="calendar.activeTasks"></span>',
        '</p>',
        '<md-input-container class="md-flex ng-hide">',
        '  <input class="sg-item-name" type="text"',
        '         aria-label="' + l('Name of the Calendar') + '"',
        '         ng-blur="$ctrl.saveFolder($event)"',
        '         sg-enter="$ctrl.saveFolder($event)"',
        '         sg-escape="$ctrl.revertEditing()" />',
        '</md-input-container>',
        '<md-icon class="md-menu md-secondary-container"',
        '           as-sortable-item-handle="as-sortable-item-handle"',
        '           md-colors="::{color: \'accent-400\'}">drag_handle</md-icon>',
        '<md-icon class="md-menu md-secondary-container sg-list-sortable-hide"',
        '         ng-click="$ctrl.showMenu($event)"',
        '         aria-label="' + l("Options") + '">more_vert</md-icon>'
      ].join(''),
      controller: 'sgCalendarListItemController',
      controllerAs: '$ctrl'
    };
  }

  /**
   * @ngInject
   */
  sgCalendarListItemController.$inject = ['$rootScope', '$scope', '$element', '$timeout', '$mdToast', '$mdPanel', '$mdMedia', '$mdSidenav', 'sgConstant', 'Dialog', 'Calendar'];
  function sgCalendarListItemController($rootScope, $scope, $element, $timeout, $mdToast, $mdPanel, $mdMedia, $mdSidenav, sgConstant, Dialog, Calendar) {
    var $ctrl = this;


    this.$onInit = function() {
      this.editMode = false;
    };


    this.$postLink = function() {
      this.clickableElement = $element.find('p')[0];
      this.nameElements = this.clickableElement.getElementsByClassName('sg-calendar-name');
      this.inputContainer = $element.find('md-input-container')[0];
      this.inputElement = $element.find('input')[0];
      this.moreOptionsButton = _.last($element.find('md-icon'));
      this.updateCalendarName();
    };


    this.updateCalendarName = function() {
      _.forEach(this.nameElements, function(e) {
        e.innerHTML = $ctrl.calendar.name;
      });
    };


    this.editFolder = function($event) {
      $event.stopPropagation();
      $event.preventDefault();
      this.editMode = true;
      this.inputElement.value = this.calendar.name;
      this.clickableElement.classList.add('ng-hide');
      this.inputContainer.classList.remove('ng-hide');
      if ($event.srcEvent && $event.srcEvent.type == 'touchend') {
        $timeout(function() {
          $ctrl.inputElement.focus();
          $ctrl.inputElement.select();
        }, 200); // delayed focus for iOS
      }
      else {
        this.inputElement.select();
        this.inputElement.focus();
      }
      if (this.panel) {
        this.panel.close();
      }
    };


    this.saveFolder = function($event) {
      if (this.inputElement.disabled)
        return;

      if (this.inputElement.value.length === 0)
        this.revertEditing();

      this.calendar.name = this.inputElement.value;
      this.inputElement.disabled = true;
      this.calendar.$rename()
        .then(function(data) {
          $ctrl.editMode = false;
          $ctrl.inputContainer.classList.add('ng-hide');
          $ctrl.clickableElement.classList.remove('ng-hide');
          $ctrl.updateCalendarName();
        }, function() {
          $ctrl.editMode = true;
          $ctrl.inputElement.value = $ctrl.calendar.name;
          $timeout(function() {
            $ctrl.inputElement.focus();
            $ctrl.inputElement.select();
          }, 200); // delayed focus for iOS
        })
        .finally(function() {
          $ctrl.inputElement.disabled = false;
        });
    };


    this.revertEditing = function() {
      this.editMode = false;
      this.clickableElement.classList.remove('ng-hide');
      this.inputContainer.classList.add('ng-hide');
      this.inputElement.value = this.calendar.name;
    };


    this.confirmDelete = function() {
      if (this.calendar.isSubscription) {
        // Unsubscribe without confirmation
        this.calendar.$delete()
          .catch(function(data, status) {
            Dialog.alert(l('An error occured while deleting the calendar "%{0}".', $ctrl.calendar.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the calendar "%{0}"?', this.calendar.name),
                       { ok: l('Delete') })
          .then(function() {
            $ctrl.calendar.$delete()
              .catch(function(data, status) {
                Dialog.alert(l('An error occured while deleting the calendar "%{0}".', $ctrl.calendar.name),
                             l(data.error));
              });
          });
      }
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
          calendar: this.calendar,
          editFolder: angular.bind(this, this.editFolder),
          confirmDelete: angular.bind(this, this.confirmDelete)
        },
        bindToController: true,
        controller: MenuController,
        controllerAs: '$menuCtrl',
        position: panelPosition,
        animation: panelAnimation,
        targetEvent: $event,
        templateUrl: 'UIxCalendarMenu',
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

      MenuController.$inject = ['mdPanelRef', '$mdDialog', 'FileUploader', 'User'];
      function MenuController(mdPanelRef, $mdDialog, FileUploader, User) {
        var $menuCtrl = this;

        this.showOnly = function() {
          _.forEach(Calendar.$findAll(), function(o) {
            if ($menuCtrl.calendar.id == o.id)
              o.active = 1;
            else
              o.active = 0;
          });
        };

        this.showAll = function() {
          _.forEach(Calendar.$findAll(), function(o) { o.active = 1; });
        };

        this.showProperties = function() {
          var color = this.calendar.color;
          $mdDialog.show({
            templateUrl: this.calendar.id + '/properties',
            controller: PropertiesDialogController,
            controllerAs: 'properties',
            clickOutsideToClose: true,
            escapeToClose: true,
            locals: {
              srcCalendar: this.calendar
            }
          }).catch(function() {
            // Restore original color when cancelling or closing the dialog
            $menuCtrl.calendar.color = color;
          });

          /**
           * @ngInject
           */
          PropertiesDialogController.$inject = ['$scope', '$mdDialog', 'srcCalendar'];
          function PropertiesDialogController($scope, $mdDialog, srcCalendar) {
            var vm = this;

            vm.calendar = new Calendar(srcCalendar.$omit());
            vm.saveProperties = saveProperties;
            vm.close = close;

            $scope.$watch(function() { return vm.calendar.color; }, function() {
              srcCalendar.color = vm.calendar.color;
            });

            function saveProperties(form) {
              if (form.$valid) {
                vm.calendar.$save().then(function() {
                  // Refresh list instance
                  srcCalendar.init(vm.calendar.$omit());
                  $mdDialog.hide();
                }, function() {
                  form.$setPristine();
                });
              }
            }

            function close() {
              $mdDialog.cancel();
            }
          }
        };

        this.showLinks = function() {
          $mdDialog.show({
            parent: angular.element(document.body),
            clickOutsideToClose: true,
            escapeToClose: true,
            templateUrl: this.calendar.id + '/links',
            controller: LinksDialogController,
            controllerAs: 'links',
            locals: {
              calendar: this.calendar
            }
          });

          /**
           * @ngInject
           */
          LinksDialogController.$inject = ['$mdDialog', 'calendar'];
          function LinksDialogController($mdDialog, calendar) {
            var vm = this;
            vm.calendar = calendar;
            vm.close = close;

            function close() {
              $mdDialog.hide();
            }
          }
        };

        this.importCalendar = function() {
          $mdDialog.show({
            parent: angular.element(document.body),
            targetEvent: $event,
            clickOutsideToClose: true,
            escapeToClose: true,
            templateUrl: 'UIxCalendarImportDialog', // subtemplate of UIxCalMainView.wox
            controller: CalendarImportDialogController,
            controllerAs: '$CalendarImportDialogController',
            locals: {
              folder: this.calendar
            }
          });

          /**
           * @ngInject
           */
          CalendarImportDialogController.$inject = ['scope', '$mdDialog', 'folder'];
          function CalendarImportDialogController(scope, $mdDialog, folder) {
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
                  msg = l('No event was imported.');
                else {
                  msg = l('A total of %{0} events were imported in the calendar.', response.imported);
                  $rootScope.$emit('calendars:list');
                }

                $mdToast.show(
                  $mdToast.simple()
                    .textContent(msg)
                    .position(sgConstant.toastPosition)
                    .hideDelay(3000));
              },
              onErrorItem: function(item, response, status, headers) {
                $mdToast.show({
                  template: [
                    '<md-toast>',
                    '  <div class="md-toast-content">',
                    '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
                    '    <span>' + l('An error occurred while importing calendar.') + '</span>',
                    '  </div>',
                    '</md-toast>'
                  ].join(''),
                  position: sgConstant.toastPosition,
                  hideDelay: 3000
                });
              }
            });

            vm.close = function() {
              $mdDialog.hide();
            };

            function filterByExtension(item) {
              var isTextFile = item.type.indexOf('text') === 0 ||
                  /\.(ics)$/.test(item.name);

              if (!isTextFile)
                $mdToast.show({
                  template: [
                    '<md-toast>',
                    '  <div class="md-toast-content">',
                    '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
                    '    <span>' + l('Select an iCalendar file (.ics).') + '</span>',
                    '  </div>',
                    '</md-toast>'
                  ].join(''),
                  position: sgConstant.toastPosition,
                  hideDelay: 3000
                });

              return isTextFile;
            }
          }
        };

        this.share = function() {
          // Fetch list of ACL users
          this.calendar.$acl.$users().then(function() {
            // Show ACL editor
            $mdDialog.show({
              templateUrl: $menuCtrl.calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
              controller: 'AclController', // from the ng module SOGo.Common
              controllerAs: 'acl',
              clickOutsideToClose: true,
              escapeToClose: true,
              locals: {
                usersWithACL: $menuCtrl.calendar.$acl.users,
                User: User,
                folder: $menuCtrl.calendar
              }
            });
          });
        };

      } // MenuController


    };
  }


  angular
    .module('SOGo.SchedulerUI')
    .controller('sgCalendarListItemController', sgCalendarListItemController)
    .directive('sgCalendarListItem', sgCalendarListItem);
})();
