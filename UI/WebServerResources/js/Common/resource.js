(function() {
    'use strict';

    /* Constructor  */
    function Resource($http, $q, path, options) {
        angular.extend(this, {
            _http: $http,
            _q: $q,
            _path: path
        });
        angular.extend(this, options);
    }

    /* The factory we'll use to register with Angular */
    Resource.$factory =  ['$http', '$q', function($http, $q) {
        return function(path, options) {
            return new Resource($http, $q, path, options);
        };
    }];

    /* Factory registration in Angular module */
    angular.module('SOGo.Common').factory('sgResource', Resource.$factory);

    /* Instance methods */

    Resource.prototype.path = function(uid) {
        return (uid ? this._path + '/' + uid : this._path) + '/view';
    };

    Resource.prototype.find = function(uid) {
        var deferred = this._q.defer();

        this._http
            .get(this.path(uid))
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.filter = function(uid, params) {
        var deferred = this._q.defer();

        this._http({
            method: 'GET',
            url: this.path(uid),
            params: params
        })
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.newguid = function(uid) {
        var deferred = this._q.defer();
        var path = this._path + '/' + uid + '/newguid';

        this._http
            .get(path)
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.set = function(uid, newValue, options) {
        var deferred = this._q.defer();
        var action = (options && options.action)? options.action : 'save';
        var path = this._path + '/' + uid + '/' + action;

        this._http
            .post(path, newValue)
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };

    Resource.prototype.remove = function(uid) {
        var deferred = this._q.defer();
        var path = this._path + '/' + uid + '/delete';

        this._http
            .get(path)
            .success(deferred.resolve)
            .error(deferred.reject);

        return deferred.promise;
    };
})();
