(function() {
  'use strict';

  function User() {}

  /* The factory we'll use to register with Angular */
  User.factory = ['sgSettings', 'sgResource', function(Settings, Resource) {
    angular.extend(User, {
      $$resource: new Resource(Settings.baseURL)
    });

    return User; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.Common').factory('sgUser', User.factory);

  /* Instance methods
   * Public method, assigned to prototype      
   */
  User.prototype.$filter = function(search) {
    // return a collections of users for a filter
    var param = {search: search};
    return User.$$resource.fetch(null, "usersSearch", param).then(function(results) {
      return results;
    })
  };
})();
