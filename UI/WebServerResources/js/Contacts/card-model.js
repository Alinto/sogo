(function() {
    'use strict';

    /* Constructor */
    function Card(futureCardData) {

        // Data is immediately available
        if (typeof futureCardData.then !== 'function') {
            angular.extend(this, futureCardData);
            if (this.pid && !this.id) {
                // Prepare for the creation of a new card;
                // Get UID from the server.
                var newCardData = Card.$$resource.newguid(this.pid);
                this.$unwrap(newCardData);
            }
            return;
        }

        // The promise will be unwrapped first
        this.$unwrap(futureCardData);
    }

    Card.$tel_types = ['work', 'home', 'cell', 'fax', 'pager'];
    Card.$email_types = ['work', 'home', 'pref'];
    Card.$url_types = ['work', 'home', 'pref'];
    Card.$address_types = ['work', 'home'];

    /* The factory we'll use to register with Angular */
    Card.$factory = ['$timeout', 'sgSettings', 'sgResource', function($timeout, Settings, Resource) {
        angular.extend(Card, {
            $$resource: new Resource(Settings.baseURL),
            $timeout: $timeout
        });

        return Card; // return constructor
    }];

    /* Factory registration in Angular module */
    angular.module('SOGo.Contacts')
    .factory('sgCard', Card.$factory)

    // Directive to format a postal address
    .directive('sgAddress', function() {
        return {
            restrict: 'A',
            replace: true,
            scope: { data: '=sgAddress' },
            controller: ['$scope', function($scope) {
                $scope.addressLines = function(data) {
                    var lines = [];
                    if (data.street) lines.push(data.street);
                    if (data.street2) lines.push(data.street2);
                    var locality_region = [];
                    if (data.locality) locality_region.push(data.locality);
                    if (data.region) locality_region.push(data.region);
                    if (locality_region.length > 0) lines.push(locality_region.join(', '));
                    if (data.country) lines.push(data.country);
                    if (data.postalcode) lines.push(data.postalcode);
                    return lines.join('<br>');
                };
            }],
            template: '<address ng-bind-html="addressLines(data)"></address>'
        }
    });

    /* Fetch a card */
    Card.$find = function(addressbook_id, card_id) {
        var futureCardData = this.$$resource.find([addressbook_id, card_id].join('/'));

        if (card_id) return new Card(futureCardData); // a single card

        return Card.$unwrapCollection(futureCardData); // a collection of cards
    };

    /* Unwrap to a collection of Card instances */
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

    /* Instance methods */

    Card.prototype.$id = function() {
        return this.$futureCardData.then(function(data) {
            return data.id;
        });
    };

    Card.prototype.$save = function() {
        var action = 'saveAsContact';
        if (this.tag == 'VLIST') action = 'saveAsList';
        //var action = 'saveAs' + this.tag.substring(1).capitalize();
        return Card.$$resource.set([this.pid, this.id || '_new_'].join('/'),
                                   this.$omit(),
                                   { 'action': action })
            .then(function (data) {
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
        var fn = this.fn || '';
        if (fn.length == 0) {
            var names = [];
            if (this.givenname && this.givenname.length > 0)
                names.push(this.givenname);
            if (this.nickname && this.nickname.length > 0)
                names.push("<em>" + this.nickname + "</em>");
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

    Card.prototype.$preferredEmail = function() {
        var email = _.find(this.emails, function(o) {
            return o.type == 'pref';
        });
        if (email) {
            email = email.value;
        }
        else if (this.emails && this.emails.length) {
            email = this.emails[0].value;
        }

        return email;
    };

    Card.prototype.$birthday = function() {
        return new Date(this.birthday*1000);
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
        return this.categories.length - 1;
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

    // Unwrap a promise
    Card.prototype.$unwrap = function(futureCardData) {
        var self = this;

        this.$futureCardData = futureCardData;
        this.$futureCardData.then(function(data) {
            // The success callback. Calling _.extend from $timeout will wrap it into a try/catch call and return
            // a promise resolved immediately.
            Card.$timeout(function() {
                angular.extend(self, data);
            });
        });
    };

    // Return a sanitized object used to send to the server
    Card.prototype.$omit = function() {
        var card = {};
        angular.forEach(this, function(value, key) {
            if (key != 'constructor' && key[0] != '$') {
                card[key] = value;
            }
        });
        return card;
    };
})();
