(function() {
  'use strict';

  /**
   * @name User
   * @constructor
   * @param {object} [userData] - some default values for the user
   */
  function User(userData) {
    if (userData)
      angular.extend(this, userData);
  }

  /**
   * @memberof User
   * @desc The factory we'll use to register with Angular.
   * @return the User constructor
   */
  User.factory = ['$q', 'sgSettings', 'sgResource', function($q, Settings, Resource) {
    angular.extend(User, {
      $q: $q,
      $$resource: new Resource(Settings.baseURL)
    });

    return User;
  }];

  /**
   * @module SOGo.Common
   * @desc Factory registration of User in Angular module.
   */
  angular.module('SOGo.Common').factory('sgUser', User.factory);

  /**
   * @memberof User
   * @desc Search for users that match a string.
   * @param {String} search - a string used to performed the search
   * @return a promise of an array of matching User objects
   */
  User.$filter = function(search) {
    var param = {search: search};
    return User.$$resource.fetch(null, 'usersSearch', param).then(function(users) {
      var results = [];
      angular.forEach(users, function(data) {
        console.debug(JSON.stringify(data, undefined, 2));
        var user = new User(data);
        results.push(user);
      });
      return results;
    });
  };

  /**
   * @function $shortFormat
   * @memberof User.prototype
   * @return the fullname along with the email address
   */
  User.prototype.$shortFormat = function() {
    var fullname = this.cn || this.c_email;
    if (this.c_email && fullname != this.c_email) {
      fullname += ' (' + this.c_email + ')';
    }
    return fullname;
  };

  /**
   * @function $acl
   * @memberof User.prototype
   * @desc Fetch the user rights associated to a specific folder and populate the 'rights' attribute.
   * @param {String} the folder ID
   * @return a promise
   */
  User.prototype.$acl = function(folderId) {
    var _this = this,
        deferred = User.$q.defer(),
        param = {uid: this.uid};
    if (this.$shadowRights) {
      deferred.resolve(this.rights);
    }
    else {
      User.$$resource.fetch(folderId, 'userRights', param).then(function(data) {
        _this.rights = data;
        // Convert numbers (0|1) to boolean values
        angular.forEach(_.keys(_this.rights), function(key) {
          _this.rights[key] = _this.rights[key] ? true : false;
        });
        // console.debug('rights ' + _this.uid + ' => ' + JSON.stringify(data, undefined, 2));
        // Keep a copy of the server's version
        _this.$shadowRights = angular.copy(data);
        deferred.resolve(data);
        return data;
      });
    }
    return deferred;
  };

  /**
   * @function $isAnonymous
   * @memberof User.prototype
   * @return true if it's the special anonymous user
   */
  User.prototype.$isAnonymous = function() {
    return this.uid == 'anonymous';
  };

  /**
   * @function $isSpecial
   * @memberof User.prototype
   * @return true if the user is not a regular system user
   */
  User.prototype.$isSpecial = function() {
    return this.userClass && this.userClass == 'public-user';
  };

  /**
   * @function $confirmRights
   * @memberof User.prototype
   * @desc Check if a confirmation is required before giving some rights.
   * @return the confirmation message or false if no confirmation is required
   */
  User.prototype.$confirmRights = function() {
    var confirmation = false;

    if (this.$confirmation) {
      // Don't bother the user more than once
      return false;
    }

    if (_.some(_.values(this.rights))) {
      if (this.uid == 'anonymous') {
        confirmation = l('Potentially anyone on the Internet will be able to access your folder, even if they do not have an account on this system. Is this information suitable for the public Internet?');
      }
      else if (this.uid == '<default>') {
        confirmation = l('Any user with an account on this system will be able to access your folder. Are you certain you trust them all?');
      }
    }

    this.$confirmation = confirmation;

    return confirmation;
  };

  /**
   * @function $rightsAreDirty
   * @memberof User.prototype
   * @return whether or not the rights have changed from their initial values
   */
  User.prototype.$rightsAreDirty = function() {
    return this.rights && !_.isEqual(this.rights, this.$shadowRights);
  };

  /**
   * @function $resetRights
   * @memberof User.prototype
   * @desc Restore initial rights or disable all rights
   * @param {Boolean} [zero] - reset all rights to zero when true
   */
  User.prototype.$resetRights = function(zero) {
    var _this = this;
    if (zero) {
      // Disable all rights
      _.map(_.keys(this.rights), function(key) {
        _this.rights[key] = 0;
      });
    }
    else {
      // Restore initial rights
      this.rights = angular.copy(this.$shadowRights);
    }
  };

  /**
   * @function $omit
   * @memberof User.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the User instance
   */
  User.prototype.$omit = function() {
    var user = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        user[key] = value;
      }
    });
    return user;
  };

})();
