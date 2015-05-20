/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Card
   * @constructor
   * @param {object} futureCardData
   * @param {string} [partial]
   */
  function Card(futureCardData, partial) {

    // Data is immediately available
    if (typeof futureCardData.then !== 'function') {
      this.init(futureCardData, partial);
      if (this.pid && !this.id) {
        // Prepare for the creation of a new card;
        // Get UID from the server.
        var newCardData = Card.$$resource.newguid(this.pid);
        this.$unwrap(newCardData);
        this.isNew = true;
      }
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureCardData);
    }
  }

  Card.$TEL_TYPES = ['work', 'home', 'cell', 'fax', 'pager'];
  Card.$EMAIL_TYPES = ['work', 'home', 'pref'];
  Card.$URL_TYPES = ['work', 'home', 'pref'];
  Card.$ADDRESS_TYPES = ['work', 'home'];

  /**
   * @memberof Card
   * @desc The factory we'll use to register with Angular.
   * @returns the Card constructor
   */
  Card.$factory = ['$timeout', 'sgSettings', 'Resource', 'Gravatar', function($timeout, Settings, Resource, Gravatar) {
    angular.extend(Card, {
      $$resource: new Resource(Settings.activeUser.folderURL + 'Contacts', Settings.activeUser),
      $timeout: $timeout,
      $gravatar: Gravatar,
      $categories: window.UserDefaults.SOGoContactsCategories
    });

    return Card; // return constructor
  }];

  /**
   * @module SOGo.ContactsUI
   * @desc Factory registration of Card in Angular module.
   */
  angular.module('SOGo.ContactsUI')
    .factory('Card', Card.$factory)

  /**
   * @memberof Card
   * @desc Fetch a card from a specific addressbook.
   * @param {string} addressbookId - the addressbook ID
   * @param {string} cardId - the card ID
   * @see {@link AddressBook.$getCard}
   */
  Card.$find = function(addressbookId, cardId) {
    var futureCardData = this.$$resource.fetch([addressbookId, cardId].join('/'), 'view');

    if (cardId) return new Card(futureCardData); // a single card

    return Card.$unwrapCollection(futureCardData); // a collection of cards
  };

  /**
   * @function filterCategories
   * @memberof Card.prototype
   * @desc Search for categories matching some criterias
   * @param {string} search - the search string to match
   * @returns a collection of strings
   */
  Card.filterCategories = function(query) {
    var re = new RegExp(query, 'i');
    return _.filter(Card.$categories, function(category) {
      return category.search(re) != -1;
    });
  };

  /**
   * @memberof Card
   * @desc Unwrap to a collection of Card instances.
   * @param {object} futureCardData
   */
  Card.$unwrapCollection = function(futureCardData) {
    var collection = {};

    collection.$futureCardData = futureCardData;

    futureCardData.then(function(cards) {
      Card.$timeout(function() {
        angular.forEach(cards, function(data, index) {
          collection[data.id] = new Card(data);
        });
      });
    });

    return collection;
  };

  /**
   * @function init
   * @memberof Card.prototype
   * @desc Extend instance with required attributes and new data.
   * @param {object} data - attributes of card
   */
  Card.prototype.init = function(data, partial) {
    this.refs = [];
    angular.extend(this, data);
    if (!this.$$fullname)
      this.$$fullname = this.$fullname();
    if (!this.$$email)
      this.$$email = this.$preferredEmail();
    if (!this.$$image)
      this.$$image = this.image || Card.$gravatar(this.$preferredEmail(partial), 32);
    this.selected = false;
  };

  /**
   * @function $id
   * @memberof Card.prototype
   * @desc Return the card ID.
   * @returns the card ID
   */
  Card.prototype.$id = function() {
    return this.$futureCardData.then(function(data) {
      return data.id;
    });
  };

  /**
   * @function $save
   * @memberof Card.prototype
   * @desc Save the card to the server.
   */
  Card.prototype.$save = function() {
    var _this = this,
        action = 'saveAsContact';

    if (this.tag == 'vlist') action = 'saveAsList';

    return Card.$$resource.save([this.pid, this.id || '_new_'].join('/'),
                                this.$omit(),
                                { action: action })
      .then(function(data) {
        // Make a copy of the data for an eventual reset
        _this.$shadowData = _this.$omit(true);
        return data;
      });
  };

  Card.prototype.$delete = function(attribute, index) {
    if (attribute) {
      if (index > -1 && this[attribute].length > index) {
        this[attribute].splice(index, 1);
      }
    }
    else {
      // No arguments -- delete card
      return Card.$$resource.remove([this.pid, this.id].join('/'));
    }
  };

  Card.prototype.$fullname = function() {
    var fn = this.fn || '', names;
    if (fn.length == 0) {
      names = [];
      if (this.givenname && this.givenname.length > 0)
        names.push(this.givenname);
      if (this.nickname && this.nickname.length > 0)
        names.push('<em>' + this.nickname + '</em>');
      if (this.sn && this.sn.length > 0)
        names.push(this.sn);
      if (names.length > 0)
        fn = names.join(' ');
      else if (this.org && this.org.length > 0) {
        fn = this.org;
      }
      else if (this.emails && this.emails.length > 0) {
        fn = _.find(this.emails, function(i) { return i.value != ''; }).value;
      }
      else if (this.c_cn && this.c_cn.length > 0) {
        fn = this.c_cn;
      }
    }

    return fn;
  };

  Card.prototype.$description = function() {
    var description = [];
    if (this.title) description.push(this.title);
    if (this.role) description.push(this.role);
    if (this.orgUnits && this.orgUnits.length > 0)
      _.forEach(this.orgUnits, function(unit) {
        if (unit.value != '')
          description.push(unit.value);
      });
    if (this.org) description.push(this.org);
    if (this.description) description.push(this.description);

    return description.join(', ');
  };

  /**
   * @function $preferredEmail
   * @memberof Card.prototype
   * @desc Get the preferred email address.
   * @param {string} [partial] - a partial string that the email must match
   * @returns the first email address of type "pref" or the first address if none found
   */
  Card.prototype.$preferredEmail = function(partial) {
    var email, re;
    if (partial) {
      re = new RegExp(partial, 'i');
      email = _.find(this.emails, function(o) {
        return re.test(o.value);
      });
    }
    if (email) {
      email = email.value;
    }
    else {
      email = _.find(this.emails, function(o) {
        return o.type == 'pref';
      });
      if (email) {
        email = email.value;
      }
      else if (this.emails && this.emails.length) {
        email = this.emails[0].value;
      }
      else {
        email = '';
      }
    }

    return email;
  };

  /**
   * @function $shortFormat
   * @memberof Card.prototype
   * @param {string} [partial] - a partial string that the email must match
   * @returns the fullname along with a matching email address in parentheses
   */
  Card.prototype.$shortFormat = function(partial) {
    var fullname = this.$fullname(),
        email = this.$preferredEmail(partial);
    if (email && email != fullname)
      fullname += ' <' + email + '>';
    return fullname;
  };

  Card.prototype.$birthday = function() {
    return new Date(this.birthday * 1000);
  };

  Card.prototype.$isCard = function() {
    return this.tag == 'vcard';
  };

  Card.prototype.$isList = function() {
    return this.tag == 'vlist';
  };

  Card.prototype.$addOrgUnit = function(orgUnit) {
    if (angular.isUndefined(this.orgUnits)) {
      this.orgUnits = [{value: orgUnit}];
    }
    else {
      for (var i = 0; i < this.orgUnits.length; i++) {
        if (this.orgUnits[i].value == orgUnit) {
          break;
        }
      }
      if (i == this.orgUnits.length)
        this.orgUnits.push({value: orgUnit});
    }
    return this.orgUnits.length - 1;
  };

  Card.prototype.$addCategory = function(category) {
    if (angular.isUndefined(this.categories)) {
      this.categories = [{value: category}];
    }
    else {
      for (var i = 0; i < this.categories.length; i++) {
        if (this.categories[i].value == category) {
          break;
        }
      }
      if (i == this.categories.length)
        this.categories.push({value: category});
    }
  };

  Card.prototype.$addEmail = function(type) {
    if (angular.isUndefined(this.emails)) {
      this.emails = [{type: type, value: ''}];
    }
    else if (!_.find(this.emails, function(i) { return i.value == ''; })) {
      this.emails.push({type: type, value: ''});
    }
    return this.emails.length - 1;
  };

  Card.prototype.$addPhone = function(type) {
    if (angular.isUndefined(this.phones)) {
      this.phones = [{type: type, value: ''}];
    }
    else if (!_.find(this.phones, function(i) { return i.value == ''; })) {
      this.phones.push({type: type, value: ''});
    }
    return this.phones.length - 1;
  };

  Card.prototype.$addUrl = function(type, url) {
    if (angular.isUndefined(this.urls)) {
      this.urls = [{type: type, value: url}];
    }
    else if (!_.find(this.urls, function(i) { return i.value == url; })) {
      this.urls.push({type: type, value: url});
    }
    return this.urls.length - 1;
  };

  Card.prototype.$addAddress = function(type, postoffice, street, street2, locality, region, country, postalcode) {
    if (angular.isUndefined(this.addresses)) {
      this.addresses = [{type: type, postoffice: postoffice, street: street, street2: street2, locality: locality, region: region, country: country, postalcode: postalcode}];
    }
    else if (!_.find(this.addresses, function(i) {
      return i.street == street
        && i.street2 == street2
        && i.locality == locality
        && i.country == country
        && i.postalcode == postalcode;
    })) {
      this.addresses.push({type: type, postoffice: postoffice, street: street, street2: street2, locality: locality, region: region, country: country, postalcode: postalcode});
    }
    return this.addresses.length - 1;
  };

  Card.prototype.$addMember = function(email) {
    var card = new Card({email: email, emails: [{value: email}]}),
        i;
    if (angular.isUndefined(this.refs)) {
      this.refs = [card];
    }
    else if (email.length == 0) {
      this.refs.push(card);
    }
    else {
      for (i = 0; i < this.refs.length; i++) {
        if (this.refs[i].email == email) {
          break;
        }
      }
      if (i == this.refs.length)
        this.refs.push(card);
    }
    return this.refs.length - 1;
  };

  /**
   * @function $reset
   * @memberof Card.prototype
   * @desc Reset the original state the card's data.
   */
  Card.prototype.$reset = function() {
    var _this = this;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        delete _this[key];
      }
    });
    angular.extend(this, this.$shadowData);
    // Reinstanciate Card objects for list members
    angular.forEach(this.refs, function(o, i) {
      if (o.email) o.emails = [{value: o.email}];
      _this.refs[i] = new Card(o);
    });
    this.$shadowData = this.$omit(true);
  };

  /**
   * @function $updateMember
   * @memberof Card.prototype
   * @desc Update an existing list member from a Card instance.
   * A list member has the following attribtues:
   * - email
   * - reference
   * - fn
   * @param {number} index
   * @param {string} email
   * @param {Card} card
   */
  Card.prototype.$updateMember = function(index, email, card) {
    var ref = {
      email: email,
      emails: [{value: email}],
      reference: card.c_name,
      fn: card.$fullname()
    };
    this.refs[index] = new Card(ref);
  };

  /**
   * @function $unwrap
   * @memberof Card.prototype
   * @desc Unwrap a promise and make a copy of the resolved data.
   * @param {object} futureCardData - a promise of the Card's data
   */
  Card.prototype.$unwrap = function(futureCardData) {
    var _this = this;

    // Expose the promise
    this.$futureCardData = futureCardData;

    // Resolve the promise
    this.$futureCardData.then(function(data) {
      // Calling $timeout will force Angular to refresh the view
      Card.$timeout(function() {
        _this.init(data);
        // Instanciate Card objects for list members
        angular.forEach(_this.refs, function(o, i) {
          if (o.email) o.emails = [{value: o.email}];
          _this.refs[i] = new Card(o);
        });
        if (_this.birthday) {
          _this.birthday = new Date(_this.birthday * 1000);
        }
        // Make a copy of the data for an eventual reset
        _this.$shadowData = _this.$omit(true);
      });
    });
  };

  /**
   * @function $omit
   * @memberof Card.prototype
   * @desc Return a sanitized object used to send to the server.
   * @param {boolean} [deep] - make a deep copy if true
   * @return an object literal copy of the Card instance
   */
  Card.prototype.$omit = function(deep) {
    var card = {};
    angular.forEach(this, function(value, key) {
      if (key == 'refs') {
        card.refs = _.map(value, function(o) {
          return o.$omit(deep);
        });
      }
      else if (key != 'constructor' && key[0] != '$') {
        if (deep)
          card[key] = angular.copy(value);
        else
          card[key] = value;
      }
    });
    return card;
  };
})();
