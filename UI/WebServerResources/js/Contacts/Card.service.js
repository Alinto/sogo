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
  Card.$factory = ['$q', '$timeout', 'sgSettings', 'sgCard_STATUS', 'Resource', 'Preferences', function($q, $timeout, Settings, Card_STATUS, Resource, Preferences) {
    angular.extend(Card, {
      STATUS: Card_STATUS,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Contacts', Settings.activeUser()),
      $q: $q,
      $timeout: $timeout,
      $Preferences: Preferences
    });
    // Initialize categories from user's defaults
    if (Preferences.defaults.SOGoContactsCategories) {
      Card.$categories = Preferences.defaults.SOGoContactsCategories;
    }
    if (Preferences.defaults.SOGoAlternateAvatar)
      Card.$alternateAvatar = Preferences.defaults.SOGoAlternateAvatar;

    return Card; // return constructor
  }];

  /**
   * @module SOGo.ContactsUI
   * @desc Factory registration of Card in Angular module.
   */
  try {
    angular.module('SOGo.ContactsUI');
  }
  catch(e) {
    angular.module('SOGo.ContactsUI', ['SOGo.Common', 'SOGo.PreferencesUI']);
  }
  angular.module('SOGo.ContactsUI')
    .constant('sgCard_STATUS', {
      NOT_LOADED:      0,
      DELAYED_LOADING: 1,
      LOADING:         2,
      LOADED:          3,
      DELAYED_MS:      300
    })
    .factory('Card', Card.$factory);

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
    return _.map(_.filter(Card.$categories, function(category) {
      return category.search(re) != -1;
    }), function(category) {
      return { value: category };
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
    var _this = this;

    if (angular.isUndefined(this.refs))
      this.refs = [];
    if (angular.isUndefined(this.categories))
      this.categories = [];
    this.c_screenname = null;
    angular.extend(this, data);
    if (!this.$$fullname)
      this.$$fullname = this.$fullname();
    if (!this.$$email)
      this.$$email = this.$preferredEmail(partial);
    if (!this.$$image)
      this.$$image = this.image;
    if (!this.$$image)
      this.$$image = Card.$Preferences.avatar(this.$$email, 40, {no_404: true});
    if (this.hasphoto)
      this.photoURL = Card.$$resource.path(this.pid, this.id, 'photo');
    if (this.isgroup)
      this.c_component = 'vlist';
    this.$avatarIcon = this.$isList()? 'group' : 'person';
    if (data.orgs && data.orgs.length)
      this.orgs = _.map(data.orgs, function(org) { return { 'value': org }; });
    if (data.notes && data.notes.length)
      this.notes = _.map(data.notes, function(note) { return { 'value': note }; });
    else if (!this.notes || !this.notes.length)
      this.notes = [ { value: '' } ];
    // Lowercase the type of specific fields
    angular.forEach(['addresses', 'phones', 'urls'], function(key) {
      angular.forEach(_this[key], function(o) {
        if (o.type) o.type = o.type.toLowerCase();
      });
    });
    // Instanciate Card objects for list members
    angular.forEach(this.refs, function(o, i) {
      if (o.email) o.emails = [{value: o.email}];
      o.id = o.reference;
      _this.refs[i] = new Card(o);
    });
    // Instanciate date object of birthday
    if (this.birthday && angular.isString(this.birthday)) {
      var dlp = Card.$Preferences.$mdDateLocaleProvider;
      this.birthday = this.birthday.parseDate(dlp, '%Y-%m-%d');
      this.$birthday = dlp.formatDate(this.birthday);
    }

    this.$loaded = angular.isDefined(this.c_name)? Card.STATUS.LOADED : Card.STATUS.NOT_LOADED;

    // An empty attribute to trick md-autocomplete when adding attendees from the appointment editor
    this.empty = ' ';
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
   * @function $isLoading
   * @memberof Card.prototype
   * @returns true if the Card definition is still being retrieved from server after a specific delay
   * @see sgCard_STATUS
   */
  Card.prototype.$isLoading = function() {
    return this.$loaded == Card.STATUS.LOADING;
  };

  /**
   * @function $reload
   * @memberof Message.prototype
   * @desc Fetch the viewable message body along with other metadata such as the list of attachments.
   * @returns a promise of the HTTP operation
   */
  Card.prototype.$reload = function() {
    var futureCardData;

    if (this.$futureCardData)
      return this;

    futureCardData = Card.$$resource.fetch([this.pid, this.id].join('/'), 'view');

    return this.$unwrap(futureCardData);
  };

  /**
   * @function $save
   * @memberof Card.prototype
   * @desc Save the card to the server.
   */
  Card.prototype.$save = function() {
    var _this = this,
        action = 'saveAsContact';

    if (this.c_component == 'vlist') {
      action = 'saveAsList';
      _.forEach(this.refs, function(ref) {
        ref.reference = ref.id;
      });
    }

    return Card.$$resource.save([this.pid, this.id || '_new_'].join('/'),
                                this.$omit(),
                                { action: action })
      .then(function(data) {
        // Format birthdate
        if (_this.birthday)
          _this.$birthday = Card.$Preferences.$mdDateLocaleProvider.formatDate(_this.birthday);
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
      else
        delete this[attribute];
    }
    else {
      // No arguments -- delete card
      return Card.$$resource.remove([this.pid, this.id].join('/'));
    }
  };

  /**
   * @function export
   * @memberof Card.prototype
   * @desc Download the current card
   * @returns a promise of the HTTP operation
   */
  Card.prototype.export = function() {
    var data, options;

    data = { uids: [ this.id ] };
    options = {
      type: 'application/octet-stream',
      filename: this.$$fullname + '.ldif'
    };

    return Card.$$resource.download(this.pid, 'export', data, options);
  };

  Card.prototype.$fullname = function(options) {
    var fn = this.c_cn || '', html = options && options.html, email, names;
    if (fn.length === 0) {
      names = [];
      if (this.c_givenname && this.c_givenname.length > 0)
        names.push(this.c_givenname);
      if (this.nickname && this.nickname.length > 0)
        names.push((html?'<em>':'') + this.nickname + (html?'</em>':''));
      if (this.c_sn && this.c_sn.length > 0)
        names.push(this.c_sn);
      if (names.length > 0)
        fn = names.join(' ');
      else if (this.org && this.org.length > 0) {
        fn = this.org;
      }
      else if (this.emails && this.emails.length > 0) {
        email = _.find(this.emails, function(i) { return i.value !== ''; });
        if (email)
          fn = email.value;
      }
    }
    if (this.contactinfo)
      fn += ' (' + this.contactinfo.split("\n").join("; ") + ')';

    return fn;
  };

  Card.prototype.$description = function() {
    var description = [];
    if (this.title) description.push(this.title);
    if (this.role) description.push(this.role);
    if (this.org) description.push(this.org);
    if (this.orgs) description = _.concat(description, _.map(this.orgs, 'value'));
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
      else if (this.c_mail && this.c_mail.length) {
        email = this.c_mail[0];
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
    var fullname = [this.$$fullname],
        email = this.$preferredEmail(partial);
    if (email && email != this.$$fullname)
      fullname.push(' <' + email + '>');
    return fullname.join(' ');
  };

  Card.prototype.$isCard = function() {
    return this.c_component == 'vcard';
  };

  Card.prototype.$isList = function(options) {
    // isGroup attribute means it's a group of a LDAP source (not expandable on the client-side)
    var condition = (!options || !options.expandable || options.expandable && !this.isgroup);
    return this.c_component == 'vlist' && condition;
  };

  Card.prototype.$addOrg = function(org) {
    if (angular.isUndefined(this.orgs)) {
      this.orgs = [org];
    }
    else if (org != this.org && !_.includes(this.orgs, org)) {
      this.orgs.push(org);
    }
    return this.orgs.length - 1;
  };

  // Card.prototype.$addCategory = function(category) {
  //   if (category) {
  //     if (angular.isUndefined(this.categories)) {
  //       this.categories = [{value: category}];
  //     }
  //     else {
  //       for (var i = 0; i < this.categories.length; i++) {
  //         if (this.categories[i].value == category) {
  //           break;
  //         }
  //       }
  //       if (i == this.categories.length)
  //         this.categories.push({value: category});
  //     }
  //   }
  // };

  Card.prototype.$addEmail = function(type) {
    if (angular.isUndefined(this.emails)) {
      this.emails = [{type: type, value: ''}];
    }
    else if (_.isUndefined(_.find(this.emails, function(i) { return i.value === ''; }))) {
      this.emails.push({type: type, value: ''});
    }
    return this.emails.length - 1;
  };

  Card.prototype.$addScreenName = function(screenName) {
    this.c_screenname = screenName;
  };

  Card.prototype.$addPhone = function(type) {
    if (angular.isUndefined(this.phones)) {
      this.phones = [{type: type, value: ''}];
    }
    else if (_.isUndefined(_.find(this.phones, function(i) { return i.value === ''; }))) {
      this.phones.push({type: type, value: ''});
    }
    return this.phones.length - 1;
  };

  Card.prototype.$addUrl = function(type, url) {
    if (angular.isUndefined(this.urls)) {
      this.urls = [{type: type, value: url}];
    }
    else if (_.isUndefined(_.find(this.urls, function(i) { return i.value == url; }))) {
      this.urls.push({type: type, value: url});
    }
    return this.urls.length - 1;
  };

  Card.prototype.$addAddress = function(type, postoffice, street, street2, locality, region, country, postalcode) {
    if (angular.isUndefined(this.addresses)) {
      this.addresses = [{type: type, postoffice: postoffice, street: street, street2: street2, locality: locality, region: region, country: country, postalcode: postalcode}];
    }
    else if (!_.find(this.addresses, function(i) {
      return i.street == street &&
        i.street2 == street2 &&
        i.locality == locality &&
        i.country == country &&
        i.postalcode == postalcode;
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
    else if (email.length === 0) {
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
   * @function $certificate
   * @memberof Account.prototype
   * @desc View the S/MIME certificate details associated to the account.
   * @returns a promise of the HTTP operation
   */
  Card.prototype.$certificate = function() {
    var _this = this;

    if (this.hasCertificate) {
      if (this.$$certificate)
        return Card.$q.when(this.$$certificate);
      else {
        return Card.$$resource.fetch([this.pid, this.id].join('/'), 'certificate').then(function(data) {
          _this.$$certificate = data;
          return data;
        });
      }
    }
    else {
      return Card.$q.reject();
    }
  };

  /**
   * @function $removeCertificate
   * @memberof Account.prototype
   * @desc Remove any S/MIME certificate associated with the account.
   * @returns a promise of the HTTP operation
   */
  Card.prototype.$removeCertificate = function() {
    var _this = this;

    return Card.$$resource.fetch([this.pid, this.id].join('/'), 'removeCertificate').then(function() {
      _this.hasCertificate = false;
    });
  };

  /**
   * @function explode
   * @memberof Card.prototype
   * @desc Create a new Card associated to each email address of this card.
   * @return an array of Card instances
   */
  Card.prototype.explode = function() {
    var _this = this, cards = [], data;

    if (this.emails) {
      if (this.emails.length > 1) {
        data = this.$omit();
        _.forEach(this.emails, function(email) {
          var card = new Card(angular.extend({}, data, {emails: [email]}));
          cards.push(card);
        });
        return cards;
      }
      else
        return [this];
    }

    return [];
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
    this.init(this.$shadowData);
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
  // Card.prototype.$updateMember = function(index, email, card) {
  //   var ref = {
  //     email: email,
  //     emails: [{value: email}],
  //     reference: card.c_name,
  //     c_cn: card.$fullname()
  //   };
  //   this.refs[index] = new Card(ref);
  // };

  /**
   * @function $unwrap
   * @memberof Card.prototype
   * @desc Unwrap a promise and make a copy of the resolved data.
   * @param {object} futureCardData - a promise of the Card's data
   */
  Card.prototype.$unwrap = function(futureCardData) {
    var _this = this;

    // Card is not loaded yet
    this.$loaded = Card.STATUS.DELAYED_LOADING;
    Card.$timeout(function() {
      if (_this.$loaded != Card.STATUS.LOADED)
        _this.$loaded = Card.STATUS.LOADING;
    }, Card.STATUS.DELAYED_MS);

    // Expose the promise
    this.$futureCardData = futureCardData.then(function(data) {
      _this.init(data);
      // Mark card as loaded
      _this.$loaded = Card.STATUS.LOADED;
      // Make a copy of the data for an eventual reset
      _this.$shadowData = _this.$omit(true);

      return _this;
    });

    return this.$futureCardData;
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

    // We convert back our birthday object
    if (!deep) {
      if (card.birthday)
        card.birthday = card.birthday.format(Card.$Preferences.$mdDateLocaleProvider, '%Y-%m-%d');
      else
        card.birthday = '';
    }

    // We flatten the organizations to an array of strings
    if (this.orgs)
      card.orgs = _.map(this.orgs, 'value');

    // We flatten the notes to an array of strings
    if (this.notes)
      card.notes = _.map(this.notes, 'value');

    return card;
  };

  Card.prototype.toString = function() {
    var desc = this.id + ' ' + this.$$fullname;

    if (this.$$email)
      desc += ' <' + this.$$email + '>';

    return '[' + desc + ']';
  };
})();
