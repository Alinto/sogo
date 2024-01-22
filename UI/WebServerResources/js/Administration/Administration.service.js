/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Administration
   * @constructor
   */
  function Administration() {

  }

  /**
   * @memberof Administration
   * @desc The factory we'll use to register with Angular
   * @returns the Administration constructor
   */
  Administration.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'User', function($q, $timeout, $log, Settings, Resource, User) {
    angular.extend(Administration, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL'), Settings.activeUser()),
      activeUser: Settings.activeUser(),
      $User: User
    });

    return new Administration(); // return unique instance
  }];

  /**
   * @function $getMotd
   * @memberof Administration.prototype
   * @desc Get the motd to the server.
   */
  Administration.prototype.$getMotd = function () {
    var _this = this;

    return Administration.$$resource.fetch("Administration/getMotd")
      .then(function (data) {
        return data;
      });
  };

  /**
   * @function $saveMotd
   * @memberof Administration.prototype
   * @desc Save the motd to the server.
   */
  Administration.prototype.$saveMotd = function (message) {
    var _this = this;

    return Administration.$$resource.save("Administration", { motd: message }, { action: "saveMotd" })
      .then(function (data) {
        return data;
      });
  };

  /* Initialize module if necessary */
  try {
    angular.module('SOGo.AdministrationUI');
  }
  catch(e) {
    angular.module('SOGo.AdministrationUI', ['SOGo.Common']);
  }

  /* Factory registration in Angular module */
  angular.module('SOGo.AdministrationUI')
    .factory('Administration', Administration.$factory);

})();
