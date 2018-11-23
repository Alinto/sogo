/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Resource
   * @constructor
   * @param {Object} $http - the Angular HTTP service
   * @param {Object} $q - the Angular promise/deferred service
   * @param {String} path - the base path of the external resource
   * @param {Object} options - extra attributes to be associated to the object
   */
  function Resource($http, $q, $window, $cookies, path, activeUser, options) {
    angular.extend(this, {
      _http: $http,
      _q: $q,
      _window: $window,
      _cookies: $cookies,
      _path: path,
      _activeUser: activeUser
    });
    angular.extend(this, options);
    // Trim trailing slash
    this._path = this._path.replace(/\/$/, '');
  }

  /**
   * @memberof Resource
   * @desc The factory we'll use to register with Angular.
   * @return a new Resource object
   */
  Resource.$factory =  ['$http', '$q', '$window', '$cookies', function($http, $q, $window, $cookies) {
    return function(path, activeUser, options) {
      return new Resource($http, $q, $window, $cookies, path, activeUser, options);
    };
  }];

  /**
   * @module SOGo.Common
   * @desc Factory registration of Resource in Angular module.
   */
  angular.module('SOGo.Common').factory('Resource', Resource.$factory);

  /**
   * @function userResource
   * @memberof Resource.prototype
   * @desc Create a new Resource object associated to a username different than the active user.
   * @param {String} uid - the user UID
   * @return a new Resource object
   */
  Resource.prototype.userResource = function(uid) {
    var path = _.compact(this._activeUser.folderURL.split('/'));

    if (uid)
      path.splice(path.length - 1, 1, escape(uid));

    return new Resource(this._http, this._q, this._window, this._cookies, '/' + path.join('/'), this._activeUser);
  };

  /**
   * @function path
   * @memberof Resource.prototype
   * @desc Create a URL of the resource context with any number of additional segments
   * @return an absolute URL
   */
  Resource.prototype.path = function() {
    var path = [this._path];

    if (arguments.length > 0)
      Array.prototype.push.apply(path, Array.prototype.slice.call(arguments));

    return path.join('/');
  };

  /**
   * @function fetch
   * @memberof Resource.prototype
   * @desc Fetch resource using a specific folder, action and/or parameters.
   * @param {string} folderId - the folder on which the action will be applied (ex: addressbook, calendar)
   * @param {string} action - the action to be used in the URL
   * @param {Object} params - Object parameters injected through the $http service
   * @return a promise
   */
  Resource.prototype.fetch = function(folderId, action, params) {
    var deferred = this._q.defer(),
        path = [this._path];
    if (folderId) path.push(folderId.split('/'));
    if (action)   path.push(action);
    path = _.compact(_.flatten(path)).join('/');

    this._http({
      method: 'GET',
      url: path,
      params: params
    })
      .then(function(response) {
        return deferred.resolve(response.data);
      }, deferred.reject);

    return deferred.promise;
  };

  /**
   * @function newguid
   * @memberof Resource.prototype
   * @desc Fetch a new GUID on the specified folder ID.
   * @return a promise of the new data structure
   */
  Resource.prototype.newguid = function(folderId) {
    var deferred = this._q.defer(),
        path = this._path + '/' + folderId + '/newguid';

    this._http
      .get(path)
      .then(function(response) {
        return deferred.resolve(response.data);
      }, deferred.reject);

    return deferred.promise;
  };

  /**
   * @function create
   * @memberof Resource.prototype
   * @desc Create a new resource using a specific action (post).
   * @param {string} action - the action to be used in the URL
   * @param {string} name - the new resource's name
   * @return a promise
   */
  Resource.prototype.create = function(action, name) {
    var deferred = this._q.defer(),
        path = this._path + '/' + action;

    this._http
      .post(path, { name: name })
      .then(function(response) {
        return deferred.resolve(response.data);
      }, deferred.reject);

    return deferred.promise;
  };

  /**
   * @function post
   * @memberof Resource.prototype
   * @desc Post a resource attributes on the server.
   * @return a promise
   */
  Resource.prototype.post = function(id, action, data) {
    var deferred = this._q.defer(),
        path = [this._path];
    if (id) path.push(id);
    if (action) path.push(action);
    path = _.compact(_.flatten(path)).join('/');

    this._http
      .post(path, data)
      .then(function(response) {
        return deferred.resolve(response.data);
      }, deferred.reject);

    return deferred.promise;
  };

  /**
   * @function save
   * @memberof Resource.prototype
   * @desc Save a resource attributes on the server (post /save).
   * @return a promise
   */
  Resource.prototype.save = function(id, newValue, options) {
    var action = (options && options.action)? options.action : 'save';

    return this.post(id, action, newValue);
  };

  /**
   * @function download
   * @memberof Resource.prototype
   * @desc Download a file from the server. Requires FileSaver.js.
   * @see {@link http://blog.davidjs.com/2015/07/download-files-via-post-request-in-angularjs/|Download files via POST request in AngularJs}
   * @see {@link https://github.com/eligrey/FileSaver.js|FileSaver.js}
   * @return a promise
   */
  Resource.prototype.download = function(id, action, data, options) {
    var deferred = this._q.defer(),
        type = (options && options.type)? options.type : 'application/zip',
        path = [this._path];
    if (id) path.push(id);
    if (action) path.push(action);
    path = _.compact(_.flatten(path)).join('/');

    function getFileNameFromHeader(header) {
      var result;

      if (!header) return null;
      result = header.split(";")[1].trim().split("=")[1];

      return result.replace(/"/g, '');
    }

    return this._http({
      method: 'POST',
      url: path,
      data: data,
      headers: {
        accept: type
      },
      responseType: 'arraybuffer',
      cache: false,
      transformResponse: function (data, headers, status) {
        var fileName, result, blob = null;

        if (status < 200 || status > 299) {
          throw new Error('Bad gateway');
        }
        if (data) {
          blob = new Blob([data], { type: type });
        }
        if (options && options.filename) {
          fileName = options.filename;
        }
        else {
          getFileNameFromHeader(headers('content-disposition'));
        }
        if (!saveAs) {
          throw new Error('To use Resource.download, FileSaver.js must be loaded.');
        }
        else {
          saveAs(blob, fileName);
        }
      }
    });
  };

  Resource.prototype.open = function(id, action) {
    var path = [this._path], xsrfToken;
    xsrfToken = this._cookies.get('XSRF-TOKEN');
    if (id) path.push(id);
    if (action) path.push(action);
    path = _.compact(_.flatten(path)).join('/');
    if (xsrfToken) {
      path += '?X-XSRF-TOKEN=' + xsrfToken;
    }

    this._window.location.href = path;
  };

  /**
   * @function remove
   * @memberof Resource.prototype
   * @desc Delete a resource (get /delete).
   * @return a promise
   */
  Resource.prototype.remove = function(uid) {
    var deferred = this._q.defer(),
        path = this._path + '/' + uid + '/delete';

    this._http
      .get(path)
      .then(function(response) {
        return deferred.resolve(response.data);
      }, deferred.reject);

    return deferred.promise;
  };

})();
