(function() {
    'use strict';

    /* Constructor */

    function Contact(futureContactData) {

        /* DATA IS IMMEDIATELY AVAILABLE */
        // if (!futureContactData.inspect) {
        //     angular.extend(this, futureContactData);
        //     return;
        // }

        /* THE PROMISE WILL BE UNWRAPPED FIRST */
        this.$unwrap(futureContactData);
    }

    Contact.$tel_types = [_('work'), 'home', 'cell', 'fax', 'pager'];
    Contact.$email_types = ['work', 'home', 'pref'];
    Contact.$url_types = ['work', 'home', 'pref'];
    Contact.$address_types = ['work', 'home'];

    /* THE FACTORY WE'LL USE TO REGISTER WITH ANGULAR */
    Contact.$factory = ['$timeout', 'sgSettings', 'sgResource', function($timeout, Settings, Resource) {
        angular.extend(Contact, {
            $$resource: new Resource(Settings.baseURL),
            $timeout: $timeout
        });

        return Contact; // return constructor
    }];

    /* ANGULAR MODULE REGISTRATION */
    angular.module('SOGo').factory('sgContact', Contact.$factory);

    /* FETCH A UNIT */
    Contact.$find = function(addressbook_id, contact_id) {

        /* FALLS BACK ON AN INSTANCE OF RESOURCE */
        // Fetch data over the wire.
        var futureContactData = this.$$resource.find([addressbook_id, contact_id].join('/'));

        if (contact_id) return new Contact(futureContactData); // a single contact

        return Contact.$unwrapCollection(futureContactData); // a collection of contacts
    };

    // Instance methods

    Contact.prototype.$id = function() {
        //var self = this;
        return this.$futureAddressBookData.then(function(data) {
            return data.id;
        });
    };

    // Unwrap a promise
    Contact.prototype.$unwrap = function(futureContactData) {
        var self = this;

        this.$futureContactData = futureContactData;
        this.$futureContactData.then(function(data) {
            // The success callback. Calling _.extend from $timeout will wrap it into a try/catch call.
            // I guess this is the only reason to do this.
            Contact.$timeout(function() {
                angular.extend(self, data);
            });
        });
    };

    Contact.prototype.$fullname = function() {
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
        }

        return fn;
    };

    Contact.prototype.$description = function() {
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

    Contact.prototype.$birthday = function() {
        return new Date(this.birthday*1000);
    };

    Contact.prototype.$isContact = function() {
        return this.tag == 'VCARD';
    };

    Contact.prototype.$isList = function() {
        return this.tag == 'VLIST';
    };

    Contact.prototype.$delete = function(attribute, index) {
        if (index > -1 && this[attribute].length > index) {
            this[attribute].splice(index, 1);
        }
    };

    Contact.prototype.$addOrgUnit = function(orgUnit) {
        if (angular.isUndefined(this.orgUnits)) {
            this.orgUnits = [{value: orgUnit}];
        }
        else {
            console.debug(angular.toJson(this.orgUnits));
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

    Contact.prototype.$addCategory = function(category) {
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

    Contact.prototype.$addEmail = function(type) {
        if (angular.isUndefined(this.emails)) {
            this.emails = [{type: type, value: ''}];
        }
        else if (!_.find(this.emails, function(i) { return i.value == ''; })) {
            this.emails.push({type: type, value: ''});
        }
        return this.emails.length - 1;
    };

    Contact.prototype.$addPhone = function(type) {
        if (angular.isUndefined(this.phones)) {
            this.phones = [{type: type, value: ''}];
        }
        else if (!_.find(this.phones, function(i) { return i.value == ''; })) {
            this.phones.push({type: type, value: ''});
        }
        return this.phones.length - 1;
    };

    Contact.prototype.$addUrl = function(type, url) {
        if (angular.isUndefined(this.urls)) {
            this.urls = [{type: type, value: url}];
        }
        else if (!_.find(this.urls, function(i) { return i.value == url; })) {
            this.urls.push({type: type, value: url});
        }
        return this.urls.length - 1;
    };

    Contact.prototype.$addAddress = function(type, postoffice, street, street2, locality, region, country, postalcode) {
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

    /* never call for now */
    Contact.$unwrapCollection = function(futureContactData) {
        var collection = {};

        collection.$futureContactData = futureContactData;

        futureContactData.then(function(contacts) {
            Contact.$timeout(function() {
                angular.forEach(contacts, function(data, index) {
                    collection[data.id] = new Contact(data);
                });
            });
        });

        return collection;
    };

    // $omit returns a sanitized object used to send to the server
    Contact.prototype.$omit = function() {
        var contact = {};
        angular.forEach(this, function(value, key) {
            if (key != 'constructor' && key[0] != '$') {
                contact[key] = value;
            }
        });
        console.debug(angular.toJson(contact));
        return contact;
    };

    Contact.prototype.$save = function() {
        return Contact.$$resource.set([this.pid, this.id].join('/'), this.$omit()).then(function (data) {
            return data;
        });
    };

})();
