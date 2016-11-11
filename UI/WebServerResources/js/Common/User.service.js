(function() {
  'use strict';

  /**
   * @name User
   * @constructor
   * @param {object} [userData] - some default values for the user
   */
  function User(userData) {
    if (userData) {
      this.init(userData);
    }
  }

  /**
   * @memberof User
   * @desc The factory we'll use to register with Angular.
   * @return the User constructor
   */
  User.factory = ['$q', '$log', 'sgSettings', 'Resource', function($q, $log, Settings, Resource) {
    angular.extend(User, {
      $q: $q,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL'), Settings.activeUser()),
      $query: '',
      $users: []
    });

    return User;
  }];

  /**
   * @module SOGo.Common
   * @desc Factory registration of User in Angular module.
   */
  angular.module('SOGo.Common').factory('User', User.factory);

  /**
   * @memberof User
   * @desc Search for users that match a string.
   * @param {string} search - a string used to performed the search
   * @param {object[]} excludedUsers - a list of User objects that must be excluded from the results
   * @return a promise of an array of matching User objects
   */
  User.$filter = function(search, excludedUsers, options) {
    var _this = this, param = {search: search};

    if (!options || !options.dry) {
      if (!search) {
        // No query specified
        User.$users.splice(0, User.$users.length);
        return User.$q.when(User.$users);
      }
      if (User.$query == search) {
        // Query hasn't changed
        return User.$q.when(User.$users);
      }
      User.$query = search;
    }

    return User.$$resource.fetch(null, 'usersSearch', param).then(function(response) {
      var results, index, user, users,
          compareUids = function(data) {
            return this.uid == data.uid;
          };

      if (options) {
        if (options.dry)
          users = [];
        else if (options.results)
          users = options.results;
      }
      else
        users = User.$users;

      if (excludedUsers) {
        // Remove excluded users from response
        results = _.filter(response.users, function(user) {
          return !_.find(excludedUsers, _.bind(compareUids, user));
        });
      }
      else {
        results = response.users;
      }

      // Remove users that no longer match the search query
      for (index = users.length - 1; index >= 0; index--) {
        user = users[index];
        if (!_.find(results, _.bind(compareUids, user))) {
          users.splice(index, 1);
        }
      }
      // Add new users matching the search query
      _.forEach(results, function(data, index) {
        if (_.isUndefined(_.find(users, _.bind(compareUids, data)))) {
          var user = new User(data);
          users.splice(index, 0, user);
        }
      });
      User.$log.debug(users);
      return users;
    });
  };

  /**
   * @function init
   * @memberof User.prototype
   * @desc Extend instance with required attributes and new data.
   * @param {object} data - attributes of user
   */
  User.prototype.init = function(data) {
    angular.extend(this, data);
    if (!this.$$shortFormat)
      this.$$shortFormat = this.$shortFormat();
    if (!this.$$image)
      this.$$image = this.image;
    this.$avatarIcon = (this.$isGroup() || this.$isSpecial()) ? 'group' : 'person';
    // NOTE: We can't assign a Gravatar at this stage since we would need the Preferences module
    // which already depend on the User module.

    // An empty attribute to trick md-autocomplete when adding users from the ACLs editor
    this.empty = ' ';
  };

  /**
   * @function $shortFormat
   * @memberof User.prototype
   * @return the fullname along with the email address
   */
  User.prototype.$shortFormat = function(options) {
    var fullname = this.cn || this.c_email;
    var email = this.c_email;
    var no_email = options && options.email === false;
    if (!no_email && email && fullname != email) {
      fullname += ' <' + email + '>';
    }
    return fullname;
  };

  /**
   * @function $acl
   * @memberof User.prototype
   * @desc Fetch the user rights associated to a specific folder and populate the 'rights' attribute.
   * @param {string} the folder ID
   * @param {Object} owner - the owner to use when fetching the ACL as it might not be the Settings.activeUser
   * @return a promise
   */
  User.prototype.$acl = function(folderId, owner) {
    var _this = this,
        deferred = User.$q.defer(),
        param = {uid: this.uid};
    if (this.$shadowRights) {
      deferred.resolve(this.rights);
    }
    else {
      var rights;

      if (angular.isDefined(owner))
        rights = User.$$resource.userResource(owner).fetch(folderId, 'userRights', param);
      else
        rights = User.$$resource.fetch(folderId, 'userRights', param);

      rights.then(function(data) {
        _this.rights = data;
        // Convert numbers (0|1) to boolean values
        //angular.forEach(_.keys(_this.rights), function(key) {
        //  _this.rights[key] = _this.rights[key] ? true : false;
        //});
        // console.debug('rights ' + _this.uid + ' => ' + JSON.stringify(data, undefined, 2));
        // Keep a copy of the server's version
        _this.$shadowRights = angular.copy(data);
        deferred.resolve(data);
        return data;
      });
    }
    return deferred.promise;
  };

  /**
   * @function $isGroup
   * @memberof User.prototype
   * @return true if the user actually represents a group of users
   */
  User.prototype.$isGroup = function() {
    return this.isGroup || this.userClass && this.userClass == 'normal-group';
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
   * @desc Only accurate from the ACL editor.
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
  User.prototype.$confirmRights = function(folder) {
    var confirmation = false;

    if (this.$confirmation) {
      // Don't bother the user more than once
      return false;
    }

    if (_.some(_.values(this.rights))) {
      if (this.uid == 'anonymous') {
        if (folder.constructor.name == 'AddressBook')
          confirmation = l('Potentially anyone on the Internet will be able to access your address book "%{0}", even if they do not have an account on this system. Is this information suitable for the public Internet?', folder.name);
        else if (folder.constructor.name == 'Calendar')
          confirmation = l('Potentially anyone on the Internet will be able to access your calendar "%{0}", even if they do not have an account on this system. Is this information suitable for the public Internet?', folder.name);
      }
      else if (this.uid == 'anyone' || this.uid == '<default>') {
        if (folder.constructor.name == 'AddressBook')
          confirmation = l('Any user with an account on this system will be able to access your address book "%{0}". Are you certain you trust them all?', folder.name);
        else if (folder.constructor.name == 'Calendar')
          confirmation = l('Any user with an account on this system will be able to access your calendar "%{0}". Are you certain you trust them all?', folder.name);
        else if (folder.constructor.name == 'Mailbox')
          confirmation = l('Any user with an account on this system will be able to access your mailbox "%{0}". Are you certain you trust them all?', folder.name);
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
   * @param {boolean} [zero] - reset all rights to zero when true
   */
  User.prototype.$resetRights = function(zero) {
    var _this = this;
    if (zero) {
      // Disable all rights
      _.map(_.keys(this.rights), function(key) {
        if (angular.isString(_this.rights[key]))
          _this.rights[key] = 'None';
        else
          _this.rights[key] = 0;
      });
    }
    else if (this.$shadowRights) {
      // Restore initial rights
      this.rights = angular.copy(this.$shadowRights);
    }
  };

  /**
   * @function $folders
   * @memberof User.prototype
   * @desc Retrieve the list of folders of a specific type
   * @param {string} type - either 'contact' or 'calendar'
   * @return a promise of the HTTP query result or the cached result
   */
  User.prototype.$folders = function(type) {
    var _this = this,
        deferred = User.$q.defer(),
        param = {type: type};
    if (this.$$folders) {
      deferred.resolve(this.$$folders);
    }
    else {
      User.$$resource.userResource(this.uid).fetch(null, 'foldersSearch', param).then(function(response) {
        _this.$$folders = response.folders;
        deferred.resolve(response.folders);
      });
    }
    return deferred.promise;
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

  User.prototype.toString = function() {
    return '[User ' + this.c_email + ']';
  };

})();
