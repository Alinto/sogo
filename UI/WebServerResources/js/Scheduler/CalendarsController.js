/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarsController.$inject = ['$rootScope', '$scope', '$window', '$mdDialog', '$log', '$mdToast', 'FileUploader', 'sgFocus', 'Dialog', 'sgSettings', 'Preferences', 'Calendar', 'User', 'stateCalendars'];
  function CalendarsController($rootScope, $scope, $window, $mdDialog, $log, $mdToast, FileUploader, focus, Dialog, Settings, Preferences, Calendar, User, stateCalendars) {
    var vm = this;

    vm.activeUser = Settings.activeUser;
    vm.service = Calendar;
    vm.newCalendar = newCalendar;
    vm.addWebCalendar = addWebCalendar;
    vm.confirmDelete = confirmDelete;
    vm.editFolder = editFolder;
    vm.revertEditing = revertEditing;
    vm.renameFolder = renameFolder;
    vm.share = share;
    vm.importCalendar = importCalendar;
    vm.showOnly = showOnly;
    vm.showAll = showAll;
    vm.showLinks = showLinks;
    vm.showProperties = showProperties;
    vm.subscribeToFolder = subscribeToFolder;
    // vm.today = today;

    vm.filter = { name: '' };
    vm.sortableMode = false;
    vm.toggleSortableMode = toggleSortableMode;
    vm.resetSort = resetSort;
    vm.sortableCalendars = {
      scrollableContainer: '#sidenav-content',
      containment: 'md-list',
      orderChanged: _sortableEnd,
      accept: _sortableAccept
    };

    Preferences.ready().then(function() {
      vm.categories = _.map(Preferences.defaults.SOGoCalendarCategories, function(name) {
        return { id: name.asCSSIdentifier(),
                 name: name,
                 color: Preferences.defaults.SOGoCalendarCategoriesColors[name]
               };
      });
    });

    // Dispatch the event named 'calendars:list' when a calendar is activated or deactivated or
    // when the color of a calendar is changed
    $scope.$watch(
      function() {
        return _.union(
          _.map(Calendar.$calendars, function(o) { return _.pick(o, ['id', 'active', 'color']); }),
          _.map(Calendar.$subscriptions, function(o) { return _.pick(o, ['id', 'active', 'color']); }),
          _.map(Calendar.$webcalendars, function(o) { return _.pick(o, ['id', 'active', 'color']); })
        );
      },
      function(newList, oldList) {
        var commonList, ids, promise;

        // Identify which calendar has changed
        commonList = _.intersectionBy(newList, oldList, 'id');
        ids = _.map(_.filter(commonList, function(o) {
          var oldObject = _.find(oldList, { id: o.id });
          return !_.isEqual(o, oldObject);
        }), 'id');
        promise = Calendar.$q.when();

        if (ids.length > 0) {
          $log.debug(ids.join(', ') + ' changed');
          promise = Calendar.saveFoldersActivation(ids);
        }
        if (ids.length > 0 || commonList.length != newList.length || commonList.length != oldList.length)
          promise.then(function() {
            $rootScope.$emit('calendars:list');
          });
      },
      true // compare for object equality
    );

    /**
     * Only allow to sort items within the same list.
     */
    function _sortableAccept(sourceItemHandleScope, destSortableScope, destItemScope) {
      return sourceItemHandleScope.sortableScope.element[0] == destSortableScope.element[0];
    }

    function _sortableEnd() {
      Calendar.saveFoldersOrder(_.flatMap(Calendar.$findAll(), 'id'));
    }

    function toggleSortableMode() {
      vm.sortableMode = !vm.sortableMode;
      vm.filter.name = '';
    }

    function resetSort() {
      Calendar.saveFoldersOrder();
    }

    function newCalendar(ev) {
      Dialog.prompt(l('New calendar'), l('Name of the Calendar'))
        .then(function(name) {
          var calendar = new Calendar(
            {
              name: name,
              isEditable: true,
              isRemote: false,
              owner: UserLogin
            }
          );
          calendar.$id().then(function() {
            Calendar.$add(calendar);
          });
        });
    }

    function addWebCalendar() {
      Dialog.prompt(l('Subscribe to a web calendar...'), l('URL of the Calendar'), {inputType: 'url'})
        .then(function(url) {
          Calendar.$addWebCalendar(url).then(function(calendar) {
            if (angular.isObject(calendar)) {
              // Web calendar requires HTTP authentication
              $mdDialog.show({
                parent: angular.element(document.body),
                clickOutsideToClose: true,
                escapeToClose: true,
                templateUrl: 'UIxWebCalendarAuthDialog',
                controller: WebCalendarAuthDialogController,
                controllerAs: '$WebCalendarAuthDialogController',
                locals: {
                  url: url,
                  calendar: calendar
                }
              });
            }
          });
        });

      /**
       * @ngInject
       */
      WebCalendarAuthDialogController.$inject = ['scope', '$mdDialog', 'url', 'calendar'];
      function WebCalendarAuthDialogController(scope, $mdDialog, url, calendar) {
        var vm = this,
            parts = url.split("/"),
            hostname = parts[2];

        vm.title = l("Please identify yourself to %{0}").formatted(hostname);
        vm.authenticate = function(form) {
          if (form.$valid || !form.$error.required) {
            calendar.setCredentials(vm.username, vm.password).then(function(message) {
              $mdDialog.hide();
            }, function(reason) {
              form.password.$setValidity('credentials', false);
            });
          }
        };
        vm.cancel = function() {
          $mdDialog.cancel();
        };
      }
    }

    function confirmDelete(folder) {
      if (folder.isSubscription) {
        // Unsubscribe without confirmation
        folder.$delete()
          .catch(function(data, status) {
            Dialog.alert(l('An error occured while deleting the calendar "%{0}".', folder.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the calendar "%{0}"?', folder.name),
                       { ok: l('Delete') })
          .then(function() {
            folder.$delete()
              .catch(function(data, status) {
                Dialog.alert(l('An error occured while deleting the calendar "%{0}".', folder.name),
                             l(data.error));
              });
          });
      }
    }

    function importCalendar($event, folder) {
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: $event,
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: 'UIxCalendarImportDialog',
        controller: CalendarImportDialogController,
        controllerAs: '$CalendarImportDialogController',
        locals: {
          folder: folder
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
                '    <span>' + l('An error occurred while importing calendar.') + '</span>',
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
              position: 'top right',
              hideDelay: 3000
            });

          return isTextFile;
        }
      }
    }

    function showOnly(calendar) {
      _.forEach(Calendar.$findAll(), function(o) {
        if (calendar.id == o.id)
          o.active = 1;
        else
          o.active = 0;
      });
    }

    function showAll() {
      _.forEach(Calendar.$findAll(), function(o) { o.active = 1; });
    }

    function showLinks(calendar) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: calendar.id + '/links',
        controller: LinksDialogController,
        controllerAs: 'links',
        locals: {
          calendar: calendar
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
    }

    function showProperties(calendar) {
      var color = calendar.color;
      $mdDialog.show({
        templateUrl: calendar.id + '/properties',
        controller: PropertiesDialogController,
        controllerAs: 'properties',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          srcCalendar: calendar
        }
      }).catch(function() {
        // Restore original color when cancelling or closing the dialog
        calendar.color = color;
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

        function saveProperties() {
          vm.calendar.$save();
          // Refresh list instance
          srcCalendar.init(vm.calendar.$omit());
          $mdDialog.hide();
        }

        function close() {
          $mdDialog.cancel();
        }
      }
    }

    function editFolder(folder) {
      vm.calendarName = folder.name;
      vm.editMode = folder.id;
      focus('calendarName_' + folder.id);
    }

    function revertEditing(folder) {
      folder.$reset();
      vm.editMode = false;
    }

    function renameFolder(folder) {
      folder.$rename()
        .then(function(data) {
          vm.editMode = false;
        });
    }

    function share(calendar) {
      calendar.$acl.$users().then(function() {
        $mdDialog.show({
          templateUrl: calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: 'AclController', // from the ng module SOGo.Common
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: calendar.$acl.users,
            User: User,
            folder: calendar
          }
        });
      });
    }

    // Callback of sgSubscribe directive
    function subscribeToFolder(calendarData) {
      $log.debug('subscribeToFolder ' + calendarData.owner + calendarData.name);
      Calendar.$subscribe(calendarData.owner, calendarData.name).then(function(data) {
         $mdToast.show(
           $mdToast.simple()
             .content(l('Successfully subscribed to calendar'))
             .position('top right')
             .hideDelay(3000));
      });
    }

    // function today() {
    //   var fragments = $window.location.hash.split('/'),
    //       state = fragments[1],
    //       view = fragments[2],
    //       now = new Date(),
    //       path = ['#', state, view, now.getDayString()];
    //   $window.location = path.join('/');
    // }
  }

  angular
    .module('SOGo.SchedulerUI')
    .controller('CalendarsController', CalendarsController);
})();
