/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name AddressBook
   * @constructor
   * @param {object} futureAddressBookData - either an object literal or a promise
   */
  function AddressBook(futureAddressBookData) {
    // Data is immediately available
    if (typeof futureAddressBookData.then !== 'function') {
      this.init(futureAddressBookData);
      if (this.name && !this.id) {
        // Create a new addressbook on the server
        var newAddressBookData = AddressBook.$$resource.create('createFolder', this.name);
        this.$unwrap(newAddressBookData);
        this.acls = {'objectEditor': 1, 'objectCreator': 1, 'objectEraser': 1};
      }
      else if (this.id) {
        this.$acl = new AddressBook.$$Acl('Contacts/' + this.id);
      }
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureAddressBookData);
    }
  }

  /**
   * @memberof AddressBook
   * @desc The factory we'll use to register with Angular
   * @returns the AddressBook constructor
   */
  AddressBook.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Card', 'Acl', 'Preferences', function($q, $timeout, $log, Settings, Resource, Card, Acl, Preferences) {
    angular.extend(AddressBook, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Contacts', Settings.activeUser()),
      $Card: Card,
      $$Acl: Acl,
      $Preferences: Preferences,
      $query: {search: 'name_or_address', value: '', sort: 'c_cn', asc: 1},
      activeUser: Settings.activeUser(),
      selectedFolder: null,
      $refreshTimeout: null
    });
    // Initialize sort parameters from user's settings
    Preferences.ready().then(function() {
      if (Preferences.settings.Contact.SortingState) {
        AddressBook.$query.sort = Preferences.settings.Contact.SortingState[0];
        AddressBook.$query.asc = parseInt(Preferences.settings.Contact.SortingState[1]);
      }
    });
    return AddressBook; // return constructor
  }];

  /**
   * @module SOGo.ContactsUI
   * @desc Factory registration of AddressBook in Angular module.
   */
  try {
    angular.module('SOGo.ContactsUI');
  }
  catch(e) {
    angular.module('SOGo.ContactsUI', ['SOGo.Common', 'SOGo.PreferencesUI']);
  }
  angular.module('SOGo.ContactsUI')
    .factory('AddressBook', AddressBook.$factory);

  /**
   * @memberof AddressBook
   * @desc Search for cards among all addressbooks matching some criterias.
   * @param {string} search - the search string to match
   * @param {object} [options] - additional options to the query (excludeGroups and excludeLists)
   * @param {object[]} excludedCards - a list of Card objects that must be excluded from the results
   * @returns a collection of Cards instances
   */
  AddressBook.$filterAll = function(search, options, excludedCards) {
    var params = {search: search};

    if (!search) {
      // No query specified
      AddressBook.$cards = [];
      return AddressBook.$q.when(AddressBook.$cards);
    }
    if (angular.isUndefined(AddressBook.$cards)) {
      // First session query
      AddressBook.$cards = [];
    }
    else if (AddressBook.$query.value == search) {
      // Query hasn't changed
      return AddressBook.$q.when(AddressBook.$cards);
    }
    AddressBook.$query.value = search;

    angular.extend(params, options);

    return AddressBook.$$resource.fetch(null, 'allContactSearch', params).then(function(response) {
      var results, card, index,
          compareIds = function(data) {
            return this.id == data.id;
          };
      if (excludedCards) {
        // Remove excluded cards from results
        results = _.filter(response.contacts, function(data) {
          return _.isUndefined(_.find(excludedCards, compareIds, data));
        });
      }
      else {
        results = response.contacts;
      }
      // Remove cards that no longer match the search query
      for (index = AddressBook.$cards.length - 1; index >= 0; index--) {
        card = AddressBook.$cards[index];
        if (_.isUndefined(_.find(results, compareIds, card))) {
          AddressBook.$cards.splice(index, 1);
        }
      }
      // Add new cards matching the search query
      _.each(results, function(data, index) {
        if (_.isUndefined(_.find(AddressBook.$cards, compareIds, data))) {
          var card = new AddressBook.$Card(data, search);
          AddressBook.$cards.splice(index, 0, card);
        }
      });
      AddressBook.$log.debug(AddressBook.$cards);
      return AddressBook.$cards;
    });
  };

  /**
   * @memberof AddressBook
   * @desc Add a new addressbook to the static list of addressbooks
   * @param {AddressBook} addressbook - an Addressbook object instance
   */
  AddressBook.$add = function(addressbook) {
    // Insert new addressbook at proper index
    var list, sibling, i;

    list = addressbook.isSubscription? this.$subscriptions : this.$addressbooks;
    sibling = _.find(list, function(o) {
      return (addressbook.id == 'personal' ||
              (o.id != 'personal' &&
               o.name.localeCompare(addressbook.name) === 1));
    });
    i = sibling ? _.indexOf(_.pluck(list, 'id'), sibling.id) : 1;
    list.splice(i, 0, addressbook);
  };

  /**
   * @memberof AddressBook
   * @desc Set or get the list of addressbooks. Will instantiate a new AddressBook object for each item.
   * @param {array} [data] - the metadata of the addressbooks
   * @returns the list of addressbooks
   */
  AddressBook.$findAll = function(data) {
    var _this = this;
    if (data) {
      this.$addressbooks = [];
      this.$subscriptions = [];
      this.$remotes = [];
      // Instanciate AddressBook objects
      angular.forEach(data, function(o, i) {
        var addressbook = new AddressBook(o);
        if (addressbook.isRemote)
          _this.$remotes.push(addressbook);
        else if (addressbook.isSubscription)
          _this.$subscriptions.push(addressbook);
        else
          _this.$addressbooks.push(addressbook);
      });
    }
    return _.union(this.$addressbooks, this.$subscriptions, this.$remotes);
  };

  /**
   * @memberOf AddressBook
   * @desc Fetch list of cards and return an AddressBook instance.
   * @param {string} addressbookId - the addressbook identifier
   * @returns an AddressBook object instance
   */
  AddressBook.$find = function(addressbookId) {
    var futureAddressBookData = AddressBook.$Preferences.ready().then(function() {
      return AddressBook.$$resource.fetch(addressbookId, 'view', AddressBook.$query);
    });
    return new AddressBook(futureAddressBookData);
  };

  /**
   * @memberOf AddressBook
   * @desc Subscribe to another user's addressbook and add it to the list of addressbooks.
   * @param {string} uid - user id
   * @param {string} path - path of folder for specified user
   * @returns a promise of the HTTP query result
   */
  AddressBook.$subscribe = function(uid, path) {
    var _this = this;
    return AddressBook.$$resource.userResource(uid).fetch(path, 'subscribe').then(function(addressbookData) {
      var addressbook = new AddressBook(addressbookData);
      if (_.isUndefined(_.find(_this.$subscriptions, function(o) {
        return o.id == addressbookData.id;
      }))) {
        // Not already subscribed
        AddressBook.$add(addressbook);
      }
      return addressbook;
    });
  };

  /**
   * @function init
   * @memberof AddressBook.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of addressbook
   */
  AddressBook.prototype.init = function(data, options) {
    if (!this.$cards) {
      this.$isLoading = true;
      this.$cards = [];
      this.cards = [];
    }
    angular.extend(this, data);
    // Add 'isOwned' and 'isSubscription' attributes based on active user (TODO: add it server-side?)
    this.isOwned = AddressBook.activeUser.isSuperUser || this.owner == AddressBook.activeUser.login;
    this.isSubscription = !this.isRemote && this.owner != AddressBook.activeUser.login;
  };

  /**
   * @function $id
   * @memberof AddressBook.prototype
   * @desc Resolve the addressbook id.
   * @returns a promise of the addressbook id
   */
  AddressBook.prototype.$id = function() {
    if (this.id) {
      // Object already unwrapped
      return AddressBook.$q.when(this.id);
    }
    else {
      // Wait until object is unwrapped
      return this.$futureAddressBookData.then(function(addressbook) {
        return addressbook.id;
      });
    }
  };

  /**
   * @function isSelectedCard
   * @memberof AddressBook.prototype
   * @desc Check if the specified card is selected.
   * @param {string} CardId
   * @returns true if the specified card is selected
   */
  AddressBook.prototype.isSelectedCard = function(cardId) {
    return this.selectedCard == cardId;
  };

  /**
   * @function $selectedCount
   * @memberof AddressBook.prototype
   * @desc Return the number of cards selected by the user.
   * @returns the number of selected cards
   */
  AddressBook.prototype.$selectedCount = function() {
    var count;

    count = 0;
    if (this.cards) {
      count = (_.filter(this.cards, function(card) { return card.selected; })).length;
    }
    return count;
  };

  /**
   * @function $startRefreshTimeout
   * @memberof AddressBook.prototype
   * @desc Starts the refresh timeout for the current selected address book
   */
  AddressBook.prototype.$startRefreshTimeout = function() {
    var _this = this;

    if (AddressBook.$refreshTimeout)
      AddressBook.$timeout.cancel(AddressBook.$refreshTimeout);

    AddressBook.$Preferences.ready().then(function() {
      // Restart the refresh timer, if needed
      var refreshViewCheck = AddressBook.$Preferences.defaults.SOGoRefreshViewCheck;
      if (refreshViewCheck && refreshViewCheck != 'manually') {
        var f = angular.bind(_this, AddressBook.prototype.$reload);
        AddressBook.$refreshTimeout = AddressBook.$timeout(f, refreshViewCheck.timeInterval()*1000);
      }
    });
  };

  /**
   * @function $reload
   * @memberof AddressBook.prototype
   * @desc Reload list of cards
   * @returns a promise of the Cards instances
   */
  AddressBook.prototype.$reload = function() {
    var _this = this;

    this.$startRefreshTimeout();
    return this.$filter();
  };

    /**
   * @function $filter
   * @memberof AddressBook.prototype
   * @desc Search for cards matching some criterias
   * @param {string} search - the search string to match
   * @param {object} [options] - additional options to the query (dry, excludeList)
   * @returns a collection of Cards instances
   */
  AddressBook.prototype.$filter = function(search, options, excludedCards) {
    var _this = this, query;

    if (!options || !options.dry) {
      this.$isLoading = true;
      query = AddressBook.$query;
    }
    else if (options.dry) {
      // Don't keep a copy of the query in dry mode
      query = angular.copy(AddressBook.$query);
    }

    return AddressBook.$Preferences.ready().then(function() {
      if (options) {
        angular.extend(query, options);
        if (options.dry) {
          if (!search) {
            // No query specified
            _this.$cards = [];
            return AddressBook.$q.when(_this.$cards);
          }
        }
      }

      if (angular.isDefined(search))
        query.value = search;

      return _this.$id().then(function(addressbookId) {
        return AddressBook.$$resource.fetch(addressbookId, 'view', query);
      }).then(function(response) {
        var results, cards, card, index,
            compareIds = function(data) {
              return _this.id == data.id;
            };
        if (options && options.dry) {
          // Don't keep a copy of the resulting cards.
          // This is usefull when doing autocompletion.
          cards = _this.$cards;
        }
        else {
          cards = _this.cards;
        }
        if (excludedCards) {
          // Remove excluded cards from results
          results = _.filter(response.cards, function(card) {
            return _.isUndefined(_.find(excludedCards, compareIds, card));
          });
        }
        else {
          results = response.cards;
        }
        // Remove cards that no longer match the search query
        for (index = cards.length - 1; index >= 0; index--) {
          card = cards[index];
          if (_.isUndefined(_.find(results, compareIds, card))) {
            cards.splice(index, 1);
          }
        }
        // Add new cards matching the search query
        _.each(results, function(data, index) {
          if (_.isUndefined(_.find(cards, compareIds, data))) {
            var card = new AddressBook.$Card(data, search);
            cards.splice(index, 0, card);
          }
        });
        // Respect the order of the results
        _.each(results, function(data, index) {
          var oldIndex, removedCards;
          if (cards[index].id != data.id) {
            oldIndex = _.findIndex(cards, compareIds, data);
            removedCards = cards.splice(oldIndex, 1);
            cards.splice(index, 0, removedCards[0]);
          }
        });
        _this.$isLoading = false;
        return cards;
      });
    });
  };

  /**
   * @function $rename
   * @memberof AddressBook.prototype
   * @desc Rename the addressbook and keep the list sorted
   * @param {string} name - the new name
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$rename = function(name) {
    var i = _.indexOf(_.pluck(AddressBook.$addressbooks, 'id'), this.id);
    this.name = name;
    AddressBook.$addressbooks.splice(i, 1);
    AddressBook.$add(this);
    return this.$save();
  };

  /**
   * @function $delete
   * @memberof AddressBook.prototype
   * @desc Delete the addressbook from the server and the static list of addressbooks.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$delete = function() {
    var _this = this,
        d = AddressBook.$q.defer(),
        list,
        promise;

    if (this.isSubscription) {
      promise = AddressBook.$$resource.fetch(this.id, 'unsubscribe');
      list = AddressBook.$subscriptions;
    }
    else {
      promise = AddressBook.$$resource.remove(this.id);
      list = AddressBook.$addressbooks;
    }

    promise.then(function() {
      var i = _.indexOf(_.pluck(list, 'id'), _this.id);
      list.splice(i, 1);
      d.resolve();
    }, d.reject);
    return d.promise;
  };

  /**
   * @function $deleteCards
   * @memberof AddressBook.prototype
   * @desc Delete multiple cards from addressbook.
   * @return a promise of the HTTP operation
   */
  AddressBook.prototype.$deleteCards = function(cards) {

    var uids = _.map(cards, function(card) { return card.id; });
    var _this = this;
    
    return AddressBook.$$resource.post(this.id, 'batchDelete', {uids: uids}).then(function() {
      _this.cards = _.difference(_this.cards, cards);
    });
  };

  /**
   * @function $copyCards
   * @memberof AddressBook.prototype
   * @desc Copy multiple cards from addressbook to an other one.
   * @return a promise of the HTTP operation
   */
  AddressBook.prototype.$copyCards = function(cards, folder) {
    var uids = _.map(cards, function(card) { return card.id; });
    return AddressBook.$$resource.post(this.id, 'copy', {uids: uids, folder: folder});
  };

  /**
   * @function $save
   * @memberof AddressBook.prototype
   * @desc Save the addressbook to the server. This currently can only affect the name of the addressbook.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$save = function() {
    return AddressBook.$$resource.save(this.id, this.$omit()).then(function(data) {
      return data;
    });
  };

  /**
   * @function $getCard
   * @memberof AddressBook.prototype
   * @desc Fetch the card attributes from the server.
   * @returns a promise of the HTTP operation
   */
  AddressBook.prototype.$getCard = function(cardId) {
    var _this = this;

    return this.$id().then(function(addressbookId) {
      var fullCard,
          cachedCard = _.find(_this.cards, function(data) {
            return cardId == data.id;
          });

      if (cachedCard && cachedCard.$futureCardData)
        // Full card is available
        return cachedCard;

      fullCard = AddressBook.$Card.$find(addressbookId, cardId);
      fullCard.$id().then(function(cardId) {
        // Extend the Card object of the addressbook list with the full card description
        if (cachedCard)
          angular.extend(cachedCard, fullCard);
      });
      return fullCard;
    });
  };

  /**
   * @function $unwrap
   * @memberof AddressBook.prototype
   * @desc Unwrap a promise and instanciate new Card objects using received data.
   * @param {promise} futureAddressBookData - a promise of the AddressBook's data
   */
  AddressBook.prototype.$unwrap = function(futureAddressBookData) {
    var _this = this;

    // Expose and resolve the promise
    this.$futureAddressBookData = futureAddressBookData.then(function(data) {
      return AddressBook.$timeout(function() {
        // Extend AddressBook instance from data of addressbooks list.
        // Will inherit attributes such as isEditable and isRemote.
        angular.forEach(AddressBook.$findAll(), function(o, i) {
          if (o.id == data.id) {
            angular.extend(_this, o);
          }
        });
        // Extend AddressBook instance with received data
        _this.init(data);
        // Instanciate Card objects
        angular.forEach(_this.cards, function(o, i) {
          _this.cards[i] = new AddressBook.$Card(o);
        });
        // Instanciate Acl object
        _this.$acl = new AddressBook.$$Acl('Contacts/' + _this.id);

        _this.$startRefreshTimeout();

        _this.$isLoading = false;

        return _this;
      });
    }, function(data) {
      _this.isError = true;
      if (angular.isObject(data)) {
        AddressBook.$timeout(function() {
          angular.extend(_this, data);
        });
      }
    });
  };

  /**
   * @function $omit
   * @memberof AddressBook.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Addressbook instance
   */
  AddressBook.prototype.$omit = function() {
    var addressbook = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          key != 'cards' &&
          key[0] != '$') {
        addressbook[key] = value;
      }
    });
    return addressbook;
  };
})();
