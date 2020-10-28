/**
 * State-based routing for AngularJS 1.x
 * NOTICE: This monolithic bundle also bundles the @uirouter/core code.
 *         This causes it to be incompatible with plugins that depend on @uirouter/core.
 *         We recommend switching to the ui-router-core.js and ui-router-angularjs.js bundles instead.
 *         For more information, see https://ui-router.github.io/blog/uirouter-for-angularjs-umd-bundles
 * @version v1.0.28
 * @link https://ui-router.github.io
 * @license MIT License, http://www.opensource.org/licenses/MIT
 */
(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('angular')) :
    typeof define === 'function' && define.amd ? define(['exports', 'angular'], factory) :
    (global = global || self, factory(global['@uirouter/angularjs'] = {}, global.angular));
}(this, (function (exports, ng_from_import) { 'use strict';

    /** @publicapi @module ng1 */ /** */
    /** @hidden */ var ng_from_global = angular;
    /** @hidden */ var ng = ng_from_import && ng_from_import.module ? ng_from_import : ng_from_global;

    /**
     * Higher order functions
     *
     * These utility functions are exported, but are subject to change without notice.
     *
     * @packageDocumentation
     */
    var __spreadArrays = (undefined && undefined.__spreadArrays) || function () {
        for (var s = 0, i = 0, il = arguments.length; i < il; i++) s += arguments[i].length;
        for (var r = Array(s), k = 0, i = 0; i < il; i++)
            for (var a = arguments[i], j = 0, jl = a.length; j < jl; j++, k++)
                r[k] = a[j];
        return r;
    };
    /**
     * Returns a new function for [Partial Application](https://en.wikipedia.org/wiki/Partial_application) of the original function.
     *
     * Given a function with N parameters, returns a new function that supports partial application.
     * The new function accepts anywhere from 1 to N parameters.  When that function is called with M parameters,
     * where M is less than N, it returns a new function that accepts the remaining parameters.  It continues to
     * accept more parameters until all N parameters have been supplied.
     *
     *
     * This contrived example uses a partially applied function as an predicate, which returns true
     * if an object is found in both arrays.
     * @example
     * ```
     * // returns true if an object is in both of the two arrays
     * function inBoth(array1, array2, object) {
     *   return array1.indexOf(object) !== -1 &&
     *          array2.indexOf(object) !== 1;
     * }
     * let obj1, obj2, obj3, obj4, obj5, obj6, obj7
     * let foos = [obj1, obj3]
     * let bars = [obj3, obj4, obj5]
     *
     * // A curried "copy" of inBoth
     * let curriedInBoth = curry(inBoth);
     * // Partially apply both the array1 and array2
     * let inFoosAndBars = curriedInBoth(foos, bars);
     *
     * // Supply the final argument; since all arguments are
     * // supplied, the original inBoth function is then called.
     * let obj1InBoth = inFoosAndBars(obj1); // false
     *
     * // Use the inFoosAndBars as a predicate.
     * // Filter, on each iteration, supplies the final argument
     * let allObjs = [ obj1, obj2, obj3, obj4, obj5, obj6, obj7 ];
     * let foundInBoth = allObjs.filter(inFoosAndBars); // [ obj3 ]
     *
     * ```
     *
     * @param fn
     * @returns {*|function(): (*|any)}
     */
    function curry(fn) {
        return function curried() {
            if (arguments.length >= fn.length) {
                return fn.apply(this, arguments);
            }
            var args = Array.prototype.slice.call(arguments);
            return curried.bind.apply(curried, __spreadArrays([this], args));
        };
    }
    /**
     * Given a varargs list of functions, returns a function that composes the argument functions, right-to-left
     * given: f(x), g(x), h(x)
     * let composed = compose(f,g,h)
     * then, composed is: f(g(h(x)))
     */
    function compose() {
        var args = arguments;
        var start = args.length - 1;
        return function () {
            var i = start, result = args[start].apply(this, arguments);
            while (i--)
                result = args[i].call(this, result);
            return result;
        };
    }
    /**
     * Given a varargs list of functions, returns a function that is composes the argument functions, left-to-right
     * given: f(x), g(x), h(x)
     * let piped = pipe(f,g,h);
     * then, piped is: h(g(f(x)))
     */
    function pipe() {
        var funcs = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            funcs[_i] = arguments[_i];
        }
        return compose.apply(null, [].slice.call(arguments).reverse());
    }
    /**
     * Given a property name, returns a function that returns that property from an object
     * let obj = { foo: 1, name: "blarg" };
     * let getName = prop("name");
     * getName(obj) === "blarg"
     */
    var prop = function (name) { return function (obj) { return obj && obj[name]; }; };
    /**
     * Given a property name and a value, returns a function that returns a boolean based on whether
     * the passed object has a property that matches the value
     * let obj = { foo: 1, name: "blarg" };
     * let getName = propEq("name", "blarg");
     * getName(obj) === true
     */
    var propEq = curry(function (name, _val, obj) { return obj && obj[name] === _val; });
    /**
     * Given a dotted property name, returns a function that returns a nested property from an object, or undefined
     * let obj = { id: 1, nestedObj: { foo: 1, name: "blarg" }, };
     * let getName = prop("nestedObj.name");
     * getName(obj) === "blarg"
     * let propNotFound = prop("this.property.doesnt.exist");
     * propNotFound(obj) === undefined
     */
    var parse = function (name) { return pipe.apply(null, name.split('.').map(prop)); };
    /**
     * Given a function that returns a truthy or falsey value, returns a
     * function that returns the opposite (falsey or truthy) value given the same inputs
     */
    var not = function (fn) { return function () {
        var args = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            args[_i] = arguments[_i];
        }
        return !fn.apply(null, args);
    }; };
    /**
     * Given two functions that return truthy or falsey values, returns a function that returns truthy
     * if both functions return truthy for the given arguments
     */
    function and(fn1, fn2) {
        return function () {
            var args = [];
            for (var _i = 0; _i < arguments.length; _i++) {
                args[_i] = arguments[_i];
            }
            return fn1.apply(null, args) && fn2.apply(null, args);
        };
    }
    /**
     * Given two functions that return truthy or falsey values, returns a function that returns truthy
     * if at least one of the functions returns truthy for the given arguments
     */
    function or(fn1, fn2) {
        return function () {
            var args = [];
            for (var _i = 0; _i < arguments.length; _i++) {
                args[_i] = arguments[_i];
            }
            return fn1.apply(null, args) || fn2.apply(null, args);
        };
    }
    /**
     * Check if all the elements of an array match a predicate function
     *
     * @param fn1 a predicate function `fn1`
     * @returns a function which takes an array and returns true if `fn1` is true for all elements of the array
     */
    var all = function (fn1) { return function (arr) { return arr.reduce(function (b, x) { return b && !!fn1(x); }, true); }; };
    // tslint:disable-next-line:variable-name
    var any = function (fn1) { return function (arr) { return arr.reduce(function (b, x) { return b || !!fn1(x); }, false); }; };
    /** Given a class, returns a Predicate function that returns true if the object is of that class */
    var is = function (ctor) { return function (obj) {
        return (obj != null && obj.constructor === ctor) || obj instanceof ctor;
    }; };
    /** Given a value, returns a Predicate function that returns true if another value is === equal to the original value */
    var eq = function (value) { return function (other) { return value === other; }; };
    /** Given a value, returns a function which returns the value */
    var val = function (v) { return function () { return v; }; };
    function invoke(fnName, args) {
        return function (obj) { return obj[fnName].apply(obj, args); };
    }
    /**
     * Sorta like Pattern Matching (a functional programming conditional construct)
     *
     * See http://c2.com/cgi/wiki?PatternMatching
     *
     * This is a conditional construct which allows a series of predicates and output functions
     * to be checked and then applied.  Each predicate receives the input.  If the predicate
     * returns truthy, then its matching output function (mapping function) is provided with
     * the input and, then the result is returned.
     *
     * Each combination (2-tuple) of predicate + output function should be placed in an array
     * of size 2: [ predicate, mapFn ]
     *
     * These 2-tuples should be put in an outer array.
     *
     * @example
     * ```
     *
     * // Here's a 2-tuple where the first element is the isString predicate
     * // and the second element is a function that returns a description of the input
     * let firstTuple = [ angular.isString, (input) => `Heres your string ${input}` ];
     *
     * // Second tuple: predicate "isNumber", mapfn returns a description
     * let secondTuple = [ angular.isNumber, (input) => `(${input}) That's a number!` ];
     *
     * let third = [ (input) => input === null,  (input) => `Oh, null...` ];
     *
     * let fourth = [ (input) => input === undefined,  (input) => `notdefined` ];
     *
     * let descriptionOf = pattern([ firstTuple, secondTuple, third, fourth ]);
     *
     * console.log(descriptionOf(undefined)); // 'notdefined'
     * console.log(descriptionOf(55)); // '(55) That's a number!'
     * console.log(descriptionOf("foo")); // 'Here's your string foo'
     * ```
     *
     * @param struct A 2D array.  Each element of the array should be an array, a 2-tuple,
     * with a Predicate and a mapping/output function
     * @returns {function(any): *}
     */
    function pattern(struct) {
        return function (x) {
            for (var i = 0; i < struct.length; i++) {
                if (struct[i][0](x))
                    return struct[i][1](x);
            }
        };
    }

    /**
     * Predicates
     *
     * These predicates return true/false based on the input.
     * Although these functions are exported, they are subject to change without notice.
     *
     * @packageDocumentation
     */
    var toStr = Object.prototype.toString;
    var tis = function (t) { return function (x) { return typeof x === t; }; };
    var isUndefined = tis('undefined');
    var isDefined = not(isUndefined);
    var isNull = function (o) { return o === null; };
    var isNullOrUndefined = or(isNull, isUndefined);
    var isFunction = tis('function');
    var isNumber = tis('number');
    var isString = tis('string');
    var isObject = function (x) { return x !== null && typeof x === 'object'; };
    var isArray = Array.isArray;
    var isDate = (function (x) { return toStr.call(x) === '[object Date]'; });
    var isRegExp = (function (x) { return toStr.call(x) === '[object RegExp]'; });
    /**
     * Predicate which checks if a value is injectable
     *
     * A value is "injectable" if it is a function, or if it is an ng1 array-notation-style array
     * where all the elements in the array are Strings, except the last one, which is a Function
     */
    function isInjectable(val) {
        if (isArray(val) && val.length) {
            var head = val.slice(0, -1), tail = val.slice(-1);
            return !(head.filter(not(isString)).length || tail.filter(not(isFunction)).length);
        }
        return isFunction(val);
    }
    /**
     * Predicate which checks if a value looks like a Promise
     *
     * It is probably a Promise if it's an object, and it has a `then` property which is a Function
     */
    var isPromise = and(isObject, pipe(prop('then'), isFunction));

    var noImpl = function (fnname) { return function () {
        throw new Error("No implementation for " + fnname + ". The framework specific code did not implement this method.");
    }; };
    var makeStub = function (service, methods) {
        return methods.reduce(function (acc, key) { return ((acc[key] = noImpl(service + "." + key + "()")), acc); }, {});
    };
    var services = {
        $q: undefined,
        $injector: undefined,
    };

    var __spreadArrays$1 = (undefined && undefined.__spreadArrays) || function () {
        for (var s = 0, i = 0, il = arguments.length; i < il; i++) s += arguments[i].length;
        for (var r = Array(s), k = 0, i = 0; i < il; i++)
            for (var a = arguments[i], j = 0, jl = a.length; j < jl; j++, k++)
                r[k] = a[j];
        return r;
    };
    var root = (typeof self === 'object' && self.self === self && self) ||
        (typeof global === 'object' && global.global === global && global) ||
        undefined;
    var angular$1 = root.angular || {};
    var fromJson = angular$1.fromJson || JSON.parse.bind(JSON);
    var toJson = angular$1.toJson || JSON.stringify.bind(JSON);
    var forEach = angular$1.forEach || _forEach;
    var extend = Object.assign || _extend;
    var equals = angular$1.equals || _equals;
    function identity(x) {
        return x;
    }
    function noop() { }
    /**
     * Builds proxy functions on the `to` object which pass through to the `from` object.
     *
     * For each key in `fnNames`, creates a proxy function on the `to` object.
     * The proxy function calls the real function on the `from` object.
     *
     *
     * #### Example:
     * This example creates an new class instance whose functions are prebound to the new'd object.
     * ```js
     * class Foo {
     *   constructor(data) {
     *     // Binds all functions from Foo.prototype to 'this',
     *     // then copies them to 'this'
     *     bindFunctions(Foo.prototype, this, this);
     *     this.data = data;
     *   }
     *
     *   log() {
     *     console.log(this.data);
     *   }
     * }
     *
     * let myFoo = new Foo([1,2,3]);
     * var logit = myFoo.log;
     * logit(); // logs [1, 2, 3] from the myFoo 'this' instance
     * ```
     *
     * #### Example:
     * This example creates a bound version of a service function, and copies it to another object
     * ```
     *
     * var SomeService = {
     *   this.data = [3, 4, 5];
     *   this.log = function() {
     *     console.log(this.data);
     *   }
     * }
     *
     * // Constructor fn
     * function OtherThing() {
     *   // Binds all functions from SomeService to SomeService,
     *   // then copies them to 'this'
     *   bindFunctions(SomeService, this, SomeService);
     * }
     *
     * let myOtherThing = new OtherThing();
     * myOtherThing.log(); // logs [3, 4, 5] from SomeService's 'this'
     * ```
     *
     * @param source A function that returns the source object which contains the original functions to be bound
     * @param target A function that returns the target object which will receive the bound functions
     * @param bind A function that returns the object which the functions will be bound to
     * @param fnNames The function names which will be bound (Defaults to all the functions found on the 'from' object)
     * @param latebind If true, the binding of the function is delayed until the first time it's invoked
     */
    function createProxyFunctions(source, target, bind, fnNames, latebind) {
        if (latebind === void 0) { latebind = false; }
        var bindFunction = function (fnName) { return source()[fnName].bind(bind()); };
        var makeLateRebindFn = function (fnName) {
            return function lateRebindFunction() {
                target[fnName] = bindFunction(fnName);
                return target[fnName].apply(null, arguments);
            };
        };
        fnNames = fnNames || Object.keys(source());
        return fnNames.reduce(function (acc, name) {
            acc[name] = latebind ? makeLateRebindFn(name) : bindFunction(name);
            return acc;
        }, target);
    }
    /**
     * prototypal inheritance helper.
     * Creates a new object which has `parent` object as its prototype, and then copies the properties from `extra` onto it
     */
    var inherit = function (parent, extra) { return extend(Object.create(parent), extra); };
    /** Given an array, returns true if the object is found in the array, (using indexOf) */
    var inArray = curry(_inArray);
    function _inArray(array, obj) {
        return array.indexOf(obj) !== -1;
    }
    /**
     * Given an array, and an item, if the item is found in the array, it removes it (in-place).
     * The same array is returned
     */
    var removeFrom = curry(_removeFrom);
    function _removeFrom(array, obj) {
        var idx = array.indexOf(obj);
        if (idx >= 0)
            array.splice(idx, 1);
        return array;
    }
    /** pushes a values to an array and returns the value */
    var pushTo = curry(_pushTo);
    function _pushTo(arr, val) {
        return arr.push(val), val;
    }
    /** Given an array of (deregistration) functions, calls all functions and removes each one from the source array */
    var deregAll = function (functions) {
        return functions.slice().forEach(function (fn) {
            typeof fn === 'function' && fn();
            removeFrom(functions, fn);
        });
    };
    /**
     * Applies a set of defaults to an options object.  The options object is filtered
     * to only those properties of the objects in the defaultsList.
     * Earlier objects in the defaultsList take precedence when applying defaults.
     */
    function defaults(opts) {
        var defaultsList = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            defaultsList[_i - 1] = arguments[_i];
        }
        var defaultVals = extend.apply(void 0, __spreadArrays$1([{}], defaultsList.reverse()));
        return extend(defaultVals, pick(opts || {}, Object.keys(defaultVals)));
    }
    /** Reduce function that merges each element of the list into a single object, using extend */
    var mergeR = function (memo, item) { return extend(memo, item); };
    /**
     * Finds the common ancestor path between two states.
     *
     * @param {Object} first The first state.
     * @param {Object} second The second state.
     * @return {Array} Returns an array of state names in descending order, not including the root.
     */
    function ancestors(first, second) {
        var path = [];
        // tslint:disable-next-line:forin
        for (var n in first.path) {
            if (first.path[n] !== second.path[n])
                break;
            path.push(first.path[n]);
        }
        return path;
    }
    /**
     * Return a copy of the object only containing the whitelisted properties.
     *
     * #### Example:
     * ```
     * var foo = { a: 1, b: 2, c: 3 };
     * var ab = pick(foo, ['a', 'b']); // { a: 1, b: 2 }
     * ```
     * @param obj the source object
     * @param propNames an Array of strings, which are the whitelisted property names
     */
    function pick(obj, propNames) {
        var objCopy = {};
        for (var _prop in obj) {
            if (propNames.indexOf(_prop) !== -1) {
                objCopy[_prop] = obj[_prop];
            }
        }
        return objCopy;
    }
    /**
     * Return a copy of the object omitting the blacklisted properties.
     *
     * @example
     * ```
     *
     * var foo = { a: 1, b: 2, c: 3 };
     * var ab = omit(foo, ['a', 'b']); // { c: 3 }
     * ```
     * @param obj the source object
     * @param propNames an Array of strings, which are the blacklisted property names
     */
    function omit(obj, propNames) {
        return Object.keys(obj)
            .filter(not(inArray(propNames)))
            .reduce(function (acc, key) { return ((acc[key] = obj[key]), acc); }, {});
    }
    /**
     * Maps an array, or object to a property (by name)
     */
    function pluck(collection, propName) {
        return map(collection, prop(propName));
    }
    /** Filters an Array or an Object's properties based on a predicate */
    function filter(collection, callback) {
        var arr = isArray(collection), result = arr ? [] : {};
        var accept = arr ? function (x) { return result.push(x); } : function (x, key) { return (result[key] = x); };
        forEach(collection, function (item, i) {
            if (callback(item, i))
                accept(item, i);
        });
        return result;
    }
    /** Finds an object from an array, or a property of an object, that matches a predicate */
    function find(collection, callback) {
        var result;
        forEach(collection, function (item, i) {
            if (result)
                return;
            if (callback(item, i))
                result = item;
        });
        return result;
    }
    /** Given an object, returns a new object, where each property is transformed by the callback function */
    var mapObj = map;
    /** Maps an array or object properties using a callback function */
    function map(collection, callback, target) {
        target = target || (isArray(collection) ? [] : {});
        forEach(collection, function (item, i) { return (target[i] = callback(item, i)); });
        return target;
    }
    /**
     * Given an object, return its enumerable property values
     *
     * @example
     * ```
     *
     * let foo = { a: 1, b: 2, c: 3 }
     * let vals = values(foo); // [ 1, 2, 3 ]
     * ```
     */
    var values = function (obj) { return Object.keys(obj).map(function (key) { return obj[key]; }); };
    /**
     * Reduce function that returns true if all of the values are truthy.
     *
     * @example
     * ```
     *
     * let vals = [ 1, true, {}, "hello world"];
     * vals.reduce(allTrueR, true); // true
     *
     * vals.push(0);
     * vals.reduce(allTrueR, true); // false
     * ```
     */
    var allTrueR = function (memo, elem) { return memo && elem; };
    /**
     * Reduce function that returns true if any of the values are truthy.
     *
     *  * @example
     * ```
     *
     * let vals = [ 0, null, undefined ];
     * vals.reduce(anyTrueR, true); // false
     *
     * vals.push("hello world");
     * vals.reduce(anyTrueR, true); // true
     * ```
     */
    var anyTrueR = function (memo, elem) { return memo || elem; };
    /**
     * Reduce function which un-nests a single level of arrays
     * @example
     * ```
     *
     * let input = [ [ "a", "b" ], [ "c", "d" ], [ [ "double", "nested" ] ] ];
     * input.reduce(unnestR, []) // [ "a", "b", "c", "d", [ "double, "nested" ] ]
     * ```
     */
    var unnestR = function (memo, elem) { return memo.concat(elem); };
    /**
     * Reduce function which recursively un-nests all arrays
     *
     * @example
     * ```
     *
     * let input = [ [ "a", "b" ], [ "c", "d" ], [ [ "double", "nested" ] ] ];
     * input.reduce(unnestR, []) // [ "a", "b", "c", "d", "double, "nested" ]
     * ```
     */
    var flattenR = function (memo, elem) {
        return isArray(elem) ? memo.concat(elem.reduce(flattenR, [])) : pushR(memo, elem);
    };
    /**
     * Reduce function that pushes an object to an array, then returns the array.
     * Mostly just for [[flattenR]] and [[uniqR]]
     */
    function pushR(arr, obj) {
        arr.push(obj);
        return arr;
    }
    /** Reduce function that filters out duplicates */
    var uniqR = function (acc, token) { return (inArray(acc, token) ? acc : pushR(acc, token)); };
    /**
     * Return a new array with a single level of arrays unnested.
     *
     * @example
     * ```
     *
     * let input = [ [ "a", "b" ], [ "c", "d" ], [ [ "double", "nested" ] ] ];
     * unnest(input) // [ "a", "b", "c", "d", [ "double, "nested" ] ]
     * ```
     */
    var unnest = function (arr) { return arr.reduce(unnestR, []); };
    /**
     * Return a completely flattened version of an array.
     *
     * @example
     * ```
     *
     * let input = [ [ "a", "b" ], [ "c", "d" ], [ [ "double", "nested" ] ] ];
     * flatten(input) // [ "a", "b", "c", "d", "double, "nested" ]
     * ```
     */
    var flatten = function (arr) { return arr.reduce(flattenR, []); };
    /**
     * Given a .filter Predicate, builds a .filter Predicate which throws an error if any elements do not pass.
     * @example
     * ```
     *
     * let isNumber = (obj) => typeof(obj) === 'number';
     * let allNumbers = [ 1, 2, 3, 4, 5 ];
     * allNumbers.filter(assertPredicate(isNumber)); //OK
     *
     * let oneString = [ 1, 2, 3, 4, "5" ];
     * oneString.filter(assertPredicate(isNumber, "Not all numbers")); // throws Error(""Not all numbers"");
     * ```
     */
    var assertPredicate = assertFn;
    /**
     * Given a .map function, builds a .map function which throws an error if any mapped elements do not pass a truthyness test.
     * @example
     * ```
     *
     * var data = { foo: 1, bar: 2 };
     *
     * let keys = [ 'foo', 'bar' ]
     * let values = keys.map(assertMap(key => data[key], "Key not found"));
     * // values is [1, 2]
     *
     * let keys = [ 'foo', 'bar', 'baz' ]
     * let values = keys.map(assertMap(key => data[key], "Key not found"));
     * // throws Error("Key not found")
     * ```
     */
    var assertMap = assertFn;
    function assertFn(predicateOrMap, errMsg) {
        if (errMsg === void 0) { errMsg = 'assert failure'; }
        return function (obj) {
            var result = predicateOrMap(obj);
            if (!result) {
                throw new Error(isFunction(errMsg) ? errMsg(obj) : errMsg);
            }
            return result;
        };
    }
    /**
     * Like _.pairs: Given an object, returns an array of key/value pairs
     *
     * @example
     * ```
     *
     * pairs({ foo: "FOO", bar: "BAR }) // [ [ "foo", "FOO" ], [ "bar": "BAR" ] ]
     * ```
     */
    var pairs = function (obj) { return Object.keys(obj).map(function (key) { return [key, obj[key]]; }); };
    /**
     * Given two or more parallel arrays, returns an array of tuples where
     * each tuple is composed of [ a[i], b[i], ... z[i] ]
     *
     * @example
     * ```
     *
     * let foo = [ 0, 2, 4, 6 ];
     * let bar = [ 1, 3, 5, 7 ];
     * let baz = [ 10, 30, 50, 70 ];
     * arrayTuples(foo, bar);       // [ [0, 1], [2, 3], [4, 5], [6, 7] ]
     * arrayTuples(foo, bar, baz);  // [ [0, 1, 10], [2, 3, 30], [4, 5, 50], [6, 7, 70] ]
     * ```
     */
    function arrayTuples() {
        var args = [];
        for (var _i = 0; _i < arguments.length; _i++) {
            args[_i] = arguments[_i];
        }
        if (args.length === 0)
            return [];
        var maxArrayLen = args.reduce(function (min, arr) { return Math.min(arr.length, min); }, 9007199254740991); // aka 2^53 − 1 aka Number.MAX_SAFE_INTEGER
        var result = [];
        var _loop_1 = function (i) {
            // This is a hot function
            // Unroll when there are 1-4 arguments
            switch (args.length) {
                case 1:
                    result.push([args[0][i]]);
                    break;
                case 2:
                    result.push([args[0][i], args[1][i]]);
                    break;
                case 3:
                    result.push([args[0][i], args[1][i], args[2][i]]);
                    break;
                case 4:
                    result.push([args[0][i], args[1][i], args[2][i], args[3][i]]);
                    break;
                default:
                    result.push(args.map(function (array) { return array[i]; }));
                    break;
            }
        };
        for (var i = 0; i < maxArrayLen; i++) {
            _loop_1(i);
        }
        return result;
    }
    /**
     * Reduce function which builds an object from an array of [key, value] pairs.
     *
     * Each iteration sets the key/val pair on the memo object, then returns the memo for the next iteration.
     *
     * Each keyValueTuple should be an array with values [ key: string, value: any ]
     *
     * @example
     * ```
     *
     * var pairs = [ ["fookey", "fooval"], ["barkey", "barval"] ]
     *
     * var pairsToObj = pairs.reduce((memo, pair) => applyPairs(memo, pair), {})
     * // pairsToObj == { fookey: "fooval", barkey: "barval" }
     *
     * // Or, more simply:
     * var pairsToObj = pairs.reduce(applyPairs, {})
     * // pairsToObj == { fookey: "fooval", barkey: "barval" }
     * ```
     */
    function applyPairs(memo, keyValTuple) {
        var key, value;
        if (isArray(keyValTuple))
            key = keyValTuple[0], value = keyValTuple[1];
        if (!isString(key))
            throw new Error('invalid parameters to applyPairs');
        memo[key] = value;
        return memo;
    }
    /** Get the last element of an array */
    function tail(arr) {
        return (arr.length && arr[arr.length - 1]) || undefined;
    }
    /**
     * shallow copy from src to dest
     */
    function copy(src, dest) {
        if (dest)
            Object.keys(dest).forEach(function (key) { return delete dest[key]; });
        if (!dest)
            dest = {};
        return extend(dest, src);
    }
    /** Naive forEach implementation works with Objects or Arrays */
    function _forEach(obj, cb, _this) {
        if (isArray(obj))
            return obj.forEach(cb, _this);
        Object.keys(obj).forEach(function (key) { return cb(obj[key], key); });
    }
    function _extend(toObj) {
        for (var i = 1; i < arguments.length; i++) {
            var obj = arguments[i];
            if (!obj)
                continue;
            var keys = Object.keys(obj);
            for (var j = 0; j < keys.length; j++) {
                toObj[keys[j]] = obj[keys[j]];
            }
        }
        return toObj;
    }
    function _equals(o1, o2) {
        if (o1 === o2)
            return true;
        if (o1 === null || o2 === null)
            return false;
        if (o1 !== o1 && o2 !== o2)
            return true; // NaN === NaN
        var t1 = typeof o1, t2 = typeof o2;
        if (t1 !== t2 || t1 !== 'object')
            return false;
        var tup = [o1, o2];
        if (all(isArray)(tup))
            return _arraysEq(o1, o2);
        if (all(isDate)(tup))
            return o1.getTime() === o2.getTime();
        if (all(isRegExp)(tup))
            return o1.toString() === o2.toString();
        if (all(isFunction)(tup))
            return true; // meh
        var predicates = [isFunction, isArray, isDate, isRegExp];
        if (predicates.map(any).reduce(function (b, fn) { return b || !!fn(tup); }, false))
            return false;
        var keys = {};
        // tslint:disable-next-line:forin
        for (var key in o1) {
            if (!_equals(o1[key], o2[key]))
                return false;
            keys[key] = true;
        }
        for (var key in o2) {
            if (!keys[key])
                return false;
        }
        return true;
    }
    function _arraysEq(a1, a2) {
        if (a1.length !== a2.length)
            return false;
        return arrayTuples(a1, a2).reduce(function (b, t) { return b && _equals(t[0], t[1]); }, true);
    }
    // issue #2676
    var silenceUncaughtInPromise = function (promise) { return promise.catch(function (e) { return 0; }) && promise; };
    var silentRejection = function (error) { return silenceUncaughtInPromise(services.$q.reject(error)); };

    /**
     * Matches state names using glob-like pattern strings.
     *
     * Globs can be used in specific APIs including:
     *
     * - [[StateService.is]]
     * - [[StateService.includes]]
     * - The first argument to Hook Registration functions like [[TransitionService.onStart]]
     *    - [[HookMatchCriteria]] and [[HookMatchCriterion]]
     *
     * A `Glob` string is a pattern which matches state names.
     * Nested state names are split into segments (separated by a dot) when processing.
     * The state named `foo.bar.baz` is split into three segments ['foo', 'bar', 'baz']
     *
     * Globs work according to the following rules:
     *
     * ### Exact match:
     *
     * The glob `'A.B'` matches the state named exactly `'A.B'`.
     *
     * | Glob        |Matches states named|Does not match state named|
     * |:------------|:--------------------|:---------------------|
     * | `'A'`       | `'A'`               | `'B'` , `'A.C'`      |
     * | `'A.B'`     | `'A.B'`             | `'A'` , `'A.B.C'`    |
     * | `'foo'`     | `'foo'`             | `'FOO'` , `'foo.bar'`|
     *
     * ### Single star (`*`)
     *
     * A single star (`*`) is a wildcard that matches exactly one segment.
     *
     * | Glob        |Matches states named  |Does not match state named |
     * |:------------|:---------------------|:--------------------------|
     * | `'*'`       | `'A'` , `'Z'`        | `'A.B'` , `'Z.Y.X'`       |
     * | `'A.*'`     | `'A.B'` , `'A.C'`    | `'A'` , `'A.B.C'`         |
     * | `'A.*.*'`   | `'A.B.C'` , `'A.X.Y'`| `'A'`, `'A.B'` , `'Z.Y.X'`|
     *
     * ### Double star (`**`)
     *
     * A double star (`'**'`) is a wildcard that matches *zero or more segments*
     *
     * | Glob        |Matches states named                           |Does not match state named         |
     * |:------------|:----------------------------------------------|:----------------------------------|
     * | `'**'`      | `'A'` , `'A.B'`, `'Z.Y.X'`                    | (matches all states)              |
     * | `'A.**'`    | `'A'` , `'A.B'` , `'A.C.X'`                   | `'Z.Y.X'`                         |
     * | `'**.X'`    | `'X'` , `'A.X'` , `'Z.Y.X'`                   | `'A'` , `'A.login.Z'`             |
     * | `'A.**.X'`  | `'A.X'` , `'A.B.X'` , `'A.B.C.X'`             | `'A'` , `'A.B.C'`                 |
     *
     * @packageDocumentation
     */
    var Glob = /** @class */ (function () {
        function Glob(text) {
            this.text = text;
            this.glob = text.split('.');
            var regexpString = this.text
                .split('.')
                .map(function (seg) {
                if (seg === '**')
                    return '(?:|(?:\\.[^.]*)*)';
                if (seg === '*')
                    return '\\.[^.]*';
                return '\\.' + seg;
            })
                .join('');
            this.regexp = new RegExp('^' + regexpString + '$');
        }
        /** Returns true if the string has glob-like characters in it */
        Glob.is = function (text) {
            return !!/[!,*]+/.exec(text);
        };
        /** Returns a glob from the string, or null if the string isn't Glob-like */
        Glob.fromString = function (text) {
            return Glob.is(text) ? new Glob(text) : null;
        };
        Glob.prototype.matches = function (name) {
            return this.regexp.test('.' + name);
        };
        return Glob;
    }());

    var Queue = /** @class */ (function () {
        function Queue(_items, _limit) {
            if (_items === void 0) { _items = []; }
            if (_limit === void 0) { _limit = null; }
            this._items = _items;
            this._limit = _limit;
            this._evictListeners = [];
            this.onEvict = pushTo(this._evictListeners);
        }
        Queue.prototype.enqueue = function (item) {
            var items = this._items;
            items.push(item);
            if (this._limit && items.length > this._limit)
                this.evict();
            return item;
        };
        Queue.prototype.evict = function () {
            var item = this._items.shift();
            this._evictListeners.forEach(function (fn) { return fn(item); });
            return item;
        };
        Queue.prototype.dequeue = function () {
            if (this.size())
                return this._items.splice(0, 1)[0];
        };
        Queue.prototype.clear = function () {
            var current = this._items;
            this._items = [];
            return current;
        };
        Queue.prototype.size = function () {
            return this._items.length;
        };
        Queue.prototype.remove = function (item) {
            var idx = this._items.indexOf(item);
            return idx > -1 && this._items.splice(idx, 1)[0];
        };
        Queue.prototype.peekTail = function () {
            return this._items[this._items.length - 1];
        };
        Queue.prototype.peekHead = function () {
            if (this.size())
                return this._items[0];
        };
        return Queue;
    }());

    /** An enum for Transition Rejection reasons */

    (function (RejectType) {
        /**
         * A new transition superseded this one.
         *
         * While this transition was running, a new transition started.
         * This transition is cancelled because it was superseded by new transition.
         */
        RejectType[RejectType["SUPERSEDED"] = 2] = "SUPERSEDED";
        /**
         * The transition was aborted
         *
         * The transition was aborted by a hook which returned `false`
         */
        RejectType[RejectType["ABORTED"] = 3] = "ABORTED";
        /**
         * The transition was invalid
         *
         * The transition was never started because it was invalid
         */
        RejectType[RejectType["INVALID"] = 4] = "INVALID";
        /**
         * The transition was ignored
         *
         * The transition was ignored because it would have no effect.
         *
         * Either:
         *
         * - The transition is targeting the current state and parameter values
         * - The transition is targeting the same state and parameter values as the currently running transition.
         */
        RejectType[RejectType["IGNORED"] = 5] = "IGNORED";
        /**
         * The transition errored.
         *
         * This generally means a hook threw an error or returned a rejected promise
         */
        RejectType[RejectType["ERROR"] = 6] = "ERROR";
    })(exports.RejectType || (exports.RejectType = {}));
    /** @internal */
    var id = 0;
    var Rejection = /** @class */ (function () {
        function Rejection(type, message, detail) {
            /** @internal */
            this.$id = id++;
            this.type = type;
            this.message = message;
            this.detail = detail;
        }
        /** Returns true if the obj is a rejected promise created from the `asPromise` factory */
        Rejection.isRejectionPromise = function (obj) {
            return obj && typeof obj.then === 'function' && is(Rejection)(obj._transitionRejection);
        };
        /** Returns a Rejection due to transition superseded */
        Rejection.superseded = function (detail, options) {
            var message = 'The transition has been superseded by a different transition';
            var rejection = new Rejection(exports.RejectType.SUPERSEDED, message, detail);
            if (options && options.redirected) {
                rejection.redirected = true;
            }
            return rejection;
        };
        /** Returns a Rejection due to redirected transition */
        Rejection.redirected = function (detail) {
            return Rejection.superseded(detail, { redirected: true });
        };
        /** Returns a Rejection due to invalid transition */
        Rejection.invalid = function (detail) {
            var message = 'This transition is invalid';
            return new Rejection(exports.RejectType.INVALID, message, detail);
        };
        /** Returns a Rejection due to ignored transition */
        Rejection.ignored = function (detail) {
            var message = 'The transition was ignored';
            return new Rejection(exports.RejectType.IGNORED, message, detail);
        };
        /** Returns a Rejection due to aborted transition */
        Rejection.aborted = function (detail) {
            var message = 'The transition has been aborted';
            return new Rejection(exports.RejectType.ABORTED, message, detail);
        };
        /** Returns a Rejection due to aborted transition */
        Rejection.errored = function (detail) {
            var message = 'The transition errored';
            return new Rejection(exports.RejectType.ERROR, message, detail);
        };
        /**
         * Returns a Rejection
         *
         * Normalizes a value as a Rejection.
         * If the value is already a Rejection, returns it.
         * Otherwise, wraps and returns the value as a Rejection (Rejection type: ERROR).
         *
         * @returns `detail` if it is already a `Rejection`, else returns an ERROR Rejection.
         */
        Rejection.normalize = function (detail) {
            return is(Rejection)(detail) ? detail : Rejection.errored(detail);
        };
        Rejection.prototype.toString = function () {
            var detailString = function (d) { return (d && d.toString !== Object.prototype.toString ? d.toString() : stringify(d)); };
            var detail = detailString(this.detail);
            var _a = this, $id = _a.$id, type = _a.type, message = _a.message;
            return "Transition Rejection($id: " + $id + " type: " + type + ", message: " + message + ", detail: " + detail + ")";
        };
        Rejection.prototype.toPromise = function () {
            return extend(silentRejection(this), { _transitionRejection: this });
        };
        return Rejection;
    }());

    /**
     * Functions that manipulate strings
     *
     * Although these functions are exported, they are subject to change without notice.
     *
     * @packageDocumentation
     */
    /**
     * Returns a string shortened to a maximum length
     *
     * If the string is already less than the `max` length, return the string.
     * Else return the string, shortened to `max - 3` and append three dots ("...").
     *
     * @param max the maximum length of the string to return
     * @param str the input string
     */
    function maxLength(max, str) {
        if (str.length <= max)
            return str;
        return str.substr(0, max - 3) + '...';
    }
    /**
     * Returns a string, with spaces added to the end, up to a desired str length
     *
     * If the string is already longer than the desired length, return the string.
     * Else returns the string, with extra spaces on the end, such that it reaches `length` characters.
     *
     * @param length the desired length of the string to return
     * @param str the input string
     */
    function padString(length, str) {
        while (str.length < length)
            str += ' ';
        return str;
    }
    function kebobString(camelCase) {
        return camelCase
            .replace(/^([A-Z])/, function ($1) { return $1.toLowerCase(); }) // replace first char
            .replace(/([A-Z])/g, function ($1) { return '-' + $1.toLowerCase(); }); // replace rest
    }
    function functionToString(fn) {
        var fnStr = fnToString(fn);
        var namedFunctionMatch = fnStr.match(/^(function [^ ]+\([^)]*\))/);
        var toStr = namedFunctionMatch ? namedFunctionMatch[1] : fnStr;
        var fnName = fn['name'] || '';
        if (fnName && toStr.match(/function \(/)) {
            return 'function ' + fnName + toStr.substr(9);
        }
        return toStr;
    }
    function fnToString(fn) {
        var _fn = isArray(fn) ? fn.slice(-1)[0] : fn;
        return (_fn && _fn.toString()) || 'undefined';
    }
    var isRejection = Rejection.isRejectionPromise;
    var hasToString = function (obj) {
        return isObject(obj) && !isArray(obj) && obj.constructor !== Object && isFunction(obj.toString);
    };
    var stringifyPattern = pattern([
        [isUndefined, val('undefined')],
        [isNull, val('null')],
        [isPromise, val('[Promise]')],
        [isRejection, function (x) { return x._transitionRejection.toString(); }],
        [hasToString, function (x) { return x.toString(); }],
        [isInjectable, functionToString],
        [val(true), identity],
    ]);
    function stringify(o) {
        var seen = [];
        function format(value) {
            if (isObject(value)) {
                if (seen.indexOf(value) !== -1)
                    return '[circular ref]';
                seen.push(value);
            }
            return stringifyPattern(value);
        }
        if (isUndefined(o)) {
            // Workaround for IE & Edge Spec incompatibility where replacer function would not be called when JSON.stringify
            // is given `undefined` as value. To work around that, we simply detect `undefined` and bail out early by
            // manually stringifying it.
            return format(o);
        }
        return JSON.stringify(o, function (key, value) { return format(value); }).replace(/\\"/g, '"');
    }
    /** Returns a function that splits a string on a character or substring */
    var beforeAfterSubstr = function (char) { return function (str) {
        if (!str)
            return ['', ''];
        var idx = str.indexOf(char);
        if (idx === -1)
            return [str, ''];
        return [str.substr(0, idx), str.substr(idx + 1)];
    }; };
    var hostRegex = new RegExp('^(?:[a-z]+:)?//[^/]+/');
    var stripLastPathElement = function (str) { return str.replace(/\/[^/]*$/, ''); };
    var splitHash = beforeAfterSubstr('#');
    var splitQuery = beforeAfterSubstr('?');
    var splitEqual = beforeAfterSubstr('=');
    var trimHashVal = function (str) { return (str ? str.replace(/^#/, '') : ''); };
    /**
     * Splits on a delimiter, but returns the delimiters in the array
     *
     * #### Example:
     * ```js
     * var splitOnSlashes = splitOnDelim('/');
     * splitOnSlashes("/foo"); // ["/", "foo"]
     * splitOnSlashes("/foo/"); // ["/", "foo", "/"]
     * ```
     */
    function splitOnDelim(delim) {
        var re = new RegExp('(' + delim + ')', 'g');
        return function (str) { return str.split(re).filter(identity); };
    }
    /**
     * Reduce fn that joins neighboring strings
     *
     * Given an array of strings, returns a new array
     * where all neighboring strings have been joined.
     *
     * #### Example:
     * ```js
     * let arr = ["foo", "bar", 1, "baz", "", "qux" ];
     * arr.reduce(joinNeighborsR, []) // ["foobar", 1, "bazqux" ]
     * ```
     */
    function joinNeighborsR(acc, x) {
        if (isString(tail(acc)) && isString(x))
            return acc.slice(0, -1).concat(tail(acc) + x);
        return pushR(acc, x);
    }

    /**
     * workaround for missing console object in IE9 when dev tools haven't been opened o_O
     * @packageDocumentation
     */
    var noopConsoleStub = { log: noop, error: noop, table: noop };
    function ie9Console(console) {
        var bound = function (fn) { return Function.prototype.bind.call(fn, console); };
        return {
            log: bound(console.log),
            error: bound(console.log),
            table: bound(console.log),
        };
    }
    function fallbackConsole(console) {
        var log = console.log.bind(console);
        var error = console.error ? console.error.bind(console) : log;
        var table = console.table ? console.table.bind(console) : log;
        return { log: log, error: error, table: table };
    }
    function getSafeConsole() {
        // @ts-ignore
        var isIE9 = typeof document !== 'undefined' && document.documentMode && document.documentMode === 9;
        if (isIE9) {
            return window && window.console ? ie9Console(window.console) : noopConsoleStub;
        }
        else if (!console.table || !console.error) {
            return fallbackConsole(console);
        }
        else {
            return console;
        }
    }
    var safeConsole = getSafeConsole();

    /**
     * # Transition tracing (debug)
     *
     * Enable transition tracing to print transition information to the console,
     * in order to help debug your application.
     * Tracing logs detailed information about each Transition to your console.
     *
     * To enable tracing, import the [[Trace]] singleton and enable one or more categories.
     *
     * ### ES6
     * ```js
     * import {trace} from "@uirouter/core";
     * trace.enable(1, 5); // TRANSITION and VIEWCONFIG
     * ```
     *
     * ### CJS
     * ```js
     * let trace = require("@uirouter/core").trace;
     * trace.enable("TRANSITION", "VIEWCONFIG");
     * ```
     *
     * ### Globals
     * ```js
     * let trace = window["@uirouter/core"].trace;
     * trace.enable(); // Trace everything (very verbose)
     * ```
     *
     * ### Angular 1:
     * ```js
     * app.run($trace => $trace.enable());
     * ```
     *
     * @packageDocumentation
     */
    function uiViewString(uiview) {
        if (!uiview)
            return 'ui-view (defunct)';
        var state = uiview.creationContext ? uiview.creationContext.name || '(root)' : '(none)';
        return "[ui-view#" + uiview.id + " " + uiview.$type + ":" + uiview.fqn + " (" + uiview.name + "@" + state + ")]";
    }
    var viewConfigString = function (viewConfig) {
        var view = viewConfig.viewDecl;
        var state = view.$context.name || '(root)';
        return "[View#" + viewConfig.$id + " from '" + state + "' state]: target ui-view: '" + view.$uiViewName + "@" + view.$uiViewContextAnchor + "'";
    };
    function normalizedCat(input) {
        return isNumber(input) ? exports.Category[input] : exports.Category[exports.Category[input]];
    }
    /**
     * Trace categories Enum
     *
     * Enable or disable a category using [[Trace.enable]] or [[Trace.disable]]
     *
     * `trace.enable(Category.TRANSITION)`
     *
     * These can also be provided using a matching string, or position ordinal
     *
     * `trace.enable("TRANSITION")`
     *
     * `trace.enable(1)`
     */

    (function (Category) {
        Category[Category["RESOLVE"] = 0] = "RESOLVE";
        Category[Category["TRANSITION"] = 1] = "TRANSITION";
        Category[Category["HOOK"] = 2] = "HOOK";
        Category[Category["UIVIEW"] = 3] = "UIVIEW";
        Category[Category["VIEWCONFIG"] = 4] = "VIEWCONFIG";
    })(exports.Category || (exports.Category = {}));
    var _tid = parse('$id');
    var _rid = parse('router.$id');
    var transLbl = function (trans) { return "Transition #" + _tid(trans) + "-" + _rid(trans); };
    /**
     * Prints UI-Router Transition trace information to the console.
     */
    var Trace = /** @class */ (function () {
        /** @internal */
        function Trace() {
            /** @internal */
            this._enabled = {};
            this.approximateDigests = 0;
        }
        /** @internal */
        Trace.prototype._set = function (enabled, categories) {
            var _this = this;
            if (!categories.length) {
                categories = Object.keys(exports.Category)
                    .map(function (k) { return parseInt(k, 10); })
                    .filter(function (k) { return !isNaN(k); })
                    .map(function (key) { return exports.Category[key]; });
            }
            categories.map(normalizedCat).forEach(function (category) { return (_this._enabled[category] = enabled); });
        };
        Trace.prototype.enable = function () {
            var categories = [];
            for (var _i = 0; _i < arguments.length; _i++) {
                categories[_i] = arguments[_i];
            }
            this._set(true, categories);
        };
        Trace.prototype.disable = function () {
            var categories = [];
            for (var _i = 0; _i < arguments.length; _i++) {
                categories[_i] = arguments[_i];
            }
            this._set(false, categories);
        };
        /**
         * Retrieves the enabled stateus of a [[Category]]
         *
         * ```js
         * trace.enabled("VIEWCONFIG"); // true or false
         * ```
         *
         * @returns boolean true if the category is enabled
         */
        Trace.prototype.enabled = function (category) {
            return !!this._enabled[normalizedCat(category)];
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceTransitionStart = function (trans) {
            if (!this.enabled(exports.Category.TRANSITION))
                return;
            safeConsole.log(transLbl(trans) + ": Started  -> " + stringify(trans));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceTransitionIgnored = function (trans) {
            if (!this.enabled(exports.Category.TRANSITION))
                return;
            safeConsole.log(transLbl(trans) + ": Ignored  <> " + stringify(trans));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceHookInvocation = function (step, trans, options) {
            if (!this.enabled(exports.Category.HOOK))
                return;
            var event = parse('traceData.hookType')(options) || 'internal', context = parse('traceData.context.state.name')(options) || parse('traceData.context')(options) || 'unknown', name = functionToString(step.registeredHook.callback);
            safeConsole.log(transLbl(trans) + ":   Hook -> " + event + " context: " + context + ", " + maxLength(200, name));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceHookResult = function (hookResult, trans, transitionOptions) {
            if (!this.enabled(exports.Category.HOOK))
                return;
            safeConsole.log(transLbl(trans) + ":   <- Hook returned: " + maxLength(200, stringify(hookResult)));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceResolvePath = function (path, when, trans) {
            if (!this.enabled(exports.Category.RESOLVE))
                return;
            safeConsole.log(transLbl(trans) + ":         Resolving " + path + " (" + when + ")");
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceResolvableResolved = function (resolvable, trans) {
            if (!this.enabled(exports.Category.RESOLVE))
                return;
            safeConsole.log(transLbl(trans) + ":               <- Resolved  " + resolvable + " to: " + maxLength(200, stringify(resolvable.data)));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceError = function (reason, trans) {
            if (!this.enabled(exports.Category.TRANSITION))
                return;
            safeConsole.log(transLbl(trans) + ": <- Rejected " + stringify(trans) + ", reason: " + reason);
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceSuccess = function (finalState, trans) {
            if (!this.enabled(exports.Category.TRANSITION))
                return;
            safeConsole.log(transLbl(trans) + ": <- Success  " + stringify(trans) + ", final state: " + finalState.name);
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceUIViewEvent = function (event, viewData, extra) {
            if (extra === void 0) { extra = ''; }
            if (!this.enabled(exports.Category.UIVIEW))
                return;
            safeConsole.log("ui-view: " + padString(30, event) + " " + uiViewString(viewData) + extra);
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceUIViewConfigUpdated = function (viewData, context) {
            if (!this.enabled(exports.Category.UIVIEW))
                return;
            this.traceUIViewEvent('Updating', viewData, " with ViewConfig from context='" + context + "'");
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceUIViewFill = function (viewData, html) {
            if (!this.enabled(exports.Category.UIVIEW))
                return;
            this.traceUIViewEvent('Fill', viewData, " with: " + maxLength(200, html));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceViewSync = function (pairs) {
            if (!this.enabled(exports.Category.VIEWCONFIG))
                return;
            var uivheader = 'uiview component fqn';
            var cfgheader = 'view config state (view name)';
            var mapping = pairs
                .map(function (_a) {
                var _b;
                var uiView = _a.uiView, viewConfig = _a.viewConfig;
                var uiv = uiView && uiView.fqn;
                var cfg = viewConfig && viewConfig.viewDecl.$context.name + ": (" + viewConfig.viewDecl.$name + ")";
                return _b = {}, _b[uivheader] = uiv, _b[cfgheader] = cfg, _b;
            })
                .sort(function (a, b) { return (a[uivheader] || '').localeCompare(b[uivheader] || ''); });
            safeConsole.table(mapping);
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceViewServiceEvent = function (event, viewConfig) {
            if (!this.enabled(exports.Category.VIEWCONFIG))
                return;
            safeConsole.log("VIEWCONFIG: " + event + " " + viewConfigString(viewConfig));
        };
        /** @internal called by ui-router code */
        Trace.prototype.traceViewServiceUIViewEvent = function (event, viewData) {
            if (!this.enabled(exports.Category.VIEWCONFIG))
                return;
            safeConsole.log("VIEWCONFIG: " + event + " " + uiViewString(viewData));
        };
        return Trace;
    }());
    /**
     * The [[Trace]] singleton
     *
     * #### Example:
     * ```js
     * import {trace} from "@uirouter/core";
     * trace.enable(1, 5);
     * ```
     */
    var trace = new Trace();

    /**
     * An internal class which implements [[ParamTypeDefinition]].
     *
     * A [[ParamTypeDefinition]] is a plain javascript object used to register custom parameter types.
     * When a param type definition is registered, an instance of this class is created internally.
     *
     * This class has naive implementations for all the [[ParamTypeDefinition]] methods.
     *
     * Used by [[UrlMatcher]] when matching or formatting URLs, or comparing and validating parameter values.
     *
     * #### Example:
     * ```js
     * var paramTypeDef = {
     *   decode: function(val) { return parseInt(val, 10); },
     *   encode: function(val) { return val && val.toString(); },
     *   equals: function(a, b) { return this.is(a) && a === b; },
     *   is: function(val) { return angular.isNumber(val) && isFinite(val) && val % 1 === 0; },
     *   pattern: /\d+/
     * }
     *
     * var paramType = new ParamType(paramTypeDef);
     * ```
     */
    var ParamType = /** @class */ (function () {
        /**
         * @param def  A configuration object which contains the custom type definition.  The object's
         *        properties will override the default methods and/or pattern in `ParamType`'s public interface.
         * @returns a new ParamType object
         */
        function ParamType(def) {
            /** @inheritdoc */
            this.pattern = /.*/;
            /** @inheritdoc */
            this.inherit = true;
            extend(this, def);
        }
        // consider these four methods to be "abstract methods" that should be overridden
        /** @inheritdoc */
        ParamType.prototype.is = function (val, key) {
            return true;
        };
        /** @inheritdoc */
        ParamType.prototype.encode = function (val, key) {
            return val;
        };
        /** @inheritdoc */
        ParamType.prototype.decode = function (val, key) {
            return val;
        };
        /** @inheritdoc */
        ParamType.prototype.equals = function (a, b) {
            // tslint:disable-next-line:triple-equals
            return a == b;
        };
        ParamType.prototype.$subPattern = function () {
            var sub = this.pattern.toString();
            return sub.substr(1, sub.length - 2);
        };
        ParamType.prototype.toString = function () {
            return "{ParamType:" + this.name + "}";
        };
        /** Given an encoded string, or a decoded object, returns a decoded object */
        ParamType.prototype.$normalize = function (val) {
            return this.is(val) ? val : this.decode(val);
        };
        /**
         * Wraps an existing custom ParamType as an array of ParamType, depending on 'mode'.
         * e.g.:
         * - urlmatcher pattern "/path?{queryParam[]:int}"
         * - url: "/path?queryParam=1&queryParam=2
         * - $stateParams.queryParam will be [1, 2]
         * if `mode` is "auto", then
         * - url: "/path?queryParam=1 will create $stateParams.queryParam: 1
         * - url: "/path?queryParam=1&queryParam=2 will create $stateParams.queryParam: [1, 2]
         */
        ParamType.prototype.$asArray = function (mode, isSearch) {
            if (!mode)
                return this;
            if (mode === 'auto' && !isSearch)
                throw new Error("'auto' array mode is for query parameters only");
            return new ArrayType(this, mode);
        };
        return ParamType;
    }());
    /** Wraps up a `ParamType` object to handle array values. */
    function ArrayType(type, mode) {
        var _this = this;
        // Wrap non-array value as array
        function arrayWrap(val) {
            return isArray(val) ? val : isDefined(val) ? [val] : [];
        }
        // Unwrap array value for "auto" mode. Return undefined for empty array.
        function arrayUnwrap(val) {
            switch (val.length) {
                case 0:
                    return undefined;
                case 1:
                    return mode === 'auto' ? val[0] : val;
                default:
                    return val;
            }
        }
        // Wraps type (.is/.encode/.decode) functions to operate on each value of an array
        function arrayHandler(callback, allTruthyMode) {
            return function handleArray(val) {
                if (isArray(val) && val.length === 0)
                    return val;
                var arr = arrayWrap(val);
                var result = map(arr, callback);
                return allTruthyMode === true ? filter(result, function (x) { return !x; }).length === 0 : arrayUnwrap(result);
            };
        }
        // Wraps type (.equals) functions to operate on each value of an array
        function arrayEqualsHandler(callback) {
            return function handleArray(val1, val2) {
                var left = arrayWrap(val1), right = arrayWrap(val2);
                if (left.length !== right.length)
                    return false;
                for (var i = 0; i < left.length; i++) {
                    if (!callback(left[i], right[i]))
                        return false;
                }
                return true;
            };
        }
        ['encode', 'decode', 'equals', '$normalize'].forEach(function (name) {
            var paramTypeFn = type[name].bind(type);
            var wrapperFn = name === 'equals' ? arrayEqualsHandler : arrayHandler;
            _this[name] = wrapperFn(paramTypeFn);
        });
        extend(this, {
            dynamic: type.dynamic,
            name: type.name,
            pattern: type.pattern,
            inherit: type.inherit,
            raw: type.raw,
            is: arrayHandler(type.is.bind(type), true),
            $arrayMode: mode,
        });
    }

    var hasOwn = Object.prototype.hasOwnProperty;
    var isShorthand = function (cfg) {
        return ['value', 'type', 'squash', 'array', 'dynamic'].filter(hasOwn.bind(cfg || {})).length === 0;
    };

    (function (DefType) {
        DefType[DefType["PATH"] = 0] = "PATH";
        DefType[DefType["SEARCH"] = 1] = "SEARCH";
        DefType[DefType["CONFIG"] = 2] = "CONFIG";
    })(exports.DefType || (exports.DefType = {}));
    function getParamDeclaration(paramName, location, state) {
        var noReloadOnSearch = (state.reloadOnSearch === false && location === exports.DefType.SEARCH) || undefined;
        var dynamic = find([state.dynamic, noReloadOnSearch], isDefined);
        var defaultConfig = isDefined(dynamic) ? { dynamic: dynamic } : {};
        var paramConfig = unwrapShorthand(state && state.params && state.params[paramName]);
        return extend(defaultConfig, paramConfig);
    }
    function unwrapShorthand(cfg) {
        cfg = isShorthand(cfg) ? { value: cfg } : cfg;
        getStaticDefaultValue['__cacheable'] = true;
        function getStaticDefaultValue() {
            return cfg.value;
        }
        var $$fn = isInjectable(cfg.value) ? cfg.value : getStaticDefaultValue;
        return extend(cfg, { $$fn: $$fn });
    }
    function getType(cfg, urlType, location, id, paramTypes) {
        if (cfg.type && urlType && urlType.name !== 'string')
            throw new Error("Param '" + id + "' has two type configurations.");
        if (cfg.type && urlType && urlType.name === 'string' && paramTypes.type(cfg.type))
            return paramTypes.type(cfg.type);
        if (urlType)
            return urlType;
        if (!cfg.type) {
            var type = location === exports.DefType.CONFIG
                ? 'any'
                : location === exports.DefType.PATH
                    ? 'path'
                    : location === exports.DefType.SEARCH
                        ? 'query'
                        : 'string';
            return paramTypes.type(type);
        }
        return cfg.type instanceof ParamType ? cfg.type : paramTypes.type(cfg.type);
    }
    /** returns false, true, or the squash value to indicate the "default parameter url squash policy". */
    function getSquashPolicy(config, isOptional, defaultPolicy) {
        var squash = config.squash;
        if (!isOptional || squash === false)
            return false;
        if (!isDefined(squash) || squash == null)
            return defaultPolicy;
        if (squash === true || isString(squash))
            return squash;
        throw new Error("Invalid squash policy: '" + squash + "'. Valid policies: false, true, or arbitrary string");
    }
    function getReplace(config, arrayMode, isOptional, squash) {
        var defaultPolicy = [
            { from: '', to: isOptional || arrayMode ? undefined : '' },
            { from: null, to: isOptional || arrayMode ? undefined : '' },
        ];
        var replace = isArray(config.replace) ? config.replace : [];
        if (isString(squash))
            replace.push({ from: squash, to: undefined });
        var configuredKeys = map(replace, prop('from'));
        return filter(defaultPolicy, function (item) { return configuredKeys.indexOf(item.from) === -1; }).concat(replace);
    }
    var Param = /** @class */ (function () {
        function Param(id, type, location, urlConfig, state) {
            var config = getParamDeclaration(id, location, state);
            type = getType(config, type, location, id, urlConfig.paramTypes);
            var arrayMode = getArrayMode();
            type = arrayMode ? type.$asArray(arrayMode, location === exports.DefType.SEARCH) : type;
            var isOptional = config.value !== undefined || location === exports.DefType.SEARCH;
            var dynamic = isDefined(config.dynamic) ? !!config.dynamic : !!type.dynamic;
            var raw = isDefined(config.raw) ? !!config.raw : !!type.raw;
            var squash = getSquashPolicy(config, isOptional, urlConfig.defaultSquashPolicy());
            var replace = getReplace(config, arrayMode, isOptional, squash);
            var inherit = isDefined(config.inherit) ? !!config.inherit : !!type.inherit;
            // array config: param name (param[]) overrides default settings.  explicit config overrides param name.
            function getArrayMode() {
                var arrayDefaults = { array: location === exports.DefType.SEARCH ? 'auto' : false };
                var arrayParamNomenclature = id.match(/\[\]$/) ? { array: true } : {};
                return extend(arrayDefaults, arrayParamNomenclature, config).array;
            }
            extend(this, { id: id, type: type, location: location, isOptional: isOptional, dynamic: dynamic, raw: raw, squash: squash, replace: replace, inherit: inherit, array: arrayMode, config: config });
        }
        Param.values = function (params, values) {
            if (values === void 0) { values = {}; }
            var paramValues = {};
            for (var _i = 0, params_1 = params; _i < params_1.length; _i++) {
                var param = params_1[_i];
                paramValues[param.id] = param.value(values[param.id]);
            }
            return paramValues;
        };
        /**
         * Finds [[Param]] objects which have different param values
         *
         * Filters a list of [[Param]] objects to only those whose parameter values differ in two param value objects
         *
         * @param params: The list of Param objects to filter
         * @param values1: The first set of parameter values
         * @param values2: the second set of parameter values
         *
         * @returns any Param objects whose values were different between values1 and values2
         */
        Param.changed = function (params, values1, values2) {
            if (values1 === void 0) { values1 = {}; }
            if (values2 === void 0) { values2 = {}; }
            return params.filter(function (param) { return !param.type.equals(values1[param.id], values2[param.id]); });
        };
        /**
         * Checks if two param value objects are equal (for a set of [[Param]] objects)
         *
         * @param params The list of [[Param]] objects to check
         * @param values1 The first set of param values
         * @param values2 The second set of param values
         *
         * @returns true if the param values in values1 and values2 are equal
         */
        Param.equals = function (params, values1, values2) {
            if (values1 === void 0) { values1 = {}; }
            if (values2 === void 0) { values2 = {}; }
            return Param.changed(params, values1, values2).length === 0;
        };
        /** Returns true if a the parameter values are valid, according to the Param definitions */
        Param.validates = function (params, values) {
            if (values === void 0) { values = {}; }
            return params.map(function (param) { return param.validates(values[param.id]); }).reduce(allTrueR, true);
        };
        Param.prototype.isDefaultValue = function (value) {
            return this.isOptional && this.type.equals(this.value(), value);
        };
        /**
         * [Internal] Gets the decoded representation of a value if the value is defined, otherwise, returns the
         * default value, which may be the result of an injectable function.
         */
        Param.prototype.value = function (value) {
            var _this = this;
            /**
             * [Internal] Get the default value of a parameter, which may be an injectable function.
             */
            var getDefaultValue = function () {
                if (_this._defaultValueCache)
                    return _this._defaultValueCache.defaultValue;
                if (!services.$injector)
                    throw new Error('Injectable functions cannot be called at configuration time');
                var defaultValue = services.$injector.invoke(_this.config.$$fn);
                if (defaultValue !== null && defaultValue !== undefined && !_this.type.is(defaultValue))
                    throw new Error("Default value (" + defaultValue + ") for parameter '" + _this.id + "' is not an instance of ParamType (" + _this.type.name + ")");
                if (_this.config.$$fn['__cacheable']) {
                    _this._defaultValueCache = { defaultValue: defaultValue };
                }
                return defaultValue;
            };
            var replaceSpecialValues = function (val) {
                for (var _i = 0, _a = _this.replace; _i < _a.length; _i++) {
                    var tuple = _a[_i];
                    if (tuple.from === val)
                        return tuple.to;
                }
                return val;
            };
            value = replaceSpecialValues(value);
            return isUndefined(value) ? getDefaultValue() : this.type.$normalize(value);
        };
        Param.prototype.isSearch = function () {
            return this.location === exports.DefType.SEARCH;
        };
        Param.prototype.validates = function (value) {
            // There was no parameter value, but the param is optional
            if ((isUndefined(value) || value === null) && this.isOptional)
                return true;
            // The value was not of the correct ParamType, and could not be decoded to the correct ParamType
            var normalized = this.type.$normalize(value);
            if (!this.type.is(normalized))
                return false;
            // The value was of the correct type, but when encoded, did not match the ParamType's regexp
            var encoded = this.type.encode(normalized);
            return !(isString(encoded) && !this.type.pattern.exec(encoded));
        };
        Param.prototype.toString = function () {
            return "{Param:" + this.id + " " + this.type + " squash: '" + this.squash + "' optional: " + this.isOptional + "}";
        };
        return Param;
    }());

    /**
     * A registry for parameter types.
     *
     * This registry manages the built-in (and custom) parameter types.
     *
     * The built-in parameter types are:
     *
     * - [[string]]
     * - [[path]]
     * - [[query]]
     * - [[hash]]
     * - [[int]]
     * - [[bool]]
     * - [[date]]
     * - [[json]]
     * - [[any]]
     *
     * To register custom parameter types, use [[UrlConfig.type]], i.e.,
     *
     * ```js
     * router.urlService.config.type(customType)
     * ```
     */
    var ParamTypes = /** @class */ (function () {
        function ParamTypes() {
            this.enqueue = true;
            this.typeQueue = [];
            this.defaultTypes = pick(ParamTypes.prototype, [
                'hash',
                'string',
                'query',
                'path',
                'int',
                'bool',
                'date',
                'json',
                'any',
            ]);
            // Register default types. Store them in the prototype of this.types.
            var makeType = function (definition, name) { return new ParamType(extend({ name: name }, definition)); };
            this.types = inherit(map(this.defaultTypes, makeType), {});
        }
        ParamTypes.prototype.dispose = function () {
            this.types = {};
        };
        /**
         * Registers a parameter type
         *
         * End users should call [[UrlMatcherFactory.type]], which delegates to this method.
         */
        ParamTypes.prototype.type = function (name, definition, definitionFn) {
            if (!isDefined(definition))
                return this.types[name];
            if (this.types.hasOwnProperty(name))
                throw new Error("A type named '" + name + "' has already been defined.");
            this.types[name] = new ParamType(extend({ name: name }, definition));
            if (definitionFn) {
                this.typeQueue.push({ name: name, def: definitionFn });
                if (!this.enqueue)
                    this._flushTypeQueue();
            }
            return this;
        };
        ParamTypes.prototype._flushTypeQueue = function () {
            while (this.typeQueue.length) {
                var type = this.typeQueue.shift();
                if (type.pattern)
                    throw new Error("You cannot override a type's .pattern at runtime.");
                extend(this.types[type.name], services.$injector.invoke(type.def));
            }
        };
        return ParamTypes;
    }());
    function initDefaultTypes() {
        var makeDefaultType = function (def) {
            var valToString = function (val) { return (val != null ? val.toString() : val); };
            var defaultTypeBase = {
                encode: valToString,
                decode: valToString,
                is: is(String),
                pattern: /.*/,
                // tslint:disable-next-line:triple-equals
                equals: function (a, b) { return a == b; },
            };
            return extend({}, defaultTypeBase, def);
        };
        // Default Parameter Type Definitions
        extend(ParamTypes.prototype, {
            string: makeDefaultType({}),
            path: makeDefaultType({
                pattern: /[^/]*/,
            }),
            query: makeDefaultType({}),
            hash: makeDefaultType({
                inherit: false,
            }),
            int: makeDefaultType({
                decode: function (val) { return parseInt(val, 10); },
                is: function (val) {
                    return !isNullOrUndefined(val) && this.decode(val.toString()) === val;
                },
                pattern: /-?\d+/,
            }),
            bool: makeDefaultType({
                encode: function (val) { return (val && 1) || 0; },
                decode: function (val) { return parseInt(val, 10) !== 0; },
                is: is(Boolean),
                pattern: /0|1/,
            }),
            date: makeDefaultType({
                encode: function (val) {
                    return !this.is(val)
                        ? undefined
                        : [val.getFullYear(), ('0' + (val.getMonth() + 1)).slice(-2), ('0' + val.getDate()).slice(-2)].join('-');
                },
                decode: function (val) {
                    if (this.is(val))
                        return val;
                    var match = this.capture.exec(val);
                    return match ? new Date(match[1], match[2] - 1, match[3]) : undefined;
                },
                is: function (val) { return val instanceof Date && !isNaN(val.valueOf()); },
                equals: function (l, r) {
                    return ['getFullYear', 'getMonth', 'getDate'].reduce(function (acc, fn) { return acc && l[fn]() === r[fn](); }, true);
                },
                pattern: /[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[1-2][0-9]|3[0-1])/,
                capture: /([0-9]{4})-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])/,
            }),
            json: makeDefaultType({
                encode: toJson,
                decode: fromJson,
                is: is(Object),
                equals: equals,
                pattern: /[^/]*/,
            }),
            // does not encode/decode
            any: makeDefaultType({
                encode: identity,
                decode: identity,
                is: function () { return true; },
                equals: equals,
            }),
        });
    }
    initDefaultTypes();

    var StateParams = /** @class */ (function () {
        function StateParams(params) {
            if (params === void 0) { params = {}; }
            extend(this, params);
        }
        /**
         * Merges a set of parameters with all parameters inherited between the common parents of the
         * current state and a given destination state.
         *
         * @param {Object} newParams The set of parameters which will be composited with inherited params.
         * @param {Object} $current Internal definition of object representing the current state.
         * @param {Object} $to Internal definition of object representing state to transition to.
         */
        StateParams.prototype.$inherit = function (newParams, $current, $to) {
            var parentParams;
            var parents = ancestors($current, $to), inherited = {}, inheritList = [];
            for (var i in parents) {
                if (!parents[i] || !parents[i].params)
                    continue;
                parentParams = Object.keys(parents[i].params);
                if (!parentParams.length)
                    continue;
                for (var j in parentParams) {
                    if (inheritList.indexOf(parentParams[j]) >= 0)
                        continue;
                    inheritList.push(parentParams[j]);
                    inherited[parentParams[j]] = this[parentParams[j]];
                }
            }
            return extend({}, inherited, newParams);
        };
        return StateParams;
    }());

    /**
     * A node in a [[TreeChanges]] path
     *
     * For a [[TreeChanges]] path, this class holds the stateful information for a single node in the path.
     * Each PathNode corresponds to a state being entered, exited, or retained.
     * The stateful information includes parameter values and resolve data.
     */
    var PathNode = /** @class */ (function () {
        function PathNode(stateOrNode) {
            if (stateOrNode instanceof PathNode) {
                var node = stateOrNode;
                this.state = node.state;
                this.paramSchema = node.paramSchema.slice();
                this.paramValues = extend({}, node.paramValues);
                this.resolvables = node.resolvables.slice();
                this.views = node.views && node.views.slice();
            }
            else {
                var state = stateOrNode;
                this.state = state;
                this.paramSchema = state.parameters({ inherit: false });
                this.paramValues = {};
                this.resolvables = state.resolvables.map(function (res) { return res.clone(); });
            }
        }
        PathNode.prototype.clone = function () {
            return new PathNode(this);
        };
        /** Sets [[paramValues]] for the node, from the values of an object hash */
        PathNode.prototype.applyRawParams = function (params) {
            var getParamVal = function (paramDef) { return [paramDef.id, paramDef.value(params[paramDef.id])]; };
            this.paramValues = this.paramSchema.reduce(function (memo, pDef) { return applyPairs(memo, getParamVal(pDef)); }, {});
            return this;
        };
        /** Gets a specific [[Param]] metadata that belongs to the node */
        PathNode.prototype.parameter = function (name) {
            return find(this.paramSchema, propEq('id', name));
        };
        /**
         * @returns true if the state and parameter values for another PathNode are
         * equal to the state and param values for this PathNode
         */
        PathNode.prototype.equals = function (node, paramsFn) {
            var diff = this.diff(node, paramsFn);
            return diff && diff.length === 0;
        };
        /**
         * Finds Params with different parameter values on another PathNode.
         *
         * Given another node (of the same state), finds the parameter values which differ.
         * Returns the [[Param]] (schema objects) whose parameter values differ.
         *
         * Given another node for a different state, returns `false`
         *
         * @param node The node to compare to
         * @param paramsFn A function that returns which parameters should be compared.
         * @returns The [[Param]]s which differ, or null if the two nodes are for different states
         */
        PathNode.prototype.diff = function (node, paramsFn) {
            if (this.state !== node.state)
                return false;
            var params = paramsFn ? paramsFn(this) : this.paramSchema;
            return Param.changed(params, this.paramValues, node.paramValues);
        };
        /**
         * Returns a clone of the PathNode
         * @deprecated use instance method `node.clone()`
         */
        PathNode.clone = function (node) { return node.clone(); };
        return PathNode;
    }());

    /**
     * Encapsulate the target (destination) state/params/options of a [[Transition]].
     *
     * This class is frequently used to redirect a transition to a new destination.
     *
     * See:
     *
     * - [[HookResult]]
     * - [[TransitionHookFn]]
     * - [[TransitionService.onStart]]
     *
     * To create a `TargetState`, use [[StateService.target]].
     *
     * ---
     *
     * This class wraps:
     *
     * 1) an identifier for a state
     * 2) a set of parameters
     * 3) and transition options
     * 4) the registered state object (the [[StateDeclaration]])
     *
     * Many UI-Router APIs such as [[StateService.go]] take a [[StateOrName]] argument which can
     * either be a *state object* (a [[StateDeclaration]] or [[StateObject]]) or a *state name* (a string).
     * The `TargetState` class normalizes those options.
     *
     * A `TargetState` may be valid (the state being targeted exists in the registry)
     * or invalid (the state being targeted is not registered).
     */
    var TargetState = /** @class */ (function () {
        /**
         * The TargetState constructor
         *
         * Note: Do not construct a `TargetState` manually.
         * To create a `TargetState`, use the [[StateService.target]] factory method.
         *
         * @param _stateRegistry The StateRegistry to use to look up the _definition
         * @param _identifier An identifier for a state.
         *    Either a fully-qualified state name, or the object used to define the state.
         * @param _params Parameters for the target state
         * @param _options Transition options.
         *
         * @internal
         */
        function TargetState(_stateRegistry, _identifier, _params, _options) {
            this._stateRegistry = _stateRegistry;
            this._identifier = _identifier;
            this._identifier = _identifier;
            this._params = extend({}, _params || {});
            this._options = extend({}, _options || {});
            this._definition = _stateRegistry.matcher.find(_identifier, this._options.relative);
        }
        /** The name of the state this object targets */
        TargetState.prototype.name = function () {
            return (this._definition && this._definition.name) || this._identifier;
        };
        /** The identifier used when creating this TargetState */
        TargetState.prototype.identifier = function () {
            return this._identifier;
        };
        /** The target parameter values */
        TargetState.prototype.params = function () {
            return this._params;
        };
        /** The internal state object (if it was found) */
        TargetState.prototype.$state = function () {
            return this._definition;
        };
        /** The internal state declaration (if it was found) */
        TargetState.prototype.state = function () {
            return this._definition && this._definition.self;
        };
        /** The target options */
        TargetState.prototype.options = function () {
            return this._options;
        };
        /** True if the target state was found */
        TargetState.prototype.exists = function () {
            return !!(this._definition && this._definition.self);
        };
        /** True if the object is valid */
        TargetState.prototype.valid = function () {
            return !this.error();
        };
        /** If the object is invalid, returns the reason why */
        TargetState.prototype.error = function () {
            var base = this.options().relative;
            if (!this._definition && !!base) {
                var stateName = base.name ? base.name : base;
                return "Could not resolve '" + this.name() + "' from state '" + stateName + "'";
            }
            if (!this._definition)
                return "No such state '" + this.name() + "'";
            if (!this._definition.self)
                return "State '" + this.name() + "' has an invalid definition";
        };
        TargetState.prototype.toString = function () {
            return "'" + this.name() + "'" + stringify(this.params());
        };
        /**
         * Returns a copy of this TargetState which targets a different state.
         * The new TargetState has the same parameter values and transition options.
         *
         * @param state The new state that should be targeted
         */
        TargetState.prototype.withState = function (state) {
            return new TargetState(this._stateRegistry, state, this._params, this._options);
        };
        /**
         * Returns a copy of this TargetState, using the specified parameter values.
         *
         * @param params the new parameter values to use
         * @param replace When false (default) the new parameter values will be merged with the current values.
         *                When true the parameter values will be used instead of the current values.
         */
        TargetState.prototype.withParams = function (params, replace) {
            if (replace === void 0) { replace = false; }
            var newParams = replace ? params : extend({}, this._params, params);
            return new TargetState(this._stateRegistry, this._identifier, newParams, this._options);
        };
        /**
         * Returns a copy of this TargetState, using the specified Transition Options.
         *
         * @param options the new options to use
         * @param replace When false (default) the new options will be merged with the current options.
         *                When true the options will be used instead of the current options.
         */
        TargetState.prototype.withOptions = function (options, replace) {
            if (replace === void 0) { replace = false; }
            var newOpts = replace ? options : extend({}, this._options, options);
            return new TargetState(this._stateRegistry, this._identifier, this._params, newOpts);
        };
        /** Returns true if the object has a state property that might be a state or state name */
        TargetState.isDef = function (obj) {
            return obj && obj.state && (isString(obj.state) || (isObject(obj.state) && isString(obj.state.name)));
        };
        return TargetState;
    }());

    /**
     * This class contains functions which convert TargetStates, Nodes and paths from one type to another.
     */
    var PathUtils = /** @class */ (function () {
        function PathUtils() {
        }
        /** Given a PathNode[], create an TargetState */
        PathUtils.makeTargetState = function (registry, path) {
            var state = tail(path).state;
            return new TargetState(registry, state, path.map(prop('paramValues')).reduce(mergeR, {}), {});
        };
        PathUtils.buildPath = function (targetState) {
            var toParams = targetState.params();
            return targetState.$state().path.map(function (state) { return new PathNode(state).applyRawParams(toParams); });
        };
        /** Given a fromPath: PathNode[] and a TargetState, builds a toPath: PathNode[] */
        PathUtils.buildToPath = function (fromPath, targetState) {
            var toPath = PathUtils.buildPath(targetState);
            if (targetState.options().inherit) {
                return PathUtils.inheritParams(fromPath, toPath, Object.keys(targetState.params()));
            }
            return toPath;
        };
        /**
         * Creates ViewConfig objects and adds to nodes.
         *
         * On each [[PathNode]], creates ViewConfig objects from the views: property of the node's state
         */
        PathUtils.applyViewConfigs = function ($view, path, states) {
            // Only apply the viewConfigs to the nodes for the given states
            path
                .filter(function (node) { return inArray(states, node.state); })
                .forEach(function (node) {
                var viewDecls = values(node.state.views || {});
                var subPath = PathUtils.subPath(path, function (n) { return n === node; });
                var viewConfigs = viewDecls.map(function (view) { return $view.createViewConfig(subPath, view); });
                node.views = viewConfigs.reduce(unnestR, []);
            });
        };
        /**
         * Given a fromPath and a toPath, returns a new to path which inherits parameters from the fromPath
         *
         * For a parameter in a node to be inherited from the from path:
         * - The toPath's node must have a matching node in the fromPath (by state).
         * - The parameter name must not be found in the toKeys parameter array.
         *
         * Note: the keys provided in toKeys are intended to be those param keys explicitly specified by some
         * caller, for instance, $state.transitionTo(..., toParams).  If a key was found in toParams,
         * it is not inherited from the fromPath.
         */
        PathUtils.inheritParams = function (fromPath, toPath, toKeys) {
            if (toKeys === void 0) { toKeys = []; }
            function nodeParamVals(path, state) {
                var node = find(path, propEq('state', state));
                return extend({}, node && node.paramValues);
            }
            var noInherit = fromPath
                .map(function (node) { return node.paramSchema; })
                .reduce(unnestR, [])
                .filter(function (param) { return !param.inherit; })
                .map(prop('id'));
            /**
             * Given an [[PathNode]] "toNode", return a new [[PathNode]] with param values inherited from the
             * matching node in fromPath.  Only inherit keys that aren't found in "toKeys" from the node in "fromPath""
             */
            function makeInheritedParamsNode(toNode) {
                // All param values for the node (may include default key/vals, when key was not found in toParams)
                var toParamVals = extend({}, toNode && toNode.paramValues);
                // limited to only those keys found in toParams
                var incomingParamVals = pick(toParamVals, toKeys);
                toParamVals = omit(toParamVals, toKeys);
                var fromParamVals = omit(nodeParamVals(fromPath, toNode.state) || {}, noInherit);
                // extend toParamVals with any fromParamVals, then override any of those those with incomingParamVals
                var ownParamVals = extend(toParamVals, fromParamVals, incomingParamVals);
                return new PathNode(toNode.state).applyRawParams(ownParamVals);
            }
            // The param keys specified by the incoming toParams
            return toPath.map(makeInheritedParamsNode);
        };
        /**
         * Computes the tree changes (entering, exiting) between a fromPath and toPath.
         */
        PathUtils.treeChanges = function (fromPath, toPath, reloadState) {
            var max = Math.min(fromPath.length, toPath.length);
            var keep = 0;
            var nodesMatch = function (node1, node2) { return node1.equals(node2, PathUtils.nonDynamicParams); };
            while (keep < max && fromPath[keep].state !== reloadState && nodesMatch(fromPath[keep], toPath[keep])) {
                keep++;
            }
            /** Given a retained node, return a new node which uses the to node's param values */
            function applyToParams(retainedNode, idx) {
                var cloned = retainedNode.clone();
                cloned.paramValues = toPath[idx].paramValues;
                return cloned;
            }
            var from, retained, exiting, entering, to;
            from = fromPath;
            retained = from.slice(0, keep);
            exiting = from.slice(keep);
            // Create a new retained path (with shallow copies of nodes) which have the params of the toPath mapped
            var retainedWithToParams = retained.map(applyToParams);
            entering = toPath.slice(keep);
            to = retainedWithToParams.concat(entering);
            return { from: from, to: to, retained: retained, retainedWithToParams: retainedWithToParams, exiting: exiting, entering: entering };
        };
        /**
         * Returns a new path which is: the subpath of the first path which matches the second path.
         *
         * The new path starts from root and contains any nodes that match the nodes in the second path.
         * It stops before the first non-matching node.
         *
         * Nodes are compared using their state property and their parameter values.
         * If a `paramsFn` is provided, only the [[Param]] returned by the function will be considered when comparing nodes.
         *
         * @param pathA the first path
         * @param pathB the second path
         * @param paramsFn a function which returns the parameters to consider when comparing
         *
         * @returns an array of PathNodes from the first path which match the nodes in the second path
         */
        PathUtils.matching = function (pathA, pathB, paramsFn) {
            var done = false;
            var tuples = arrayTuples(pathA, pathB);
            return tuples.reduce(function (matching, _a) {
                var nodeA = _a[0], nodeB = _a[1];
                done = done || !nodeA.equals(nodeB, paramsFn);
                return done ? matching : matching.concat(nodeA);
            }, []);
        };
        /**
         * Returns true if two paths are identical.
         *
         * @param pathA
         * @param pathB
         * @param paramsFn a function which returns the parameters to consider when comparing
         * @returns true if the the states and parameter values for both paths are identical
         */
        PathUtils.equals = function (pathA, pathB, paramsFn) {
            return pathA.length === pathB.length && PathUtils.matching(pathA, pathB, paramsFn).length === pathA.length;
        };
        /**
         * Return a subpath of a path, which stops at the first matching node
         *
         * Given an array of nodes, returns a subset of the array starting from the first node,
         * stopping when the first node matches the predicate.
         *
         * @param path a path of [[PathNode]]s
         * @param predicate a [[Predicate]] fn that matches [[PathNode]]s
         * @returns a subpath up to the matching node, or undefined if no match is found
         */
        PathUtils.subPath = function (path, predicate) {
            var node = find(path, predicate);
            var elementIdx = path.indexOf(node);
            return elementIdx === -1 ? undefined : path.slice(0, elementIdx + 1);
        };
        PathUtils.nonDynamicParams = function (node) {
            return node.state.parameters({ inherit: false }).filter(function (param) { return !param.dynamic; });
        };
        /** Gets the raw parameter values from a path */
        PathUtils.paramValues = function (path) { return path.reduce(function (acc, node) { return extend(acc, node.paramValues); }, {}); };
        return PathUtils;
    }());

    var resolvePolicies = {
        when: {
            LAZY: 'LAZY',
            EAGER: 'EAGER',
        },
        async: {
            WAIT: 'WAIT',
            NOWAIT: 'NOWAIT',
        },
    };

    // TODO: explicitly make this user configurable
    var defaultResolvePolicy = {
        when: 'LAZY',
        async: 'WAIT',
    };
    /**
     * The basic building block for the resolve system.
     *
     * Resolvables encapsulate a state's resolve's resolveFn, the resolveFn's declared dependencies, the wrapped (.promise),
     * and the unwrapped-when-complete (.data) result of the resolveFn.
     *
     * Resolvable.get() either retrieves the Resolvable's existing promise, or else invokes resolve() (which invokes the
     * resolveFn) and returns the resulting promise.
     *
     * Resolvable.get() and Resolvable.resolve() both execute within a context path, which is passed as the first
     * parameter to those fns.
     */
    var Resolvable = /** @class */ (function () {
        function Resolvable(arg1, resolveFn, deps, policy, data) {
            this.resolved = false;
            this.promise = undefined;
            if (arg1 instanceof Resolvable) {
                extend(this, arg1);
            }
            else if (isFunction(resolveFn)) {
                if (isNullOrUndefined(arg1))
                    throw new Error('new Resolvable(): token argument is required');
                if (!isFunction(resolveFn))
                    throw new Error('new Resolvable(): resolveFn argument must be a function');
                this.token = arg1;
                this.policy = policy;
                this.resolveFn = resolveFn;
                this.deps = deps || [];
                this.data = data;
                this.resolved = data !== undefined;
                this.promise = this.resolved ? services.$q.when(this.data) : undefined;
            }
            else if (isObject(arg1) && arg1.token && (arg1.hasOwnProperty('resolveFn') || arg1.hasOwnProperty('data'))) {
                var literal = arg1;
                return new Resolvable(literal.token, literal.resolveFn, literal.deps, literal.policy, literal.data);
            }
        }
        Resolvable.prototype.getPolicy = function (state) {
            var thisPolicy = this.policy || {};
            var statePolicy = (state && state.resolvePolicy) || {};
            return {
                when: thisPolicy.when || statePolicy.when || defaultResolvePolicy.when,
                async: thisPolicy.async || statePolicy.async || defaultResolvePolicy.async,
            };
        };
        /**
         * Asynchronously resolve this Resolvable's data
         *
         * Given a ResolveContext that this Resolvable is found in:
         * Wait for this Resolvable's dependencies, then invoke this Resolvable's function
         * and update the Resolvable's state
         */
        Resolvable.prototype.resolve = function (resolveContext, trans) {
            var _this = this;
            var $q = services.$q;
            // Gets all dependencies from ResolveContext and wait for them to be resolved
            var getResolvableDependencies = function () {
                return $q.all(resolveContext.getDependencies(_this).map(function (resolvable) { return resolvable.get(resolveContext, trans); }));
            };
            // Invokes the resolve function passing the resolved dependencies as arguments
            var invokeResolveFn = function (resolvedDeps) { return _this.resolveFn.apply(null, resolvedDeps); };
            var node = resolveContext.findNode(this);
            var state = node && node.state;
            var asyncPolicy = this.getPolicy(state).async;
            var customAsyncPolicy = isFunction(asyncPolicy) ? asyncPolicy : identity;
            // After the final value has been resolved, update the state of the Resolvable
            var applyResolvedValue = function (resolvedValue) {
                _this.data = resolvedValue;
                _this.resolved = true;
                _this.resolveFn = null;
                trace.traceResolvableResolved(_this, trans);
                return _this.data;
            };
            // Sets the promise property first, then getsResolvableDependencies in the context of the promise chain. Always waits one tick.
            return (this.promise = $q
                .when()
                .then(getResolvableDependencies)
                .then(invokeResolveFn)
                .then(customAsyncPolicy)
                .then(applyResolvedValue));
        };
        /**
         * Gets a promise for this Resolvable's data.
         *
         * Fetches the data and returns a promise.
         * Returns the existing promise if it has already been fetched once.
         */
        Resolvable.prototype.get = function (resolveContext, trans) {
            return this.promise || this.resolve(resolveContext, trans);
        };
        Resolvable.prototype.toString = function () {
            return "Resolvable(token: " + stringify(this.token) + ", requires: [" + this.deps.map(stringify) + "])";
        };
        Resolvable.prototype.clone = function () {
            return new Resolvable(this);
        };
        Resolvable.fromData = function (token, data) { return new Resolvable(token, function () { return data; }, null, null, data); };
        return Resolvable;
    }());

    var whens = resolvePolicies.when;
    var ALL_WHENS = [whens.EAGER, whens.LAZY];
    var EAGER_WHENS = [whens.EAGER];
    // tslint:disable-next-line:no-inferrable-types
    var NATIVE_INJECTOR_TOKEN = 'Native Injector';
    /**
     * Encapsulates Dependency Injection for a path of nodes
     *
     * UI-Router states are organized as a tree.
     * A nested state has a path of ancestors to the root of the tree.
     * When a state is being activated, each element in the path is wrapped as a [[PathNode]].
     * A `PathNode` is a stateful object that holds things like parameters and resolvables for the state being activated.
     *
     * The ResolveContext closes over the [[PathNode]]s, and provides DI for the last node in the path.
     */
    var ResolveContext = /** @class */ (function () {
        function ResolveContext(_path) {
            this._path = _path;
        }
        /** Gets all the tokens found in the resolve context, de-duplicated */
        ResolveContext.prototype.getTokens = function () {
            return this._path.reduce(function (acc, node) { return acc.concat(node.resolvables.map(function (r) { return r.token; })); }, []).reduce(uniqR, []);
        };
        /**
         * Gets the Resolvable that matches the token
         *
         * Gets the last Resolvable that matches the token in this context, or undefined.
         * Throws an error if it doesn't exist in the ResolveContext
         */
        ResolveContext.prototype.getResolvable = function (token) {
            var matching = this._path
                .map(function (node) { return node.resolvables; })
                .reduce(unnestR, [])
                .filter(function (r) { return r.token === token; });
            return tail(matching);
        };
        /** Returns the [[ResolvePolicy]] for the given [[Resolvable]] */
        ResolveContext.prototype.getPolicy = function (resolvable) {
            var node = this.findNode(resolvable);
            return resolvable.getPolicy(node.state);
        };
        /**
         * Returns a ResolveContext that includes a portion of this one
         *
         * Given a state, this method creates a new ResolveContext from this one.
         * The new context starts at the first node (root) and stops at the node for the `state` parameter.
         *
         * #### Why
         *
         * When a transition is created, the nodes in the "To Path" are injected from a ResolveContext.
         * A ResolveContext closes over a path of [[PathNode]]s and processes the resolvables.
         * The "To State" can inject values from its own resolvables, as well as those from all its ancestor state's (node's).
         * This method is used to create a narrower context when injecting ancestor nodes.
         *
         * @example
         * `let ABCD = new ResolveContext([A, B, C, D]);`
         *
         * Given a path `[A, B, C, D]`, where `A`, `B`, `C` and `D` are nodes for states `a`, `b`, `c`, `d`:
         * When injecting `D`, `D` should have access to all resolvables from `A`, `B`, `C`, `D`.
         * However, `B` should only be able to access resolvables from `A`, `B`.
         *
         * When resolving for the `B` node, first take the full "To Path" Context `[A,B,C,D]` and limit to the subpath `[A,B]`.
         * `let AB = ABCD.subcontext(a)`
         */
        ResolveContext.prototype.subContext = function (state) {
            return new ResolveContext(PathUtils.subPath(this._path, function (node) { return node.state === state; }));
        };
        /**
         * Adds Resolvables to the node that matches the state
         *
         * This adds a [[Resolvable]] (generally one created on the fly; not declared on a [[StateDeclaration.resolve]] block).
         * The resolvable is added to the node matching the `state` parameter.
         *
         * These new resolvables are not automatically fetched.
         * The calling code should either fetch them, fetch something that depends on them,
         * or rely on [[resolvePath]] being called when some state is being entered.
         *
         * Note: each resolvable's [[ResolvePolicy]] is merged with the state's policy, and the global default.
         *
         * @param newResolvables the new Resolvables
         * @param state Used to find the node to put the resolvable on
         */
        ResolveContext.prototype.addResolvables = function (newResolvables, state) {
            var node = find(this._path, propEq('state', state));
            var keys = newResolvables.map(function (r) { return r.token; });
            node.resolvables = node.resolvables.filter(function (r) { return keys.indexOf(r.token) === -1; }).concat(newResolvables);
        };
        /**
         * Returns a promise for an array of resolved path Element promises
         *
         * @param when
         * @param trans
         * @returns {Promise<any>|any}
         */
        ResolveContext.prototype.resolvePath = function (when, trans) {
            var _this = this;
            if (when === void 0) { when = 'LAZY'; }
            // This option determines which 'when' policy Resolvables we are about to fetch.
            var whenOption = inArray(ALL_WHENS, when) ? when : 'LAZY';
            // If the caller specified EAGER, only the EAGER Resolvables are fetched.
            // if the caller specified LAZY, both EAGER and LAZY Resolvables are fetched.`
            var matchedWhens = whenOption === resolvePolicies.when.EAGER ? EAGER_WHENS : ALL_WHENS;
            // get the subpath to the state argument, if provided
            trace.traceResolvePath(this._path, when, trans);
            var matchesPolicy = function (acceptedVals, whenOrAsync) { return function (resolvable) {
                return inArray(acceptedVals, _this.getPolicy(resolvable)[whenOrAsync]);
            }; };
            // Trigger all the (matching) Resolvables in the path
            // Reduce all the "WAIT" Resolvables into an array
            var promises = this._path.reduce(function (acc, node) {
                var nodeResolvables = node.resolvables.filter(matchesPolicy(matchedWhens, 'when'));
                var nowait = nodeResolvables.filter(matchesPolicy(['NOWAIT'], 'async'));
                var wait = nodeResolvables.filter(not(matchesPolicy(['NOWAIT'], 'async')));
                // For the matching Resolvables, start their async fetch process.
                var subContext = _this.subContext(node.state);
                var getResult = function (r) {
                    return r
                        .get(subContext, trans)
                        // Return a tuple that includes the Resolvable's token
                        .then(function (value) { return ({ token: r.token, value: value }); });
                };
                nowait.forEach(getResult);
                return acc.concat(wait.map(getResult));
            }, []);
            // Wait for all the "WAIT" resolvables
            return services.$q.all(promises);
        };
        ResolveContext.prototype.injector = function () {
            return this._injector || (this._injector = new UIInjectorImpl(this));
        };
        ResolveContext.prototype.findNode = function (resolvable) {
            return find(this._path, function (node) { return inArray(node.resolvables, resolvable); });
        };
        /**
         * Gets the async dependencies of a Resolvable
         *
         * Given a Resolvable, returns its dependencies as a Resolvable[]
         */
        ResolveContext.prototype.getDependencies = function (resolvable) {
            var _this = this;
            var node = this.findNode(resolvable);
            // Find which other resolvables are "visible" to the `resolvable` argument
            // subpath stopping at resolvable's node, or the whole path (if the resolvable isn't in the path)
            var subPath = PathUtils.subPath(this._path, function (x) { return x === node; }) || this._path;
            var availableResolvables = subPath
                .reduce(function (acc, _node) { return acc.concat(_node.resolvables); }, []) // all of subpath's resolvables
                .filter(function (res) { return res !== resolvable; }); // filter out the `resolvable` argument
            var getDependency = function (token) {
                var matching = availableResolvables.filter(function (r) { return r.token === token; });
                if (matching.length)
                    return tail(matching);
                var fromInjector = _this.injector().getNative(token);
                if (isUndefined(fromInjector)) {
                    throw new Error('Could not find Dependency Injection token: ' + stringify(token));
                }
                return new Resolvable(token, function () { return fromInjector; }, [], fromInjector);
            };
            return resolvable.deps.map(getDependency);
        };
        return ResolveContext;
    }());
    /** @internal */
    var UIInjectorImpl = /** @class */ (function () {
        function UIInjectorImpl(context) {
            this.context = context;
            this.native = this.get(NATIVE_INJECTOR_TOKEN) || services.$injector;
        }
        UIInjectorImpl.prototype.get = function (token) {
            var resolvable = this.context.getResolvable(token);
            if (resolvable) {
                if (this.context.getPolicy(resolvable).async === 'NOWAIT') {
                    return resolvable.get(this.context);
                }
                if (!resolvable.resolved) {
                    throw new Error('Resolvable async .get() not complete:' + stringify(resolvable.token));
                }
                return resolvable.data;
            }
            return this.getNative(token);
        };
        UIInjectorImpl.prototype.getAsync = function (token) {
            var resolvable = this.context.getResolvable(token);
            if (resolvable)
                return resolvable.get(this.context);
            return services.$q.when(this.native.get(token));
        };
        UIInjectorImpl.prototype.getNative = function (token) {
            return this.native && this.native.get(token);
        };
        return UIInjectorImpl;
    }());

    var parseUrl = function (url) {
        if (!isString(url))
            return false;
        var root = url.charAt(0) === '^';
        return { val: root ? url.substring(1) : url, root: root };
    };
    function nameBuilder(state) {
        return state.name;
    }
    function selfBuilder(state) {
        state.self.$$state = function () { return state; };
        return state.self;
    }
    function dataBuilder(state) {
        if (state.parent && state.parent.data) {
            state.data = state.self.data = inherit(state.parent.data, state.data);
        }
        return state.data;
    }
    var getUrlBuilder = function ($urlMatcherFactoryProvider, root) {
        return function urlBuilder(stateObject) {
            var stateDec = stateObject.self;
            // For future states, i.e., states whose name ends with `.**`,
            // match anything that starts with the url prefix
            if (stateDec && stateDec.url && stateDec.name && stateDec.name.match(/\.\*\*$/)) {
                var newStateDec = {};
                copy(stateDec, newStateDec);
                newStateDec.url += '{remainder:any}'; // match any path (.*)
                stateDec = newStateDec;
            }
            var parent = stateObject.parent;
            var parsed = parseUrl(stateDec.url);
            var url = !parsed ? stateDec.url : $urlMatcherFactoryProvider.compile(parsed.val, { state: stateDec });
            if (!url)
                return null;
            if (!$urlMatcherFactoryProvider.isMatcher(url))
                throw new Error("Invalid url '" + url + "' in state '" + stateObject + "'");
            return parsed && parsed.root ? url : ((parent && parent.navigable) || root()).url.append(url);
        };
    };
    var getNavigableBuilder = function (isRoot) {
        return function navigableBuilder(state) {
            return !isRoot(state) && state.url ? state : state.parent ? state.parent.navigable : null;
        };
    };
    var getParamsBuilder = function (paramFactory) {
        return function paramsBuilder(state) {
            var makeConfigParam = function (config, id) { return paramFactory.fromConfig(id, null, state.self); };
            var urlParams = (state.url && state.url.parameters({ inherit: false })) || [];
            var nonUrlParams = values(mapObj(omit(state.params || {}, urlParams.map(prop('id'))), makeConfigParam));
            return urlParams
                .concat(nonUrlParams)
                .map(function (p) { return [p.id, p]; })
                .reduce(applyPairs, {});
        };
    };
    function pathBuilder(state) {
        return state.parent ? state.parent.path.concat(state) : /*root*/ [state];
    }
    function includesBuilder(state) {
        var includes = state.parent ? extend({}, state.parent.includes) : {};
        includes[state.name] = true;
        return includes;
    }
    /**
     * This is a [[StateBuilder.builder]] function for the `resolve:` block on a [[StateDeclaration]].
     *
     * When the [[StateBuilder]] builds a [[StateObject]] object from a raw [[StateDeclaration]], this builder
     * validates the `resolve` property and converts it to a [[Resolvable]] array.
     *
     * resolve: input value can be:
     *
     * {
     *   // analyzed but not injected
     *   myFooResolve: function() { return "myFooData"; },
     *
     *   // function.toString() parsed, "DependencyName" dep as string (not min-safe)
     *   myBarResolve: function(DependencyName) { return DependencyName.fetchSomethingAsPromise() },
     *
     *   // Array split; "DependencyName" dep as string
     *   myBazResolve: [ "DependencyName", function(dep) { return dep.fetchSomethingAsPromise() },
     *
     *   // Array split; DependencyType dep as token (compared using ===)
     *   myQuxResolve: [ DependencyType, function(dep) { return dep.fetchSometingAsPromise() },
     *
     *   // val.$inject used as deps
     *   // where:
     *   //     corgeResolve.$inject = ["DependencyName"];
     *   //     function corgeResolve(dep) { dep.fetchSometingAsPromise() }
     *   // then "DependencyName" dep as string
     *   myCorgeResolve: corgeResolve,
     *
     *  // inject service by name
     *  // When a string is found, desugar creating a resolve that injects the named service
     *   myGraultResolve: "SomeService"
     * }
     *
     * or:
     *
     * [
     *   new Resolvable("myFooResolve", function() { return "myFooData" }),
     *   new Resolvable("myBarResolve", function(dep) { return dep.fetchSomethingAsPromise() }, [ "DependencyName" ]),
     *   { provide: "myBazResolve", useFactory: function(dep) { dep.fetchSomethingAsPromise() }, deps: [ "DependencyName" ] }
     * ]
     */
    function resolvablesBuilder(state) {
        /** convert resolve: {} and resolvePolicy: {} objects to an array of tuples */
        var objects2Tuples = function (resolveObj, resolvePolicies) {
            return Object.keys(resolveObj || {}).map(function (token) { return ({
                token: token,
                val: resolveObj[token],
                deps: undefined,
                policy: resolvePolicies[token],
            }); });
        };
        /** fetch DI annotations from a function or ng1-style array */
        var annotate = function (fn) {
            var $injector = services.$injector;
            // ng1 doesn't have an $injector until runtime.
            // If the $injector doesn't exist, use "deferred" literal as a
            // marker indicating they should be annotated when runtime starts
            return fn['$inject'] || ($injector && $injector.annotate(fn, $injector.strictDi)) || 'deferred';
        };
        /** true if the object has both `token` and `resolveFn`, and is probably a [[ResolveLiteral]] */
        var isResolveLiteral = function (obj) { return !!(obj.token && obj.resolveFn); };
        /** true if the object looks like a provide literal, or a ng2 Provider */
        var isLikeNg2Provider = function (obj) {
            return !!((obj.provide || obj.token) && (obj.useValue || obj.useFactory || obj.useExisting || obj.useClass));
        };
        /** true if the object looks like a tuple from obj2Tuples */
        var isTupleFromObj = function (obj) {
            return !!(obj && obj.val && (isString(obj.val) || isArray(obj.val) || isFunction(obj.val)));
        };
        /** extracts the token from a Provider or provide literal */
        var getToken = function (p) { return p.provide || p.token; };
        // prettier-ignore: Given a literal resolve or provider object, returns a Resolvable
        var literal2Resolvable = pattern([
            [prop('resolveFn'), function (p) { return new Resolvable(getToken(p), p.resolveFn, p.deps, p.policy); }],
            [prop('useFactory'), function (p) { return new Resolvable(getToken(p), p.useFactory, p.deps || p.dependencies, p.policy); }],
            [prop('useClass'), function (p) { return new Resolvable(getToken(p), function () { return new p.useClass(); }, [], p.policy); }],
            [prop('useValue'), function (p) { return new Resolvable(getToken(p), function () { return p.useValue; }, [], p.policy, p.useValue); }],
            [prop('useExisting'), function (p) { return new Resolvable(getToken(p), identity, [p.useExisting], p.policy); }],
        ]);
        // prettier-ignore
        var tuple2Resolvable = pattern([
            [pipe(prop('val'), isString), function (tuple) { return new Resolvable(tuple.token, identity, [tuple.val], tuple.policy); }],
            [pipe(prop('val'), isArray), function (tuple) { return new Resolvable(tuple.token, tail(tuple.val), tuple.val.slice(0, -1), tuple.policy); }],
            [pipe(prop('val'), isFunction), function (tuple) { return new Resolvable(tuple.token, tuple.val, annotate(tuple.val), tuple.policy); }],
        ]);
        // prettier-ignore
        var item2Resolvable = pattern([
            [is(Resolvable), function (r) { return r; }],
            [isResolveLiteral, literal2Resolvable],
            [isLikeNg2Provider, literal2Resolvable],
            [isTupleFromObj, tuple2Resolvable],
            [val(true), function (obj) { throw new Error('Invalid resolve value: ' + stringify(obj)); },],
        ]);
        // If resolveBlock is already an array, use it as-is.
        // Otherwise, assume it's an object and convert to an Array of tuples
        var decl = state.resolve;
        var items = isArray(decl) ? decl : objects2Tuples(decl, state.resolvePolicy || {});
        return items.map(item2Resolvable);
    }
    /**
     * A internal global service
     *
     * StateBuilder is a factory for the internal [[StateObject]] objects.
     *
     * When you register a state with the [[StateRegistry]], you register a plain old javascript object which
     * conforms to the [[StateDeclaration]] interface.  This factory takes that object and builds the corresponding
     * [[StateObject]] object, which has an API and is used internally.
     *
     * Custom properties or API may be added to the internal [[StateObject]] object by registering a decorator function
     * using the [[builder]] method.
     */
    var StateBuilder = /** @class */ (function () {
        function StateBuilder(matcher, urlMatcherFactory) {
            this.matcher = matcher;
            var self = this;
            var root = function () { return matcher.find(''); };
            var isRoot = function (state) { return state.name === ''; };
            function parentBuilder(state) {
                if (isRoot(state))
                    return null;
                return matcher.find(self.parentName(state)) || root();
            }
            this.builders = {
                name: [nameBuilder],
                self: [selfBuilder],
                parent: [parentBuilder],
                data: [dataBuilder],
                // Build a URLMatcher if necessary, either via a relative or absolute URL
                url: [getUrlBuilder(urlMatcherFactory, root)],
                // Keep track of the closest ancestor state that has a URL (i.e. is navigable)
                navigable: [getNavigableBuilder(isRoot)],
                params: [getParamsBuilder(urlMatcherFactory.paramFactory)],
                // Each framework-specific ui-router implementation should define its own `views` builder
                // e.g., src/ng1/statebuilders/views.ts
                views: [],
                // Keep a full path from the root down to this state as this is needed for state activation.
                path: [pathBuilder],
                // Speed up $state.includes() as it's used a lot
                includes: [includesBuilder],
                resolvables: [resolvablesBuilder],
            };
        }
        StateBuilder.prototype.builder = function (name, fn) {
            var builders = this.builders;
            var array = builders[name] || [];
            // Backwards compat: if only one builder exists, return it, else return whole arary.
            if (isString(name) && !isDefined(fn))
                return array.length > 1 ? array : array[0];
            if (!isString(name) || !isFunction(fn))
                return;
            builders[name] = array;
            builders[name].push(fn);
            return function () { return builders[name].splice(builders[name].indexOf(fn, 1)) && null; };
        };
        /**
         * Builds all of the properties on an essentially blank State object, returning a State object which has all its
         * properties and API built.
         *
         * @param state an uninitialized State object
         * @returns the built State object
         */
        StateBuilder.prototype.build = function (state) {
            var _a = this, matcher = _a.matcher, builders = _a.builders;
            var parent = this.parentName(state);
            if (parent && !matcher.find(parent, undefined, false)) {
                return null;
            }
            for (var key in builders) {
                if (!builders.hasOwnProperty(key))
                    continue;
                var chain = builders[key].reduce(function (parentFn, step) { return function (_state) { return step(_state, parentFn); }; }, noop);
                state[key] = chain(state);
            }
            return state;
        };
        StateBuilder.prototype.parentName = function (state) {
            // name = 'foo.bar.baz.**'
            var name = state.name || '';
            // segments = ['foo', 'bar', 'baz', '.**']
            var segments = name.split('.');
            // segments = ['foo', 'bar', 'baz']
            var lastSegment = segments.pop();
            // segments = ['foo', 'bar'] (ignore .** segment for future states)
            if (lastSegment === '**')
                segments.pop();
            if (segments.length) {
                if (state.parent) {
                    throw new Error("States that specify the 'parent:' property should not have a '.' in their name (" + name + ")");
                }
                // 'foo.bar'
                return segments.join('.');
            }
            if (!state.parent)
                return '';
            return isString(state.parent) ? state.parent : state.parent.name;
        };
        StateBuilder.prototype.name = function (state) {
            var name = state.name;
            if (name.indexOf('.') !== -1 || !state.parent)
                return name;
            var parentName = isString(state.parent) ? state.parent : state.parent.name;
            return parentName ? parentName + '.' + name : name;
        };
        return StateBuilder;
    }());

    /**
     * Internal representation of a UI-Router state.
     *
     * Instances of this class are created when a [[StateDeclaration]] is registered with the [[StateRegistry]].
     *
     * A registered [[StateDeclaration]] is augmented with a getter ([[StateDeclaration.$$state]]) which returns the corresponding [[StateObject]] object.
     *
     * This class prototypally inherits from the corresponding [[StateDeclaration]].
     * Each of its own properties (i.e., `hasOwnProperty`) are built using builders from the [[StateBuilder]].
     */
    var StateObject = /** @class */ (function () {
        /** @deprecated use State.create() */
        function StateObject(config) {
            return StateObject.create(config || {});
        }
        /**
         * Create a state object to put the private/internal implementation details onto.
         * The object's prototype chain looks like:
         * (Internal State Object) -> (Copy of State.prototype) -> (State Declaration object) -> (State Declaration's prototype...)
         *
         * @param stateDecl the user-supplied State Declaration
         * @returns {StateObject} an internal State object
         */
        StateObject.create = function (stateDecl) {
            stateDecl = StateObject.isStateClass(stateDecl) ? new stateDecl() : stateDecl;
            var state = inherit(inherit(stateDecl, StateObject.prototype));
            stateDecl.$$state = function () { return state; };
            state.self = stateDecl;
            state.__stateObjectCache = {
                nameGlob: Glob.fromString(state.name),
            };
            return state;
        };
        /**
         * Returns true if the provided parameter is the same state.
         *
         * Compares the identity of the state against the passed value, which is either an object
         * reference to the actual `State` instance, the original definition object passed to
         * `$stateProvider.state()`, or the fully-qualified name.
         *
         * @param ref Can be one of (a) a `State` instance, (b) an object that was passed
         *        into `$stateProvider.state()`, (c) the fully-qualified name of a state as a string.
         * @returns Returns `true` if `ref` matches the current `State` instance.
         */
        StateObject.prototype.is = function (ref) {
            return this === ref || this.self === ref || this.fqn() === ref;
        };
        /**
         * @deprecated this does not properly handle dot notation
         * @returns Returns a dot-separated name of the state.
         */
        StateObject.prototype.fqn = function () {
            if (!this.parent || !(this.parent instanceof this.constructor))
                return this.name;
            var name = this.parent.fqn();
            return name ? name + '.' + this.name : this.name;
        };
        /**
         * Returns the root node of this state's tree.
         *
         * @returns The root of this state's tree.
         */
        StateObject.prototype.root = function () {
            return (this.parent && this.parent.root()) || this;
        };
        /**
         * Gets the state's `Param` objects
         *
         * Gets the list of [[Param]] objects owned by the state.
         * If `opts.inherit` is true, it also includes the ancestor states' [[Param]] objects.
         * If `opts.matchingKeys` exists, returns only `Param`s whose `id` is a key on the `matchingKeys` object
         *
         * @param opts options
         */
        StateObject.prototype.parameters = function (opts) {
            opts = defaults(opts, { inherit: true, matchingKeys: null });
            var inherited = (opts.inherit && this.parent && this.parent.parameters()) || [];
            return inherited
                .concat(values(this.params))
                .filter(function (param) { return !opts.matchingKeys || opts.matchingKeys.hasOwnProperty(param.id); });
        };
        /**
         * Returns a single [[Param]] that is owned by the state
         *
         * If `opts.inherit` is true, it also searches the ancestor states` [[Param]]s.
         * @param id the name of the [[Param]] to return
         * @param opts options
         */
        StateObject.prototype.parameter = function (id, opts) {
            if (opts === void 0) { opts = {}; }
            return ((this.url && this.url.parameter(id, opts)) ||
                find(values(this.params), propEq('id', id)) ||
                (opts.inherit && this.parent && this.parent.parameter(id)));
        };
        StateObject.prototype.toString = function () {
            return this.fqn();
        };
        /** Predicate which returns true if the object is an class with @State() decorator */
        StateObject.isStateClass = function (stateDecl) {
            return isFunction(stateDecl) && stateDecl['__uiRouterState'] === true;
        };
        /** Predicate which returns true if the object is a [[StateDeclaration]] object */
        StateObject.isStateDeclaration = function (obj) { return isFunction(obj['$$state']); };
        /** Predicate which returns true if the object is an internal [[StateObject]] object */
        StateObject.isState = function (obj) { return isObject(obj['__stateObjectCache']); };
        return StateObject;
    }());

    var StateMatcher = /** @class */ (function () {
        function StateMatcher(_states) {
            this._states = _states;
        }
        StateMatcher.prototype.isRelative = function (stateName) {
            stateName = stateName || '';
            return stateName.indexOf('.') === 0 || stateName.indexOf('^') === 0;
        };
        StateMatcher.prototype.find = function (stateOrName, base, matchGlob) {
            if (matchGlob === void 0) { matchGlob = true; }
            if (!stateOrName && stateOrName !== '')
                return undefined;
            var isStr = isString(stateOrName);
            var name = isStr ? stateOrName : stateOrName.name;
            if (this.isRelative(name))
                name = this.resolvePath(name, base);
            var state = this._states[name];
            if (state && (isStr || (!isStr && (state === stateOrName || state.self === stateOrName)))) {
                return state;
            }
            else if (isStr && matchGlob) {
                var _states = values(this._states);
                var matches = _states.filter(function (_state) { return _state.__stateObjectCache.nameGlob && _state.__stateObjectCache.nameGlob.matches(name); });
                if (matches.length > 1) {
                    safeConsole.error("stateMatcher.find: Found multiple matches for " + name + " using glob: ", matches.map(function (match) { return match.name; }));
                }
                return matches[0];
            }
            return undefined;
        };
        StateMatcher.prototype.resolvePath = function (name, base) {
            if (!base)
                throw new Error("No reference point given for path '" + name + "'");
            var baseState = this.find(base);
            var splitName = name.split('.');
            var pathLength = splitName.length;
            var i = 0, current = baseState;
            for (; i < pathLength; i++) {
                if (splitName[i] === '' && i === 0) {
                    current = baseState;
                    continue;
                }
                if (splitName[i] === '^') {
                    if (!current.parent)
                        throw new Error("Path '" + name + "' not valid for state '" + baseState.name + "'");
                    current = current.parent;
                    continue;
                }
                break;
            }
            var relName = splitName.slice(i).join('.');
            return current.name + (current.name && relName ? '.' : '') + relName;
        };
        return StateMatcher;
    }());

    var StateQueueManager = /** @class */ (function () {
        function StateQueueManager(router, states, builder, listeners) {
            this.router = router;
            this.states = states;
            this.builder = builder;
            this.listeners = listeners;
            this.queue = [];
        }
        StateQueueManager.prototype.dispose = function () {
            this.queue = [];
        };
        StateQueueManager.prototype.register = function (stateDecl) {
            var queue = this.queue;
            var state = StateObject.create(stateDecl);
            var name = state.name;
            if (!isString(name))
                throw new Error('State must have a valid name');
            if (this.states.hasOwnProperty(name) || inArray(queue.map(prop('name')), name))
                throw new Error("State '" + name + "' is already defined");
            queue.push(state);
            this.flush();
            return state;
        };
        StateQueueManager.prototype.flush = function () {
            var _this = this;
            var _a = this, queue = _a.queue, states = _a.states, builder = _a.builder;
            var registered = [], // states that got registered
            orphans = [], // states that don't yet have a parent registered
            previousQueueLength = {}; // keep track of how long the queue when an orphan was first encountered
            var getState = function (name) { return _this.states.hasOwnProperty(name) && _this.states[name]; };
            var notifyListeners = function () {
                if (registered.length) {
                    _this.listeners.forEach(function (listener) {
                        return listener('registered', registered.map(function (s) { return s.self; }));
                    });
                }
            };
            while (queue.length > 0) {
                var state = queue.shift();
                var name_1 = state.name;
                var result = builder.build(state);
                var orphanIdx = orphans.indexOf(state);
                if (result) {
                    var existingState = getState(name_1);
                    if (existingState && existingState.name === name_1) {
                        throw new Error("State '" + name_1 + "' is already defined");
                    }
                    var existingFutureState = getState(name_1 + '.**');
                    if (existingFutureState) {
                        // Remove future state of the same name
                        this.router.stateRegistry.deregister(existingFutureState);
                    }
                    states[name_1] = state;
                    this.attachRoute(state);
                    if (orphanIdx >= 0)
                        orphans.splice(orphanIdx, 1);
                    registered.push(state);
                    continue;
                }
                var prev = previousQueueLength[name_1];
                previousQueueLength[name_1] = queue.length;
                if (orphanIdx >= 0 && prev === queue.length) {
                    // Wait until two consecutive iterations where no additional states were dequeued successfully.
                    // throw new Error(`Cannot register orphaned state '${name}'`);
                    queue.push(state);
                    notifyListeners();
                    return states;
                }
                else if (orphanIdx < 0) {
                    orphans.push(state);
                }
                queue.push(state);
            }
            notifyListeners();
            return states;
        };
        StateQueueManager.prototype.attachRoute = function (state) {
            if (state.abstract || !state.url)
                return;
            var rulesApi = this.router.urlService.rules;
            rulesApi.rule(rulesApi.urlRuleFactory.create(state));
        };
        return StateQueueManager;
    }());

    /**
     * A registry for all of the application's [[StateDeclaration]]s
     *
     * This API is found at `router.stateRegistry` ([[UIRouter.stateRegistry]])
     */
    var StateRegistry = /** @class */ (function () {
        /** @internal */
        function StateRegistry(router) {
            this.router = router;
            this.states = {};
            /** @internal */
            this.listeners = [];
            this.matcher = new StateMatcher(this.states);
            this.builder = new StateBuilder(this.matcher, router.urlMatcherFactory);
            this.stateQueue = new StateQueueManager(router, this.states, this.builder, this.listeners);
            this._registerRoot();
        }
        /** @internal */
        StateRegistry.prototype._registerRoot = function () {
            var rootStateDef = {
                name: '',
                url: '^',
                views: null,
                params: {
                    '#': { value: null, type: 'hash', dynamic: true },
                },
                abstract: true,
            };
            var _root = (this._root = this.stateQueue.register(rootStateDef));
            _root.navigable = null;
        };
        /** @internal */
        StateRegistry.prototype.dispose = function () {
            var _this = this;
            this.stateQueue.dispose();
            this.listeners = [];
            this.get().forEach(function (state) { return _this.get(state) && _this.deregister(state); });
        };
        /**
         * Listen for a State Registry events
         *
         * Adds a callback that is invoked when states are registered or deregistered with the StateRegistry.
         *
         * #### Example:
         * ```js
         * let allStates = registry.get();
         *
         * // Later, invoke deregisterFn() to remove the listener
         * let deregisterFn = registry.onStatesChanged((event, states) => {
         *   switch(event) {
         *     case: 'registered':
         *       states.forEach(state => allStates.push(state));
         *       break;
         *     case: 'deregistered':
         *       states.forEach(state => {
         *         let idx = allStates.indexOf(state);
         *         if (idx !== -1) allStates.splice(idx, 1);
         *       });
         *       break;
         *   }
         * });
         * ```
         *
         * @param listener a callback function invoked when the registered states changes.
         *        The function receives two parameters, `event` and `state`.
         *        See [[StateRegistryListener]]
         * @return a function that deregisters the listener
         */
        StateRegistry.prototype.onStatesChanged = function (listener) {
            this.listeners.push(listener);
            return function deregisterListener() {
                removeFrom(this.listeners)(listener);
            }.bind(this);
        };
        /**
         * Gets the implicit root state
         *
         * Gets the root of the state tree.
         * The root state is implicitly created by UI-Router.
         * Note: this returns the internal [[StateObject]] representation, not a [[StateDeclaration]]
         *
         * @return the root [[StateObject]]
         */
        StateRegistry.prototype.root = function () {
            return this._root;
        };
        /**
         * Adds a state to the registry
         *
         * Registers a [[StateDeclaration]] or queues it for registration.
         *
         * Note: a state will be queued if the state's parent isn't yet registered.
         *
         * @param stateDefinition the definition of the state to register.
         * @returns the internal [[StateObject]] object.
         *          If the state was successfully registered, then the object is fully built (See: [[StateBuilder]]).
         *          If the state was only queued, then the object is not fully built.
         */
        StateRegistry.prototype.register = function (stateDefinition) {
            return this.stateQueue.register(stateDefinition);
        };
        /** @internal */
        StateRegistry.prototype._deregisterTree = function (state) {
            var _this = this;
            var all = this.get().map(function (s) { return s.$$state(); });
            var getChildren = function (states) {
                var _children = all.filter(function (s) { return states.indexOf(s.parent) !== -1; });
                return _children.length === 0 ? _children : _children.concat(getChildren(_children));
            };
            var children = getChildren([state]);
            var deregistered = [state].concat(children).reverse();
            deregistered.forEach(function (_state) {
                var rulesApi = _this.router.urlService.rules;
                // Remove URL rule
                rulesApi
                    .rules()
                    .filter(propEq('state', _state))
                    .forEach(function (rule) { return rulesApi.removeRule(rule); });
                // Remove state from registry
                delete _this.states[_state.name];
            });
            return deregistered;
        };
        /**
         * Removes a state from the registry
         *
         * This removes a state from the registry.
         * If the state has children, they are are also removed from the registry.
         *
         * @param stateOrName the state's name or object representation
         * @returns {StateObject[]} a list of removed states
         */
        StateRegistry.prototype.deregister = function (stateOrName) {
            var _state = this.get(stateOrName);
            if (!_state)
                throw new Error("Can't deregister state; not found: " + stateOrName);
            var deregisteredStates = this._deregisterTree(_state.$$state());
            this.listeners.forEach(function (listener) {
                return listener('deregistered', deregisteredStates.map(function (s) { return s.self; }));
            });
            return deregisteredStates;
        };
        StateRegistry.prototype.get = function (stateOrName, base) {
            var _this = this;
            if (arguments.length === 0)
                return Object.keys(this.states).map(function (name) { return _this.states[name].self; });
            var found = this.matcher.find(stateOrName, base);
            return (found && found.self) || null;
        };
        /**
         * Registers a [[BuilderFunction]] for a specific [[StateObject]] property (e.g., `parent`, `url`, or `path`).
         * More than one BuilderFunction can be registered for a given property.
         *
         * The BuilderFunction(s) will be used to define the property on any subsequently built [[StateObject]] objects.
         *
         * @param property The name of the State property being registered for.
         * @param builderFunction The BuilderFunction which will be used to build the State property
         * @returns a function which deregisters the BuilderFunction
         */
        StateRegistry.prototype.decorator = function (property, builderFunction) {
            return this.builder.builder(property, builderFunction);
        };
        return StateRegistry;
    }());

    (function (TransitionHookPhase) {
        TransitionHookPhase[TransitionHookPhase["CREATE"] = 0] = "CREATE";
        TransitionHookPhase[TransitionHookPhase["BEFORE"] = 1] = "BEFORE";
        TransitionHookPhase[TransitionHookPhase["RUN"] = 2] = "RUN";
        TransitionHookPhase[TransitionHookPhase["SUCCESS"] = 3] = "SUCCESS";
        TransitionHookPhase[TransitionHookPhase["ERROR"] = 4] = "ERROR";
    })(exports.TransitionHookPhase || (exports.TransitionHookPhase = {}));

    (function (TransitionHookScope) {
        TransitionHookScope[TransitionHookScope["TRANSITION"] = 0] = "TRANSITION";
        TransitionHookScope[TransitionHookScope["STATE"] = 1] = "STATE";
    })(exports.TransitionHookScope || (exports.TransitionHookScope = {}));

    var defaultOptions = {
        current: noop,
        transition: null,
        traceData: {},
        bind: null,
    };
    var TransitionHook = /** @class */ (function () {
        function TransitionHook(transition, stateContext, registeredHook, options) {
            var _this = this;
            this.transition = transition;
            this.stateContext = stateContext;
            this.registeredHook = registeredHook;
            this.options = options;
            this.isSuperseded = function () { return _this.type.hookPhase === exports.TransitionHookPhase.RUN && !_this.options.transition.isActive(); };
            this.options = defaults(options, defaultOptions);
            this.type = registeredHook.eventType;
        }
        /**
         * Chains together an array of TransitionHooks.
         *
         * Given a list of [[TransitionHook]] objects, chains them together.
         * Each hook is invoked after the previous one completes.
         *
         * #### Example:
         * ```js
         * var hooks: TransitionHook[] = getHooks();
         * let promise: Promise<any> = TransitionHook.chain(hooks);
         *
         * promise.then(handleSuccess, handleError);
         * ```
         *
         * @param hooks the list of hooks to chain together
         * @param waitFor if provided, the chain is `.then()`'ed off this promise
         * @returns a `Promise` for sequentially invoking the hooks (in order)
         */
        TransitionHook.chain = function (hooks, waitFor) {
            // Chain the next hook off the previous
            var createHookChainR = function (prev, nextHook) { return prev.then(function () { return nextHook.invokeHook(); }); };
            return hooks.reduce(createHookChainR, waitFor || services.$q.when());
        };
        /**
         * Invokes all the provided TransitionHooks, in order.
         * Each hook's return value is checked.
         * If any hook returns a promise, then the rest of the hooks are chained off that promise, and the promise is returned.
         * If no hook returns a promise, then all hooks are processed synchronously.
         *
         * @param hooks the list of TransitionHooks to invoke
         * @param doneCallback a callback that is invoked after all the hooks have successfully completed
         *
         * @returns a promise for the async result, or the result of the callback
         */
        TransitionHook.invokeHooks = function (hooks, doneCallback) {
            for (var idx = 0; idx < hooks.length; idx++) {
                var hookResult = hooks[idx].invokeHook();
                if (isPromise(hookResult)) {
                    var remainingHooks = hooks.slice(idx + 1);
                    return TransitionHook.chain(remainingHooks, hookResult).then(doneCallback);
                }
            }
            return doneCallback();
        };
        /**
         * Run all TransitionHooks, ignoring their return value.
         */
        TransitionHook.runAllHooks = function (hooks) {
            hooks.forEach(function (hook) { return hook.invokeHook(); });
        };
        TransitionHook.prototype.logError = function (err) {
            this.transition.router.stateService.defaultErrorHandler()(err);
        };
        TransitionHook.prototype.invokeHook = function () {
            var _this = this;
            var hook = this.registeredHook;
            if (hook._deregistered)
                return;
            var notCurrent = this.getNotCurrentRejection();
            if (notCurrent)
                return notCurrent;
            var options = this.options;
            trace.traceHookInvocation(this, this.transition, options);
            var invokeCallback = function () { return hook.callback.call(options.bind, _this.transition, _this.stateContext); };
            var normalizeErr = function (err) { return Rejection.normalize(err).toPromise(); };
            var handleError = function (err) { return hook.eventType.getErrorHandler(_this)(err); };
            var handleResult = function (result) { return hook.eventType.getResultHandler(_this)(result); };
            try {
                var result = invokeCallback();
                if (!this.type.synchronous && isPromise(result)) {
                    return result.catch(normalizeErr).then(handleResult, handleError);
                }
                else {
                    return handleResult(result);
                }
            }
            catch (err) {
                // If callback throws (synchronously)
                return handleError(Rejection.normalize(err));
            }
            finally {
                if (hook.invokeLimit && ++hook.invokeCount >= hook.invokeLimit) {
                    hook.deregister();
                }
            }
        };
        /**
         * This method handles the return value of a Transition Hook.
         *
         * A hook can return false (cancel), a TargetState (redirect),
         * or a promise (which may later resolve to false or a redirect)
         *
         * This also handles "transition superseded" -- when a new transition
         * was started while the hook was still running
         */
        TransitionHook.prototype.handleHookResult = function (result) {
            var _this = this;
            var notCurrent = this.getNotCurrentRejection();
            if (notCurrent)
                return notCurrent;
            // Hook returned a promise
            if (isPromise(result)) {
                // Wait for the promise, then reprocess with the resulting value
                return result.then(function (val) { return _this.handleHookResult(val); });
            }
            trace.traceHookResult(result, this.transition, this.options);
            // Hook returned false
            if (result === false) {
                // Abort this Transition
                return Rejection.aborted('Hook aborted transition').toPromise();
            }
            var isTargetState = is(TargetState);
            // hook returned a TargetState
            if (isTargetState(result)) {
                // Halt the current Transition and redirect (a new Transition) to the TargetState.
                return Rejection.redirected(result).toPromise();
            }
        };
        /**
         * Return a Rejection promise if the transition is no longer current due
         * to a stopped router (disposed), or a new transition has started and superseded this one.
         */
        TransitionHook.prototype.getNotCurrentRejection = function () {
            var router = this.transition.router;
            // The router is stopped
            if (router._disposed) {
                return Rejection.aborted("UIRouter instance #" + router.$id + " has been stopped (disposed)").toPromise();
            }
            if (this.transition._aborted) {
                return Rejection.aborted().toPromise();
            }
            // This transition is no longer current.
            // Another transition started while this hook was still running.
            if (this.isSuperseded()) {
                // Abort this transition
                return Rejection.superseded(this.options.current()).toPromise();
            }
        };
        TransitionHook.prototype.toString = function () {
            var _a = this, options = _a.options, registeredHook = _a.registeredHook;
            var event = parse('traceData.hookType')(options) || 'internal', context = parse('traceData.context.state.name')(options) || parse('traceData.context')(options) || 'unknown', name = fnToString(registeredHook.callback);
            return event + " context: " + context + ", " + maxLength(200, name);
        };
        /**
         * These GetResultHandler(s) are used by [[invokeHook]] below
         * Each HookType chooses a GetResultHandler (See: [[TransitionService._defineCoreEvents]])
         */
        TransitionHook.HANDLE_RESULT = function (hook) { return function (result) {
            return hook.handleHookResult(result);
        }; };
        /**
         * If the result is a promise rejection, log it.
         * Otherwise, ignore the result.
         */
        TransitionHook.LOG_REJECTED_RESULT = function (hook) { return function (result) {
            isPromise(result) && result.catch(function (err) { return hook.logError(Rejection.normalize(err)); });
            return undefined;
        }; };
        /**
         * These GetErrorHandler(s) are used by [[invokeHook]] below
         * Each HookType chooses a GetErrorHandler (See: [[TransitionService._defineCoreEvents]])
         */
        TransitionHook.LOG_ERROR = function (hook) { return function (error) { return hook.logError(error); }; };
        TransitionHook.REJECT_ERROR = function (hook) { return function (error) { return silentRejection(error); }; };
        TransitionHook.THROW_ERROR = function (hook) { return function (error) {
            throw error;
        }; };
        return TransitionHook;
    }());

    /**
     * Determines if the given state matches the matchCriteria
     *
     * @internal
     *
     * @param state a State Object to test against
     * @param criterion
     * - If a string, matchState uses the string as a glob-matcher against the state name
     * - If an array (of strings), matchState uses each string in the array as a glob-matchers against the state name
     *   and returns a positive match if any of the globs match.
     * - If a function, matchState calls the function with the state and returns true if the function's result is truthy.
     * @returns {boolean}
     */
    function matchState(state, criterion, transition) {
        var toMatch = isString(criterion) ? [criterion] : criterion;
        function matchGlobs(_state) {
            var globStrings = toMatch;
            for (var i = 0; i < globStrings.length; i++) {
                var glob = new Glob(globStrings[i]);
                if ((glob && glob.matches(_state.name)) || (!glob && globStrings[i] === _state.name)) {
                    return true;
                }
            }
            return false;
        }
        var matchFn = (isFunction(toMatch) ? toMatch : matchGlobs);
        return !!matchFn(state, transition);
    }
    /**
     * The registration data for a registered transition hook
     */
    var RegisteredHook = /** @class */ (function () {
        function RegisteredHook(tranSvc, eventType, callback, matchCriteria, removeHookFromRegistry, options) {
            if (options === void 0) { options = {}; }
            this.tranSvc = tranSvc;
            this.eventType = eventType;
            this.callback = callback;
            this.matchCriteria = matchCriteria;
            this.removeHookFromRegistry = removeHookFromRegistry;
            this.invokeCount = 0;
            this._deregistered = false;
            this.priority = options.priority || 0;
            this.bind = options.bind || null;
            this.invokeLimit = options.invokeLimit;
        }
        /**
         * Gets the matching [[PathNode]]s
         *
         * Given an array of [[PathNode]]s, and a [[HookMatchCriterion]], returns an array containing
         * the [[PathNode]]s that the criteria matches, or `null` if there were no matching nodes.
         *
         * Returning `null` is significant to distinguish between the default
         * "match-all criterion value" of `true` compared to a `() => true` function,
         * when the nodes is an empty array.
         *
         * This is useful to allow a transition match criteria of `entering: true`
         * to still match a transition, even when `entering === []`.  Contrast that
         * with `entering: (state) => true` which only matches when a state is actually
         * being entered.
         */
        RegisteredHook.prototype._matchingNodes = function (nodes, criterion, transition) {
            if (criterion === true)
                return nodes;
            var matching = nodes.filter(function (node) { return matchState(node.state, criterion, transition); });
            return matching.length ? matching : null;
        };
        /**
         * Gets the default match criteria (all `true`)
         *
         * Returns an object which has all the criteria match paths as keys and `true` as values, i.e.:
         *
         * ```js
         * {
         *   to: true,
         *   from: true,
         *   entering: true,
         *   exiting: true,
         *   retained: true,
         * }
         */
        RegisteredHook.prototype._getDefaultMatchCriteria = function () {
            return mapObj(this.tranSvc._pluginapi._getPathTypes(), function () { return true; });
        };
        /**
         * Gets matching nodes as [[IMatchingNodes]]
         *
         * Create a IMatchingNodes object from the TransitionHookTypes that is roughly equivalent to:
         *
         * ```js
         * let matches: IMatchingNodes = {
         *   to:       _matchingNodes([tail(treeChanges.to)],   mc.to),
         *   from:     _matchingNodes([tail(treeChanges.from)], mc.from),
         *   exiting:  _matchingNodes(treeChanges.exiting,      mc.exiting),
         *   retained: _matchingNodes(treeChanges.retained,     mc.retained),
         *   entering: _matchingNodes(treeChanges.entering,     mc.entering),
         * };
         * ```
         */
        RegisteredHook.prototype._getMatchingNodes = function (treeChanges, transition) {
            var _this = this;
            var criteria = extend(this._getDefaultMatchCriteria(), this.matchCriteria);
            var paths = values(this.tranSvc._pluginapi._getPathTypes());
            return paths.reduce(function (mn, pathtype) {
                // STATE scope criteria matches against every node in the path.
                // TRANSITION scope criteria matches against only the last node in the path
                var isStateHook = pathtype.scope === exports.TransitionHookScope.STATE;
                var path = treeChanges[pathtype.name] || [];
                var nodes = isStateHook ? path : [tail(path)];
                mn[pathtype.name] = _this._matchingNodes(nodes, criteria[pathtype.name], transition);
                return mn;
            }, {});
        };
        /**
         * Determines if this hook's [[matchCriteria]] match the given [[TreeChanges]]
         *
         * @returns an IMatchingNodes object, or null. If an IMatchingNodes object is returned, its values
         * are the matching [[PathNode]]s for each [[HookMatchCriterion]] (to, from, exiting, retained, entering)
         */
        RegisteredHook.prototype.matches = function (treeChanges, transition) {
            var matches = this._getMatchingNodes(treeChanges, transition);
            // Check if all the criteria matched the TreeChanges object
            var allMatched = values(matches).every(identity);
            return allMatched ? matches : null;
        };
        RegisteredHook.prototype.deregister = function () {
            this.removeHookFromRegistry(this);
            this._deregistered = true;
        };
        return RegisteredHook;
    }());
    /** Return a registration function of the requested type. */
    function makeEvent(registry, transitionService, eventType) {
        // Create the object which holds the registered transition hooks.
        var _registeredHooks = (registry._registeredHooks = registry._registeredHooks || {});
        var hooks = (_registeredHooks[eventType.name] = []);
        var removeHookFn = removeFrom(hooks);
        // Create hook registration function on the IHookRegistry for the event
        registry[eventType.name] = hookRegistrationFn;
        function hookRegistrationFn(matchObject, callback, options) {
            if (options === void 0) { options = {}; }
            var registeredHook = new RegisteredHook(transitionService, eventType, callback, matchObject, removeHookFn, options);
            hooks.push(registeredHook);
            return registeredHook.deregister.bind(registeredHook);
        }
        return hookRegistrationFn;
    }

    /**
     * This class returns applicable TransitionHooks for a specific Transition instance.
     *
     * Hooks ([[RegisteredHook]]) may be registered globally, e.g., $transitions.onEnter(...), or locally, e.g.
     * myTransition.onEnter(...).  The HookBuilder finds matching RegisteredHooks (where the match criteria is
     * determined by the type of hook)
     *
     * The HookBuilder also converts RegisteredHooks objects to TransitionHook objects, which are used to run a Transition.
     *
     * The HookBuilder constructor is given the $transitions service and a Transition instance.  Thus, a HookBuilder
     * instance may only be used for one specific Transition object. (side note: the _treeChanges accessor is private
     * in the Transition class, so we must also provide the Transition's _treeChanges)
     */
    var HookBuilder = /** @class */ (function () {
        function HookBuilder(transition) {
            this.transition = transition;
        }
        HookBuilder.prototype.buildHooksForPhase = function (phase) {
            var _this = this;
            var $transitions = this.transition.router.transitionService;
            return $transitions._pluginapi
                ._getEvents(phase)
                .map(function (type) { return _this.buildHooks(type); })
                .reduce(unnestR, [])
                .filter(identity);
        };
        /**
         * Returns an array of newly built TransitionHook objects.
         *
         * - Finds all RegisteredHooks registered for the given `hookType` which matched the transition's [[TreeChanges]].
         * - Finds [[PathNode]] (or `PathNode[]`) to use as the TransitionHook context(s)
         * - For each of the [[PathNode]]s, creates a TransitionHook
         *
         * @param hookType the type of the hook registration function, e.g., 'onEnter', 'onFinish'.
         */
        HookBuilder.prototype.buildHooks = function (hookType) {
            var transition = this.transition;
            var treeChanges = transition.treeChanges();
            // Find all the matching registered hooks for a given hook type
            var matchingHooks = this.getMatchingHooks(hookType, treeChanges, transition);
            if (!matchingHooks)
                return [];
            var baseHookOptions = {
                transition: transition,
                current: transition.options().current,
            };
            var makeTransitionHooks = function (hook) {
                // Fetch the Nodes that caused this hook to match.
                var matches = hook.matches(treeChanges, transition);
                // Select the PathNode[] that will be used as TransitionHook context objects
                var matchingNodes = matches[hookType.criteriaMatchPath.name];
                // Return an array of HookTuples
                return matchingNodes.map(function (node) {
                    var _options = extend({
                        bind: hook.bind,
                        traceData: { hookType: hookType.name, context: node },
                    }, baseHookOptions);
                    var state = hookType.criteriaMatchPath.scope === exports.TransitionHookScope.STATE ? node.state.self : null;
                    var transitionHook = new TransitionHook(transition, state, hook, _options);
                    return { hook: hook, node: node, transitionHook: transitionHook };
                });
            };
            return matchingHooks
                .map(makeTransitionHooks)
                .reduce(unnestR, [])
                .sort(tupleSort(hookType.reverseSort))
                .map(function (tuple) { return tuple.transitionHook; });
        };
        /**
         * Finds all RegisteredHooks from:
         * - The Transition object instance hook registry
         * - The TransitionService ($transitions) global hook registry
         *
         * which matched:
         * - the eventType
         * - the matchCriteria (to, from, exiting, retained, entering)
         *
         * @returns an array of matched [[RegisteredHook]]s
         */
        HookBuilder.prototype.getMatchingHooks = function (hookType, treeChanges, transition) {
            var isCreate = hookType.hookPhase === exports.TransitionHookPhase.CREATE;
            // Instance and Global hook registries
            var $transitions = this.transition.router.transitionService;
            var registries = isCreate ? [$transitions] : [this.transition, $transitions];
            return registries
                .map(function (reg) { return reg.getHooks(hookType.name); }) // Get named hooks from registries
                .filter(assertPredicate(isArray, "broken event named: " + hookType.name)) // Sanity check
                .reduce(unnestR, []) // Un-nest RegisteredHook[][] to RegisteredHook[] array
                .filter(function (hook) { return hook.matches(treeChanges, transition); }); // Only those satisfying matchCriteria
        };
        return HookBuilder;
    }());
    /**
     * A factory for a sort function for HookTuples.
     *
     * The sort function first compares the PathNode depth (how deep in the state tree a node is), then compares
     * the EventHook priority.
     *
     * @param reverseDepthSort a boolean, when true, reverses the sort order for the node depth
     * @returns a tuple sort function
     */
    function tupleSort(reverseDepthSort) {
        if (reverseDepthSort === void 0) { reverseDepthSort = false; }
        return function nodeDepthThenPriority(l, r) {
            var factor = reverseDepthSort ? -1 : 1;
            var depthDelta = (l.node.state.path.length - r.node.state.path.length) * factor;
            return depthDelta !== 0 ? depthDelta : r.hook.priority - l.hook.priority;
        };
    }

    /** @internal */
    var stateSelf = prop('self');
    /**
     * Represents a transition between two states.
     *
     * When navigating to a state, we are transitioning **from** the current state **to** the new state.
     *
     * This object contains all contextual information about the to/from states, parameters, resolves.
     * It has information about all states being entered and exited as a result of the transition.
     */
    var Transition = /** @class */ (function () {
        /**
         * Creates a new Transition object.
         *
         * If the target state is not valid, an error is thrown.
         *
         * @internal
         *
         * @param fromPath The path of [[PathNode]]s from which the transition is leaving.  The last node in the `fromPath`
         *        encapsulates the "from state".
         * @param targetState The target state and parameters being transitioned to (also, the transition options)
         * @param router The [[UIRouter]] instance
         * @internal
         */
        function Transition(fromPath, targetState, router) {
            var _this = this;
            /** @internal */
            this._deferred = services.$q.defer();
            /**
             * This promise is resolved or rejected based on the outcome of the Transition.
             *
             * When the transition is successful, the promise is resolved
             * When the transition is unsuccessful, the promise is rejected with the [[Rejection]] or javascript error
             */
            this.promise = this._deferred.promise;
            /** @internal Holds the hook registration functions such as those passed to Transition.onStart() */
            this._registeredHooks = {};
            /** @internal */
            this._hookBuilder = new HookBuilder(this);
            /** Checks if this transition is currently active/running. */
            this.isActive = function () { return _this.router.globals.transition === _this; };
            this.router = router;
            this._targetState = targetState;
            if (!targetState.valid()) {
                throw new Error(targetState.error());
            }
            // current() is assumed to come from targetState.options, but provide a naive implementation otherwise.
            this._options = extend({ current: val(this) }, targetState.options());
            this.$id = router.transitionService._transitionCount++;
            var toPath = PathUtils.buildToPath(fromPath, targetState);
            this._treeChanges = PathUtils.treeChanges(fromPath, toPath, this._options.reloadState);
            this.createTransitionHookRegFns();
            var onCreateHooks = this._hookBuilder.buildHooksForPhase(exports.TransitionHookPhase.CREATE);
            TransitionHook.invokeHooks(onCreateHooks, function () { return null; });
            this.applyViewConfigs(router);
        }
        /** @internal */
        Transition.prototype.onBefore = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onStart = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onExit = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onRetain = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onEnter = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onFinish = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onSuccess = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        Transition.prototype.onError = function (criteria, callback, options) {
            return;
        };
        /** @internal
         * Creates the transition-level hook registration functions
         * (which can then be used to register hooks)
         */
        Transition.prototype.createTransitionHookRegFns = function () {
            var _this = this;
            this.router.transitionService._pluginapi
                ._getEvents()
                .filter(function (type) { return type.hookPhase !== exports.TransitionHookPhase.CREATE; })
                .forEach(function (type) { return makeEvent(_this, _this.router.transitionService, type); });
        };
        /** @internal */
        Transition.prototype.getHooks = function (hookName) {
            return this._registeredHooks[hookName];
        };
        Transition.prototype.applyViewConfigs = function (router) {
            var enteringStates = this._treeChanges.entering.map(function (node) { return node.state; });
            PathUtils.applyViewConfigs(router.transitionService.$view, this._treeChanges.to, enteringStates);
        };
        /**
         * @internal
         * @returns the internal from [State] object
         */
        Transition.prototype.$from = function () {
            return tail(this._treeChanges.from).state;
        };
        /**
         * @internal
         * @returns the internal to [State] object
         */
        Transition.prototype.$to = function () {
            return tail(this._treeChanges.to).state;
        };
        /**
         * Returns the "from state"
         *
         * Returns the state that the transition is coming *from*.
         *
         * @returns The state declaration object for the Transition's ("from state").
         */
        Transition.prototype.from = function () {
            return this.$from().self;
        };
        /**
         * Returns the "to state"
         *
         * Returns the state that the transition is going *to*.
         *
         * @returns The state declaration object for the Transition's target state ("to state").
         */
        Transition.prototype.to = function () {
            return this.$to().self;
        };
        /**
         * Gets the Target State
         *
         * A transition's [[TargetState]] encapsulates the [[to]] state, the [[params]], and the [[options]] as a single object.
         *
         * @returns the [[TargetState]] of this Transition
         */
        Transition.prototype.targetState = function () {
            return this._targetState;
        };
        /**
         * Determines whether two transitions are equivalent.
         * @deprecated
         */
        Transition.prototype.is = function (compare) {
            if (compare instanceof Transition) {
                // TODO: Also compare parameters
                return this.is({ to: compare.$to().name, from: compare.$from().name });
            }
            return !((compare.to && !matchState(this.$to(), compare.to, this)) ||
                (compare.from && !matchState(this.$from(), compare.from, this)));
        };
        Transition.prototype.params = function (pathname) {
            if (pathname === void 0) { pathname = 'to'; }
            return Object.freeze(this._treeChanges[pathname].map(prop('paramValues')).reduce(mergeR, {}));
        };
        Transition.prototype.paramsChanged = function () {
            var fromParams = this.params('from');
            var toParams = this.params('to');
            // All the parameters declared on both the "to" and "from" paths
            var allParamDescriptors = []
                .concat(this._treeChanges.to)
                .concat(this._treeChanges.from)
                .map(function (pathNode) { return pathNode.paramSchema; })
                .reduce(flattenR, [])
                .reduce(uniqR, []);
            var changedParamDescriptors = Param.changed(allParamDescriptors, fromParams, toParams);
            return changedParamDescriptors.reduce(function (changedValues, descriptor) {
                changedValues[descriptor.id] = toParams[descriptor.id];
                return changedValues;
            }, {});
        };
        /**
         * Creates a [[UIInjector]] Dependency Injector
         *
         * Returns a Dependency Injector for the Transition's target state (to state).
         * The injector provides resolve values which the target state has access to.
         *
         * The `UIInjector` can also provide values from the native root/global injector (ng1/ng2).
         *
         * #### Example:
         * ```js
         * .onEnter({ entering: 'myState' }, trans => {
         *   var myResolveValue = trans.injector().get('myResolve');
         *   // Inject a global service from the global/native injector (if it exists)
         *   var MyService = trans.injector().get('MyService');
         * })
         * ```
         *
         * In some cases (such as `onBefore`), you may need access to some resolve data but it has not yet been fetched.
         * You can use [[UIInjector.getAsync]] to get a promise for the data.
         * #### Example:
         * ```js
         * .onBefore({}, trans => {
         *   return trans.injector().getAsync('myResolve').then(myResolveValue =>
         *     return myResolveValue !== 'ABORT';
         *   });
         * });
         * ```
         *
         * If a `state` is provided, the injector that is returned will be limited to resolve values that the provided state has access to.
         * This can be useful if both a parent state `foo` and a child state `foo.bar` have both defined a resolve such as `data`.
         * #### Example:
         * ```js
         * .onEnter({ to: 'foo.bar' }, trans => {
         *   // returns result of `foo` state's `myResolve` resolve
         *   // even though `foo.bar` also has a `myResolve` resolve
         *   var fooData = trans.injector('foo').get('myResolve');
         * });
         * ```
         *
         * If you need resolve data from the exiting states, pass `'from'` as `pathName`.
         * The resolve data from the `from` path will be returned.
         * #### Example:
         * ```js
         * .onExit({ exiting: 'foo.bar' }, trans => {
         *   // Gets the resolve value of `myResolve` from the state being exited
         *   var fooData = trans.injector(null, 'from').get('myResolve');
         * });
         * ```
         *
         *
         * @param state Limits the resolves provided to only the resolves the provided state has access to.
         * @param pathName Default: `'to'`: Chooses the path for which to create the injector. Use this to access resolves for `exiting` states.
         *
         * @returns a [[UIInjector]]
         */
        Transition.prototype.injector = function (state, pathName) {
            if (pathName === void 0) { pathName = 'to'; }
            var path = this._treeChanges[pathName];
            if (state)
                path = PathUtils.subPath(path, function (node) { return node.state === state || node.state.name === state; });
            return new ResolveContext(path).injector();
        };
        /**
         * Gets all available resolve tokens (keys)
         *
         * This method can be used in conjunction with [[injector]] to inspect the resolve values
         * available to the Transition.
         *
         * This returns all the tokens defined on [[StateDeclaration.resolve]] blocks, for the states
         * in the Transition's [[TreeChanges.to]] path.
         *
         * #### Example:
         * This example logs all resolve values
         * ```js
         * let tokens = trans.getResolveTokens();
         * tokens.forEach(token => console.log(token + " = " + trans.injector().get(token)));
         * ```
         *
         * #### Example:
         * This example creates promises for each resolve value.
         * This triggers fetches of resolves (if any have not yet been fetched).
         * When all promises have all settled, it logs the resolve values.
         * ```js
         * let tokens = trans.getResolveTokens();
         * let promise = tokens.map(token => trans.injector().getAsync(token));
         * Promise.all(promises).then(values => console.log("Resolved values: " + values));
         * ```
         *
         * Note: Angular 1 users whould use `$q.all()`
         *
         * @param pathname resolve context's path name (e.g., `to` or `from`)
         *
         * @returns an array of resolve tokens (keys)
         */
        Transition.prototype.getResolveTokens = function (pathname) {
            if (pathname === void 0) { pathname = 'to'; }
            return new ResolveContext(this._treeChanges[pathname]).getTokens();
        };
        /**
         * Dynamically adds a new [[Resolvable]] (i.e., [[StateDeclaration.resolve]]) to this transition.
         *
         * Allows a transition hook to dynamically add a Resolvable to this Transition.
         *
         * Use the [[Transition.injector]] to retrieve the resolved data in subsequent hooks ([[UIInjector.get]]).
         *
         * If a `state` argument is provided, the Resolvable is processed when that state is being entered.
         * If no `state` is provided then the root state is used.
         * If the given `state` has already been entered, the Resolvable is processed when any child state is entered.
         * If no child states will be entered, the Resolvable is processed during the `onFinish` phase of the Transition.
         *
         * The `state` argument also scopes the resolved data.
         * The resolved data is available from the injector for that `state` and any children states.
         *
         * #### Example:
         * ```js
         * transitionService.onBefore({}, transition => {
         *   transition.addResolvable({
         *     token: 'myResolve',
         *     deps: ['MyService'],
         *     resolveFn: myService => myService.getData()
         *   });
         * });
         * ```
         *
         * @param resolvable a [[ResolvableLiteral]] object (or a [[Resolvable]])
         * @param state the state in the "to path" which should receive the new resolve (otherwise, the root state)
         */
        Transition.prototype.addResolvable = function (resolvable, state) {
            if (state === void 0) { state = ''; }
            resolvable = is(Resolvable)(resolvable) ? resolvable : new Resolvable(resolvable);
            var stateName = typeof state === 'string' ? state : state.name;
            var topath = this._treeChanges.to;
            var targetNode = find(topath, function (node) { return node.state.name === stateName; });
            var resolveContext = new ResolveContext(topath);
            resolveContext.addResolvables([resolvable], targetNode.state);
        };
        /**
         * Gets the transition from which this transition was redirected.
         *
         * If the current transition is a redirect, this method returns the transition that was redirected.
         *
         * #### Example:
         * ```js
         * let transitionA = $state.go('A').transition
         * transitionA.onStart({}, () => $state.target('B'));
         * $transitions.onSuccess({ to: 'B' }, (trans) => {
         *   trans.to().name === 'B'; // true
         *   trans.redirectedFrom() === transitionA; // true
         * });
         * ```
         *
         * @returns The previous Transition, or null if this Transition is not the result of a redirection
         */
        Transition.prototype.redirectedFrom = function () {
            return this._options.redirectedFrom || null;
        };
        /**
         * Gets the original transition in a redirect chain
         *
         * A transition might belong to a long chain of multiple redirects.
         * This method walks the [[redirectedFrom]] chain back to the original (first) transition in the chain.
         *
         * #### Example:
         * ```js
         * // states
         * registry.register({ name: 'A', redirectTo: 'B' });
         * registry.register({ name: 'B', redirectTo: 'C' });
         * registry.register({ name: 'C', redirectTo: 'D' });
         * registry.register({ name: 'D' });
         *
         * let transitionA = $state.go('A').transition
         *
         * $transitions.onSuccess({ to: 'D' }, (trans) => {
         *   trans.to().name === 'D'; // true
         *   trans.redirectedFrom().to().name === 'C'; // true
         *   trans.originalTransition() === transitionA; // true
         *   trans.originalTransition().to().name === 'A'; // true
         * });
         * ```
         *
         * @returns The original Transition that started a redirect chain
         */
        Transition.prototype.originalTransition = function () {
            var rf = this.redirectedFrom();
            return (rf && rf.originalTransition()) || this;
        };
        /**
         * Get the transition options
         *
         * @returns the options for this Transition.
         */
        Transition.prototype.options = function () {
            return this._options;
        };
        /**
         * Gets the states being entered.
         *
         * @returns an array of states that will be entered during this transition.
         */
        Transition.prototype.entering = function () {
            return map(this._treeChanges.entering, prop('state')).map(stateSelf);
        };
        /**
         * Gets the states being exited.
         *
         * @returns an array of states that will be exited during this transition.
         */
        Transition.prototype.exiting = function () {
            return map(this._treeChanges.exiting, prop('state')).map(stateSelf).reverse();
        };
        /**
         * Gets the states being retained.
         *
         * @returns an array of states that are already entered from a previous Transition, that will not be
         *    exited during this Transition
         */
        Transition.prototype.retained = function () {
            return map(this._treeChanges.retained, prop('state')).map(stateSelf);
        };
        /**
         * Get the [[ViewConfig]]s associated with this Transition
         *
         * Each state can define one or more views (template/controller), which are encapsulated as `ViewConfig` objects.
         * This method fetches the `ViewConfigs` for a given path in the Transition (e.g., "to" or "entering").
         *
         * @param pathname the name of the path to fetch views for:
         *   (`'to'`, `'from'`, `'entering'`, `'exiting'`, `'retained'`)
         * @param state If provided, only returns the `ViewConfig`s for a single state in the path
         *
         * @returns a list of ViewConfig objects for the given path.
         */
        Transition.prototype.views = function (pathname, state) {
            if (pathname === void 0) { pathname = 'entering'; }
            var path = this._treeChanges[pathname];
            path = !state ? path : path.filter(propEq('state', state));
            return path.map(prop('views')).filter(identity).reduce(unnestR, []);
        };
        Transition.prototype.treeChanges = function (pathname) {
            return pathname ? this._treeChanges[pathname] : this._treeChanges;
        };
        /**
         * Creates a new transition that is a redirection of the current one.
         *
         * This transition can be returned from a [[TransitionService]] hook to
         * redirect a transition to a new state and/or set of parameters.
         *
         * @internal
         *
         * @returns Returns a new [[Transition]] instance.
         */
        Transition.prototype.redirect = function (targetState) {
            var redirects = 1, trans = this;
            // tslint:disable-next-line:no-conditional-assignment
            while ((trans = trans.redirectedFrom()) != null) {
                if (++redirects > 20)
                    throw new Error("Too many consecutive Transition redirects (20+)");
            }
            var redirectOpts = { redirectedFrom: this, source: 'redirect' };
            // If the original transition was caused by URL sync, then use { location: 'replace' }
            // on the new transition (unless the target state explicitly specifies location: false).
            // This causes the original url to be replaced with the url for the redirect target
            // so the original url disappears from the browser history.
            if (this.options().source === 'url' && targetState.options().location !== false) {
                redirectOpts.location = 'replace';
            }
            var newOptions = extend({}, this.options(), targetState.options(), redirectOpts);
            targetState = targetState.withOptions(newOptions, true);
            var newTransition = this.router.transitionService.create(this._treeChanges.from, targetState);
            var originalEnteringNodes = this._treeChanges.entering;
            var redirectEnteringNodes = newTransition._treeChanges.entering;
            // --- Re-use resolve data from original transition ---
            // When redirecting from a parent state to a child state where the parent parameter values haven't changed
            // (because of the redirect), the resolves fetched by the original transition are still valid in the
            // redirected transition.
            //
            // This allows you to define a redirect on a parent state which depends on an async resolve value.
            // You can wait for the resolve, then redirect to a child state based on the result.
            // The redirected transition does not have to re-fetch the resolve.
            // ---------------------------------------------------------
            var nodeIsReloading = function (reloadState) { return function (node) {
                return reloadState && node.state.includes[reloadState.name];
            }; };
            // Find any "entering" nodes in the redirect path that match the original path and aren't being reloaded
            var matchingEnteringNodes = PathUtils.matching(redirectEnteringNodes, originalEnteringNodes, PathUtils.nonDynamicParams).filter(not(nodeIsReloading(targetState.options().reloadState)));
            // Use the existing (possibly pre-resolved) resolvables for the matching entering nodes.
            matchingEnteringNodes.forEach(function (node, idx) {
                node.resolvables = originalEnteringNodes[idx].resolvables;
            });
            return newTransition;
        };
        /** @internal If a transition doesn't exit/enter any states, returns any [[Param]] whose value changed */
        Transition.prototype._changedParams = function () {
            var tc = this._treeChanges;
            /** Return undefined if it's not a "dynamic" transition, for the following reasons */
            // If user explicitly wants a reload
            if (this._options.reload)
                return undefined;
            // If any states are exiting or entering
            if (tc.exiting.length || tc.entering.length)
                return undefined;
            // If to/from path lengths differ
            if (tc.to.length !== tc.from.length)
                return undefined;
            // If the to/from paths are different
            var pathsDiffer = arrayTuples(tc.to, tc.from)
                .map(function (tuple) { return tuple[0].state !== tuple[1].state; })
                .reduce(anyTrueR, false);
            if (pathsDiffer)
                return undefined;
            // Find any parameter values that differ
            var nodeSchemas = tc.to.map(function (node) { return node.paramSchema; });
            var _a = [tc.to, tc.from].map(function (path) { return path.map(function (x) { return x.paramValues; }); }), toValues = _a[0], fromValues = _a[1];
            var tuples = arrayTuples(nodeSchemas, toValues, fromValues);
            return tuples.map(function (_a) {
                var schema = _a[0], toVals = _a[1], fromVals = _a[2];
                return Param.changed(schema, toVals, fromVals);
            }).reduce(unnestR, []);
        };
        /**
         * Returns true if the transition is dynamic.
         *
         * A transition is dynamic if no states are entered nor exited, but at least one dynamic parameter has changed.
         *
         * @returns true if the Transition is dynamic
         */
        Transition.prototype.dynamic = function () {
            var changes = this._changedParams();
            return !changes ? false : changes.map(function (x) { return x.dynamic; }).reduce(anyTrueR, false);
        };
        /**
         * Returns true if the transition is ignored.
         *
         * A transition is ignored if no states are entered nor exited, and no parameter values have changed.
         *
         * @returns true if the Transition is ignored.
         */
        Transition.prototype.ignored = function () {
            return !!this._ignoredReason();
        };
        /** @internal */
        Transition.prototype._ignoredReason = function () {
            var pending = this.router.globals.transition;
            var reloadState = this._options.reloadState;
            var same = function (pathA, pathB) {
                if (pathA.length !== pathB.length)
                    return false;
                var matching = PathUtils.matching(pathA, pathB);
                return pathA.length === matching.filter(function (node) { return !reloadState || !node.state.includes[reloadState.name]; }).length;
            };
            var newTC = this.treeChanges();
            var pendTC = pending && pending.treeChanges();
            if (pendTC && same(pendTC.to, newTC.to) && same(pendTC.exiting, newTC.exiting))
                return 'SameAsPending';
            if (newTC.exiting.length === 0 && newTC.entering.length === 0 && same(newTC.from, newTC.to))
                return 'SameAsCurrent';
        };
        /**
         * Runs the transition
         *
         * This method is generally called from the [[StateService.transitionTo]]
         *
         * @internal
         *
         * @returns a promise for a successful transition.
         */
        Transition.prototype.run = function () {
            var _this = this;
            var runAllHooks = TransitionHook.runAllHooks;
            // Gets transition hooks array for the given phase
            var getHooksFor = function (phase) { return _this._hookBuilder.buildHooksForPhase(phase); };
            // When the chain is complete, then resolve or reject the deferred
            var transitionSuccess = function () {
                trace.traceSuccess(_this.$to(), _this);
                _this.success = true;
                _this._deferred.resolve(_this.to());
                runAllHooks(getHooksFor(exports.TransitionHookPhase.SUCCESS));
            };
            var transitionError = function (reason) {
                trace.traceError(reason, _this);
                _this.success = false;
                _this._deferred.reject(reason);
                _this._error = reason;
                runAllHooks(getHooksFor(exports.TransitionHookPhase.ERROR));
            };
            var runTransition = function () {
                // Wait to build the RUN hook chain until the BEFORE hooks are done
                // This allows a BEFORE hook to dynamically add additional RUN hooks via the Transition object.
                var allRunHooks = getHooksFor(exports.TransitionHookPhase.RUN);
                var done = function () { return services.$q.when(undefined); };
                return TransitionHook.invokeHooks(allRunHooks, done);
            };
            var startTransition = function () {
                var globals = _this.router.globals;
                globals.lastStartedTransitionId = _this.$id;
                globals.transition = _this;
                globals.transitionHistory.enqueue(_this);
                trace.traceTransitionStart(_this);
                return services.$q.when(undefined);
            };
            var allBeforeHooks = getHooksFor(exports.TransitionHookPhase.BEFORE);
            TransitionHook.invokeHooks(allBeforeHooks, startTransition)
                .then(runTransition)
                .then(transitionSuccess, transitionError);
            return this.promise;
        };
        /**
         * Checks if the Transition is valid
         *
         * @returns true if the Transition is valid
         */
        Transition.prototype.valid = function () {
            return !this.error() || this.success !== undefined;
        };
        /**
         * Aborts this transition
         *
         * Imperative API to abort a Transition.
         * This only applies to Transitions that are not yet complete.
         */
        Transition.prototype.abort = function () {
            // Do not set flag if the transition is already complete
            if (isUndefined(this.success)) {
                this._aborted = true;
            }
        };
        /**
         * The Transition error reason.
         *
         * If the transition is invalid (and could not be run), returns the reason the transition is invalid.
         * If the transition was valid and ran, but was not successful, returns the reason the transition failed.
         *
         * @returns a transition rejection explaining why the transition is invalid, or the reason the transition failed.
         */
        Transition.prototype.error = function () {
            var state = this.$to();
            if (state.self.abstract) {
                return Rejection.invalid("Cannot transition to abstract state '" + state.name + "'");
            }
            var paramDefs = state.parameters();
            var values = this.params();
            var invalidParams = paramDefs.filter(function (param) { return !param.validates(values[param.id]); });
            if (invalidParams.length) {
                var invalidValues = invalidParams.map(function (param) { return "[" + param.id + ":" + stringify(values[param.id]) + "]"; }).join(', ');
                var detail = "The following parameter values are not valid for state '" + state.name + "': " + invalidValues;
                return Rejection.invalid(detail);
            }
            if (this.success === false)
                return this._error;
        };
        /**
         * A string representation of the Transition
         *
         * @returns A string representation of the Transition
         */
        Transition.prototype.toString = function () {
            var fromStateOrName = this.from();
            var toStateOrName = this.to();
            var avoidEmptyHash = function (params) {
                return params['#'] !== null && params['#'] !== undefined ? params : omit(params, ['#']);
            };
            // (X) means the to state is invalid.
            var id = this.$id, from = isObject(fromStateOrName) ? fromStateOrName.name : fromStateOrName, fromParams = stringify(avoidEmptyHash(this._treeChanges.from.map(prop('paramValues')).reduce(mergeR, {}))), toValid = this.valid() ? '' : '(X) ', to = isObject(toStateOrName) ? toStateOrName.name : toStateOrName, toParams = stringify(avoidEmptyHash(this.params()));
            return "Transition#" + id + "( '" + from + "'" + fromParams + " -> " + toValid + "'" + to + "'" + toParams + " )";
        };
        /** @internal */
        Transition.diToken = Transition;
        return Transition;
    }());

    function quoteRegExp(str, param) {
        var surroundPattern = ['', ''], result = str.replace(/[\\\[\]\^$*+?.()|{}]/g, '\\$&');
        if (!param)
            return result;
        switch (param.squash) {
            case false:
                surroundPattern = ['(', ')' + (param.isOptional ? '?' : '')];
                break;
            case true:
                result = result.replace(/\/$/, '');
                surroundPattern = ['(?:/(', ')|/)?'];
                break;
            default:
                surroundPattern = ["(" + param.squash + "|", ')?'];
                break;
        }
        return result + surroundPattern[0] + param.type.pattern.source + surroundPattern[1];
    }
    var memoizeTo = function (obj, _prop, fn) { return (obj[_prop] = obj[_prop] || fn()); };
    var splitOnSlash = splitOnDelim('/');
    var defaultConfig = {
        state: { params: {} },
        strict: true,
        caseInsensitive: true,
        decodeParams: true,
    };
    /**
     * Matches URLs against patterns.
     *
     * Matches URLs against patterns and extracts named parameters from the path or the search
     * part of the URL.
     *
     * A URL pattern consists of a path pattern, optionally followed by '?' and a list of search (query)
     * parameters. Multiple search parameter names are separated by '&'. Search parameters
     * do not influence whether or not a URL is matched, but their values are passed through into
     * the matched parameters returned by [[UrlMatcher.exec]].
     *
     * - *Path parameters* are defined using curly brace placeholders (`/somepath/{param}`)
     * or colon placeholders (`/somePath/:param`).
     *
     * - *A parameter RegExp* may be defined for a param after a colon
     * (`/somePath/{param:[a-zA-Z0-9]+}`) in a curly brace placeholder.
     * The regexp must match for the url to be matched.
     * Should the regexp itself contain curly braces, they must be in matched pairs or escaped with a backslash.
     *
     * Note: a RegExp parameter will encode its value using either [[ParamTypes.path]] or [[ParamTypes.query]].
     *
     * - *Custom parameter types* may also be specified after a colon (`/somePath/{param:int}`) in curly brace parameters.
     *   See [[UrlMatcherFactory.type]] for more information.
     *
     * - *Catch-all parameters* are defined using an asterisk placeholder (`/somepath/*catchallparam`).
     *   A catch-all * parameter value will contain the remainder of the URL.
     *
     * ---
     *
     * Parameter names may contain only word characters (latin letters, digits, and underscore) and
     * must be unique within the pattern (across both path and search parameters).
     * A path parameter matches any number of characters other than '/'. For catch-all
     * placeholders the path parameter matches any number of characters.
     *
     * Examples:
     *
     * * `'/hello/'` - Matches only if the path is exactly '/hello/'. There is no special treatment for
     *   trailing slashes, and patterns have to match the entire path, not just a prefix.
     * * `'/user/:id'` - Matches '/user/bob' or '/user/1234!!!' or even '/user/' but not '/user' or
     *   '/user/bob/details'. The second path segment will be captured as the parameter 'id'.
     * * `'/user/{id}'` - Same as the previous example, but using curly brace syntax.
     * * `'/user/{id:[^/]*}'` - Same as the previous example.
     * * `'/user/{id:[0-9a-fA-F]{1,8}}'` - Similar to the previous example, but only matches if the id
     *   parameter consists of 1 to 8 hex digits.
     * * `'/files/{path:.*}'` - Matches any URL starting with '/files/' and captures the rest of the
     *   path into the parameter 'path'.
     * * `'/files/*path'` - ditto.
     * * `'/calendar/{start:date}'` - Matches "/calendar/2014-11-12" (because the pattern defined
     *   in the built-in  `date` ParamType matches `2014-11-12`) and provides a Date object in $stateParams.start
     *
     */
    var UrlMatcher = /** @class */ (function () {
        /**
         * @param pattern The pattern to compile into a matcher.
         * @param paramTypes The [[ParamTypes]] registry
         * @param paramFactory A [[ParamFactory]] object
         * @param config  A [[UrlMatcherCompileConfig]] configuration object
         */
        function UrlMatcher(pattern, paramTypes, paramFactory, config) {
            var _this = this;
            /** @internal */
            this._cache = { path: [this] };
            /** @internal */
            this._children = [];
            /** @internal */
            this._params = [];
            /** @internal */
            this._segments = [];
            /** @internal */
            this._compiled = [];
            this.config = config = defaults(config, defaultConfig);
            this.pattern = pattern;
            // Find all placeholders and create a compiled pattern, using either classic or curly syntax:
            //   '*' name
            //   ':' name
            //   '{' name '}'
            //   '{' name ':' regexp '}'
            // The regular expression is somewhat complicated due to the need to allow curly braces
            // inside the regular expression. The placeholder regexp breaks down as follows:
            //    ([:*])([\w\[\]]+)              - classic placeholder ($1 / $2) (search version has - for snake-case)
            //    \{([\w\[\]]+)(?:\:\s*( ... ))?\}  - curly brace placeholder ($3) with optional regexp/type ... ($4) (search version has - for snake-case
            //    (?: ... | ... | ... )+         - the regexp consists of any number of atoms, an atom being either
            //    [^{}\\]+                       - anything other than curly braces or backslash
            //    \\.                            - a backslash escape
            //    \{(?:[^{}\\]+|\\.)*\}          - a matched set of curly braces containing other atoms
            var placeholder = /([:*])([\w\[\]]+)|\{([\w\[\]]+)(?:\:\s*((?:[^{}\\]+|\\.|\{(?:[^{}\\]+|\\.)*\})+))?\}/g;
            var searchPlaceholder = /([:]?)([\w\[\].-]+)|\{([\w\[\].-]+)(?:\:\s*((?:[^{}\\]+|\\.|\{(?:[^{}\\]+|\\.)*\})+))?\}/g;
            var patterns = [];
            var last = 0;
            var matchArray;
            var checkParamErrors = function (id) {
                if (!UrlMatcher.nameValidator.test(id))
                    throw new Error("Invalid parameter name '" + id + "' in pattern '" + pattern + "'");
                if (find(_this._params, propEq('id', id)))
                    throw new Error("Duplicate parameter name '" + id + "' in pattern '" + pattern + "'");
            };
            // Split into static segments separated by path parameter placeholders.
            // The number of segments is always 1 more than the number of parameters.
            var matchDetails = function (m, isSearch) {
                // IE[78] returns '' for unmatched groups instead of null
                var id = m[2] || m[3];
                var regexp = isSearch ? m[4] : m[4] || (m[1] === '*' ? '[\\s\\S]*' : null);
                var makeRegexpType = function (str) {
                    return inherit(paramTypes.type(isSearch ? 'query' : 'path'), {
                        pattern: new RegExp(str, _this.config.caseInsensitive ? 'i' : undefined),
                    });
                };
                return {
                    id: id,
                    regexp: regexp,
                    segment: pattern.substring(last, m.index),
                    type: !regexp ? null : paramTypes.type(regexp) || makeRegexpType(regexp),
                };
            };
            var details;
            var segment;
            // tslint:disable-next-line:no-conditional-assignment
            while ((matchArray = placeholder.exec(pattern))) {
                details = matchDetails(matchArray, false);
                if (details.segment.indexOf('?') >= 0)
                    break; // we're into the search part
                checkParamErrors(details.id);
                this._params.push(paramFactory.fromPath(details.id, details.type, config.state));
                this._segments.push(details.segment);
                patterns.push([details.segment, tail(this._params)]);
                last = placeholder.lastIndex;
            }
            segment = pattern.substring(last);
            // Find any search parameter names and remove them from the last segment
            var i = segment.indexOf('?');
            if (i >= 0) {
                var search = segment.substring(i);
                segment = segment.substring(0, i);
                if (search.length > 0) {
                    last = 0;
                    // tslint:disable-next-line:no-conditional-assignment
                    while ((matchArray = searchPlaceholder.exec(search))) {
                        details = matchDetails(matchArray, true);
                        checkParamErrors(details.id);
                        this._params.push(paramFactory.fromSearch(details.id, details.type, config.state));
                        last = placeholder.lastIndex;
                        // check if ?&
                    }
                }
            }
            this._segments.push(segment);
            this._compiled = patterns.map(function (_pattern) { return quoteRegExp.apply(null, _pattern); }).concat(quoteRegExp(segment));
        }
        /** @internal */
        UrlMatcher.encodeDashes = function (str) {
            // Replace dashes with encoded "\-"
            return encodeURIComponent(str).replace(/-/g, function (c) { return "%5C%" + c.charCodeAt(0).toString(16).toUpperCase(); });
        };
        /** @internal Given a matcher, return an array with the matcher's path segments and path params, in order */
        UrlMatcher.pathSegmentsAndParams = function (matcher) {
            var staticSegments = matcher._segments;
            var pathParams = matcher._params.filter(function (p) { return p.location === exports.DefType.PATH; });
            return arrayTuples(staticSegments, pathParams.concat(undefined))
                .reduce(unnestR, [])
                .filter(function (x) { return x !== '' && isDefined(x); });
        };
        /** @internal Given a matcher, return an array with the matcher's query params */
        UrlMatcher.queryParams = function (matcher) {
            return matcher._params.filter(function (p) { return p.location === exports.DefType.SEARCH; });
        };
        /**
         * Compare two UrlMatchers
         *
         * This comparison function converts a UrlMatcher into static and dynamic path segments.
         * Each static path segment is a static string between a path separator (slash character).
         * Each dynamic segment is a path parameter.
         *
         * The comparison function sorts static segments before dynamic ones.
         */
        UrlMatcher.compare = function (a, b) {
            /**
             * Turn a UrlMatcher and all its parent matchers into an array
             * of slash literals '/', string literals, and Param objects
             *
             * This example matcher matches strings like "/foo/:param/tail":
             * var matcher = $umf.compile("/foo").append($umf.compile("/:param")).append($umf.compile("/")).append($umf.compile("tail"));
             * var result = segments(matcher); // [ '/', 'foo', '/', Param, '/', 'tail' ]
             *
             * Caches the result as `matcher._cache.segments`
             */
            var segments = function (matcher) {
                return (matcher._cache.segments =
                    matcher._cache.segments ||
                        matcher._cache.path
                            .map(UrlMatcher.pathSegmentsAndParams)
                            .reduce(unnestR, [])
                            .reduce(joinNeighborsR, [])
                            .map(function (x) { return (isString(x) ? splitOnSlash(x) : x); })
                            .reduce(unnestR, []));
            };
            /**
             * Gets the sort weight for each segment of a UrlMatcher
             *
             * Caches the result as `matcher._cache.weights`
             */
            var weights = function (matcher) {
                return (matcher._cache.weights =
                    matcher._cache.weights ||
                        segments(matcher).map(function (segment) {
                            // Sort slashes first, then static strings, the Params
                            if (segment === '/')
                                return 1;
                            if (isString(segment))
                                return 2;
                            if (segment instanceof Param)
                                return 3;
                        }));
            };
            /**
             * Pads shorter array in-place (mutates)
             */
            var padArrays = function (l, r, padVal) {
                var len = Math.max(l.length, r.length);
                while (l.length < len)
                    l.push(padVal);
                while (r.length < len)
                    r.push(padVal);
            };
            var weightsA = weights(a), weightsB = weights(b);
            padArrays(weightsA, weightsB, 0);
            var _pairs = arrayTuples(weightsA, weightsB);
            var cmp, i;
            for (i = 0; i < _pairs.length; i++) {
                cmp = _pairs[i][0] - _pairs[i][1];
                if (cmp !== 0)
                    return cmp;
            }
            return 0;
        };
        /**
         * Creates a new concatenated UrlMatcher
         *
         * Builds a new UrlMatcher by appending another UrlMatcher to this one.
         *
         * @param url A `UrlMatcher` instance to append as a child of the current `UrlMatcher`.
         */
        UrlMatcher.prototype.append = function (url) {
            this._children.push(url);
            url._cache = {
                path: this._cache.path.concat(url),
                parent: this,
                pattern: null,
            };
            return url;
        };
        /** @internal */
        UrlMatcher.prototype.isRoot = function () {
            return this._cache.path[0] === this;
        };
        /** Returns the input pattern string */
        UrlMatcher.prototype.toString = function () {
            return this.pattern;
        };
        UrlMatcher.prototype._getDecodedParamValue = function (value, param) {
            if (isDefined(value)) {
                if (this.config.decodeParams && !param.type.raw && !isArray(value)) {
                    value = decodeURIComponent(value);
                }
                value = param.type.decode(value);
            }
            return param.value(value);
        };
        /**
         * Tests the specified url/path against this matcher.
         *
         * Tests if the given url matches this matcher's pattern, and returns an object containing the captured
         * parameter values.  Returns null if the path does not match.
         *
         * The returned object contains the values
         * of any search parameters that are mentioned in the pattern, but their value may be null if
         * they are not present in `search`. This means that search parameters are always treated
         * as optional.
         *
         * #### Example:
         * ```js
         * new UrlMatcher('/user/{id}?q&r').exec('/user/bob', {
         *   x: '1', q: 'hello'
         * });
         * // returns { id: 'bob', q: 'hello', r: null }
         * ```
         *
         * @param path    The URL path to match, e.g. `$location.path()`.
         * @param search  URL search parameters, e.g. `$location.search()`.
         * @param hash    URL hash e.g. `$location.hash()`.
         * @param options
         *
         * @returns The captured parameter values.
         */
        UrlMatcher.prototype.exec = function (path, search, hash, options) {
            var _this = this;
            if (search === void 0) { search = {}; }
            var match = memoizeTo(this._cache, 'pattern', function () {
                return new RegExp([
                    '^',
                    unnest(_this._cache.path.map(prop('_compiled'))).join(''),
                    _this.config.strict === false ? '/?' : '',
                    '$',
                ].join(''), _this.config.caseInsensitive ? 'i' : undefined);
            }).exec(path);
            if (!match)
                return null;
            // options = defaults(options, { isolate: false });
            var allParams = this.parameters(), pathParams = allParams.filter(function (param) { return !param.isSearch(); }), searchParams = allParams.filter(function (param) { return param.isSearch(); }), nPathSegments = this._cache.path.map(function (urlm) { return urlm._segments.length - 1; }).reduce(function (a, x) { return a + x; }), values = {};
            if (nPathSegments !== match.length - 1)
                throw new Error("Unbalanced capture group in route '" + this.pattern + "'");
            function decodePathArray(paramVal) {
                var reverseString = function (str) { return str.split('').reverse().join(''); };
                var unquoteDashes = function (str) { return str.replace(/\\-/g, '-'); };
                var split = reverseString(paramVal).split(/-(?!\\)/);
                var allReversed = map(split, reverseString);
                return map(allReversed, unquoteDashes).reverse();
            }
            for (var i = 0; i < nPathSegments; i++) {
                var param = pathParams[i];
                var value = match[i + 1];
                // if the param value matches a pre-replace pair, replace the value before decoding.
                for (var j = 0; j < param.replace.length; j++) {
                    if (param.replace[j].from === value)
                        value = param.replace[j].to;
                }
                if (value && param.array === true)
                    value = decodePathArray(value);
                values[param.id] = this._getDecodedParamValue(value, param);
            }
            searchParams.forEach(function (param) {
                var value = search[param.id];
                for (var j = 0; j < param.replace.length; j++) {
                    if (param.replace[j].from === value)
                        value = param.replace[j].to;
                }
                values[param.id] = _this._getDecodedParamValue(value, param);
            });
            if (hash)
                values['#'] = hash;
            return values;
        };
        /**
         * @internal
         * Returns all the [[Param]] objects of all path and search parameters of this pattern in order of appearance.
         *
         * @returns {Array.<Param>}  An array of [[Param]] objects. Must be treated as read-only. If the
         *    pattern has no parameters, an empty array is returned.
         */
        UrlMatcher.prototype.parameters = function (opts) {
            if (opts === void 0) { opts = {}; }
            if (opts.inherit === false)
                return this._params;
            return unnest(this._cache.path.map(function (matcher) { return matcher._params; }));
        };
        /**
         * @internal
         * Returns a single parameter from this UrlMatcher by id
         *
         * @param id
         * @param opts
         * @returns {T|Param|any|boolean|UrlMatcher|null}
         */
        UrlMatcher.prototype.parameter = function (id, opts) {
            var _this = this;
            if (opts === void 0) { opts = {}; }
            var findParam = function () {
                for (var _i = 0, _a = _this._params; _i < _a.length; _i++) {
                    var param = _a[_i];
                    if (param.id === id)
                        return param;
                }
            };
            var parent = this._cache.parent;
            return findParam() || (opts.inherit !== false && parent && parent.parameter(id, opts)) || null;
        };
        /**
         * Validates the input parameter values against this UrlMatcher
         *
         * Checks an object hash of parameters to validate their correctness according to the parameter
         * types of this `UrlMatcher`.
         *
         * @param params The object hash of parameters to validate.
         * @returns Returns `true` if `params` validates, otherwise `false`.
         */
        UrlMatcher.prototype.validates = function (params) {
            var validParamVal = function (param, val) { return !param || param.validates(val); };
            params = params || {};
            // I'm not sure why this checks only the param keys passed in, and not all the params known to the matcher
            var paramSchema = this.parameters().filter(function (paramDef) { return params.hasOwnProperty(paramDef.id); });
            return paramSchema.map(function (paramDef) { return validParamVal(paramDef, params[paramDef.id]); }).reduce(allTrueR, true);
        };
        /**
         * Given a set of parameter values, creates a URL from this UrlMatcher.
         *
         * Creates a URL that matches this pattern by substituting the specified values
         * for the path and search parameters.
         *
         * #### Example:
         * ```js
         * new UrlMatcher('/user/{id}?q').format({ id:'bob', q:'yes' });
         * // returns '/user/bob?q=yes'
         * ```
         *
         * @param values  the values to substitute for the parameters in this pattern.
         * @returns the formatted URL (path and optionally search part).
         */
        UrlMatcher.prototype.format = function (values) {
            if (values === void 0) { values = {}; }
            // Build the full path of UrlMatchers (including all parent UrlMatchers)
            var urlMatchers = this._cache.path;
            // Extract all the static segments and Params (processed as ParamDetails)
            // into an ordered array
            var pathSegmentsAndParams = urlMatchers
                .map(UrlMatcher.pathSegmentsAndParams)
                .reduce(unnestR, [])
                .map(function (x) { return (isString(x) ? x : getDetails(x)); });
            // Extract the query params into a separate array
            var queryParams = urlMatchers
                .map(UrlMatcher.queryParams)
                .reduce(unnestR, [])
                .map(getDetails);
            var isInvalid = function (param) { return param.isValid === false; };
            if (pathSegmentsAndParams.concat(queryParams).filter(isInvalid).length) {
                return null;
            }
            /**
             * Given a Param, applies the parameter value, then returns detailed information about it
             */
            function getDetails(param) {
                // Normalize to typed value
                var value = param.value(values[param.id]);
                var isValid = param.validates(value);
                var isDefaultValue = param.isDefaultValue(value);
                // Check if we're in squash mode for the parameter
                var squash = isDefaultValue ? param.squash : false;
                // Allow the Parameter's Type to encode the value
                var encoded = param.type.encode(value);
                return { param: param, value: value, isValid: isValid, isDefaultValue: isDefaultValue, squash: squash, encoded: encoded };
            }
            // Build up the path-portion from the list of static segments and parameters
            var pathString = pathSegmentsAndParams.reduce(function (acc, x) {
                // The element is a static segment (a raw string); just append it
                if (isString(x))
                    return acc + x;
                // Otherwise, it's a ParamDetails.
                var squash = x.squash, encoded = x.encoded, param = x.param;
                // If squash is === true, try to remove a slash from the path
                if (squash === true)
                    return acc.match(/\/$/) ? acc.slice(0, -1) : acc;
                // If squash is a string, use the string for the param value
                if (isString(squash))
                    return acc + squash;
                if (squash !== false)
                    return acc; // ?
                if (encoded == null)
                    return acc;
                // If this parameter value is an array, encode the value using encodeDashes
                if (isArray(encoded))
                    return acc + map(encoded, UrlMatcher.encodeDashes).join('-');
                // If the parameter type is "raw", then do not encodeURIComponent
                if (param.raw)
                    return acc + encoded;
                // Encode the value
                return acc + encodeURIComponent(encoded);
            }, '');
            // Build the query string by applying parameter values (array or regular)
            // then mapping to key=value, then flattening and joining using "&"
            var queryString = queryParams
                .map(function (paramDetails) {
                var param = paramDetails.param, squash = paramDetails.squash, encoded = paramDetails.encoded, isDefaultValue = paramDetails.isDefaultValue;
                if (encoded == null || (isDefaultValue && squash !== false))
                    return;
                if (!isArray(encoded))
                    encoded = [encoded];
                if (encoded.length === 0)
                    return;
                if (!param.raw)
                    encoded = map(encoded, encodeURIComponent);
                return encoded.map(function (val) { return param.id + "=" + val; });
            })
                .filter(identity)
                .reduce(unnestR, [])
                .join('&');
            // Concat the pathstring with the queryString (if exists) and the hashString (if exists)
            return pathString + (queryString ? "?" + queryString : '') + (values['#'] ? '#' + values['#'] : '');
        };
        /** @internal */
        UrlMatcher.nameValidator = /^\w+([-.]+\w+)*(?:\[\])?$/;
        return UrlMatcher;
    }());

    var __assign = (undefined && undefined.__assign) || function () {
        __assign = Object.assign || function(t) {
            for (var s, i = 1, n = arguments.length; i < n; i++) {
                s = arguments[i];
                for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                    t[p] = s[p];
            }
            return t;
        };
        return __assign.apply(this, arguments);
    };
    var ParamFactory = /** @class */ (function () {
        function ParamFactory(router) {
            this.router = router;
        }
        ParamFactory.prototype.fromConfig = function (id, type, state) {
            return new Param(id, type, exports.DefType.CONFIG, this.router.urlService.config, state);
        };
        ParamFactory.prototype.fromPath = function (id, type, state) {
            return new Param(id, type, exports.DefType.PATH, this.router.urlService.config, state);
        };
        ParamFactory.prototype.fromSearch = function (id, type, state) {
            return new Param(id, type, exports.DefType.SEARCH, this.router.urlService.config, state);
        };
        return ParamFactory;
    }());
    /**
     * Factory for [[UrlMatcher]] instances.
     *
     * The factory is available to ng1 services as
     * `$urlMatcherFactory` or ng1 providers as `$urlMatcherFactoryProvider`.
     */
    var UrlMatcherFactory = /** @class */ (function () {
        // TODO: move implementations to UrlConfig (urlService.config)
        function UrlMatcherFactory(/** @internal */ router) {
            var _this = this;
            this.router = router;
            /** Creates a new [[Param]] for a given location (DefType) */
            this.paramFactory = new ParamFactory(this.router);
            // TODO: Check if removal of this will break anything, then remove these
            this.UrlMatcher = UrlMatcher;
            this.Param = Param;
            /** @deprecated use [[UrlConfig.caseInsensitive]] */
            this.caseInsensitive = function (value) { return _this.router.urlService.config.caseInsensitive(value); };
            /** @deprecated use [[UrlConfig.defaultSquashPolicy]] */
            this.defaultSquashPolicy = function (value) { return _this.router.urlService.config.defaultSquashPolicy(value); };
            /** @deprecated use [[UrlConfig.strictMode]] */
            this.strictMode = function (value) { return _this.router.urlService.config.strictMode(value); };
            /** @deprecated use [[UrlConfig.type]] */
            this.type = function (name, definition, definitionFn) {
                return _this.router.urlService.config.type(name, definition, definitionFn) || _this;
            };
        }
        /**
         * Creates a [[UrlMatcher]] for the specified pattern.
         *
         * @param pattern  The URL pattern.
         * @param config  The config object hash.
         * @returns The UrlMatcher.
         */
        UrlMatcherFactory.prototype.compile = function (pattern, config) {
            var urlConfig = this.router.urlService.config;
            // backward-compatible support for config.params -> config.state.params
            var params = config && !config.state && config.params;
            config = params ? __assign({ state: { params: params } }, config) : config;
            var globalConfig = {
                strict: urlConfig._isStrictMode,
                caseInsensitive: urlConfig._isCaseInsensitive,
                decodeParams: urlConfig._decodeParams,
            };
            return new UrlMatcher(pattern, urlConfig.paramTypes, this.paramFactory, extend(globalConfig, config));
        };
        /**
         * Returns true if the specified object is a [[UrlMatcher]], or false otherwise.
         *
         * @param object  The object to perform the type check against.
         * @returns `true` if the object matches the `UrlMatcher` interface, by
         *          implementing all the same methods.
         */
        UrlMatcherFactory.prototype.isMatcher = function (object) {
            // TODO: typeof?
            if (!isObject(object))
                return false;
            var result = true;
            forEach(UrlMatcher.prototype, function (val, name) {
                if (isFunction(val))
                    result = result && isDefined(object[name]) && isFunction(object[name]);
            });
            return result;
        };
        /** @internal */
        UrlMatcherFactory.prototype.$get = function () {
            var urlConfig = this.router.urlService.config;
            urlConfig.paramTypes.enqueue = false;
            urlConfig.paramTypes._flushTypeQueue();
            return this;
        };
        return UrlMatcherFactory;
    }());

    /**
     * Creates a [[UrlRule]]
     *
     * Creates a [[UrlRule]] from a:
     *
     * - `string`
     * - [[UrlMatcher]]
     * - `RegExp`
     * - [[StateObject]]
     */
    var UrlRuleFactory = /** @class */ (function () {
        function UrlRuleFactory(router) {
            this.router = router;
        }
        UrlRuleFactory.prototype.compile = function (str) {
            return this.router.urlMatcherFactory.compile(str);
        };
        UrlRuleFactory.prototype.create = function (what, handler) {
            var _this = this;
            var isState = StateObject.isState, isStateDeclaration = StateObject.isStateDeclaration;
            var makeRule = pattern([
                [isString, function (_what) { return makeRule(_this.compile(_what)); }],
                [is(UrlMatcher), function (_what) { return _this.fromUrlMatcher(_what, handler); }],
                [or(isState, isStateDeclaration), function (_what) { return _this.fromState(_what, _this.router); }],
                [is(RegExp), function (_what) { return _this.fromRegExp(_what, handler); }],
                [isFunction, function (_what) { return new BaseUrlRule(_what, handler); }],
            ]);
            var rule = makeRule(what);
            if (!rule)
                throw new Error("invalid 'what' in when()");
            return rule;
        };
        /**
         * A UrlRule which matches based on a UrlMatcher
         *
         * The `handler` may be either a `string`, a [[UrlRuleHandlerFn]] or another [[UrlMatcher]]
         *
         * ## Handler as a function
         *
         * If `handler` is a function, the function is invoked with:
         *
         * - matched parameter values ([[RawParams]] from [[UrlMatcher.exec]])
         * - url: the current Url ([[UrlParts]])
         * - router: the router object ([[UIRouter]])
         *
         * #### Example:
         * ```js
         * var urlMatcher = $umf.compile("/foo/:fooId/:barId");
         * var rule = factory.fromUrlMatcher(urlMatcher, match => "/home/" + match.fooId + "/" + match.barId);
         * var match = rule.match('/foo/123/456'); // results in { fooId: '123', barId: '456' }
         * var result = rule.handler(match); // '/home/123/456'
         * ```
         *
         * ## Handler as UrlMatcher
         *
         * If `handler` is a UrlMatcher, the handler matcher is used to create the new url.
         * The `handler` UrlMatcher is formatted using the matched param from the first matcher.
         * The url is replaced with the result.
         *
         * #### Example:
         * ```js
         * var urlMatcher = $umf.compile("/foo/:fooId/:barId");
         * var handler = $umf.compile("/home/:fooId/:barId");
         * var rule = factory.fromUrlMatcher(urlMatcher, handler);
         * var match = rule.match('/foo/123/456'); // results in { fooId: '123', barId: '456' }
         * var result = rule.handler(match); // '/home/123/456'
         * ```
         */
        UrlRuleFactory.prototype.fromUrlMatcher = function (urlMatcher, handler) {
            var _handler = handler;
            if (isString(handler))
                handler = this.router.urlMatcherFactory.compile(handler);
            if (is(UrlMatcher)(handler))
                _handler = function (match) { return handler.format(match); };
            function matchUrlParamters(url) {
                var params = urlMatcher.exec(url.path, url.search, url.hash);
                return urlMatcher.validates(params) && params;
            }
            // Prioritize URLs, lowest to highest:
            // - Some optional URL parameters, but none matched
            // - No optional parameters in URL
            // - Some optional parameters, some matched
            // - Some optional parameters, all matched
            function matchPriority(params) {
                var optional = urlMatcher.parameters().filter(function (param) { return param.isOptional; });
                if (!optional.length)
                    return 0.000001;
                var matched = optional.filter(function (param) { return params[param.id]; });
                return matched.length / optional.length;
            }
            var details = { urlMatcher: urlMatcher, matchPriority: matchPriority, type: 'URLMATCHER' };
            return extend(new BaseUrlRule(matchUrlParamters, _handler), details);
        };
        /**
         * A UrlRule which matches a state by its url
         *
         * #### Example:
         * ```js
         * var rule = factory.fromState($state.get('foo'), router);
         * var match = rule.match('/foo/123/456'); // results in { fooId: '123', barId: '456' }
         * var result = rule.handler(match);
         * // Starts a transition to 'foo' with params: { fooId: '123', barId: '456' }
         * ```
         */
        UrlRuleFactory.prototype.fromState = function (stateOrDecl, router) {
            var state = StateObject.isStateDeclaration(stateOrDecl) ? stateOrDecl.$$state() : stateOrDecl;
            /**
             * Handles match by transitioning to matched state
             *
             * First checks if the router should start a new transition.
             * A new transition is not required if the current state's URL
             * and the new URL are already identical
             */
            var handler = function (match) {
                var $state = router.stateService;
                var globals = router.globals;
                if ($state.href(state, match) !== $state.href(globals.current, globals.params)) {
                    $state.transitionTo(state, match, { inherit: true, source: 'url' });
                }
            };
            var details = { state: state, type: 'STATE' };
            return extend(this.fromUrlMatcher(state.url, handler), details);
        };
        /**
         * A UrlRule which matches based on a regular expression
         *
         * The `handler` may be either a [[UrlRuleHandlerFn]] or a string.
         *
         * ## Handler as a function
         *
         * If `handler` is a function, the function is invoked with:
         *
         * - regexp match array (from `regexp`)
         * - url: the current Url ([[UrlParts]])
         * - router: the router object ([[UIRouter]])
         *
         * #### Example:
         * ```js
         * var rule = factory.fromRegExp(/^\/foo\/(bar|baz)$/, match => "/home/" + match[1])
         * var match = rule.match('/foo/bar'); // results in [ '/foo/bar', 'bar' ]
         * var result = rule.handler(match); // '/home/bar'
         * ```
         *
         * ## Handler as string
         *
         * If `handler` is a string, the url is *replaced by the string* when the Rule is invoked.
         * The string is first interpolated using `string.replace()` style pattern.
         *
         * #### Example:
         * ```js
         * var rule = factory.fromRegExp(/^\/foo\/(bar|baz)$/, "/home/$1")
         * var match = rule.match('/foo/bar'); // results in [ '/foo/bar', 'bar' ]
         * var result = rule.handler(match); // '/home/bar'
         * ```
         */
        UrlRuleFactory.prototype.fromRegExp = function (regexp, handler) {
            if (regexp.global || regexp.sticky)
                throw new Error('Rule RegExp must not be global or sticky');
            /**
             * If handler is a string, the url will be replaced by the string.
             * If the string has any String.replace() style variables in it (like `$2`),
             * they will be replaced by the captures from [[match]]
             */
            var redirectUrlTo = function (match) {
                // Interpolates matched values into $1 $2, etc using a String.replace()-style pattern
                return handler.replace(/\$(\$|\d{1,2})/, function (m, what) { return match[what === '$' ? 0 : Number(what)]; });
            };
            var _handler = isString(handler) ? redirectUrlTo : handler;
            var matchParamsFromRegexp = function (url) { return regexp.exec(url.path); };
            var details = { regexp: regexp, type: 'REGEXP' };
            return extend(new BaseUrlRule(matchParamsFromRegexp, _handler), details);
        };
        UrlRuleFactory.isUrlRule = function (obj) { return obj && ['type', 'match', 'handler'].every(function (key) { return isDefined(obj[key]); }); };
        return UrlRuleFactory;
    }());
    /**
     * A base rule which calls `match`
     *
     * The value from the `match` function is passed through to the `handler`.
     * @internal
     */
    var BaseUrlRule = /** @class */ (function () {
        function BaseUrlRule(match, handler) {
            var _this = this;
            this.match = match;
            this.type = 'RAW';
            this.matchPriority = function (match) { return 0 - _this.$id; };
            this.handler = handler || identity;
        }
        return BaseUrlRule;
    }());

    function appendBasePath(url, isHtml5, absolute, baseHref) {
        if (baseHref === '/')
            return url;
        if (isHtml5)
            return stripLastPathElement(baseHref) + url;
        if (absolute)
            return baseHref.slice(1) + url;
        return url;
    }
    /**
     * Updates URL and responds to URL changes
     *
     * ### Deprecation warning:
     * This class is now considered to be an internal API
     * Use the [[UrlService]] instead.
     * For configuring URL rules, use the [[UrlRules]] which can be found as [[UrlService.rules]].
     */
    var UrlRouter = /** @class */ (function () {
        /** @internal */
        function UrlRouter(/** @internal */ router) {
            var _this = this;
            this.router = router;
            // Delegate these calls to [[UrlService]]
            /** @deprecated use [[UrlService.sync]]*/
            this.sync = function (evt) { return _this.router.urlService.sync(evt); };
            /** @deprecated use [[UrlService.listen]]*/
            this.listen = function (enabled) { return _this.router.urlService.listen(enabled); };
            /** @deprecated use [[UrlService.deferIntercept]]*/
            this.deferIntercept = function (defer) { return _this.router.urlService.deferIntercept(defer); };
            /** @deprecated use [[UrlService.match]]*/
            this.match = function (urlParts) { return _this.router.urlService.match(urlParts); };
            // Delegate these calls to [[UrlRules]]
            /** @deprecated use [[UrlRules.initial]]*/
            this.initial = function (handler) {
                return _this.router.urlService.rules.initial(handler);
            };
            /** @deprecated use [[UrlRules.otherwise]]*/
            this.otherwise = function (handler) {
                return _this.router.urlService.rules.otherwise(handler);
            };
            /** @deprecated use [[UrlRules.removeRule]]*/
            this.removeRule = function (rule) { return _this.router.urlService.rules.removeRule(rule); };
            /** @deprecated use [[UrlRules.rule]]*/
            this.rule = function (rule) { return _this.router.urlService.rules.rule(rule); };
            /** @deprecated use [[UrlRules.rules]]*/
            this.rules = function () { return _this.router.urlService.rules.rules(); };
            /** @deprecated use [[UrlRules.sort]]*/
            this.sort = function (compareFn) { return _this.router.urlService.rules.sort(compareFn); };
            /** @deprecated use [[UrlRules.when]]*/
            this.when = function (matcher, handler, options) { return _this.router.urlService.rules.when(matcher, handler, options); };
            this.urlRuleFactory = new UrlRuleFactory(router);
        }
        /** Internal API. */
        UrlRouter.prototype.update = function (read) {
            var $url = this.router.locationService;
            if (read) {
                this.location = $url.url();
                return;
            }
            if ($url.url() === this.location)
                return;
            $url.url(this.location, true);
        };
        /**
         * Internal API.
         *
         * Pushes a new location to the browser history.
         *
         * @internal
         * @param urlMatcher
         * @param params
         * @param options
         */
        UrlRouter.prototype.push = function (urlMatcher, params, options) {
            var replace = options && !!options.replace;
            this.router.urlService.url(urlMatcher.format(params || {}), replace);
        };
        /**
         * Builds and returns a URL with interpolated parameters
         *
         * #### Example:
         * ```js
         * matcher = $umf.compile("/about/:person");
         * params = { person: "bob" };
         * $bob = $urlRouter.href(matcher, params);
         * // $bob == "/about/bob";
         * ```
         *
         * @param urlMatcher The [[UrlMatcher]] object which is used as the template of the URL to generate.
         * @param params An object of parameter values to fill the matcher's required parameters.
         * @param options Options object. The options are:
         *
         * - **`absolute`** - {boolean=false},  If true will generate an absolute url, e.g. "http://www.example.com/fullurl".
         *
         * @returns Returns the fully compiled URL, or `null` if `params` fail validation against `urlMatcher`
         */
        UrlRouter.prototype.href = function (urlMatcher, params, options) {
            var url = urlMatcher.format(params);
            if (url == null)
                return null;
            options = options || { absolute: false };
            var cfg = this.router.urlService.config;
            var isHtml5 = cfg.html5Mode();
            if (!isHtml5 && url !== null) {
                url = '#' + cfg.hashPrefix() + url;
            }
            url = appendBasePath(url, isHtml5, options.absolute, cfg.baseHref());
            if (!options.absolute || !url) {
                return url;
            }
            var slash = !isHtml5 && url ? '/' : '';
            var cfgPort = cfg.port();
            var port = (cfgPort === 80 || cfgPort === 443 ? '' : ':' + cfgPort);
            return [cfg.protocol(), '://', cfg.host(), port, slash, url].join('');
        };
        Object.defineProperty(UrlRouter.prototype, "interceptDeferred", {
            /** @deprecated use [[UrlService.interceptDeferred]]*/
            get: function () {
                return this.router.urlService.interceptDeferred;
            },
            enumerable: false,
            configurable: true
        });
        return UrlRouter;
    }());

    /**
     * The View service
     *
     * This service pairs existing `ui-view` components (which live in the DOM)
     * with view configs (from the state declaration objects: [[StateDeclaration.views]]).
     *
     * - After a successful Transition, the views from the newly entered states are activated via [[activateViewConfig]].
     *   The views from exited states are deactivated via [[deactivateViewConfig]].
     *   (See: the [[registerActivateViews]] Transition Hook)
     *
     * - As `ui-view` components pop in and out of existence, they register themselves using [[registerUIView]].
     *
     * - When the [[sync]] function is called, the registered `ui-view`(s) ([[ActiveUIView]])
     * are configured with the matching [[ViewConfig]](s)
     *
     */
    var ViewService = /** @class */ (function () {
        /** @internal */
        function ViewService(/** @internal */ router) {
            var _this = this;
            this.router = router;
            /** @internal */ this._uiViews = [];
            /** @internal */ this._viewConfigs = [];
            /** @internal */ this._viewConfigFactories = {};
            /** @internal */ this._listeners = [];
            /** @internal */
            this._pluginapi = {
                _rootViewContext: this._rootViewContext.bind(this),
                _viewConfigFactory: this._viewConfigFactory.bind(this),
                _registeredUIView: function (id) { return find(_this._uiViews, function (view) { return _this.router.$id + "." + view.id === id; }); },
                _registeredUIViews: function () { return _this._uiViews; },
                _activeViewConfigs: function () { return _this._viewConfigs; },
                _onSync: function (listener) {
                    _this._listeners.push(listener);
                    return function () { return removeFrom(_this._listeners, listener); };
                },
            };
        }
        /**
         * Normalizes a view's name from a state.views configuration block.
         *
         * This should be used by a framework implementation to calculate the values for
         * [[_ViewDeclaration.$uiViewName]] and [[_ViewDeclaration.$uiViewContextAnchor]].
         *
         * @param context the context object (state declaration) that the view belongs to
         * @param rawViewName the name of the view, as declared in the [[StateDeclaration.views]]
         *
         * @returns the normalized uiViewName and uiViewContextAnchor that the view targets
         */
        ViewService.normalizeUIViewTarget = function (context, rawViewName) {
            if (rawViewName === void 0) { rawViewName = ''; }
            // TODO: Validate incoming view name with a regexp to allow:
            // ex: "view.name@foo.bar" , "^.^.view.name" , "view.name@^.^" , "" ,
            // "@" , "$default@^" , "!$default.$default" , "!foo.bar"
            var viewAtContext = rawViewName.split('@');
            var uiViewName = viewAtContext[0] || '$default'; // default to unnamed view
            var uiViewContextAnchor = isString(viewAtContext[1]) ? viewAtContext[1] : '^'; // default to parent context
            // Handle relative view-name sugar syntax.
            // Matches rawViewName "^.^.^.foo.bar" into array: ["^.^.^.foo.bar", "^.^.^", "foo.bar"],
            var relativeViewNameSugar = /^(\^(?:\.\^)*)\.(.*$)/.exec(uiViewName);
            if (relativeViewNameSugar) {
                // Clobbers existing contextAnchor (rawViewName validation will fix this)
                uiViewContextAnchor = relativeViewNameSugar[1]; // set anchor to "^.^.^"
                uiViewName = relativeViewNameSugar[2]; // set view-name to "foo.bar"
            }
            if (uiViewName.charAt(0) === '!') {
                uiViewName = uiViewName.substr(1);
                uiViewContextAnchor = ''; // target absolutely from root
            }
            // handle parent relative targeting "^.^.^"
            var relativeMatch = /^(\^(?:\.\^)*)$/;
            if (relativeMatch.exec(uiViewContextAnchor)) {
                var anchorState = uiViewContextAnchor.split('.').reduce(function (anchor, x) { return anchor.parent; }, context);
                uiViewContextAnchor = anchorState.name;
            }
            else if (uiViewContextAnchor === '.') {
                uiViewContextAnchor = context.name;
            }
            return { uiViewName: uiViewName, uiViewContextAnchor: uiViewContextAnchor };
        };
        /** @internal */
        ViewService.prototype._rootViewContext = function (context) {
            return (this._rootContext = context || this._rootContext);
        };
        /** @internal */
        ViewService.prototype._viewConfigFactory = function (viewType, factory) {
            this._viewConfigFactories[viewType] = factory;
        };
        ViewService.prototype.createViewConfig = function (path, decl) {
            var cfgFactory = this._viewConfigFactories[decl.$type];
            if (!cfgFactory)
                throw new Error('ViewService: No view config factory registered for type ' + decl.$type);
            var cfgs = cfgFactory(path, decl);
            return isArray(cfgs) ? cfgs : [cfgs];
        };
        /**
         * Deactivates a ViewConfig.
         *
         * This function deactivates a `ViewConfig`.
         * After calling [[sync]], it will un-pair from any `ui-view` with which it is currently paired.
         *
         * @param viewConfig The ViewConfig view to deregister.
         */
        ViewService.prototype.deactivateViewConfig = function (viewConfig) {
            trace.traceViewServiceEvent('<- Removing', viewConfig);
            removeFrom(this._viewConfigs, viewConfig);
        };
        ViewService.prototype.activateViewConfig = function (viewConfig) {
            trace.traceViewServiceEvent('-> Registering', viewConfig);
            this._viewConfigs.push(viewConfig);
        };
        ViewService.prototype.sync = function () {
            var _this = this;
            var uiViewsByFqn = this._uiViews.map(function (uiv) { return [uiv.fqn, uiv]; }).reduce(applyPairs, {});
            // Return a weighted depth value for a uiView.
            // The depth is the nesting depth of ui-views (based on FQN; times 10,000)
            // plus the depth of the state that is populating the uiView
            function uiViewDepth(uiView) {
                var stateDepth = function (context) { return (context && context.parent ? stateDepth(context.parent) + 1 : 1); };
                return uiView.fqn.split('.').length * 10000 + stateDepth(uiView.creationContext);
            }
            // Return the ViewConfig's context's depth in the context tree.
            function viewConfigDepth(config) {
                var context = config.viewDecl.$context, count = 0;
                while (++count && context.parent)
                    context = context.parent;
                return count;
            }
            // Given a depth function, returns a compare function which can return either ascending or descending order
            var depthCompare = curry(function (depthFn, posNeg, left, right) { return posNeg * (depthFn(left) - depthFn(right)); });
            var matchingConfigPair = function (uiView) {
                var matchingConfigs = _this._viewConfigs.filter(ViewService.matches(uiViewsByFqn, uiView));
                if (matchingConfigs.length > 1) {
                    // This is OK.  Child states can target a ui-view that the parent state also targets (the child wins)
                    // Sort by depth and return the match from the deepest child
                    // console.log(`Multiple matching view configs for ${uiView.fqn}`, matchingConfigs);
                    matchingConfigs.sort(depthCompare(viewConfigDepth, -1)); // descending
                }
                return { uiView: uiView, viewConfig: matchingConfigs[0] };
            };
            var configureUIView = function (tuple) {
                // If a parent ui-view is reconfigured, it could destroy child ui-views.
                // Before configuring a child ui-view, make sure it's still in the active uiViews array.
                if (_this._uiViews.indexOf(tuple.uiView) !== -1)
                    tuple.uiView.configUpdated(tuple.viewConfig);
            };
            // Sort views by FQN and state depth. Process uiviews nearest the root first.
            var uiViewTuples = this._uiViews.sort(depthCompare(uiViewDepth, 1)).map(matchingConfigPair);
            var matchedViewConfigs = uiViewTuples.map(function (tuple) { return tuple.viewConfig; });
            var unmatchedConfigTuples = this._viewConfigs
                .filter(function (config) { return !inArray(matchedViewConfigs, config); })
                .map(function (viewConfig) { return ({ uiView: undefined, viewConfig: viewConfig }); });
            uiViewTuples.forEach(configureUIView);
            var allTuples = uiViewTuples.concat(unmatchedConfigTuples);
            this._listeners.forEach(function (cb) { return cb(allTuples); });
            trace.traceViewSync(allTuples);
        };
        /**
         * Registers a `ui-view` component
         *
         * When a `ui-view` component is created, it uses this method to register itself.
         * After registration the [[sync]] method is used to ensure all `ui-view` are configured with the proper [[ViewConfig]].
         *
         * Note: the `ui-view` component uses the `ViewConfig` to determine what view should be loaded inside the `ui-view`,
         * and what the view's state context is.
         *
         * Note: There is no corresponding `deregisterUIView`.
         *       A `ui-view` should hang on to the return value of `registerUIView` and invoke it to deregister itself.
         *
         * @param uiView The metadata for a UIView
         * @return a de-registration function used when the view is destroyed.
         */
        ViewService.prototype.registerUIView = function (uiView) {
            trace.traceViewServiceUIViewEvent('-> Registering', uiView);
            var uiViews = this._uiViews;
            var fqnAndTypeMatches = function (uiv) { return uiv.fqn === uiView.fqn && uiv.$type === uiView.$type; };
            if (uiViews.filter(fqnAndTypeMatches).length)
                trace.traceViewServiceUIViewEvent('!!!! duplicate uiView named:', uiView);
            uiViews.push(uiView);
            this.sync();
            return function () {
                var idx = uiViews.indexOf(uiView);
                if (idx === -1) {
                    trace.traceViewServiceUIViewEvent('Tried removing non-registered uiView', uiView);
                    return;
                }
                trace.traceViewServiceUIViewEvent('<- Deregistering', uiView);
                removeFrom(uiViews)(uiView);
            };
        };
        /**
         * Returns the list of views currently available on the page, by fully-qualified name.
         *
         * @return {Array} Returns an array of fully-qualified view names.
         */
        ViewService.prototype.available = function () {
            return this._uiViews.map(prop('fqn'));
        };
        /**
         * Returns the list of views on the page containing loaded content.
         *
         * @return {Array} Returns an array of fully-qualified view names.
         */
        ViewService.prototype.active = function () {
            return this._uiViews.filter(prop('$config')).map(prop('name'));
        };
        /**
         * Given a ui-view and a ViewConfig, determines if they "match".
         *
         * A ui-view has a fully qualified name (fqn) and a context object.  The fqn is built from its overall location in
         * the DOM, describing its nesting relationship to any parent ui-view tags it is nested inside of.
         *
         * A ViewConfig has a target ui-view name and a context anchor.  The ui-view name can be a simple name, or
         * can be a segmented ui-view path, describing a portion of a ui-view fqn.
         *
         * In order for a ui-view to match ViewConfig, ui-view's $type must match the ViewConfig's $type
         *
         * If the ViewConfig's target ui-view name is a simple name (no dots), then a ui-view matches if:
         * - the ui-view's name matches the ViewConfig's target name
         * - the ui-view's context matches the ViewConfig's anchor
         *
         * If the ViewConfig's target ui-view name is a segmented name (with dots), then a ui-view matches if:
         * - There exists a parent ui-view where:
         *    - the parent ui-view's name matches the first segment (index 0) of the ViewConfig's target name
         *    - the parent ui-view's context matches the ViewConfig's anchor
         * - And the remaining segments (index 1..n) of the ViewConfig's target name match the tail of the ui-view's fqn
         *
         * Example:
         *
         * DOM:
         * <ui-view>                        <!-- created in the root context (name: "") -->
         *   <ui-view name="foo">                <!-- created in the context named: "A"      -->
         *     <ui-view>                    <!-- created in the context named: "A.B"    -->
         *       <ui-view name="bar">            <!-- created in the context named: "A.B.C"  -->
         *       </ui-view>
         *     </ui-view>
         *   </ui-view>
         * </ui-view>
         *
         * uiViews: [
         *  { fqn: "$default",                  creationContext: { name: "" } },
         *  { fqn: "$default.foo",              creationContext: { name: "A" } },
         *  { fqn: "$default.foo.$default",     creationContext: { name: "A.B" } }
         *  { fqn: "$default.foo.$default.bar", creationContext: { name: "A.B.C" } }
         * ]
         *
         * These four view configs all match the ui-view with the fqn: "$default.foo.$default.bar":
         *
         * - ViewConfig1: { uiViewName: "bar",                       uiViewContextAnchor: "A.B.C" }
         * - ViewConfig2: { uiViewName: "$default.bar",              uiViewContextAnchor: "A.B" }
         * - ViewConfig3: { uiViewName: "foo.$default.bar",          uiViewContextAnchor: "A" }
         * - ViewConfig4: { uiViewName: "$default.foo.$default.bar", uiViewContextAnchor: "" }
         *
         * Using ViewConfig3 as an example, it matches the ui-view with fqn "$default.foo.$default.bar" because:
         * - The ViewConfig's segmented target name is: [ "foo", "$default", "bar" ]
         * - There exists a parent ui-view (which has fqn: "$default.foo") where:
         *    - the parent ui-view's name "foo" matches the first segment "foo" of the ViewConfig's target name
         *    - the parent ui-view's context "A" matches the ViewConfig's anchor context "A"
         * - And the remaining segments [ "$default", "bar" ].join("."_ of the ViewConfig's target name match
         *   the tail of the ui-view's fqn "default.bar"
         *
         * @internal
         */
        ViewService.matches = function (uiViewsByFqn, uiView) { return function (viewConfig) {
            // Don't supply an ng1 ui-view with an ng2 ViewConfig, etc
            if (uiView.$type !== viewConfig.viewDecl.$type)
                return false;
            // Split names apart from both viewConfig and uiView into segments
            var vc = viewConfig.viewDecl;
            var vcSegments = vc.$uiViewName.split('.');
            var uivSegments = uiView.fqn.split('.');
            // Check if the tails of the segment arrays match. ex, these arrays' tails match:
            // vc: ["foo", "bar"], uiv fqn: ["$default", "foo", "bar"]
            if (!equals(vcSegments, uivSegments.slice(0 - vcSegments.length)))
                return false;
            // Now check if the fqn ending at the first segment of the viewConfig matches the context:
            // ["$default", "foo"].join(".") == "$default.foo", does the ui-view $default.foo context match?
            var negOffset = 1 - vcSegments.length || undefined;
            var fqnToFirstSegment = uivSegments.slice(0, negOffset).join('.');
            var uiViewContext = uiViewsByFqn[fqnToFirstSegment].creationContext;
            return vc.$uiViewContextAnchor === (uiViewContext && uiViewContext.name);
        }; };
        return ViewService;
    }());

    /**
     * Global router state
     *
     * This is where we hold the global mutable state such as current state, current
     * params, current transition, etc.
     */
    var UIRouterGlobals = /** @class */ (function () {
        function UIRouterGlobals() {
            /**
             * Current parameter values
             *
             * The parameter values from the latest successful transition
             */
            this.params = new StateParams();
            /** @internal */
            this.lastStartedTransitionId = -1;
            /** @internal */
            this.transitionHistory = new Queue([], 1);
            /** @internal */
            this.successfulTransitions = new Queue([], 1);
        }
        UIRouterGlobals.prototype.dispose = function () {
            this.transitionHistory.clear();
            this.successfulTransitions.clear();
            this.transition = null;
        };
        return UIRouterGlobals;
    }());

    var prioritySort = function (a, b) { return (b.priority || 0) - (a.priority || 0); };
    var typeSort = function (a, b) {
        var weights = { STATE: 4, URLMATCHER: 4, REGEXP: 3, RAW: 2, OTHER: 1 };
        return (weights[a.type] || 0) - (weights[b.type] || 0);
    };
    var urlMatcherSort = function (a, b) {
        return !a.urlMatcher || !b.urlMatcher ? 0 : UrlMatcher.compare(a.urlMatcher, b.urlMatcher);
    };
    var idSort = function (a, b) {
        // Identically sorted STATE and URLMATCHER best rule will be chosen by `matchPriority` after each rule matches the URL
        var useMatchPriority = { STATE: true, URLMATCHER: true };
        var equal = useMatchPriority[a.type] && useMatchPriority[b.type];
        return equal ? 0 : (a.$id || 0) - (b.$id || 0);
    };
    /**
     * Default rule priority sorting function.
     *
     * Sorts rules by:
     *
     * - Explicit priority (set rule priority using [[UrlRules.when]])
     * - Rule type (STATE: 4, URLMATCHER: 4, REGEXP: 3, RAW: 2, OTHER: 1)
     * - `UrlMatcher` specificity ([[UrlMatcher.compare]]): works for STATE and URLMATCHER types to pick the most specific rule.
     * - Rule registration order (for rule types other than STATE and URLMATCHER)
     *   - Equally sorted State and UrlMatcher rules will each match the URL.
     *     Then, the *best* match is chosen based on how many parameter values were matched.
     */
    var defaultRuleSortFn;
    defaultRuleSortFn = function (a, b) {
        var cmp = prioritySort(a, b);
        if (cmp !== 0)
            return cmp;
        cmp = typeSort(a, b);
        if (cmp !== 0)
            return cmp;
        cmp = urlMatcherSort(a, b);
        if (cmp !== 0)
            return cmp;
        return idSort(a, b);
    };
    function getHandlerFn(handler) {
        if (!isFunction(handler) && !isString(handler) && !is(TargetState)(handler) && !TargetState.isDef(handler)) {
            throw new Error("'handler' must be a string, function, TargetState, or have a state: 'newtarget' property");
        }
        return isFunction(handler) ? handler : val(handler);
    }
    /**
     * API for managing URL rules
     *
     * This API is used to create and manage URL rules.
     * URL rules are a mechanism to respond to specific URL patterns.
     *
     * The most commonly used methods are [[otherwise]] and [[when]].
     *
     * This API is found at `router.urlService.rules` (see: [[UIRouter.urlService]], [[URLService.rules]])
     */
    var UrlRules = /** @class */ (function () {
        /** @internal */
        function UrlRules(/** @internal */ router) {
            this.router = router;
            /** @internal */ this._sortFn = defaultRuleSortFn;
            /** @internal */ this._rules = [];
            /** @internal */ this._id = 0;
            this.urlRuleFactory = new UrlRuleFactory(router);
        }
        /** @internal */
        UrlRules.prototype.dispose = function (router) {
            this._rules = [];
            delete this._otherwiseFn;
        };
        /**
         * Defines the initial state, path, or behavior to use when the app starts.
         *
         * This rule defines the initial/starting state for the application.
         *
         * This rule is triggered the first time the URL is checked (when the app initially loads).
         * The rule is triggered only when the url matches either `""` or `"/"`.
         *
         * Note: The rule is intended to be used when the root of the application is directly linked to.
         * When the URL is *not* `""` or `"/"` and doesn't match other rules, the [[otherwise]] rule is triggered.
         * This allows 404-like behavior when an unknown URL is deep-linked.
         *
         * #### Example:
         * Start app at `home` state.
         * ```js
         * .initial({ state: 'home' });
         * ```
         *
         * #### Example:
         * Start app at `/home` (by url)
         * ```js
         * .initial('/home');
         * ```
         *
         * #### Example:
         * When no other url rule matches, go to `home` state
         * ```js
         * .initial((matchValue, url, router) => {
         *   console.log('initial state');
         *   return { state: 'home' };
         * })
         * ```
         *
         * @param handler The initial state or url path, or a function which returns the state or url path (or performs custom logic).
         */
        UrlRules.prototype.initial = function (handler) {
            var handlerFn = getHandlerFn(handler);
            var matchFn = function (urlParts, router) {
                return router.globals.transitionHistory.size() === 0 && !!/^\/?$/.exec(urlParts.path);
            };
            this.rule(this.urlRuleFactory.create(matchFn, handlerFn));
        };
        /**
         * Defines the state, url, or behavior to use when no other rule matches the URL.
         *
         * This rule is matched when *no other rule* matches.
         * It is generally used to handle unknown URLs (similar to "404" behavior, but on the client side).
         *
         * - If `handler` a string, it is treated as a url redirect
         *
         * #### Example:
         * When no other url rule matches, redirect to `/index`
         * ```js
         * .otherwise('/index');
         * ```
         *
         * - If `handler` is an object with a `state` property, the state is activated.
         *
         * #### Example:
         * When no other url rule matches, redirect to `home` and provide a `dashboard` parameter value.
         * ```js
         * .otherwise({ state: 'home', params: { dashboard: 'default' } });
         * ```
         *
         * - If `handler` is a function, the function receives the current url ([[UrlParts]]) and the [[UIRouter]] object.
         *   The function can perform actions, and/or return a value.
         *
         * #### Example:
         * When no other url rule matches, manually trigger a transition to the `home` state
         * ```js
         * .otherwise((matchValue, urlParts, router) => {
         *   router.stateService.go('home');
         * });
         * ```
         *
         * #### Example:
         * When no other url rule matches, go to `home` state
         * ```js
         * .otherwise((matchValue, urlParts, router) => {
         *   return { state: 'home' };
         * });
         * ```
         *
         * @param handler The url path to redirect to, or a function which returns the url path (or performs custom logic).
         */
        UrlRules.prototype.otherwise = function (handler) {
            var handlerFn = getHandlerFn(handler);
            this._otherwiseFn = this.urlRuleFactory.create(val(true), handlerFn);
            this._sorted = false;
        };
        /**
         * Remove a rule previously registered
         *
         * @param rule the matcher rule that was previously registered using [[rule]]
         */
        UrlRules.prototype.removeRule = function (rule) {
            removeFrom(this._rules, rule);
        };
        /**
         * Manually adds a URL Rule.
         *
         * Usually, a url rule is added using [[StateDeclaration.url]] or [[when]].
         * This api can be used directly for more control (to register a [[BaseUrlRule]], for example).
         * Rules can be created using [[urlRuleFactory]], or created manually as simple objects.
         *
         * A rule should have a `match` function which returns truthy if the rule matched.
         * It should also have a `handler` function which is invoked if the rule is the best match.
         *
         * @return a function that deregisters the rule
         */
        UrlRules.prototype.rule = function (rule) {
            var _this = this;
            if (!UrlRuleFactory.isUrlRule(rule))
                throw new Error('invalid rule');
            rule.$id = this._id++;
            rule.priority = rule.priority || 0;
            this._rules.push(rule);
            this._sorted = false;
            return function () { return _this.removeRule(rule); };
        };
        /**
         * Gets all registered rules
         *
         * @returns an array of all the registered rules
         */
        UrlRules.prototype.rules = function () {
            this.ensureSorted();
            return this._rules.concat(this._otherwiseFn ? [this._otherwiseFn] : []);
        };
        /**
         * Defines URL Rule priorities
         *
         * More than one rule ([[UrlRule]]) might match a given URL.
         * This `compareFn` is used to sort the rules by priority.
         * Higher priority rules should sort earlier.
         *
         * The [[defaultRuleSortFn]] is used by default.
         *
         * You only need to call this function once.
         * The `compareFn` will be used to sort the rules as each is registered.
         *
         * If called without any parameter, it will re-sort the rules.
         *
         * ---
         *
         * Url rules may come from multiple sources: states's urls ([[StateDeclaration.url]]), [[when]], and [[rule]].
         * Each rule has a (user-provided) [[UrlRule.priority]], a [[UrlRule.type]], and a [[UrlRule.$id]]
         * The `$id` is is the order in which the rule was registered.
         *
         * The sort function should use these data, or data found on a specific type
         * of [[UrlRule]] (such as [[StateRule.state]]), to order the rules as desired.
         *
         * #### Example:
         * This compare function prioritizes rules by the order in which the rules were registered.
         * A rule registered earlier has higher priority.
         *
         * ```js
         * function compareFn(a, b) {
         *   return a.$id - b.$id;
         * }
         * ```
         *
         * @param compareFn a function that compares to [[UrlRule]] objects.
         *    The `compareFn` should abide by the `Array.sort` compare function rules.
         *    Given two rules, `a` and `b`, return a negative number if `a` should be higher priority.
         *    Return a positive number if `b` should be higher priority.
         *    Return `0` if the rules are identical.
         *
         *    See the [mozilla reference](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort#Description)
         *    for details.
         */
        UrlRules.prototype.sort = function (compareFn) {
            var sorted = this.stableSort(this._rules, (this._sortFn = compareFn || this._sortFn));
            // precompute _sortGroup values and apply to each rule
            var group = 0;
            for (var i = 0; i < sorted.length; i++) {
                sorted[i]._group = group;
                if (i < sorted.length - 1 && this._sortFn(sorted[i], sorted[i + 1]) !== 0) {
                    group++;
                }
            }
            this._rules = sorted;
            this._sorted = true;
        };
        /** @internal */
        UrlRules.prototype.ensureSorted = function () {
            this._sorted || this.sort();
        };
        /** @internal */
        UrlRules.prototype.stableSort = function (arr, compareFn) {
            var arrOfWrapper = arr.map(function (elem, idx) { return ({ elem: elem, idx: idx }); });
            arrOfWrapper.sort(function (wrapperA, wrapperB) {
                var cmpDiff = compareFn(wrapperA.elem, wrapperB.elem);
                return cmpDiff === 0 ? wrapperA.idx - wrapperB.idx : cmpDiff;
            });
            return arrOfWrapper.map(function (wrapper) { return wrapper.elem; });
        };
        /**
         * Registers a `matcher` and `handler` for custom URLs handling.
         *
         * The `matcher` can be:
         *
         * - a [[UrlMatcher]]: See: [[UrlMatcherFactory.compile]]
         * - a `string`: The string is compiled to a [[UrlMatcher]]
         * - a `RegExp`: The regexp is used to match the url.
         *
         * The `handler` can be:
         *
         * - a string: The url is redirected to the value of the string.
         * - a function: The url is redirected to the return value of the function.
         *
         * ---
         *
         * When the `handler` is a `string` and the `matcher` is a `UrlMatcher` (or string), the redirect
         * string is interpolated with parameter values.
         *
         * #### Example:
         * When the URL is `/foo/123` the rule will redirect to `/bar/123`.
         * ```js
         * .when("/foo/:param1", "/bar/:param1")
         * ```
         *
         * ---
         *
         * When the `handler` is a string and the `matcher` is a `RegExp`, the redirect string is
         * interpolated with capture groups from the RegExp.
         *
         * #### Example:
         * When the URL is `/foo/123` the rule will redirect to `/bar/123`.
         * ```js
         * .when(new RegExp("^/foo/(.*)$"), "/bar/$1");
         * ```
         *
         * ---
         *
         * When the handler is a function, it receives the matched value, the current URL, and the `UIRouter` object (See [[UrlRuleHandlerFn]]).
         * The "matched value" differs based on the `matcher`.
         * For [[UrlMatcher]]s, it will be the matched state params.
         * For `RegExp`, it will be the match array from `regexp.exec()`.
         *
         * If the handler returns a string, the URL is redirected to the string.
         *
         * #### Example:
         * When the URL is `/foo/123` the rule will redirect to `/bar/123`.
         * ```js
         * .when(new RegExp("^/foo/(.*)$"), match => "/bar/" + match[1]);
         * ```
         *
         * Note: the `handler` may also invoke arbitrary code, such as `$state.go()`
         *
         * @param matcher A pattern `string` to match, compiled as a [[UrlMatcher]], or a `RegExp`.
         * @param handler The path to redirect to, or a function that returns the path.
         * @param options `{ priority: number }`
         *
         * @return the registered [[UrlRule]]
         */
        UrlRules.prototype.when = function (matcher, handler, options) {
            var rule = this.urlRuleFactory.create(matcher, handler);
            if (isDefined(options && options.priority))
                rule.priority = options.priority;
            this.rule(rule);
            return rule;
        };
        return UrlRules;
    }());

    /**
     * An API to customize the URL behavior and retrieve URL configuration
     *
     * This API is used to customize the behavior of the URL.
     * This includes optional trailing slashes ([[strictMode]]), case sensitivity ([[caseInsensitive]]),
     * and custom parameter encoding (custom [[type]]).
     *
     * It also has information about the location (url) configuration such as [[port]] and [[baseHref]].
     * This information can be used to build absolute URLs, such as
     * `https://example.com:443/basepath/state/substate?param1=a#hashvalue`;
     *
     * This API is found at `router.urlService.config` (see: [[UIRouter.urlService]], [[URLService.config]])
     */
    var UrlConfig = /** @class */ (function () {
        /** @internal */ function UrlConfig(/** @internal */ router) {
            var _this = this;
            this.router = router;
            /** @internal */ this.paramTypes = new ParamTypes();
            /** @internal */ this._decodeParams = true;
            /** @internal */ this._isCaseInsensitive = false;
            /** @internal */ this._isStrictMode = true;
            /** @internal */ this._defaultSquashPolicy = false;
            /** @internal */ this.dispose = function () { return _this.paramTypes.dispose(); };
            // Delegate these calls to the current LocationConfig implementation
            /**
             * Gets the base Href, e.g., `http://localhost/approot/`
             *
             * @return the application's base href
             */
            this.baseHref = function () { return _this.router.locationConfig.baseHref(); };
            /**
             * Gets or sets the hashPrefix
             *
             * This only applies when not running in [[html5Mode]] (pushstate mode)
             *
             * If the current url is `http://localhost/app#!/uirouter/path/#anchor`, it returns `!` which is the prefix for the "hashbang" portion.
             *
             * @return the hash prefix
             */
            this.hashPrefix = function (newprefix) { return _this.router.locationConfig.hashPrefix(newprefix); };
            /**
             * Gets the host, e.g., `localhost`
             *
             * @return the protocol
             */
            this.host = function () { return _this.router.locationConfig.host(); };
            /**
             * Returns true when running in pushstate mode
             *
             * @return true when running in html5 mode (pushstate mode).
             */
            this.html5Mode = function () { return _this.router.locationConfig.html5Mode(); };
            /**
             * Gets the port, e.g., `80`
             *
             * @return the port number
             */
            this.port = function () { return _this.router.locationConfig.port(); };
            /**
             * Gets the protocol, e.g., `http`
             *
             * @return the protocol
             */
            this.protocol = function () { return _this.router.locationConfig.protocol(); };
        }
        /**
         * Defines whether URL matching should be case sensitive (the default behavior), or not.
         *
         * #### Example:
         * ```js
         * // Allow case insensitive url matches
         * urlService.config.caseInsensitive(true);
         * ```
         *
         * @param value `false` to match URL in a case sensitive manner; otherwise `true`;
         * @returns the current value of caseInsensitive
         */
        UrlConfig.prototype.caseInsensitive = function (value) {
            return (this._isCaseInsensitive = isDefined(value) ? value : this._isCaseInsensitive);
        };
        /**
         * Sets the default behavior when generating or matching URLs with default parameter values.
         *
         * #### Example:
         * ```js
         * // Remove default parameter values from the url
         * urlService.config.defaultSquashPolicy(true);
         * ```
         *
         * @param value A string that defines the default parameter URL squashing behavior.
         *    - `nosquash`: When generating an href with a default parameter value, do not squash the parameter value from the URL
         *    - `slash`: When generating an href with a default parameter value, squash (remove) the parameter value, and, if the
         *      parameter is surrounded by slashes, squash (remove) one slash from the URL
         *    - any other string, e.g. "~": When generating an href with a default parameter value, squash (remove)
         *      the parameter value from the URL and replace it with this string.
         * @returns the current value of defaultSquashPolicy
         */
        UrlConfig.prototype.defaultSquashPolicy = function (value) {
            if (isDefined(value) && value !== true && value !== false && !isString(value))
                throw new Error("Invalid squash policy: " + value + ". Valid policies: false, true, arbitrary-string");
            return (this._defaultSquashPolicy = isDefined(value) ? value : this._defaultSquashPolicy);
        };
        /**
         * Defines whether URLs should match trailing slashes, or not (the default behavior).
         *
         * #### Example:
         * ```js
         * // Allow optional trailing slashes
         * urlService.config.strictMode(false);
         * ```
         *
         * @param value `false` to match trailing slashes in URLs, otherwise `true`.
         * @returns the current value of strictMode
         */
        UrlConfig.prototype.strictMode = function (value) {
            return (this._isStrictMode = isDefined(value) ? value : this._isStrictMode);
        };
        /**
         * Creates and registers a custom [[ParamType]] object
         *
         * A custom parameter type can be used to generate URLs with typed parameters or custom encoding/decoding.
         *
         * #### Note: Register custom types *before using them* in a state definition.
         *
         * #### Example:
         * ```js
         * // Encode object parameter as JSON string
         * urlService.config.type('myjson', {
         *   encode: (obj) => JSON.stringify(obj),
         *   decode: (str) => JSON.parse(str),
         *   is: (val) => typeof(val) === 'object',
         *   pattern: /[^/]+/,
         *   equals: (a, b) => _.isEqual(a, b),
         * });
         * ```
         *
         * See [[ParamTypeDefinition]] for more examples
         *
         * @param name The type name.
         * @param definition The type definition. See [[ParamTypeDefinition]] for information on the values accepted.
         * @param definitionFn A function that is injected before the app runtime starts.
         *        The result of this function should be a [[ParamTypeDefinition]].
         *        The result is merged into the existing `definition`.
         *        See [[ParamType]] for information on the values accepted.
         *
         * @returns if only the `name` parameter was specified: the currently registered [[ParamType]] object, or undefined
         */
        UrlConfig.prototype.type = function (name, definition, definitionFn) {
            var type = this.paramTypes.type(name, definition, definitionFn);
            return !isDefined(definition) ? type : this;
        };
        return UrlConfig;
    }());

    /**
     * API for URL management
     */
    var UrlService = /** @class */ (function () {
        /** @internal */
        function UrlService(/** @internal */ router) {
            var _this = this;
            this.router = router;
            /** @internal */ this.interceptDeferred = false;
            /**
             * The nested [[UrlRules]] API for managing URL rules and rewrites
             *
             * See: [[UrlRules]] for details
             */
            this.rules = new UrlRules(this.router);
            /**
             * The nested [[UrlConfig]] API to configure the URL and retrieve URL information
             *
             * See: [[UrlConfig]] for details
             */
            this.config = new UrlConfig(this.router);
            // Delegate these calls to the current LocationServices implementation
            /**
             * Gets the current url, or updates the url
             *
             * ### Getting the current URL
             *
             * When no arguments are passed, returns the current URL.
             * The URL is normalized using the internal [[path]]/[[search]]/[[hash]] values.
             *
             * For example, the URL may be stored in the hash ([[HashLocationServices]]) or
             * have a base HREF prepended ([[PushStateLocationServices]]).
             *
             * The raw URL in the browser might be:
             *
             * ```
             * http://mysite.com/somepath/index.html#/internal/path/123?param1=foo#anchor
             * ```
             *
             * or
             *
             * ```
             * http://mysite.com/basepath/internal/path/123?param1=foo#anchor
             * ```
             *
             * then this method returns:
             *
             * ```
             * /internal/path/123?param1=foo#anchor
             * ```
             *
             *
             * #### Example:
             * ```js
             * locationServices.url(); // "/some/path?query=value#anchor"
             * ```
             *
             * ### Updating the URL
             *
             * When `newurl` arguments is provided, changes the URL to reflect `newurl`
             *
             * #### Example:
             * ```js
             * locationServices.url("/some/path?query=value#anchor", true);
             * ```
             *
             * @param newurl The new value for the URL.
             *               This url should reflect only the new internal [[path]], [[search]], and [[hash]] values.
             *               It should not include the protocol, site, port, or base path of an absolute HREF.
             * @param replace When true, replaces the current history entry (instead of appending it) with this new url
             * @param state The history's state object, i.e., pushState (if the LocationServices implementation supports it)
             *
             * @return the url (after potentially being processed)
             */
            this.url = function (newurl, replace, state) {
                return _this.router.locationService.url(newurl, replace, state);
            };
            /**
             * Gets the path part of the current url
             *
             * If the current URL is `/some/path?query=value#anchor`, this returns `/some/path`
             *
             * @return the path portion of the url
             */
            this.path = function () { return _this.router.locationService.path(); };
            /**
             * Gets the search part of the current url as an object
             *
             * If the current URL is `/some/path?query=value#anchor`, this returns `{ query: 'value' }`
             *
             * @return the search (query) portion of the url, as an object
             */
            this.search = function () { return _this.router.locationService.search(); };
            /**
             * Gets the hash part of the current url
             *
             * If the current URL is `/some/path?query=value#anchor`, this returns `anchor`
             *
             * @return the hash (anchor) portion of the url
             */
            this.hash = function () { return _this.router.locationService.hash(); };
            /**
             * @internal
             *
             * Registers a low level url change handler
             *
             * Note: Because this is a low level handler, it's not recommended for general use.
             *
             * #### Example:
             * ```js
             * let deregisterFn = locationServices.onChange((evt) => console.log("url change", evt));
             * ```
             *
             * @param callback a function that will be called when the url is changing
             * @return a function that de-registers the callback
             */
            this.onChange = function (callback) { return _this.router.locationService.onChange(callback); };
        }
        /** @internal */
        UrlService.prototype.dispose = function () {
            this.listen(false);
            this.rules.dispose();
        };
        /**
         * Gets the current URL parts
         *
         * This method returns the different parts of the current URL (the [[path]], [[search]], and [[hash]]) as a [[UrlParts]] object.
         */
        UrlService.prototype.parts = function () {
            return { path: this.path(), search: this.search(), hash: this.hash() };
        };
        /**
         * Activates the best rule for the current URL
         *
         * Checks the current URL for a matching [[UrlRule]], then invokes that rule's handler.
         * This method is called internally any time the URL has changed.
         *
         * This effectively activates the state (or redirect, etc) which matches the current URL.
         *
         * #### Example:
         * ```js
         * urlService.deferIntercept();
         *
         * fetch('/states.json').then(resp => resp.json()).then(data => {
         *   data.forEach(state => $stateRegistry.register(state));
         *   urlService.listen();
         *   // Find the matching URL and invoke the handler.
         *   urlService.sync();
         * });
         * ```
         */
        UrlService.prototype.sync = function (evt) {
            if (evt && evt.defaultPrevented)
                return;
            var _a = this.router, urlService = _a.urlService, stateService = _a.stateService;
            var url = { path: urlService.path(), search: urlService.search(), hash: urlService.hash() };
            var best = this.match(url);
            var applyResult = pattern([
                [isString, function (newurl) { return urlService.url(newurl, true); }],
                [TargetState.isDef, function (def) { return stateService.go(def.state, def.params, def.options); }],
                [is(TargetState), function (target) { return stateService.go(target.state(), target.params(), target.options()); }],
            ]);
            applyResult(best && best.rule.handler(best.match, url, this.router));
        };
        /**
         * Starts or stops listening for URL changes
         *
         * Call this sometime after calling [[deferIntercept]] to start monitoring the url.
         * This causes UI-Router to start listening for changes to the URL, if it wasn't already listening.
         *
         * If called with `false`, UI-Router will stop listening (call listen(true) to start listening again).
         *
         * #### Example:
         * ```js
         * urlService.deferIntercept();
         *
         * fetch('/states.json').then(resp => resp.json()).then(data => {
         *   data.forEach(state => $stateRegistry.register(state));
         *   // Start responding to URL changes
         *   urlService.listen();
         *   urlService.sync();
         * });
         * ```
         *
         * @param enabled `true` or `false` to start or stop listening to URL changes
         */
        UrlService.prototype.listen = function (enabled) {
            var _this = this;
            if (enabled === false) {
                this._stopListeningFn && this._stopListeningFn();
                delete this._stopListeningFn;
            }
            else {
                return (this._stopListeningFn =
                    this._stopListeningFn || this.router.urlService.onChange(function (evt) { return _this.sync(evt); }));
            }
        };
        /**
         * Disables monitoring of the URL.
         *
         * Call this method before UI-Router has bootstrapped.
         * It will stop UI-Router from performing the initial url sync.
         *
         * This can be useful to perform some asynchronous initialization before the router starts.
         * Once the initialization is complete, call [[listen]] to tell UI-Router to start watching and synchronizing the URL.
         *
         * #### Example:
         * ```js
         * // Prevent UI-Router from automatically intercepting URL changes when it starts;
         * urlService.deferIntercept();
         *
         * fetch('/states.json').then(resp => resp.json()).then(data => {
         *   data.forEach(state => $stateRegistry.register(state));
         *   urlService.listen();
         *   urlService.sync();
         * });
         * ```
         *
         * @param defer Indicates whether to defer location change interception.
         *        Passing no parameter is equivalent to `true`.
         */
        UrlService.prototype.deferIntercept = function (defer) {
            if (defer === undefined)
                defer = true;
            this.interceptDeferred = defer;
        };
        /**
         * Matches a URL
         *
         * Given a URL (as a [[UrlParts]] object), check all rules and determine the best matching rule.
         * Return the result as a [[MatchResult]].
         */
        UrlService.prototype.match = function (url) {
            var _this = this;
            url = extend({ path: '', search: {}, hash: '' }, url);
            var rules = this.rules.rules();
            // Checks a single rule. Returns { rule: rule, match: match, weight: weight } if it matched, or undefined
            var checkRule = function (rule) {
                var match = rule.match(url, _this.router);
                return match && { match: match, rule: rule, weight: rule.matchPriority(match) };
            };
            // The rules are pre-sorted.
            // - Find the first matching rule.
            // - Find any other matching rule that sorted *exactly the same*, according to `.sort()`.
            // - Choose the rule with the highest match weight.
            var best;
            for (var i = 0; i < rules.length; i++) {
                // Stop when there is a 'best' rule and the next rule sorts differently than it.
                if (best && best.rule._group !== rules[i]._group)
                    break;
                var current = checkRule(rules[i]);
                // Pick the best MatchResult
                best = !best || (current && current.weight > best.weight) ? current : best;
            }
            return best;
        };
        return UrlService;
    }());

    /** @internal */
    var _routerInstance = 0;
    /** @internal */
    var locSvcFns = ['url', 'path', 'search', 'hash', 'onChange'];
    /** @internal */
    var locCfgFns = ['port', 'protocol', 'host', 'baseHref', 'html5Mode', 'hashPrefix'];
    /** @internal */
    var locationServiceStub = makeStub('LocationServices', locSvcFns);
    /** @internal */
    var locationConfigStub = makeStub('LocationConfig', locCfgFns);
    /**
     * An instance of UI-Router.
     *
     * This object contains references to service APIs which define your application's routing behavior.
     */
    var UIRouter = /** @class */ (function () {
        /**
         * Creates a new `UIRouter` object
         *
         * @param locationService a [[LocationServices]] implementation
         * @param locationConfig a [[LocationConfig]] implementation
         * @internal
         */
        function UIRouter(locationService, locationConfig) {
            if (locationService === void 0) { locationService = locationServiceStub; }
            if (locationConfig === void 0) { locationConfig = locationConfigStub; }
            this.locationService = locationService;
            this.locationConfig = locationConfig;
            /** @internal */ this.$id = _routerInstance++;
            /** @internal */ this._disposed = false;
            /** @internal */ this._disposables = [];
            /** Enable/disable tracing to the javascript console */
            this.trace = trace;
            /** Provides services related to ui-view synchronization */
            this.viewService = new ViewService(this);
            /** An object that contains global router state, such as the current state and params */
            this.globals = new UIRouterGlobals();
            /** A service that exposes global Transition Hooks */
            this.transitionService = new TransitionService(this);
            /**
             * Deprecated for public use. Use [[urlService]] instead.
             * @deprecated Use [[urlService]] instead
             */
            this.urlMatcherFactory = new UrlMatcherFactory(this);
            /**
             * Deprecated for public use. Use [[urlService]] instead.
             * @deprecated Use [[urlService]] instead
             */
            this.urlRouter = new UrlRouter(this);
            /** Provides services related to the URL */
            this.urlService = new UrlService(this);
            /** Provides a registry for states, and related registration services */
            this.stateRegistry = new StateRegistry(this);
            /** Provides services related to states */
            this.stateService = new StateService(this);
            /** @internal plugin instances are registered here */
            this._plugins = {};
            this.viewService._pluginapi._rootViewContext(this.stateRegistry.root());
            this.globals.$current = this.stateRegistry.root();
            this.globals.current = this.globals.$current.self;
            this.disposable(this.globals);
            this.disposable(this.stateService);
            this.disposable(this.stateRegistry);
            this.disposable(this.transitionService);
            this.disposable(this.urlService);
            this.disposable(locationService);
            this.disposable(locationConfig);
        }
        /** Registers an object to be notified when the router is disposed */
        UIRouter.prototype.disposable = function (disposable) {
            this._disposables.push(disposable);
        };
        /**
         * Disposes this router instance
         *
         * When called, clears resources retained by the router by calling `dispose(this)` on all
         * registered [[disposable]] objects.
         *
         * Or, if a `disposable` object is provided, calls `dispose(this)` on that object only.
         *
         * @internal
         * @param disposable (optional) the disposable to dispose
         */
        UIRouter.prototype.dispose = function (disposable) {
            var _this = this;
            if (disposable && isFunction(disposable.dispose)) {
                disposable.dispose(this);
                return undefined;
            }
            this._disposed = true;
            this._disposables.slice().forEach(function (d) {
                try {
                    typeof d.dispose === 'function' && d.dispose(_this);
                    removeFrom(_this._disposables, d);
                }
                catch (ignored) { }
            });
        };
        /**
         * Adds a plugin to UI-Router
         *
         * This method adds a UI-Router Plugin.
         * A plugin can enhance or change UI-Router behavior using any public API.
         *
         * #### Example:
         * ```js
         * import { MyCoolPlugin } from "ui-router-cool-plugin";
         *
         * var plugin = router.addPlugin(MyCoolPlugin);
         * ```
         *
         * ### Plugin authoring
         *
         * A plugin is simply a class (or constructor function) which accepts a [[UIRouter]] instance and (optionally) an options object.
         *
         * The plugin can implement its functionality using any of the public APIs of [[UIRouter]].
         * For example, it may configure router options or add a Transition Hook.
         *
         * The plugin can then be published as a separate module.
         *
         * #### Example:
         * ```js
         * export class MyAuthPlugin implements UIRouterPlugin {
         *   constructor(router: UIRouter, options: any) {
         *     this.name = "MyAuthPlugin";
         *     let $transitions = router.transitionService;
         *     let $state = router.stateService;
         *
         *     let authCriteria = {
         *       to: (state) => state.data && state.data.requiresAuth
         *     };
         *
         *     function authHook(transition: Transition) {
         *       let authService = transition.injector().get('AuthService');
         *       if (!authService.isAuthenticated()) {
         *         return $state.target('login');
         *       }
         *     }
         *
         *     $transitions.onStart(authCriteria, authHook);
         *   }
         * }
         * ```
         *
         * @param plugin one of:
         *        - a plugin class which implements [[UIRouterPlugin]]
         *        - a constructor function for a [[UIRouterPlugin]] which accepts a [[UIRouter]] instance
         *        - a factory function which accepts a [[UIRouter]] instance and returns a [[UIRouterPlugin]] instance
         * @param options options to pass to the plugin class/factory
         * @returns the registered plugin instance
         */
        UIRouter.prototype.plugin = function (plugin, options) {
            if (options === void 0) { options = {}; }
            var pluginInstance = new plugin(this, options);
            if (!pluginInstance.name)
                throw new Error('Required property `name` missing on plugin: ' + pluginInstance);
            this._disposables.push(pluginInstance);
            return (this._plugins[pluginInstance.name] = pluginInstance);
        };
        UIRouter.prototype.getPlugin = function (pluginName) {
            return pluginName ? this._plugins[pluginName] : values(this._plugins);
        };
        return UIRouter;
    }());

    function addCoreResolvables(trans) {
        trans.addResolvable(Resolvable.fromData(UIRouter, trans.router), '');
        trans.addResolvable(Resolvable.fromData(Transition, trans), '');
        trans.addResolvable(Resolvable.fromData('$transition$', trans), '');
        trans.addResolvable(Resolvable.fromData('$stateParams', trans.params()), '');
        trans.entering().forEach(function (state) {
            trans.addResolvable(Resolvable.fromData('$state$', state), state);
        });
    }
    var registerAddCoreResolvables = function (transitionService) {
        return transitionService.onCreate({}, addCoreResolvables);
    };
    var TRANSITION_TOKENS = ['$transition$', Transition];
    var isTransition = inArray(TRANSITION_TOKENS);
    // References to Transition in the treeChanges pathnodes makes all
    // previous Transitions reachable in memory, causing a memory leak
    // This function removes resolves for '$transition$' and `Transition` from the treeChanges.
    // Do not use this on current transitions, only on old ones.
    var treeChangesCleanup = function (trans) {
        var nodes = values(trans.treeChanges()).reduce(unnestR, []).reduce(uniqR, []);
        // If the resolvable is a Transition, return a new resolvable with null data
        var replaceTransitionWithNull = function (r) {
            return isTransition(r.token) ? Resolvable.fromData(r.token, null) : r;
        };
        nodes.forEach(function (node) {
            node.resolvables = node.resolvables.map(replaceTransitionWithNull);
        });
    };

    /**
     * A [[TransitionHookFn]] that redirects to a different state or params
     *
     * Registered using `transitionService.onStart({ to: (state) => !!state.redirectTo }, redirectHook);`
     *
     * See [[StateDeclaration.redirectTo]]
     */
    var redirectToHook = function (trans) {
        var redirect = trans.to().redirectTo;
        if (!redirect)
            return;
        var $state = trans.router.stateService;
        function handleResult(result) {
            if (!result)
                return;
            if (result instanceof TargetState)
                return result;
            if (isString(result))
                return $state.target(result, trans.params(), trans.options());
            if (result['state'] || result['params'])
                return $state.target(result['state'] || trans.to(), result['params'] || trans.params(), trans.options());
        }
        if (isFunction(redirect)) {
            return services.$q.when(redirect(trans)).then(handleResult);
        }
        return handleResult(redirect);
    };
    var registerRedirectToHook = function (transitionService) {
        return transitionService.onStart({ to: function (state) { return !!state.redirectTo; } }, redirectToHook);
    };

    /**
     * A factory which creates an onEnter, onExit or onRetain transition hook function
     *
     * The returned function invokes the (for instance) state.onEnter hook when the
     * state is being entered.
     */
    function makeEnterExitRetainHook(hookName) {
        return function (transition, state) {
            var _state = state.$$state();
            var hookFn = _state[hookName];
            return hookFn(transition, state);
        };
    }
    /**
     * The [[TransitionStateHookFn]] for onExit
     *
     * When the state is being exited, the state's .onExit function is invoked.
     *
     * Registered using `transitionService.onExit({ exiting: (state) => !!state.onExit }, onExitHook);`
     *
     * See: [[IHookRegistry.onExit]]
     */
    var onExitHook = makeEnterExitRetainHook('onExit');
    var registerOnExitHook = function (transitionService) {
        return transitionService.onExit({ exiting: function (state) { return !!state.onExit; } }, onExitHook);
    };
    /**
     * The [[TransitionStateHookFn]] for onRetain
     *
     * When the state was already entered, and is not being exited or re-entered, the state's .onRetain function is invoked.
     *
     * Registered using `transitionService.onRetain({ retained: (state) => !!state.onRetain }, onRetainHook);`
     *
     * See: [[IHookRegistry.onRetain]]
     */
    var onRetainHook = makeEnterExitRetainHook('onRetain');
    var registerOnRetainHook = function (transitionService) {
        return transitionService.onRetain({ retained: function (state) { return !!state.onRetain; } }, onRetainHook);
    };
    /**
     * The [[TransitionStateHookFn]] for onEnter
     *
     * When the state is being entered, the state's .onEnter function is invoked.
     *
     * Registered using `transitionService.onEnter({ entering: (state) => !!state.onEnter }, onEnterHook);`
     *
     * See: [[IHookRegistry.onEnter]]
     */
    var onEnterHook = makeEnterExitRetainHook('onEnter');
    var registerOnEnterHook = function (transitionService) {
        return transitionService.onEnter({ entering: function (state) { return !!state.onEnter; } }, onEnterHook);
    };

    var RESOLVE_HOOK_PRIORITY = 1000;
    /**
     * A [[TransitionHookFn]] which resolves all EAGER Resolvables in the To Path
     *
     * Registered using `transitionService.onStart({}, eagerResolvePath, { priority: 1000 });`
     *
     * When a Transition starts, this hook resolves all the EAGER Resolvables, which the transition then waits for.
     *
     * See [[StateDeclaration.resolve]]
     */
    var eagerResolvePath = function (trans) {
        return new ResolveContext(trans.treeChanges().to).resolvePath('EAGER', trans).then(noop);
    };
    var registerEagerResolvePath = function (transitionService) {
        return transitionService.onStart({}, eagerResolvePath, { priority: RESOLVE_HOOK_PRIORITY });
    };
    /**
     * A [[TransitionHookFn]] which resolves all LAZY Resolvables for the state (and all its ancestors) in the To Path
     *
     * Registered using `transitionService.onEnter({ entering: () => true }, lazyResolveState, { priority: 1000 });`
     *
     * When a State is being entered, this hook resolves all the Resolvables for this state, which the transition then waits for.
     *
     * See [[StateDeclaration.resolve]]
     */
    var lazyResolveState = function (trans, state) {
        return new ResolveContext(trans.treeChanges().to).subContext(state.$$state()).resolvePath('LAZY', trans).then(noop);
    };
    var registerLazyResolveState = function (transitionService) {
        return transitionService.onEnter({ entering: val(true) }, lazyResolveState, { priority: RESOLVE_HOOK_PRIORITY });
    };
    /**
     * A [[TransitionHookFn]] which resolves any dynamically added (LAZY or EAGER) Resolvables.
     *
     * Registered using `transitionService.onFinish({}, eagerResolvePath, { priority: 1000 });`
     *
     * After all entering states have been entered, this hook resolves any remaining Resolvables.
     * These are typically dynamic resolves which were added by some Transition Hook using [[Transition.addResolvable]].
     *
     * See [[StateDeclaration.resolve]]
     */
    var resolveRemaining = function (trans) {
        return new ResolveContext(trans.treeChanges().to).resolvePath('LAZY', trans).then(noop);
    };
    var registerResolveRemaining = function (transitionService) {
        return transitionService.onFinish({}, resolveRemaining, { priority: RESOLVE_HOOK_PRIORITY });
    };

    /**
     * A [[TransitionHookFn]] which waits for the views to load
     *
     * Registered using `transitionService.onStart({}, loadEnteringViews);`
     *
     * Allows the views to do async work in [[ViewConfig.load]] before the transition continues.
     * In angular 1, this includes loading the templates.
     */
    var loadEnteringViews = function (transition) {
        var $q = services.$q;
        var enteringViews = transition.views('entering');
        if (!enteringViews.length)
            return;
        return $q.all(enteringViews.map(function (view) { return $q.when(view.load()); })).then(noop);
    };
    var registerLoadEnteringViews = function (transitionService) {
        return transitionService.onFinish({}, loadEnteringViews);
    };
    /**
     * A [[TransitionHookFn]] which activates the new views when a transition is successful.
     *
     * Registered using `transitionService.onSuccess({}, activateViews);`
     *
     * After a transition is complete, this hook deactivates the old views from the previous state,
     * and activates the new views from the destination state.
     *
     * See [[ViewService]]
     */
    var activateViews = function (transition) {
        var enteringViews = transition.views('entering');
        var exitingViews = transition.views('exiting');
        if (!enteringViews.length && !exitingViews.length)
            return;
        var $view = transition.router.viewService;
        exitingViews.forEach(function (vc) { return $view.deactivateViewConfig(vc); });
        enteringViews.forEach(function (vc) { return $view.activateViewConfig(vc); });
        $view.sync();
    };
    var registerActivateViews = function (transitionService) {
        return transitionService.onSuccess({}, activateViews);
    };

    /**
     * A [[TransitionHookFn]] which updates global UI-Router state
     *
     * Registered using `transitionService.onBefore({}, updateGlobalState);`
     *
     * Before a [[Transition]] starts, updates the global value of "the current transition" ([[Globals.transition]]).
     * After a successful [[Transition]], updates the global values of "the current state"
     * ([[Globals.current]] and [[Globals.$current]]) and "the current param values" ([[Globals.params]]).
     *
     * See also the deprecated properties:
     * [[StateService.transition]], [[StateService.current]], [[StateService.params]]
     */
    var updateGlobalState = function (trans) {
        var globals = trans.router.globals;
        var transitionSuccessful = function () {
            globals.successfulTransitions.enqueue(trans);
            globals.$current = trans.$to();
            globals.current = globals.$current.self;
            copy(trans.params(), globals.params);
        };
        var clearCurrentTransition = function () {
            // Do not clear globals.transition if a different transition has started in the meantime
            if (globals.transition === trans)
                globals.transition = null;
        };
        trans.onSuccess({}, transitionSuccessful, { priority: 10000 });
        trans.promise.then(clearCurrentTransition, clearCurrentTransition);
    };
    var registerUpdateGlobalState = function (transitionService) {
        return transitionService.onCreate({}, updateGlobalState);
    };

    /**
     * A [[TransitionHookFn]] which updates the URL after a successful transition
     *
     * Registered using `transitionService.onSuccess({}, updateUrl);`
     */
    var updateUrl = function (transition) {
        var options = transition.options();
        var $state = transition.router.stateService;
        var $urlRouter = transition.router.urlRouter;
        // Dont update the url in these situations:
        // The transition was triggered by a URL sync (options.source === 'url')
        // The user doesn't want the url to update (options.location === false)
        // The destination state, and all parents have no navigable url
        if (options.source !== 'url' && options.location && $state.$current.navigable) {
            var urlOptions = { replace: options.location === 'replace' };
            $urlRouter.push($state.$current.navigable.url, $state.params, urlOptions);
        }
        $urlRouter.update(true);
    };
    var registerUpdateUrl = function (transitionService) {
        return transitionService.onSuccess({}, updateUrl, { priority: 9999 });
    };

    /**
     * A [[TransitionHookFn]] that performs lazy loading
     *
     * When entering a state "abc" which has a `lazyLoad` function defined:
     * - Invoke the `lazyLoad` function (unless it is already in process)
     *   - Flag the hook function as "in process"
     *   - The function should return a promise (that resolves when lazy loading is complete)
     * - Wait for the promise to settle
     *   - If the promise resolves to a [[LazyLoadResult]], then register those states
     *   - Flag the hook function as "not in process"
     * - If the hook was successful
     *   - Remove the `lazyLoad` function from the state declaration
     * - If all the hooks were successful
     *   - Retry the transition (by returning a TargetState)
     *
     * ```
     * .state('abc', {
     *   component: 'fooComponent',
     *   lazyLoad: () => import('./fooComponent')
     *   });
     * ```
     *
     * See [[StateDeclaration.lazyLoad]]
     */
    var lazyLoadHook = function (transition) {
        var router = transition.router;
        function retryTransition() {
            if (transition.originalTransition().options().source !== 'url') {
                // The original transition was not triggered via url sync
                // The lazy state should be loaded now, so re-try the original transition
                var orig = transition.targetState();
                return router.stateService.target(orig.identifier(), orig.params(), orig.options());
            }
            // The original transition was triggered via url sync
            // Run the URL rules and find the best match
            var $url = router.urlService;
            var result = $url.match($url.parts());
            var rule = result && result.rule;
            // If the best match is a state, redirect the transition (instead
            // of calling sync() which supersedes the current transition)
            if (rule && rule.type === 'STATE') {
                var state = rule.state;
                var params = result.match;
                return router.stateService.target(state, params, transition.options());
            }
            // No matching state found, so let .sync() choose the best non-state match/otherwise
            router.urlService.sync();
        }
        var promises = transition
            .entering()
            .filter(function (state) { return !!state.$$state().lazyLoad; })
            .map(function (state) { return lazyLoadState(transition, state); });
        return services.$q.all(promises).then(retryTransition);
    };
    var registerLazyLoadHook = function (transitionService) {
        return transitionService.onBefore({ entering: function (state) { return !!state.lazyLoad; } }, lazyLoadHook);
    };
    /**
     * Invokes a state's lazy load function
     *
     * @param transition a Transition context
     * @param state the state to lazy load
     * @returns A promise for the lazy load result
     */
    function lazyLoadState(transition, state) {
        var lazyLoadFn = state.$$state().lazyLoad;
        // Store/get the lazy load promise on/from the hookfn so it doesn't get re-invoked
        var promise = lazyLoadFn['_promise'];
        if (!promise) {
            var success = function (result) {
                delete state.lazyLoad;
                delete state.$$state().lazyLoad;
                delete lazyLoadFn['_promise'];
                return result;
            };
            var error = function (err) {
                delete lazyLoadFn['_promise'];
                return services.$q.reject(err);
            };
            promise = lazyLoadFn['_promise'] = services.$q
                .when(lazyLoadFn(transition, state))
                .then(updateStateRegistry)
                .then(success, error);
        }
        /** Register any lazy loaded state definitions */
        function updateStateRegistry(result) {
            if (result && Array.isArray(result.states)) {
                result.states.forEach(function (_state) { return transition.router.stateRegistry.register(_state); });
            }
            return result;
        }
        return promise;
    }

    /**
     * This class defines a type of hook, such as `onBefore` or `onEnter`.
     * Plugins can define custom hook types, such as sticky states does for `onInactive`.
     */
    var TransitionEventType = /** @class */ (function () {
        /* tslint:disable:no-inferrable-types */
        function TransitionEventType(name, hookPhase, hookOrder, criteriaMatchPath, reverseSort, getResultHandler, getErrorHandler, synchronous) {
            if (reverseSort === void 0) { reverseSort = false; }
            if (getResultHandler === void 0) { getResultHandler = TransitionHook.HANDLE_RESULT; }
            if (getErrorHandler === void 0) { getErrorHandler = TransitionHook.REJECT_ERROR; }
            if (synchronous === void 0) { synchronous = false; }
            this.name = name;
            this.hookPhase = hookPhase;
            this.hookOrder = hookOrder;
            this.criteriaMatchPath = criteriaMatchPath;
            this.reverseSort = reverseSort;
            this.getResultHandler = getResultHandler;
            this.getErrorHandler = getErrorHandler;
            this.synchronous = synchronous;
        }
        return TransitionEventType;
    }());

    /**
     * A [[TransitionHookFn]] that skips a transition if it should be ignored
     *
     * This hook is invoked at the end of the onBefore phase.
     *
     * If the transition should be ignored (because no parameter or states changed)
     * then the transition is ignored and not processed.
     */
    function ignoredHook(trans) {
        var ignoredReason = trans._ignoredReason();
        if (!ignoredReason)
            return;
        trace.traceTransitionIgnored(trans);
        var pending = trans.router.globals.transition;
        // The user clicked a link going back to the *current state* ('A')
        // However, there is also a pending transition in flight (to 'B')
        // Abort the transition to 'B' because the user now wants to be back at 'A'.
        if (ignoredReason === 'SameAsCurrent' && pending) {
            pending.abort();
        }
        return Rejection.ignored().toPromise();
    }
    var registerIgnoredTransitionHook = function (transitionService) {
        return transitionService.onBefore({}, ignoredHook, { priority: -9999 });
    };

    /**
     * A [[TransitionHookFn]] that rejects the Transition if it is invalid
     *
     * This hook is invoked at the end of the onBefore phase.
     * If the transition is invalid (for example, param values do not validate)
     * then the transition is rejected.
     */
    function invalidTransitionHook(trans) {
        if (!trans.valid()) {
            throw new Error(trans.error().toString());
        }
    }
    var registerInvalidTransitionHook = function (transitionService) {
        return transitionService.onBefore({}, invalidTransitionHook, { priority: -10000 });
    };

    /**
     * The default [[Transition]] options.
     *
     * Include this object when applying custom defaults:
     * let reloadOpts = { reload: true, notify: true }
     * let options = defaults(theirOpts, customDefaults, defaultOptions);
     */
    var defaultTransOpts = {
        location: true,
        relative: null,
        inherit: false,
        notify: true,
        reload: false,
        supercede: true,
        custom: {},
        current: function () { return null; },
        source: 'unknown',
    };
    /**
     * This class provides services related to Transitions.
     *
     * - Most importantly, it allows global Transition Hooks to be registered.
     * - It allows the default transition error handler to be set.
     * - It also has a factory function for creating new [[Transition]] objects, (used internally by the [[StateService]]).
     *
     * At bootstrap, [[UIRouter]] creates a single instance (singleton) of this class.
     *
     * This API is located at `router.transitionService` ([[UIRouter.transitionService]])
     */
    var TransitionService = /** @class */ (function () {
        /** @internal */
        function TransitionService(_router) {
            /** @internal */
            this._transitionCount = 0;
            /** The transition hook types, such as `onEnter`, `onStart`, etc */
            this._eventTypes = [];
            /** @internal The registered transition hooks */
            this._registeredHooks = {};
            /** The  paths on a criteria object */
            this._criteriaPaths = {};
            this._router = _router;
            this.$view = _router.viewService;
            this._deregisterHookFns = {};
            this._pluginapi = (createProxyFunctions(val(this), {}, val(this), [
                '_definePathType',
                '_defineEvent',
                '_getPathTypes',
                '_getEvents',
                'getHooks',
            ]));
            this._defineCorePaths();
            this._defineCoreEvents();
            this._registerCoreTransitionHooks();
            _router.globals.successfulTransitions.onEvict(treeChangesCleanup);
        }
        /**
         * Registers a [[TransitionHookFn]], called *while a transition is being constructed*.
         *
         * Registers a transition lifecycle hook, which is invoked during transition construction.
         *
         * This low level hook should only be used by plugins.
         * This can be a useful time for plugins to add resolves or mutate the transition as needed.
         * The Sticky States plugin uses this hook to modify the treechanges.
         *
         * ### Lifecycle
         *
         * `onCreate` hooks are invoked *while a transition is being constructed*.
         *
         * ### Return value
         *
         * The hook's return value is ignored
         *
         * @internal
         * @param criteria defines which Transitions the Hook should be invoked for.
         * @param callback the hook function which will be invoked.
         * @param options the registration options
         * @returns a function which deregisters the hook.
         */
        TransitionService.prototype.onCreate = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onBefore = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onStart = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onExit = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onRetain = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onEnter = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onFinish = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onSuccess = function (criteria, callback, options) {
            return;
        };
        /** @inheritdoc */
        TransitionService.prototype.onError = function (criteria, callback, options) {
            return;
        };
        /**
         * dispose
         * @internal
         */
        TransitionService.prototype.dispose = function (router) {
            values(this._registeredHooks).forEach(function (hooksArray) {
                return hooksArray.forEach(function (hook) {
                    hook._deregistered = true;
                    removeFrom(hooksArray, hook);
                });
            });
        };
        /**
         * Creates a new [[Transition]] object
         *
         * This is a factory function for creating new Transition objects.
         * It is used internally by the [[StateService]] and should generally not be called by application code.
         *
         * @internal
         * @param fromPath the path to the current state (the from state)
         * @param targetState the target state (destination)
         * @returns a Transition
         */
        TransitionService.prototype.create = function (fromPath, targetState) {
            return new Transition(fromPath, targetState, this._router);
        };
        /** @internal */
        TransitionService.prototype._defineCoreEvents = function () {
            var Phase = exports.TransitionHookPhase;
            var TH = TransitionHook;
            var paths = this._criteriaPaths;
            var NORMAL_SORT = false, REVERSE_SORT = true;
            var SYNCHRONOUS = true;
            this._defineEvent('onCreate', Phase.CREATE, 0, paths.to, NORMAL_SORT, TH.LOG_REJECTED_RESULT, TH.THROW_ERROR, SYNCHRONOUS);
            this._defineEvent('onBefore', Phase.BEFORE, 0, paths.to);
            this._defineEvent('onStart', Phase.RUN, 0, paths.to);
            this._defineEvent('onExit', Phase.RUN, 100, paths.exiting, REVERSE_SORT);
            this._defineEvent('onRetain', Phase.RUN, 200, paths.retained);
            this._defineEvent('onEnter', Phase.RUN, 300, paths.entering);
            this._defineEvent('onFinish', Phase.RUN, 400, paths.to);
            this._defineEvent('onSuccess', Phase.SUCCESS, 0, paths.to, NORMAL_SORT, TH.LOG_REJECTED_RESULT, TH.LOG_ERROR, SYNCHRONOUS);
            this._defineEvent('onError', Phase.ERROR, 0, paths.to, NORMAL_SORT, TH.LOG_REJECTED_RESULT, TH.LOG_ERROR, SYNCHRONOUS);
        };
        /** @internal */
        TransitionService.prototype._defineCorePaths = function () {
            var STATE = exports.TransitionHookScope.STATE, TRANSITION = exports.TransitionHookScope.TRANSITION;
            this._definePathType('to', TRANSITION);
            this._definePathType('from', TRANSITION);
            this._definePathType('exiting', STATE);
            this._definePathType('retained', STATE);
            this._definePathType('entering', STATE);
        };
        /** @internal */
        TransitionService.prototype._defineEvent = function (name, hookPhase, hookOrder, criteriaMatchPath, reverseSort, getResultHandler, getErrorHandler, synchronous) {
            if (reverseSort === void 0) { reverseSort = false; }
            if (getResultHandler === void 0) { getResultHandler = TransitionHook.HANDLE_RESULT; }
            if (getErrorHandler === void 0) { getErrorHandler = TransitionHook.REJECT_ERROR; }
            if (synchronous === void 0) { synchronous = false; }
            var eventType = new TransitionEventType(name, hookPhase, hookOrder, criteriaMatchPath, reverseSort, getResultHandler, getErrorHandler, synchronous);
            this._eventTypes.push(eventType);
            makeEvent(this, this, eventType);
        };
        /** @internal */
        TransitionService.prototype._getEvents = function (phase) {
            var transitionHookTypes = isDefined(phase)
                ? this._eventTypes.filter(function (type) { return type.hookPhase === phase; })
                : this._eventTypes.slice();
            return transitionHookTypes.sort(function (l, r) {
                var cmpByPhase = l.hookPhase - r.hookPhase;
                return cmpByPhase === 0 ? l.hookOrder - r.hookOrder : cmpByPhase;
            });
        };
        /**
         * Adds a Path to be used as a criterion against a TreeChanges path
         *
         * For example: the `exiting` path in [[HookMatchCriteria]] is a STATE scoped path.
         * It was defined by calling `defineTreeChangesCriterion('exiting', TransitionHookScope.STATE)`
         * Each state in the exiting path is checked against the criteria and returned as part of the match.
         *
         * Another example: the `to` path in [[HookMatchCriteria]] is a TRANSITION scoped path.
         * It was defined by calling `defineTreeChangesCriterion('to', TransitionHookScope.TRANSITION)`
         * Only the tail of the `to` path is checked against the criteria and returned as part of the match.
         *
         * @internal
         */
        TransitionService.prototype._definePathType = function (name, hookScope) {
            this._criteriaPaths[name] = { name: name, scope: hookScope };
        };
        /** @internal */
        // tslint:disable-next-line
        TransitionService.prototype._getPathTypes = function () {
            return this._criteriaPaths;
        };
        /** @internal */
        TransitionService.prototype.getHooks = function (hookName) {
            return this._registeredHooks[hookName];
        };
        /** @internal */
        TransitionService.prototype._registerCoreTransitionHooks = function () {
            var fns = this._deregisterHookFns;
            fns.addCoreResolves = registerAddCoreResolvables(this);
            fns.ignored = registerIgnoredTransitionHook(this);
            fns.invalid = registerInvalidTransitionHook(this);
            // Wire up redirectTo hook
            fns.redirectTo = registerRedirectToHook(this);
            // Wire up onExit/Retain/Enter state hooks
            fns.onExit = registerOnExitHook(this);
            fns.onRetain = registerOnRetainHook(this);
            fns.onEnter = registerOnEnterHook(this);
            // Wire up Resolve hooks
            fns.eagerResolve = registerEagerResolvePath(this);
            fns.lazyResolve = registerLazyResolveState(this);
            fns.resolveAll = registerResolveRemaining(this);
            // Wire up the View management hooks
            fns.loadViews = registerLoadEnteringViews(this);
            fns.activateViews = registerActivateViews(this);
            // Updates global state after a transition
            fns.updateGlobals = registerUpdateGlobalState(this);
            // After globals.current is updated at priority: 10000
            fns.updateUrl = registerUpdateUrl(this);
            // Lazy load state trees
            fns.lazyLoad = registerLazyLoadHook(this);
        };
        return TransitionService;
    }());

    /**
     * Provides services related to ui-router states.
     *
     * This API is located at `router.stateService` ([[UIRouter.stateService]])
     */
    var StateService = /** @class */ (function () {
        /** @internal */
        function StateService(/** @internal */ router) {
            this.router = router;
            /** @internal */
            this.invalidCallbacks = [];
            /** @internal */
            this._defaultErrorHandler = function $defaultErrorHandler($error$) {
                if ($error$ instanceof Error && $error$.stack) {
                    console.error($error$);
                    console.error($error$.stack);
                }
                else if ($error$ instanceof Rejection) {
                    console.error($error$.toString());
                    if ($error$.detail && $error$.detail.stack)
                        console.error($error$.detail.stack);
                }
                else {
                    console.error($error$);
                }
            };
            var getters = ['current', '$current', 'params', 'transition'];
            var boundFns = Object.keys(StateService.prototype).filter(not(inArray(getters)));
            createProxyFunctions(val(StateService.prototype), this, val(this), boundFns);
        }
        Object.defineProperty(StateService.prototype, "transition", {
            /**
             * The [[Transition]] currently in progress (or null)
             *
             * @deprecated This is a passthrough through to [[UIRouterGlobals.transition]]
             */
            get: function () {
                return this.router.globals.transition;
            },
            enumerable: false,
            configurable: true
        });
        Object.defineProperty(StateService.prototype, "params", {
            /**
             * The latest successful state parameters
             *
             * @deprecated This is a passthrough through to [[UIRouterGlobals.params]]
             */
            get: function () {
                return this.router.globals.params;
            },
            enumerable: false,
            configurable: true
        });
        Object.defineProperty(StateService.prototype, "current", {
            /**
             * The current [[StateDeclaration]]
             *
             * @deprecated This is a passthrough through to [[UIRouterGlobals.current]]
             */
            get: function () {
                return this.router.globals.current;
            },
            enumerable: false,
            configurable: true
        });
        Object.defineProperty(StateService.prototype, "$current", {
            /**
             * The current [[StateObject]] (an internal API)
             *
             * @deprecated This is a passthrough through to [[UIRouterGlobals.$current]]
             */
            get: function () {
                return this.router.globals.$current;
            },
            enumerable: false,
            configurable: true
        });
        /** @internal */
        StateService.prototype.dispose = function () {
            this.defaultErrorHandler(noop);
            this.invalidCallbacks = [];
        };
        /**
         * Handler for when [[transitionTo]] is called with an invalid state.
         *
         * Invokes the [[onInvalid]] callbacks, in natural order.
         * Each callback's return value is checked in sequence until one of them returns an instance of TargetState.
         * The results of the callbacks are wrapped in $q.when(), so the callbacks may return promises.
         *
         * If a callback returns an TargetState, then it is used as arguments to $state.transitionTo() and the result returned.
         *
         * @internal
         */
        StateService.prototype._handleInvalidTargetState = function (fromPath, toState) {
            var _this = this;
            var fromState = PathUtils.makeTargetState(this.router.stateRegistry, fromPath);
            var globals = this.router.globals;
            var latestThing = function () { return globals.transitionHistory.peekTail(); };
            var latest = latestThing();
            var callbackQueue = new Queue(this.invalidCallbacks.slice());
            var injector = new ResolveContext(fromPath).injector();
            var checkForRedirect = function (result) {
                if (!(result instanceof TargetState)) {
                    return;
                }
                var target = result;
                // Recreate the TargetState, in case the state is now defined.
                target = _this.target(target.identifier(), target.params(), target.options());
                if (!target.valid()) {
                    return Rejection.invalid(target.error()).toPromise();
                }
                if (latestThing() !== latest) {
                    return Rejection.superseded().toPromise();
                }
                return _this.transitionTo(target.identifier(), target.params(), target.options());
            };
            function invokeNextCallback() {
                var nextCallback = callbackQueue.dequeue();
                if (nextCallback === undefined)
                    return Rejection.invalid(toState.error()).toPromise();
                var callbackResult = services.$q.when(nextCallback(toState, fromState, injector));
                return callbackResult.then(checkForRedirect).then(function (result) { return result || invokeNextCallback(); });
            }
            return invokeNextCallback();
        };
        /**
         * Registers an Invalid State handler
         *
         * Registers a [[OnInvalidCallback]] function to be invoked when [[StateService.transitionTo]]
         * has been called with an invalid state reference parameter
         *
         * Example:
         * ```js
         * stateService.onInvalid(function(to, from, injector) {
         *   if (to.name() === 'foo') {
         *     let lazyLoader = injector.get('LazyLoadService');
         *     return lazyLoader.load('foo')
         *         .then(() => stateService.target('foo'));
         *   }
         * });
         * ```
         *
         * @param {function} callback invoked when the toState is invalid
         *   This function receives the (invalid) toState, the fromState, and an injector.
         *   The function may optionally return a [[TargetState]] or a Promise for a TargetState.
         *   If one is returned, it is treated as a redirect.
         *
         * @returns a function which deregisters the callback
         */
        StateService.prototype.onInvalid = function (callback) {
            this.invalidCallbacks.push(callback);
            return function deregisterListener() {
                removeFrom(this.invalidCallbacks)(callback);
            }.bind(this);
        };
        /**
         * Reloads the current state
         *
         * A method that force reloads the current state, or a partial state hierarchy.
         * All resolves are re-resolved, and components reinstantiated.
         *
         * #### Example:
         * ```js
         * let app angular.module('app', ['ui.router']);
         *
         * app.controller('ctrl', function ($scope, $state) {
         *   $scope.reload = function(){
         *     $state.reload();
         *   }
         * });
         * ```
         *
         * Note: `reload()` is just an alias for:
         *
         * ```js
         * $state.transitionTo($state.current, $state.params, {
         *   reload: true, inherit: false
         * });
         * ```
         *
         * @param reloadState A state name or a state object.
         *    If present, this state and all its children will be reloaded, but ancestors will not reload.
         *
         * #### Example:
         * ```js
         * //assuming app application consists of 3 states: 'contacts', 'contacts.detail', 'contacts.detail.item'
         * //and current state is 'contacts.detail.item'
         * let app angular.module('app', ['ui.router']);
         *
         * app.controller('ctrl', function ($scope, $state) {
         *   $scope.reload = function(){
         *     //will reload 'contact.detail' and nested 'contact.detail.item' states
         *     $state.reload('contact.detail');
         *   }
         * });
         * ```
         *
         * @returns A promise representing the state of the new transition. See [[StateService.go]]
         */
        StateService.prototype.reload = function (reloadState) {
            return this.transitionTo(this.current, this.params, {
                reload: isDefined(reloadState) ? reloadState : true,
                inherit: false,
                notify: false,
            });
        };
        /**
         * Transition to a different state and/or parameters
         *
         * Convenience method for transitioning to a new state.
         *
         * `$state.go` calls `$state.transitionTo` internally but automatically sets options to
         * `{ location: true, inherit: true, relative: router.globals.$current, notify: true }`.
         * This allows you to use either an absolute or relative `to` argument (because of `relative: router.globals.$current`).
         * It also allows you to specify * only the parameters you'd like to update, while letting unspecified parameters
         * inherit from the current parameter values (because of `inherit: true`).
         *
         * #### Example:
         * ```js
         * let app = angular.module('app', ['ui.router']);
         *
         * app.controller('ctrl', function ($scope, $state) {
         *   $scope.changeState = function () {
         *     $state.go('contact.detail');
         *   };
         * });
         * ```
         *
         * @param to Absolute state name, state object, or relative state path (relative to current state).
         *
         * Some examples:
         *
         * - `$state.go('contact.detail')` - will go to the `contact.detail` state
         * - `$state.go('^')` - will go to the parent state
         * - `$state.go('^.sibling')` - if current state is `home.child`, will go to the `home.sibling` state
         * - `$state.go('.child.grandchild')` - if current state is home, will go to the `home.child.grandchild` state
         *
         * @param params A map of the parameters that will be sent to the state, will populate $stateParams.
         *
         *    Any parameters that are not specified will be inherited from current parameter values (because of `inherit: true`).
         *    This allows, for example, going to a sibling state that shares parameters defined by a parent state.
         *
         * @param options Transition options
         *
         * @returns {promise} A promise representing the state of the new transition.
         */
        StateService.prototype.go = function (to, params, options) {
            var defautGoOpts = { relative: this.$current, inherit: true };
            var transOpts = defaults(options, defautGoOpts, defaultTransOpts);
            return this.transitionTo(to, params, transOpts);
        };
        /**
         * Creates a [[TargetState]]
         *
         * This is a factory method for creating a TargetState
         *
         * This may be returned from a Transition Hook to redirect a transition, for example.
         */
        StateService.prototype.target = function (identifier, params, options) {
            if (options === void 0) { options = {}; }
            // If we're reloading, find the state object to reload from
            if (isObject(options.reload) && !options.reload.name)
                throw new Error('Invalid reload state object');
            var reg = this.router.stateRegistry;
            options.reloadState =
                options.reload === true ? reg.root() : reg.matcher.find(options.reload, options.relative);
            if (options.reload && !options.reloadState)
                throw new Error("No such reload state '" + (isString(options.reload) ? options.reload : options.reload.name) + "'");
            return new TargetState(this.router.stateRegistry, identifier, params, options);
        };
        /** @internal */
        StateService.prototype.getCurrentPath = function () {
            var _this = this;
            var globals = this.router.globals;
            var latestSuccess = globals.successfulTransitions.peekTail();
            var rootPath = function () { return [new PathNode(_this.router.stateRegistry.root())]; };
            return latestSuccess ? latestSuccess.treeChanges().to : rootPath();
        };
        /**
         * Low-level method for transitioning to a new state.
         *
         * The [[go]] method (which uses `transitionTo` internally) is recommended in most situations.
         *
         * #### Example:
         * ```js
         * let app = angular.module('app', ['ui.router']);
         *
         * app.controller('ctrl', function ($scope, $state) {
         *   $scope.changeState = function () {
         *     $state.transitionTo('contact.detail');
         *   };
         * });
         * ```
         *
         * @param to State name or state object.
         * @param toParams A map of the parameters that will be sent to the state,
         *      will populate $stateParams.
         * @param options Transition options
         *
         * @returns A promise representing the state of the new transition. See [[go]]
         */
        StateService.prototype.transitionTo = function (to, toParams, options) {
            var _this = this;
            if (toParams === void 0) { toParams = {}; }
            if (options === void 0) { options = {}; }
            var router = this.router;
            var globals = router.globals;
            options = defaults(options, defaultTransOpts);
            var getCurrent = function () { return globals.transition; };
            options = extend(options, { current: getCurrent });
            var ref = this.target(to, toParams, options);
            var currentPath = this.getCurrentPath();
            if (!ref.exists())
                return this._handleInvalidTargetState(currentPath, ref);
            if (!ref.valid())
                return silentRejection(ref.error());
            if (options.supercede === false && getCurrent()) {
                return (Rejection.ignored('Another transition is in progress and supercede has been set to false in TransitionOptions for the transition. So the transition was ignored in favour of the existing one in progress.').toPromise());
            }
            /**
             * Special handling for Ignored, Aborted, and Redirected transitions
             *
             * The semantics for the transition.run() promise and the StateService.transitionTo()
             * promise differ. For instance, the run() promise may be rejected because it was
             * IGNORED, but the transitionTo() promise is resolved because from the user perspective
             * no error occurred.  Likewise, the transition.run() promise may be rejected because of
             * a Redirect, but the transitionTo() promise is chained to the new Transition's promise.
             */
            var rejectedTransitionHandler = function (trans) { return function (error) {
                if (error instanceof Rejection) {
                    var isLatest = router.globals.lastStartedTransitionId <= trans.$id;
                    if (error.type === exports.RejectType.IGNORED) {
                        isLatest && router.urlRouter.update();
                        // Consider ignored `Transition.run()` as a successful `transitionTo`
                        return services.$q.when(globals.current);
                    }
                    var detail = error.detail;
                    if (error.type === exports.RejectType.SUPERSEDED && error.redirected && detail instanceof TargetState) {
                        // If `Transition.run()` was redirected, allow the `transitionTo()` promise to resolve successfully
                        // by returning the promise for the new (redirect) `Transition.run()`.
                        var redirect = trans.redirect(detail);
                        return redirect.run().catch(rejectedTransitionHandler(redirect));
                    }
                    if (error.type === exports.RejectType.ABORTED) {
                        isLatest && router.urlRouter.update();
                        return services.$q.reject(error);
                    }
                }
                var errorHandler = _this.defaultErrorHandler();
                errorHandler(error);
                return services.$q.reject(error);
            }; };
            var transition = this.router.transitionService.create(currentPath, ref);
            var transitionToPromise = transition.run().catch(rejectedTransitionHandler(transition));
            silenceUncaughtInPromise(transitionToPromise); // issue #2676
            // Return a promise for the transition, which also has the transition object on it.
            return extend(transitionToPromise, { transition: transition });
        };
        /**
         * Checks if the current state *is* the provided state
         *
         * Similar to [[includes]] but only checks for the full state name.
         * If params is supplied then it will be tested for strict equality against the current
         * active params object, so all params must match with none missing and no extras.
         *
         * #### Example:
         * ```js
         * $state.$current.name = 'contacts.details.item';
         *
         * // absolute name
         * $state.is('contact.details.item'); // returns true
         * $state.is(contactDetailItemStateObject); // returns true
         * ```
         *
         * // relative name (. and ^), typically from a template
         * // E.g. from the 'contacts.details' template
         * ```html
         * <div ng-class="{highlighted: $state.is('.item')}">Item</div>
         * ```
         *
         * @param stateOrName The state name (absolute or relative) or state object you'd like to check.
         * @param params A param object, e.g. `{sectionId: section.id}`, that you'd like
         * to test against the current active state.
         * @param options An options object. The options are:
         *   - `relative`: If `stateOrName` is a relative state name and `options.relative` is set, .is will
         *     test relative to `options.relative` state (or name).
         *
         * @returns Returns true if it is the state.
         */
        StateService.prototype.is = function (stateOrName, params, options) {
            options = defaults(options, { relative: this.$current });
            var state = this.router.stateRegistry.matcher.find(stateOrName, options.relative);
            if (!isDefined(state))
                return undefined;
            if (this.$current !== state)
                return false;
            if (!params)
                return true;
            var schema = state.parameters({ inherit: true, matchingKeys: params });
            return Param.equals(schema, Param.values(schema, params), this.params);
        };
        /**
         * Checks if the current state *includes* the provided state
         *
         * A method to determine if the current active state is equal to or is the child of the
         * state stateName. If any params are passed then they will be tested for a match as well.
         * Not all the parameters need to be passed, just the ones you'd like to test for equality.
         *
         * #### Example when `$state.$current.name === 'contacts.details.item'`
         * ```js
         * // Using partial names
         * $state.includes("contacts"); // returns true
         * $state.includes("contacts.details"); // returns true
         * $state.includes("contacts.details.item"); // returns true
         * $state.includes("contacts.list"); // returns false
         * $state.includes("about"); // returns false
         * ```
         *
         * #### Glob Examples when `* $state.$current.name === 'contacts.details.item.url'`:
         * ```js
         * $state.includes("*.details.*.*"); // returns true
         * $state.includes("*.details.**"); // returns true
         * $state.includes("**.item.**"); // returns true
         * $state.includes("*.details.item.url"); // returns true
         * $state.includes("*.details.*.url"); // returns true
         * $state.includes("*.details.*"); // returns false
         * $state.includes("item.**"); // returns false
         * ```
         *
         * @param stateOrName A partial name, relative name, glob pattern,
         *   or state object to be searched for within the current state name.
         * @param params A param object, e.g. `{sectionId: section.id}`,
         *   that you'd like to test against the current active state.
         * @param options An options object. The options are:
         *   - `relative`: If `stateOrName` is a relative state name and `options.relative` is set, .is will
         *     test relative to `options.relative` state (or name).
         *
         * @returns {boolean} Returns true if it does include the state
         */
        StateService.prototype.includes = function (stateOrName, params, options) {
            options = defaults(options, { relative: this.$current });
            var glob = isString(stateOrName) && Glob.fromString(stateOrName);
            if (glob) {
                if (!glob.matches(this.$current.name))
                    return false;
                stateOrName = this.$current.name;
            }
            var state = this.router.stateRegistry.matcher.find(stateOrName, options.relative), include = this.$current.includes;
            if (!isDefined(state))
                return undefined;
            if (!isDefined(include[state.name]))
                return false;
            if (!params)
                return true;
            var schema = state.parameters({ inherit: true, matchingKeys: params });
            return Param.equals(schema, Param.values(schema, params), this.params);
        };
        /**
         * Generates a URL for a state and parameters
         *
         * Returns the url for the given state populated with the given params.
         *
         * #### Example:
         * ```js
         * expect($state.href("about.person", { person: "bob" })).toEqual("/about/bob");
         * ```
         *
         * @param stateOrName The state name or state object you'd like to generate a url from.
         * @param params An object of parameter values to fill the state's required parameters.
         * @param options Options object. The options are:
         *
         * @returns {string} compiled state url
         */
        StateService.prototype.href = function (stateOrName, params, options) {
            var defaultHrefOpts = {
                lossy: true,
                inherit: true,
                absolute: false,
                relative: this.$current,
            };
            options = defaults(options, defaultHrefOpts);
            params = params || {};
            var state = this.router.stateRegistry.matcher.find(stateOrName, options.relative);
            if (!isDefined(state))
                return null;
            if (options.inherit)
                params = this.params.$inherit(params, this.$current, state);
            var nav = state && options.lossy ? state.navigable : state;
            if (!nav || nav.url === undefined || nav.url === null) {
                return null;
            }
            return this.router.urlRouter.href(nav.url, params, { absolute: options.absolute });
        };
        /**
         * Sets or gets the default [[transitionTo]] error handler.
         *
         * The error handler is called when a [[Transition]] is rejected or when any error occurred during the Transition.
         * This includes errors caused by resolves and transition hooks.
         *
         * Note:
         * This handler does not receive certain Transition rejections.
         * Redirected and Ignored Transitions are not considered to be errors by [[StateService.transitionTo]].
         *
         * The built-in default error handler logs the error to the console.
         *
         * You can provide your own custom handler.
         *
         * #### Example:
         * ```js
         * stateService.defaultErrorHandler(function() {
         *   // Do not log transitionTo errors
         * });
         * ```
         *
         * @param handler a global error handler function
         * @returns the current global error handler
         */
        StateService.prototype.defaultErrorHandler = function (handler) {
            return (this._defaultErrorHandler = handler || this._defaultErrorHandler);
        };
        StateService.prototype.get = function (stateOrName, base) {
            var reg = this.router.stateRegistry;
            if (arguments.length === 0)
                return reg.get();
            return reg.get(stateOrName, base || this.$current);
        };
        /**
         * Lazy loads a state
         *
         * Explicitly runs a state's [[StateDeclaration.lazyLoad]] function.
         *
         * @param stateOrName the state that should be lazy loaded
         * @param transition the optional Transition context to use (if the lazyLoad function requires an injector, etc)
         * Note: If no transition is provided, a noop transition is created using the from the current state to the current state.
         * This noop transition is not actually run.
         *
         * @returns a promise to lazy load
         */
        StateService.prototype.lazyLoad = function (stateOrName, transition) {
            var state = this.get(stateOrName);
            if (!state || !state.lazyLoad)
                throw new Error('Can not lazy load ' + stateOrName);
            var currentPath = this.getCurrentPath();
            var target = PathUtils.makeTargetState(this.router.stateRegistry, currentPath);
            transition = transition || this.router.transitionService.create(currentPath, target);
            return lazyLoadState(transition, state);
        };
        return StateService;
    }());

    /**
     * An angular1-like promise api
     *
     * This object implements four methods similar to the
     * [angular 1 promise api](https://docs.angularjs.org/api/ng/service/$q)
     *
     * UI-Router evolved from an angular 1 library to a framework agnostic library.
     * However, some of the `@uirouter/core` code uses these ng1 style APIs to support ng1 style dependency injection.
     *
     * This API provides native ES6 promise support wrapped as a $q-like API.
     * Internally, UI-Router uses this $q object to perform promise operations.
     * The `angular-ui-router` (ui-router for angular 1) uses the $q API provided by angular.
     *
     * $q-like promise api
     */
    var $q = {
        /** Normalizes a value as a promise */
        when: function (val) { return new Promise(function (resolve, reject) { return resolve(val); }); },
        /** Normalizes a value as a promise rejection */
        reject: function (val) {
            return new Promise(function (resolve, reject) {
                reject(val);
            });
        },
        /** @returns a deferred object, which has `resolve` and `reject` functions */
        defer: function () {
            var deferred = {};
            deferred.promise = new Promise(function (resolve, reject) {
                deferred.resolve = resolve;
                deferred.reject = reject;
            });
            return deferred;
        },
        /** Like Promise.all(), but also supports object key/promise notation like $q */
        all: function (promises) {
            if (isArray(promises)) {
                return Promise.all(promises);
            }
            if (isObject(promises)) {
                // Convert promises map to promises array.
                // When each promise resolves, map it to a tuple { key: key, val: val }
                var chain = Object.keys(promises).map(function (key) { return promises[key].then(function (val) { return ({ key: key, val: val }); }); });
                // Then wait for all promises to resolve, and convert them back to an object
                return $q.all(chain).then(function (values) {
                    return values.reduce(function (acc, tuple) {
                        acc[tuple.key] = tuple.val;
                        return acc;
                    }, {});
                });
            }
        },
    };

    // globally available injectables
    var globals = {};
    var STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/gm;
    var ARGUMENT_NAMES = /([^\s,]+)/g;
    /**
     * A basic angular1-like injector api
     *
     * This object implements four methods similar to the
     * [angular 1 dependency injector](https://docs.angularjs.org/api/auto/service/$injector)
     *
     * UI-Router evolved from an angular 1 library to a framework agnostic library.
     * However, some of the `@uirouter/core` code uses these ng1 style APIs to support ng1 style dependency injection.
     *
     * This object provides a naive implementation of a globally scoped dependency injection system.
     * It supports the following DI approaches:
     *
     * ### Function parameter names
     *
     * A function's `.toString()` is called, and the parameter names are parsed.
     * This only works when the parameter names aren't "mangled" by a minifier such as UglifyJS.
     *
     * ```js
     * function injectedFunction(FooService, BarService) {
     *   // FooService and BarService are injected
     * }
     * ```
     *
     * ### Function annotation
     *
     * A function may be annotated with an array of dependency names as the `$inject` property.
     *
     * ```js
     * injectedFunction.$inject = [ 'FooService', 'BarService' ];
     * function injectedFunction(fs, bs) {
     *   // FooService and BarService are injected as fs and bs parameters
     * }
     * ```
     *
     * ### Array notation
     *
     * An array provides the names of the dependencies to inject (as strings).
     * The function is the last element of the array.
     *
     * ```js
     * [ 'FooService', 'BarService', function (fs, bs) {
     *   // FooService and BarService are injected as fs and bs parameters
     * }]
     * ```
     *
     * @type {$InjectorLike}
     */
    var $injector = {
        /** Gets an object from DI based on a string token */
        get: function (name) { return globals[name]; },
        /** Returns true if an object named `name` exists in global DI */
        has: function (name) { return $injector.get(name) != null; },
        /**
         * Injects a function
         *
         * @param fn the function to inject
         * @param context the function's `this` binding
         * @param locals An object with additional DI tokens and values, such as `{ someToken: { foo: 1 } }`
         */
        invoke: function (fn, context, locals) {
            var all = extend({}, globals, locals || {});
            var params = $injector.annotate(fn);
            var ensureExist = assertPredicate(function (key) { return all.hasOwnProperty(key); }, function (key) { return "DI can't find injectable: '" + key + "'"; });
            var args = params.filter(ensureExist).map(function (x) { return all[x]; });
            if (isFunction(fn))
                return fn.apply(context, args);
            else
                return fn.slice(-1)[0].apply(context, args);
        },
        /**
         * Returns a function's dependencies
         *
         * Analyzes a function (or array) and returns an array of DI tokens that the function requires.
         * @return an array of `string`s
         */
        annotate: function (fn) {
            if (!isInjectable(fn))
                throw new Error("Not an injectable function: " + fn);
            if (fn && fn.$inject)
                return fn.$inject;
            if (isArray(fn))
                return fn.slice(0, -1);
            var fnStr = fn.toString().replace(STRIP_COMMENTS, '');
            var result = fnStr.slice(fnStr.indexOf('(') + 1, fnStr.indexOf(')')).match(ARGUMENT_NAMES);
            return result || [];
        },
    };

    var keyValsToObjectR = function (accum, _a) {
        var key = _a[0], val = _a[1];
        if (!accum.hasOwnProperty(key)) {
            accum[key] = val;
        }
        else if (isArray(accum[key])) {
            accum[key].push(val);
        }
        else {
            accum[key] = [accum[key], val];
        }
        return accum;
    };
    var getParams = function (queryString) {
        return queryString.split('&').filter(identity).map(splitEqual).reduce(keyValsToObjectR, {});
    };
    function parseUrl$1(url) {
        var orEmptyString = function (x) { return x || ''; };
        var _a = splitHash(url).map(orEmptyString), beforehash = _a[0], hash = _a[1];
        var _b = splitQuery(beforehash).map(orEmptyString), path = _b[0], search = _b[1];
        return { path: path, search: search, hash: hash, url: url };
    }
    var buildUrl = function (loc) {
        var path = loc.path();
        var searchObject = loc.search();
        var hash = loc.hash();
        var search = Object.keys(searchObject)
            .map(function (key) {
            var param = searchObject[key];
            var vals = isArray(param) ? param : [param];
            return vals.map(function (val) { return key + '=' + val; });
        })
            .reduce(unnestR, [])
            .join('&');
        return path + (search ? '?' + search : '') + (hash ? '#' + hash : '');
    };
    function locationPluginFactory(name, isHtml5, serviceClass, configurationClass) {
        return function (uiRouter) {
            var service = (uiRouter.locationService = new serviceClass(uiRouter));
            var configuration = (uiRouter.locationConfig = new configurationClass(uiRouter, isHtml5));
            function dispose(router) {
                router.dispose(service);
                router.dispose(configuration);
            }
            return { name: name, service: service, configuration: configuration, dispose: dispose };
        };
    }

    /** A base `LocationServices` */
    var BaseLocationServices = /** @class */ (function () {
        function BaseLocationServices(router, fireAfterUpdate) {
            var _this = this;
            this.fireAfterUpdate = fireAfterUpdate;
            this._listeners = [];
            this._listener = function (evt) { return _this._listeners.forEach(function (cb) { return cb(evt); }); };
            this.hash = function () { return parseUrl$1(_this._get()).hash; };
            this.path = function () { return parseUrl$1(_this._get()).path; };
            this.search = function () { return getParams(parseUrl$1(_this._get()).search); };
            this._location = root.location;
            this._history = root.history;
        }
        BaseLocationServices.prototype.url = function (url, replace) {
            if (replace === void 0) { replace = true; }
            if (isDefined(url) && url !== this._get()) {
                this._set(null, null, url, replace);
                if (this.fireAfterUpdate) {
                    this._listeners.forEach(function (cb) { return cb({ url: url }); });
                }
            }
            return buildUrl(this);
        };
        BaseLocationServices.prototype.onChange = function (cb) {
            var _this = this;
            this._listeners.push(cb);
            return function () { return removeFrom(_this._listeners, cb); };
        };
        BaseLocationServices.prototype.dispose = function (router) {
            deregAll(this._listeners);
        };
        return BaseLocationServices;
    }());

    var __extends = (undefined && undefined.__extends) || (function () {
        var extendStatics = function (d, b) {
            extendStatics = Object.setPrototypeOf ||
                ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
                function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
            return extendStatics(d, b);
        };
        return function (d, b) {
            extendStatics(d, b);
            function __() { this.constructor = d; }
            d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
        };
    })();
    /** A `LocationServices` that uses the browser hash "#" to get/set the current location */
    var HashLocationService = /** @class */ (function (_super) {
        __extends(HashLocationService, _super);
        function HashLocationService(router) {
            var _this = _super.call(this, router, false) || this;
            root.addEventListener('hashchange', _this._listener, false);
            return _this;
        }
        HashLocationService.prototype._get = function () {
            return trimHashVal(this._location.hash);
        };
        HashLocationService.prototype._set = function (state, title, url, replace) {
            this._location.hash = url;
        };
        HashLocationService.prototype.dispose = function (router) {
            _super.prototype.dispose.call(this, router);
            root.removeEventListener('hashchange', this._listener);
        };
        return HashLocationService;
    }(BaseLocationServices));

    var __extends$1 = (undefined && undefined.__extends) || (function () {
        var extendStatics = function (d, b) {
            extendStatics = Object.setPrototypeOf ||
                ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
                function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
            return extendStatics(d, b);
        };
        return function (d, b) {
            extendStatics(d, b);
            function __() { this.constructor = d; }
            d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
        };
    })();
    /** A `LocationServices` that gets/sets the current location from an in-memory object */
    var MemoryLocationService = /** @class */ (function (_super) {
        __extends$1(MemoryLocationService, _super);
        function MemoryLocationService(router) {
            return _super.call(this, router, true) || this;
        }
        MemoryLocationService.prototype._get = function () {
            return this._url;
        };
        MemoryLocationService.prototype._set = function (state, title, url, replace) {
            this._url = url;
        };
        return MemoryLocationService;
    }(BaseLocationServices));

    var __extends$2 = (undefined && undefined.__extends) || (function () {
        var extendStatics = function (d, b) {
            extendStatics = Object.setPrototypeOf ||
                ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
                function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
            return extendStatics(d, b);
        };
        return function (d, b) {
            extendStatics(d, b);
            function __() { this.constructor = d; }
            d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
        };
    })();
    /**
     * A `LocationServices` that gets/sets the current location using the browser's `location` and `history` apis
     *
     * Uses `history.pushState` and `history.replaceState`
     */
    var PushStateLocationService = /** @class */ (function (_super) {
        __extends$2(PushStateLocationService, _super);
        function PushStateLocationService(router) {
            var _this = _super.call(this, router, true) || this;
            _this._config = router.urlService.config;
            root.addEventListener('popstate', _this._listener, false);
            return _this;
        }
        /**
         * Gets the base prefix without:
         * - trailing slash
         * - trailing filename
         * - protocol and hostname
         *
         * If <base href='/base/'>, this returns '/base'.
         * If <base href='/foo/base/'>, this returns '/foo/base'.
         * If <base href='/base/index.html'>, this returns '/base'.
         * If <base href='http://localhost:8080/base/index.html'>, this returns '/base'.
         * If <base href='/base'>, this returns ''.
         * If <base href='http://localhost:8080'>, this returns ''.
         * If <base href='http://localhost:8080/'>, this returns ''.
         *
         * See: https://html.spec.whatwg.org/dev/semantics.html#the-base-element
         */
        PushStateLocationService.prototype._getBasePrefix = function () {
            return stripLastPathElement(this._config.baseHref());
        };
        PushStateLocationService.prototype._get = function () {
            var _a = this._location, pathname = _a.pathname, hash = _a.hash, search = _a.search;
            search = splitQuery(search)[1]; // strip ? if found
            hash = splitHash(hash)[1]; // strip # if found
            var basePrefix = this._getBasePrefix();
            var exactBaseHrefMatch = pathname === this._config.baseHref();
            var startsWithBase = pathname.substr(0, basePrefix.length) === basePrefix;
            pathname = exactBaseHrefMatch ? '/' : startsWithBase ? pathname.substring(basePrefix.length) : pathname;
            return pathname + (search ? '?' + search : '') + (hash ? '#' + hash : '');
        };
        PushStateLocationService.prototype._set = function (state, title, url, replace) {
            var basePrefix = this._getBasePrefix();
            var slash = url && url[0] !== '/' ? '/' : '';
            var fullUrl = url === '' || url === '/' ? this._config.baseHref() : basePrefix + slash + url;
            if (replace) {
                this._history.replaceState(state, title, fullUrl);
            }
            else {
                this._history.pushState(state, title, fullUrl);
            }
        };
        PushStateLocationService.prototype.dispose = function (router) {
            _super.prototype.dispose.call(this, router);
            root.removeEventListener('popstate', this._listener);
        };
        return PushStateLocationService;
    }(BaseLocationServices));

    /** A `LocationConfig` mock that gets/sets all config from an in-memory object */
    var MemoryLocationConfig = /** @class */ (function () {
        function MemoryLocationConfig() {
            var _this = this;
            this.dispose = noop;
            this._baseHref = '';
            this._port = 80;
            this._protocol = 'http';
            this._host = 'localhost';
            this._hashPrefix = '';
            this.port = function () { return _this._port; };
            this.protocol = function () { return _this._protocol; };
            this.host = function () { return _this._host; };
            this.baseHref = function () { return _this._baseHref; };
            this.html5Mode = function () { return false; };
            this.hashPrefix = function (newval) { return (isDefined(newval) ? (_this._hashPrefix = newval) : _this._hashPrefix); };
        }
        return MemoryLocationConfig;
    }());

    /** A `LocationConfig` that delegates to the browser's `location` object */
    var BrowserLocationConfig = /** @class */ (function () {
        function BrowserLocationConfig(router, _isHtml5) {
            if (_isHtml5 === void 0) { _isHtml5 = false; }
            this._isHtml5 = _isHtml5;
            this._baseHref = undefined;
            this._hashPrefix = '';
        }
        BrowserLocationConfig.prototype.port = function () {
            if (location.port) {
                return Number(location.port);
            }
            return this.protocol() === 'https' ? 443 : 80;
        };
        BrowserLocationConfig.prototype.protocol = function () {
            return location.protocol.replace(/:/g, '');
        };
        BrowserLocationConfig.prototype.host = function () {
            return location.hostname;
        };
        BrowserLocationConfig.prototype.html5Mode = function () {
            return this._isHtml5;
        };
        BrowserLocationConfig.prototype.hashPrefix = function (newprefix) {
            return isDefined(newprefix) ? (this._hashPrefix = newprefix) : this._hashPrefix;
        };
        BrowserLocationConfig.prototype.baseHref = function (href) {
            if (isDefined(href))
                this._baseHref = href;
            if (isUndefined(this._baseHref))
                this._baseHref = this.getBaseHref();
            return this._baseHref;
        };
        BrowserLocationConfig.prototype.getBaseHref = function () {
            var baseTag = document.getElementsByTagName('base')[0];
            if (baseTag && baseTag.href) {
                return baseTag.href.replace(/^([^/:]*:)?\/\/[^/]*/, '');
            }
            return this._isHtml5 ? '/' : location.pathname || '/';
        };
        BrowserLocationConfig.prototype.dispose = function () { };
        return BrowserLocationConfig;
    }());

    function servicesPlugin(router) {
        services.$injector = $injector;
        services.$q = $q;
        return { name: 'vanilla.services', $q: $q, $injector: $injector, dispose: function () { return null; } };
    }
    /** A `UIRouterPlugin` uses the browser hash to get/set the current location */
    var hashLocationPlugin = locationPluginFactory('vanilla.hashBangLocation', false, HashLocationService, BrowserLocationConfig);
    /** A `UIRouterPlugin` that gets/sets the current location using the browser's `location` and `history` apis */
    var pushStateLocationPlugin = locationPluginFactory('vanilla.pushStateLocation', true, PushStateLocationService, BrowserLocationConfig);
    /** A `UIRouterPlugin` that gets/sets the current location from an in-memory object */
    var memoryLocationPlugin = locationPluginFactory('vanilla.memoryLocation', false, MemoryLocationService, MemoryLocationConfig);

    var UIRouterPluginBase = /** @class */ (function () {
        function UIRouterPluginBase() {
        }
        UIRouterPluginBase.prototype.dispose = function (router) { };
        return UIRouterPluginBase;
    }());

    var index = /*#__PURE__*/Object.freeze({
        __proto__: null,
        root: root,
        fromJson: fromJson,
        toJson: toJson,
        forEach: forEach,
        extend: extend,
        equals: equals,
        identity: identity,
        noop: noop,
        createProxyFunctions: createProxyFunctions,
        inherit: inherit,
        inArray: inArray,
        _inArray: _inArray,
        removeFrom: removeFrom,
        _removeFrom: _removeFrom,
        pushTo: pushTo,
        _pushTo: _pushTo,
        deregAll: deregAll,
        defaults: defaults,
        mergeR: mergeR,
        ancestors: ancestors,
        pick: pick,
        omit: omit,
        pluck: pluck,
        filter: filter,
        find: find,
        mapObj: mapObj,
        map: map,
        values: values,
        allTrueR: allTrueR,
        anyTrueR: anyTrueR,
        unnestR: unnestR,
        flattenR: flattenR,
        pushR: pushR,
        uniqR: uniqR,
        unnest: unnest,
        flatten: flatten,
        assertPredicate: assertPredicate,
        assertMap: assertMap,
        assertFn: assertFn,
        pairs: pairs,
        arrayTuples: arrayTuples,
        applyPairs: applyPairs,
        tail: tail,
        copy: copy,
        _extend: _extend,
        silenceUncaughtInPromise: silenceUncaughtInPromise,
        silentRejection: silentRejection,
        makeStub: makeStub,
        services: services,
        Glob: Glob,
        curry: curry,
        compose: compose,
        pipe: pipe,
        prop: prop,
        propEq: propEq,
        parse: parse,
        not: not,
        and: and,
        or: or,
        all: all,
        any: any,
        is: is,
        eq: eq,
        val: val,
        invoke: invoke,
        pattern: pattern,
        isUndefined: isUndefined,
        isDefined: isDefined,
        isNull: isNull,
        isNullOrUndefined: isNullOrUndefined,
        isFunction: isFunction,
        isNumber: isNumber,
        isString: isString,
        isObject: isObject,
        isArray: isArray,
        isDate: isDate,
        isRegExp: isRegExp,
        isInjectable: isInjectable,
        isPromise: isPromise,
        Queue: Queue,
        maxLength: maxLength,
        padString: padString,
        kebobString: kebobString,
        functionToString: functionToString,
        fnToString: fnToString,
        stringify: stringify,
        beforeAfterSubstr: beforeAfterSubstr,
        hostRegex: hostRegex,
        stripLastPathElement: stripLastPathElement,
        splitHash: splitHash,
        splitQuery: splitQuery,
        splitEqual: splitEqual,
        trimHashVal: trimHashVal,
        splitOnDelim: splitOnDelim,
        joinNeighborsR: joinNeighborsR,
        get Category () { return exports.Category; },
        Trace: Trace,
        trace: trace,
        get DefType () { return exports.DefType; },
        Param: Param,
        ParamTypes: ParamTypes,
        StateParams: StateParams,
        ParamType: ParamType,
        PathNode: PathNode,
        PathUtils: PathUtils,
        resolvePolicies: resolvePolicies,
        defaultResolvePolicy: defaultResolvePolicy,
        Resolvable: Resolvable,
        NATIVE_INJECTOR_TOKEN: NATIVE_INJECTOR_TOKEN,
        ResolveContext: ResolveContext,
        resolvablesBuilder: resolvablesBuilder,
        StateBuilder: StateBuilder,
        StateObject: StateObject,
        StateMatcher: StateMatcher,
        StateQueueManager: StateQueueManager,
        StateRegistry: StateRegistry,
        StateService: StateService,
        TargetState: TargetState,
        get TransitionHookPhase () { return exports.TransitionHookPhase; },
        get TransitionHookScope () { return exports.TransitionHookScope; },
        HookBuilder: HookBuilder,
        matchState: matchState,
        RegisteredHook: RegisteredHook,
        makeEvent: makeEvent,
        get RejectType () { return exports.RejectType; },
        Rejection: Rejection,
        Transition: Transition,
        TransitionHook: TransitionHook,
        TransitionEventType: TransitionEventType,
        defaultTransOpts: defaultTransOpts,
        TransitionService: TransitionService,
        UrlRules: UrlRules,
        UrlConfig: UrlConfig,
        UrlMatcher: UrlMatcher,
        ParamFactory: ParamFactory,
        UrlMatcherFactory: UrlMatcherFactory,
        UrlRouter: UrlRouter,
        UrlRuleFactory: UrlRuleFactory,
        BaseUrlRule: BaseUrlRule,
        UrlService: UrlService,
        ViewService: ViewService,
        UIRouterGlobals: UIRouterGlobals,
        UIRouter: UIRouter,
        $q: $q,
        $injector: $injector,
        BaseLocationServices: BaseLocationServices,
        HashLocationService: HashLocationService,
        MemoryLocationService: MemoryLocationService,
        PushStateLocationService: PushStateLocationService,
        MemoryLocationConfig: MemoryLocationConfig,
        BrowserLocationConfig: BrowserLocationConfig,
        keyValsToObjectR: keyValsToObjectR,
        getParams: getParams,
        parseUrl: parseUrl$1,
        buildUrl: buildUrl,
        locationPluginFactory: locationPluginFactory,
        servicesPlugin: servicesPlugin,
        hashLocationPlugin: hashLocationPlugin,
        pushStateLocationPlugin: pushStateLocationPlugin,
        memoryLocationPlugin: memoryLocationPlugin,
        UIRouterPluginBase: UIRouterPluginBase
    });

    /** @publicapi @module ng1 */ /** */
    /** @internalapi */
    function getNg1ViewConfigFactory() {
        var templateFactory = null;
        return function (path, view) {
            templateFactory = templateFactory || services.$injector.get('$templateFactory');
            return [new Ng1ViewConfig(path, view, templateFactory)];
        };
    }
    /** @internalapi */
    var hasAnyKey = function (keys, obj) { return keys.reduce(function (acc, key) { return acc || isDefined(obj[key]); }, false); };
    /**
     * This is a [[StateBuilder.builder]] function for angular1 `views`.
     *
     * When the [[StateBuilder]] builds a [[StateObject]] object from a raw [[StateDeclaration]], this builder
     * handles the `views` property with logic specific to @uirouter/angularjs (ng1).
     *
     * If no `views: {}` property exists on the [[StateDeclaration]], then it creates the `views` object
     * and applies the state-level configuration to a view named `$default`.
     *
     * @internalapi
     */
    function ng1ViewsBuilder(state) {
        // Do not process root state
        if (!state.parent)
            return {};
        var tplKeys = ['templateProvider', 'templateUrl', 'template', 'notify', 'async'], ctrlKeys = ['controller', 'controllerProvider', 'controllerAs', 'resolveAs'], compKeys = ['component', 'bindings', 'componentProvider'], nonCompKeys = tplKeys.concat(ctrlKeys), allViewKeys = compKeys.concat(nonCompKeys);
        // Do not allow a state to have both state-level props and also a `views: {}` property.
        // A state without a `views: {}` property can declare properties for the `$default` view as properties of the state.
        // However, the `$default` approach should not be mixed with a separate `views: ` block.
        if (isDefined(state.views) && hasAnyKey(allViewKeys, state)) {
            throw new Error("State '" + state.name + "' has a 'views' object. " +
                "It cannot also have \"view properties\" at the state level.  " +
                "Move the following properties into a view (in the 'views' object): " +
                (" " + allViewKeys.filter(function (key) { return isDefined(state[key]); }).join(', ')));
        }
        var views = {}, viewsObject = state.views || { $default: pick(state, allViewKeys) };
        forEach(viewsObject, function (config, name) {
            // Account for views: { "": { template... } }
            name = name || '$default';
            // Account for views: { header: "headerComponent" }
            if (isString(config))
                config = { component: config };
            // Make a shallow copy of the config object
            config = extend({}, config);
            // Do not allow a view to mix props for component-style view with props for template/controller-style view
            if (hasAnyKey(compKeys, config) && hasAnyKey(nonCompKeys, config)) {
                throw new Error("Cannot combine: " + compKeys.join('|') + " with: " + nonCompKeys.join('|') + " in stateview: '" + name + "@" + state.name + "'");
            }
            config.resolveAs = config.resolveAs || '$resolve';
            config.$type = 'ng1';
            config.$context = state;
            config.$name = name;
            var normalized = ViewService.normalizeUIViewTarget(config.$context, config.$name);
            config.$uiViewName = normalized.uiViewName;
            config.$uiViewContextAnchor = normalized.uiViewContextAnchor;
            views[name] = config;
        });
        return views;
    }
    /** @hidden */
    var id$1 = 0;
    /** @internalapi */
    var Ng1ViewConfig = /** @class */ (function () {
        function Ng1ViewConfig(path, viewDecl, factory) {
            var _this = this;
            this.path = path;
            this.viewDecl = viewDecl;
            this.factory = factory;
            this.$id = id$1++;
            this.loaded = false;
            this.getTemplate = function (uiView, context) {
                return _this.component
                    ? _this.factory.makeComponentTemplate(uiView, context, _this.component, _this.viewDecl.bindings)
                    : _this.template;
            };
        }
        Ng1ViewConfig.prototype.load = function () {
            var _this = this;
            var $q = services.$q;
            var context = new ResolveContext(this.path);
            var params = this.path.reduce(function (acc, node) { return extend(acc, node.paramValues); }, {});
            var promises = {
                template: $q.when(this.factory.fromConfig(this.viewDecl, params, context)),
                controller: $q.when(this.getController(context)),
            };
            return $q.all(promises).then(function (results) {
                trace.traceViewServiceEvent('Loaded', _this);
                _this.controller = results.controller;
                extend(_this, results.template); // Either { template: "tpl" } or { component: "cmpName" }
                return _this;
            });
        };
        /**
         * Gets the controller for a view configuration.
         *
         * @returns {Function|Promise.<Function>} Returns a controller, or a promise that resolves to a controller.
         */
        Ng1ViewConfig.prototype.getController = function (context) {
            var provider = this.viewDecl.controllerProvider;
            if (!isInjectable(provider))
                return this.viewDecl.controller;
            var deps = services.$injector.annotate(provider);
            var providerFn = isArray(provider) ? tail(provider) : provider;
            var resolvable = new Resolvable('', providerFn, deps);
            return resolvable.get(context);
        };
        return Ng1ViewConfig;
    }());

    /** @publicapi @module view */ /** */
    /**
     * Service which manages loading of templates from a ViewConfig.
     */
    var TemplateFactory = /** @class */ (function () {
        function TemplateFactory() {
            var _this = this;
            /** @hidden */ this._useHttp = ng.version.minor < 3;
            /** @hidden */ this.$get = [
                '$http',
                '$templateCache',
                '$injector',
                function ($http, $templateCache, $injector) {
                    _this.$templateRequest = $injector.has && $injector.has('$templateRequest') && $injector.get('$templateRequest');
                    _this.$http = $http;
                    _this.$templateCache = $templateCache;
                    return _this;
                },
            ];
        }
        /** @hidden */
        TemplateFactory.prototype.useHttpService = function (value) {
            this._useHttp = value;
        };
        /**
         * Creates a template from a configuration object.
         *
         * @param config Configuration object for which to load a template.
         * The following properties are search in the specified order, and the first one
         * that is defined is used to create the template:
         *
         * @param params  Parameters to pass to the template function.
         * @param context The resolve context associated with the template's view
         *
         * @return {string|object}  The template html as a string, or a promise for
         * that string,or `null` if no template is configured.
         */
        TemplateFactory.prototype.fromConfig = function (config, params, context) {
            var defaultTemplate = '<ui-view></ui-view>';
            var asTemplate = function (result) { return services.$q.when(result).then(function (str) { return ({ template: str }); }); };
            var asComponent = function (result) { return services.$q.when(result).then(function (str) { return ({ component: str }); }); };
            return isDefined(config.template)
                ? asTemplate(this.fromString(config.template, params))
                : isDefined(config.templateUrl)
                    ? asTemplate(this.fromUrl(config.templateUrl, params))
                    : isDefined(config.templateProvider)
                        ? asTemplate(this.fromProvider(config.templateProvider, params, context))
                        : isDefined(config.component)
                            ? asComponent(config.component)
                            : isDefined(config.componentProvider)
                                ? asComponent(this.fromComponentProvider(config.componentProvider, params, context))
                                : asTemplate(defaultTemplate);
        };
        /**
         * Creates a template from a string or a function returning a string.
         *
         * @param template html template as a string or function that returns an html template as a string.
         * @param params Parameters to pass to the template function.
         *
         * @return {string|object} The template html as a string, or a promise for that
         * string.
         */
        TemplateFactory.prototype.fromString = function (template, params) {
            return isFunction(template) ? template(params) : template;
        };
        /**
         * Loads a template from the a URL via `$http` and `$templateCache`.
         *
         * @param {string|Function} url url of the template to load, or a function
         * that returns a url.
         * @param {Object} params Parameters to pass to the url function.
         * @return {string|Promise.<string>} The template html as a string, or a promise
         * for that string.
         */
        TemplateFactory.prototype.fromUrl = function (url, params) {
            if (isFunction(url))
                url = url(params);
            if (url == null)
                return null;
            if (this._useHttp) {
                return this.$http
                    .get(url, { cache: this.$templateCache, headers: { Accept: 'text/html' } })
                    .then(function (response) {
                    return response.data;
                });
            }
            return this.$templateRequest(url);
        };
        /**
         * Creates a template by invoking an injectable provider function.
         *
         * @param provider Function to invoke via `locals`
         * @param {Function} injectFn a function used to invoke the template provider
         * @return {string|Promise.<string>} The template html as a string, or a promise
         * for that string.
         */
        TemplateFactory.prototype.fromProvider = function (provider, params, context) {
            var deps = services.$injector.annotate(provider);
            var providerFn = isArray(provider) ? tail(provider) : provider;
            var resolvable = new Resolvable('', providerFn, deps);
            return resolvable.get(context);
        };
        /**
         * Creates a component's template by invoking an injectable provider function.
         *
         * @param provider Function to invoke via `locals`
         * @param {Function} injectFn a function used to invoke the template provider
         * @return {string} The template html as a string: "<component-name input1='::$resolve.foo'></component-name>".
         */
        TemplateFactory.prototype.fromComponentProvider = function (provider, params, context) {
            var deps = services.$injector.annotate(provider);
            var providerFn = isArray(provider) ? tail(provider) : provider;
            var resolvable = new Resolvable('', providerFn, deps);
            return resolvable.get(context);
        };
        /**
         * Creates a template from a component's name
         *
         * This implements route-to-component.
         * It works by retrieving the component (directive) metadata from the injector.
         * It analyses the component's bindings, then constructs a template that instantiates the component.
         * The template wires input and output bindings to resolves or from the parent component.
         *
         * @param uiView {object} The parent ui-view (for binding outputs to callbacks)
         * @param context The ResolveContext (for binding outputs to callbacks returned from resolves)
         * @param component {string} Component's name in camel case.
         * @param bindings An object defining the component's bindings: {foo: '<'}
         * @return {string} The template as a string: "<component-name input1='::$resolve.foo'></component-name>".
         */
        TemplateFactory.prototype.makeComponentTemplate = function (uiView, context, component, bindings) {
            bindings = bindings || {};
            // Bind once prefix
            var prefix = ng.version.minor >= 3 ? '::' : '';
            // Convert to kebob name. Add x- prefix if the string starts with `x-` or `data-`
            var kebob = function (camelCase) {
                var kebobed = kebobString(camelCase);
                return /^(x|data)-/.exec(kebobed) ? "x-" + kebobed : kebobed;
            };
            var attributeTpl = function (input) {
                var name = input.name, type = input.type;
                var attrName = kebob(name);
                // If the ui-view has an attribute which matches a binding on the routed component
                // then pass that attribute through to the routed component template.
                // Prefer ui-view wired mappings to resolve data, unless the resolve was explicitly bound using `bindings:`
                if (uiView.attr(attrName) && !bindings[name])
                    return attrName + "='" + uiView.attr(attrName) + "'";
                var resolveName = bindings[name] || name;
                // Pre-evaluate the expression for "@" bindings by enclosing in {{ }}
                // some-attr="{{ ::$resolve.someResolveName }}"
                if (type === '@')
                    return attrName + "='{{" + prefix + "$resolve." + resolveName + "}}'";
                // Wire "&" callbacks to resolves that return a callback function
                // Get the result of the resolve (should be a function) and annotate it to get its arguments.
                // some-attr="$resolve.someResolveResultName(foo, bar)"
                if (type === '&') {
                    var res = context.getResolvable(resolveName);
                    var fn = res && res.data;
                    var args = (fn && services.$injector.annotate(fn)) || [];
                    // account for array style injection, i.e., ['foo', function(foo) {}]
                    var arrayIdxStr = isArray(fn) ? "[" + (fn.length - 1) + "]" : '';
                    return attrName + "='$resolve." + resolveName + arrayIdxStr + "(" + args.join(',') + ")'";
                }
                // some-attr="::$resolve.someResolveName"
                return attrName + "='" + prefix + "$resolve." + resolveName + "'";
            };
            var attrs = getComponentBindings(component).map(attributeTpl).join(' ');
            var kebobName = kebob(component);
            return "<" + kebobName + " " + attrs + "></" + kebobName + ">";
        };
        return TemplateFactory;
    }());
    // Gets all the directive(s)' inputs ('@', '=', and '<') and outputs ('&')
    function getComponentBindings(name) {
        var cmpDefs = services.$injector.get(name + 'Directive'); // could be multiple
        if (!cmpDefs || !cmpDefs.length)
            throw new Error("Unable to find component named '" + name + "'");
        return cmpDefs.map(getBindings).reduce(unnestR, []);
    }
    // Given a directive definition, find its object input attributes
    // Use different properties, depending on the type of directive (component, bindToController, normal)
    var getBindings = function (def) {
        if (isObject(def.bindToController))
            return scopeBindings(def.bindToController);
        return scopeBindings(def.scope);
    };
    // for ng 1.2 style, process the scope: { input: "=foo" }
    // for ng 1.3 through ng 1.5, process the component's bindToController: { input: "=foo" } object
    var scopeBindings = function (bindingsObj) {
        return Object.keys(bindingsObj || {})
            // [ 'input', [ '=foo', '=', 'foo' ] ]
            .map(function (key) { return [key, /^([=<@&])[?]?(.*)/.exec(bindingsObj[key])]; })
            // skip malformed values
            .filter(function (tuple) { return isDefined(tuple) && isArray(tuple[1]); })
            // { name: ('foo' || 'input'), type: '=' }
            .map(function (tuple) { return ({ name: tuple[1][2] || tuple[0], type: tuple[1][1] }); });
    };

    /** @publicapi @module ng1 */ /** */
    /**
     * The Angular 1 `StateProvider`
     *
     * The `$stateProvider` works similar to Angular's v1 router, but it focuses purely
     * on state.
     *
     * A state corresponds to a "place" in the application in terms of the overall UI and
     * navigation. A state describes (via the controller / template / view properties) what
     * the UI looks like and does at that place.
     *
     * States often have things in common, and the primary way of factoring out these
     * commonalities in this model is via the state hierarchy, i.e. parent/child states aka
     * nested states.
     *
     * The `$stateProvider` provides interfaces to declare these states for your app.
     */
    var StateProvider = /** @class */ (function () {
        function StateProvider(stateRegistry, stateService) {
            this.stateRegistry = stateRegistry;
            this.stateService = stateService;
            createProxyFunctions(val(StateProvider.prototype), this, val(this));
        }
        /**
         * Decorates states when they are registered
         *
         * Allows you to extend (carefully) or override (at your own peril) the
         * `stateBuilder` object used internally by [[StateRegistry]].
         * This can be used to add custom functionality to ui-router,
         * for example inferring templateUrl based on the state name.
         *
         * When passing only a name, it returns the current (original or decorated) builder
         * function that matches `name`.
         *
         * The builder functions that can be decorated are listed below. Though not all
         * necessarily have a good use case for decoration, that is up to you to decide.
         *
         * In addition, users can attach custom decorators, which will generate new
         * properties within the state's internal definition. There is currently no clear
         * use-case for this beyond accessing internal states (i.e. $state.$current),
         * however, expect this to become increasingly relevant as we introduce additional
         * meta-programming features.
         *
         * **Warning**: Decorators should not be interdependent because the order of
         * execution of the builder functions in non-deterministic. Builder functions
         * should only be dependent on the state definition object and super function.
         *
         *
         * Existing builder functions and current return values:
         *
         * - **parent** `{object}` - returns the parent state object.
         * - **data** `{object}` - returns state data, including any inherited data that is not
         *   overridden by own values (if any).
         * - **url** `{object}` - returns a {@link ui.router.util.type:UrlMatcher UrlMatcher}
         *   or `null`.
         * - **navigable** `{object}` - returns closest ancestor state that has a URL (aka is
         *   navigable).
         * - **params** `{object}` - returns an array of state params that are ensured to
         *   be a super-set of parent's params.
         * - **views** `{object}` - returns a views object where each key is an absolute view
         *   name (i.e. "viewName@stateName") and each value is the config object
         *   (template, controller) for the view. Even when you don't use the views object
         *   explicitly on a state config, one is still created for you internally.
         *   So by decorating this builder function you have access to decorating template
         *   and controller properties.
         * - **ownParams** `{object}` - returns an array of params that belong to the state,
         *   not including any params defined by ancestor states.
         * - **path** `{string}` - returns the full path from the root down to this state.
         *   Needed for state activation.
         * - **includes** `{object}` - returns an object that includes every state that
         *   would pass a `$state.includes()` test.
         *
         * #### Example:
         * Override the internal 'views' builder with a function that takes the state
         * definition, and a reference to the internal function being overridden:
         * ```js
         * $stateProvider.decorator('views', function (state, parent) {
         *   let result = {},
         *       views = parent(state);
         *
         *   angular.forEach(views, function (config, name) {
         *     let autoName = (state.name + '.' + name).replace('.', '/');
         *     config.templateUrl = config.templateUrl || '/partials/' + autoName + '.html';
         *     result[name] = config;
         *   });
         *   return result;
         * });
         *
         * $stateProvider.state('home', {
         *   views: {
         *     'contact.list': { controller: 'ListController' },
         *     'contact.item': { controller: 'ItemController' }
         *   }
         * });
         * ```
         *
         *
         * ```js
         * // Auto-populates list and item views with /partials/home/contact/list.html,
         * // and /partials/home/contact/item.html, respectively.
         * $state.go('home');
         * ```
         *
         * @param {string} name The name of the builder function to decorate.
         * @param {object} func A function that is responsible for decorating the original
         * builder function. The function receives two parameters:
         *
         *   - `{object}` - state - The state config object.
         *   - `{object}` - super - The original builder function.
         *
         * @return {object} $stateProvider - $stateProvider instance
         */
        StateProvider.prototype.decorator = function (name, func) {
            return this.stateRegistry.decorator(name, func) || this;
        };
        StateProvider.prototype.state = function (name, definition) {
            if (isObject(name)) {
                definition = name;
            }
            else {
                definition.name = name;
            }
            this.stateRegistry.register(definition);
            return this;
        };
        /**
         * Registers an invalid state handler
         *
         * This is a passthrough to [[StateService.onInvalid]] for ng1.
         */
        StateProvider.prototype.onInvalid = function (callback) {
            return this.stateService.onInvalid(callback);
        };
        return StateProvider;
    }());

    /** @publicapi @module ng1 */ /** */
    /**
     * This is a [[StateBuilder.builder]] function for angular1 `onEnter`, `onExit`,
     * `onRetain` callback hooks on a [[Ng1StateDeclaration]].
     *
     * When the [[StateBuilder]] builds a [[StateObject]] object from a raw [[StateDeclaration]], this builder
     * ensures that those hooks are injectable for @uirouter/angularjs (ng1).
     *
     * @internalapi
     */
    var getStateHookBuilder = function (hookName) {
        return function stateHookBuilder(stateObject) {
            var hook = stateObject[hookName];
            var pathname = hookName === 'onExit' ? 'from' : 'to';
            function decoratedNg1Hook(trans, state) {
                var resolveContext = new ResolveContext(trans.treeChanges(pathname));
                var subContext = resolveContext.subContext(state.$$state());
                var locals = extend(getLocals(subContext), { $state$: state, $transition$: trans });
                return services.$injector.invoke(hook, this, locals);
            }
            return hook ? decoratedNg1Hook : undefined;
        };
    };

    /** @publicapi @module ng1 */ /** */
    /**
     * Implements UI-Router LocationServices and LocationConfig using Angular 1's $location service
     * @internalapi
     */
    var Ng1LocationServices = /** @class */ (function () {
        function Ng1LocationServices($locationProvider) {
            // .onChange() registry
            this._urlListeners = [];
            this.$locationProvider = $locationProvider;
            var _lp = val($locationProvider);
            createProxyFunctions(_lp, this, _lp, ['hashPrefix']);
        }
        /**
         * Applys ng1-specific path parameter encoding
         *
         * The Angular 1 `$location` service is a bit weird.
         * It doesn't allow slashes to be encoded/decoded bi-directionally.
         *
         * See the writeup at https://github.com/angular-ui/ui-router/issues/2598
         *
         * This code patches the `path` parameter type so it encoded/decodes slashes as ~2F
         *
         * @param router
         */
        Ng1LocationServices.monkeyPatchPathParameterType = function (router) {
            var pathType = router.urlMatcherFactory.type('path');
            pathType.encode = function (x) {
                return x != null ? x.toString().replace(/(~|\/)/g, function (m) { return ({ '~': '~~', '/': '~2F' }[m]); }) : x;
            };
            pathType.decode = function (x) {
                return x != null ? x.toString().replace(/(~~|~2F)/g, function (m) { return ({ '~~': '~', '~2F': '/' }[m]); }) : x;
            };
        };
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        Ng1LocationServices.prototype.dispose = function () { };
        Ng1LocationServices.prototype.onChange = function (callback) {
            var _this = this;
            this._urlListeners.push(callback);
            return function () { return removeFrom(_this._urlListeners)(callback); };
        };
        Ng1LocationServices.prototype.html5Mode = function () {
            var html5Mode = this.$locationProvider.html5Mode();
            html5Mode = isObject(html5Mode) ? html5Mode.enabled : html5Mode;
            return html5Mode && this.$sniffer.history;
        };
        Ng1LocationServices.prototype.baseHref = function () {
            return this._baseHref || (this._baseHref = this.$browser.baseHref() || this.$window.location.pathname);
        };
        Ng1LocationServices.prototype.url = function (newUrl, replace, state) {
            if (replace === void 0) { replace = false; }
            if (isDefined(newUrl))
                this.$location.url(newUrl);
            if (replace)
                this.$location.replace();
            if (state)
                this.$location.state(state);
            return this.$location.url();
        };
        Ng1LocationServices.prototype._runtimeServices = function ($rootScope, $location, $sniffer, $browser, $window) {
            var _this = this;
            this.$location = $location;
            this.$sniffer = $sniffer;
            this.$browser = $browser;
            this.$window = $window;
            // Bind $locationChangeSuccess to the listeners registered in LocationService.onChange
            $rootScope.$on('$locationChangeSuccess', function (evt) { return _this._urlListeners.forEach(function (fn) { return fn(evt); }); });
            var _loc = val($location);
            // Bind these LocationService functions to $location
            createProxyFunctions(_loc, this, _loc, ['replace', 'path', 'search', 'hash']);
            // Bind these LocationConfig functions to $location
            createProxyFunctions(_loc, this, _loc, ['port', 'protocol', 'host']);
        };
        return Ng1LocationServices;
    }());

    /** @publicapi @module url */ /** */
    /**
     * Manages rules for client-side URL
     *
     * ### Deprecation warning:
     * This class is now considered to be an internal API
     * Use the [[UrlService]] instead.
     * For configuring URL rules, use the [[UrlRulesApi]] which can be found as [[UrlService.rules]].
     *
     * This class manages the router rules for what to do when the URL changes.
     *
     * This provider remains for backwards compatibility.
     *
     * @internalapi
     * @deprecated
     */
    var UrlRouterProvider = /** @class */ (function () {
        /** @hidden */
        function UrlRouterProvider(/** @hidden */ router) {
            this.router = router;
        }
        UrlRouterProvider.injectableHandler = function (router, handler) {
            return function (match) { return services.$injector.invoke(handler, null, { $match: match, $stateParams: router.globals.params }); };
        };
        /** @hidden */
        UrlRouterProvider.prototype.$get = function () {
            var urlService = this.router.urlService;
            this.router.urlRouter.update(true);
            if (!urlService.interceptDeferred)
                urlService.listen();
            return this.router.urlRouter;
        };
        /**
         * Registers a url handler function.
         *
         * Registers a low level url handler (a `rule`).
         * A rule detects specific URL patterns and returns a redirect, or performs some action.
         *
         * If a rule returns a string, the URL is replaced with the string, and all rules are fired again.
         *
         * #### Example:
         * ```js
         * var app = angular.module('app', ['ui.router.router']);
         *
         * app.config(function ($urlRouterProvider) {
         *   // Here's an example of how you might allow case insensitive urls
         *   $urlRouterProvider.rule(function ($injector, $location) {
         *     var path = $location.path(),
         *         normalized = path.toLowerCase();
         *
         *     if (path !== normalized) {
         *       return normalized;
         *     }
         *   });
         * });
         * ```
         *
         * @param ruleFn
         * Handler function that takes `$injector` and `$location` services as arguments.
         * You can use them to detect a url and return a different url as a string.
         *
         * @return [[UrlRouterProvider]] (`this`)
         */
        UrlRouterProvider.prototype.rule = function (ruleFn) {
            var _this = this;
            if (!isFunction(ruleFn))
                throw new Error("'rule' must be a function");
            var match = function () { return ruleFn(services.$injector, _this.router.locationService); };
            var rule = new BaseUrlRule(match, identity);
            this.router.urlService.rules.rule(rule);
            return this;
        };
        /**
         * Defines the path or behavior to use when no url can be matched.
         *
         * #### Example:
         * ```js
         * var app = angular.module('app', ['ui.router.router']);
         *
         * app.config(function ($urlRouterProvider) {
         *   // if the path doesn't match any of the urls you configured
         *   // otherwise will take care of routing the user to the
         *   // specified url
         *   $urlRouterProvider.otherwise('/index');
         *
         *   // Example of using function rule as param
         *   $urlRouterProvider.otherwise(function ($injector, $location) {
         *     return '/a/valid/url';
         *   });
         * });
         * ```
         *
         * @param rule
         * The url path you want to redirect to or a function rule that returns the url path or performs a `$state.go()`.
         * The function version is passed two params: `$injector` and `$location` services, and should return a url string.
         *
         * @return {object} `$urlRouterProvider` - `$urlRouterProvider` instance
         */
        UrlRouterProvider.prototype.otherwise = function (rule) {
            var _this = this;
            var urlRules = this.router.urlService.rules;
            if (isString(rule)) {
                urlRules.otherwise(rule);
            }
            else if (isFunction(rule)) {
                urlRules.otherwise(function () { return rule(services.$injector, _this.router.locationService); });
            }
            else {
                throw new Error("'rule' must be a string or function");
            }
            return this;
        };
        /**
         * Registers a handler for a given url matching.
         *
         * If the handler is a string, it is
         * treated as a redirect, and is interpolated according to the syntax of match
         * (i.e. like `String.replace()` for `RegExp`, or like a `UrlMatcher` pattern otherwise).
         *
         * If the handler is a function, it is injectable.
         * It gets invoked if `$location` matches.
         * You have the option of inject the match object as `$match`.
         *
         * The handler can return
         *
         * - **falsy** to indicate that the rule didn't match after all, then `$urlRouter`
         *   will continue trying to find another one that matches.
         * - **string** which is treated as a redirect and passed to `$location.url()`
         * - **void** or any **truthy** value tells `$urlRouter` that the url was handled.
         *
         * #### Example:
         * ```js
         * var app = angular.module('app', ['ui.router.router']);
         *
         * app.config(function ($urlRouterProvider) {
         *   $urlRouterProvider.when($state.url, function ($match, $stateParams) {
         *     if ($state.$current.navigable !== state ||
         *         !equalForKeys($match, $stateParams) {
         *      $state.transitionTo(state, $match, false);
         *     }
         *   });
         * });
         * ```
         *
         * @param what A pattern string to match, compiled as a [[UrlMatcher]].
         * @param handler The path (or function that returns a path) that you want to redirect your user to.
         * @param ruleCallback [optional] A callback that receives the `rule` registered with [[UrlMatcher.rule]]
         *
         * Note: the handler may also invoke arbitrary code, such as `$state.go()`
         */
        UrlRouterProvider.prototype.when = function (what, handler) {
            if (isArray(handler) || isFunction(handler)) {
                handler = UrlRouterProvider.injectableHandler(this.router, handler);
            }
            this.router.urlService.rules.when(what, handler);
            return this;
        };
        /**
         * Disables monitoring of the URL.
         *
         * Call this method before UI-Router has bootstrapped.
         * It will stop UI-Router from performing the initial url sync.
         *
         * This can be useful to perform some asynchronous initialization before the router starts.
         * Once the initialization is complete, call [[listen]] to tell UI-Router to start watching and synchronizing the URL.
         *
         * #### Example:
         * ```js
         * var app = angular.module('app', ['ui.router']);
         *
         * app.config(function ($urlRouterProvider) {
         *   // Prevent $urlRouter from automatically intercepting URL changes;
         *   $urlRouterProvider.deferIntercept();
         * })
         *
         * app.run(function (MyService, $urlRouter, $http) {
         *   $http.get("/stuff").then(function(resp) {
         *     MyService.doStuff(resp.data);
         *     $urlRouter.listen();
         *     $urlRouter.sync();
         *   });
         * });
         * ```
         *
         * @param defer Indicates whether to defer location change interception.
         *        Passing no parameter is equivalent to `true`.
         */
        UrlRouterProvider.prototype.deferIntercept = function (defer) {
            this.router.urlService.deferIntercept(defer);
        };
        return UrlRouterProvider;
    }());

    /* eslint-disable @typescript-eslint/no-empty-function */
    ng.module('ui.router.angular1', []);
    var mod_init = ng.module('ui.router.init', ['ng']);
    var mod_util = ng.module('ui.router.util', ['ui.router.init']);
    var mod_rtr = ng.module('ui.router.router', ['ui.router.util']);
    var mod_state = ng.module('ui.router.state', ['ui.router.router', 'ui.router.util', 'ui.router.angular1']);
    var mod_main = ng.module('ui.router', ['ui.router.init', 'ui.router.state', 'ui.router.angular1']);
    var mod_cmpt = ng.module('ui.router.compat', ['ui.router']);
    var router = null;
    $uiRouterProvider.$inject = ['$locationProvider'];
    /** This angular 1 provider instantiates a Router and exposes its services via the angular injector */
    function $uiRouterProvider($locationProvider) {
        // Create a new instance of the Router when the $uiRouterProvider is initialized
        router = this.router = new UIRouter();
        router.stateProvider = new StateProvider(router.stateRegistry, router.stateService);
        // Apply ng1 specific StateBuilder code for `views`, `resolve`, and `onExit/Retain/Enter` properties
        router.stateRegistry.decorator('views', ng1ViewsBuilder);
        router.stateRegistry.decorator('onExit', getStateHookBuilder('onExit'));
        router.stateRegistry.decorator('onRetain', getStateHookBuilder('onRetain'));
        router.stateRegistry.decorator('onEnter', getStateHookBuilder('onEnter'));
        router.viewService._pluginapi._viewConfigFactory('ng1', getNg1ViewConfigFactory());
        // Disable decoding of params by UrlMatcherFactory because $location already handles this
        router.urlService.config._decodeParams = false;
        var ng1LocationService = (router.locationService = router.locationConfig = new Ng1LocationServices($locationProvider));
        Ng1LocationServices.monkeyPatchPathParameterType(router);
        // backwards compat: also expose router instance as $uiRouterProvider.router
        router['router'] = router;
        router['$get'] = $get;
        $get.$inject = ['$location', '$browser', '$window', '$sniffer', '$rootScope', '$http', '$templateCache'];
        function $get($location, $browser, $window, $sniffer, $rootScope, $http, $templateCache) {
            ng1LocationService._runtimeServices($rootScope, $location, $sniffer, $browser, $window);
            delete router['router'];
            delete router['$get'];
            return router;
        }
        return router;
    }
    var getProviderFor = function (serviceName) { return [
        '$uiRouterProvider',
        function ($urp) {
            var service = $urp.router[serviceName];
            service['$get'] = function () { return service; };
            return service;
        },
    ]; };
    // This effectively calls $get() on `$uiRouterProvider` to trigger init (when ng enters runtime)
    runBlock.$inject = ['$injector', '$q', '$uiRouter'];
    function runBlock($injector, $q, $uiRouter) {
        services.$injector = $injector;
        services.$q = $q;
        // https://github.com/angular-ui/ui-router/issues/3678
        if (!Object.prototype.hasOwnProperty.call($injector, 'strictDi')) {
            try {
                $injector.invoke(function (checkStrictDi) { });
            }
            catch (error) {
                $injector.strictDi = !!/strict mode/.exec(error && error.toString());
            }
        }
        // The $injector is now available.
        // Find any resolvables that had dependency annotation deferred
        $uiRouter.stateRegistry
            .get()
            .map(function (x) { return x.$$state().resolvables; })
            .reduce(unnestR, [])
            .filter(function (x) { return x.deps === 'deferred'; })
            .forEach(function (resolvable) { return (resolvable.deps = $injector.annotate(resolvable.resolveFn, $injector.strictDi)); });
    }
    // $urlRouter service and $urlRouterProvider
    var getUrlRouterProvider = function (uiRouter) { return (uiRouter.urlRouterProvider = new UrlRouterProvider(uiRouter)); };
    // $state service and $stateProvider
    // $urlRouter service and $urlRouterProvider
    var getStateProvider = function () { return extend(router.stateProvider, { $get: function () { return router.stateService; } }); };
    watchDigests.$inject = ['$rootScope'];
    function watchDigests($rootScope) {
        $rootScope.$watch(function () {
            trace.approximateDigests++;
        });
    }
    mod_init.provider('$uiRouter', $uiRouterProvider);
    mod_rtr.provider('$urlRouter', ['$uiRouterProvider', getUrlRouterProvider]);
    mod_util.provider('$urlService', getProviderFor('urlService'));
    mod_util.provider('$urlMatcherFactory', ['$uiRouterProvider', function () { return router.urlMatcherFactory; }]);
    mod_util.provider('$templateFactory', function () { return new TemplateFactory(); });
    mod_state.provider('$stateRegistry', getProviderFor('stateRegistry'));
    mod_state.provider('$uiRouterGlobals', getProviderFor('globals'));
    mod_state.provider('$transitions', getProviderFor('transitionService'));
    mod_state.provider('$state', ['$uiRouterProvider', getStateProvider]);
    mod_state.factory('$stateParams', ['$uiRouter', function ($uiRouter) { return $uiRouter.globals.params; }]);
    mod_main.factory('$view', function () { return router.viewService; });
    mod_main.service('$trace', function () { return trace; });
    mod_main.run(watchDigests);
    mod_util.run(['$urlMatcherFactory', function ($urlMatcherFactory) { }]);
    mod_state.run(['$state', function ($state) { }]);
    mod_rtr.run(['$urlRouter', function ($urlRouter) { }]);
    mod_init.run(runBlock);
    /** @hidden TODO: find a place to move this */
    var getLocals = function (ctx) {
        var tokens = ctx.getTokens().filter(isString);
        var tuples = tokens.map(function (key) {
            var resolvable = ctx.getResolvable(key);
            var waitPolicy = ctx.getPolicy(resolvable).async;
            return [key, waitPolicy === 'NOWAIT' ? resolvable.promise : resolvable.data];
        });
        return tuples.reduce(applyPairs, {});
    };

    /* eslint-disable @typescript-eslint/no-empty-interface */
    /** @hidden */
    function parseStateRef(ref) {
        var paramsOnly = ref.match(/^\s*({[^}]*})\s*$/);
        if (paramsOnly)
            ref = '(' + paramsOnly[1] + ')';
        var parsed = ref.replace(/\n/g, ' ').match(/^\s*([^(]*?)\s*(\((.*)\))?\s*$/);
        if (!parsed || parsed.length !== 4)
            throw new Error("Invalid state ref '" + ref + "'");
        return { state: parsed[1] || null, paramExpr: parsed[3] || null };
    }
    /** @hidden */
    function stateContext(el) {
        var $uiView = el.parent().inheritedData('$uiView');
        var path = parse('$cfg.path')($uiView);
        return path ? tail(path).state.name : undefined;
    }
    /** @hidden */
    function processedDef($state, $element, def) {
        var uiState = def.uiState || $state.current.name;
        var uiStateOpts = extend(defaultOpts($element, $state), def.uiStateOpts || {});
        var href = $state.href(uiState, def.uiStateParams, uiStateOpts);
        return { uiState: uiState, uiStateParams: def.uiStateParams, uiStateOpts: uiStateOpts, href: href };
    }
    /** @hidden */
    function getTypeInfo(el) {
        // SVGAElement does not use the href attribute, but rather the 'xlinkHref' attribute.
        var isSvg = Object.prototype.toString.call(el.prop('href')) === '[object SVGAnimatedString]';
        var isForm = el[0].nodeName === 'FORM';
        return {
            attr: isForm ? 'action' : isSvg ? 'xlink:href' : 'href',
            isAnchor: el.prop('tagName').toUpperCase() === 'A',
            clickable: !isForm,
        };
    }
    /** @hidden */
    function clickHook(el, $state, $timeout, type, getDef) {
        return function (e) {
            var button = e.which || e.button, target = getDef();
            if (!(button > 1 || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey || el.attr('target'))) {
                // HACK: This is to allow ng-clicks to be processed before the transition is initiated:
                var transition_1 = $timeout(function () {
                    if (!el.attr('disabled')) {
                        $state.go(target.uiState, target.uiStateParams, target.uiStateOpts);
                    }
                });
                e.preventDefault();
                // if the state has no URL, ignore one preventDefault from the <a> directive.
                var ignorePreventDefaultCount_1 = type.isAnchor && !target.href ? 1 : 0;
                e.preventDefault = function () {
                    if (ignorePreventDefaultCount_1-- <= 0)
                        $timeout.cancel(transition_1);
                };
            }
        };
    }
    /** @hidden */
    function defaultOpts(el, $state) {
        return {
            relative: stateContext(el) || $state.$current,
            inherit: true,
            source: 'sref',
        };
    }
    /** @hidden */
    function bindEvents(element, scope, hookFn, uiStateOpts) {
        var events;
        if (uiStateOpts) {
            events = uiStateOpts.events;
        }
        if (!isArray(events)) {
            events = ['click'];
        }
        var on = element.on ? 'on' : 'bind';
        for (var _i = 0, events_1 = events; _i < events_1.length; _i++) {
            var event_1 = events_1[_i];
            element[on](event_1, hookFn);
        }
        scope.$on('$destroy', function () {
            var off = element.off ? 'off' : 'unbind';
            for (var _i = 0, events_2 = events; _i < events_2.length; _i++) {
                var event_2 = events_2[_i];
                element[off](event_2, hookFn);
            }
        });
    }
    /**
     * `ui-sref`: A directive for linking to a state
     *
     * A directive which links to a state (and optionally, parameters).
     * When clicked, this directive activates the linked state with the supplied parameter values.
     *
     * ### Linked State
     * The attribute value of the `ui-sref` is the name of the state to link to.
     *
     * #### Example:
     * This will activate the `home` state when the link is clicked.
     * ```html
     * <a ui-sref="home">Home</a>
     * ```
     *
     * ### Relative Links
     * You can also use relative state paths within `ui-sref`, just like a relative path passed to `$state.go()` ([[StateService.go]]).
     * You just need to be aware that the path is relative to the state that *created* the link.
     * This allows a state to create a relative `ui-sref` which always targets the same destination.
     *
     * #### Example:
     * Both these links are relative to the parent state, even when a child state is currently active.
     * ```html
     * <a ui-sref=".child1">child 1 state</a>
     * <a ui-sref=".child2">child 2 state</a>
     * ```
     *
     * This link activates the parent state.
     * ```html
     * <a ui-sref="^">Return</a>
     * ```
     *
     * ### hrefs
     * If the linked state has a URL, the directive will automatically generate and
     * update the `href` attribute (using the [[StateService.href]]  method).
     *
     * #### Example:
     * Assuming the `users` state has a url of `/users/`
     * ```html
     * <a ui-sref="users" href="/users/">Users</a>
     * ```
     *
     * ### Parameter Values
     * In addition to the state name, a `ui-sref` can include parameter values which are applied when activating the state.
     * Param values can be provided in the `ui-sref` value after the state name, enclosed by parentheses.
     * The content inside the parentheses is an expression, evaluated to the parameter values.
     *
     * #### Example:
     * This example renders a list of links to users.
     * The state's `userId` parameter value comes from each user's `user.id` property.
     * ```html
     * <li ng-repeat="user in users">
     *   <a ui-sref="users.detail({ userId: user.id })">{{ user.displayName }}</a>
     * </li>
     * ```
     *
     * Note:
     * The parameter values expression is `$watch`ed for updates.
     *
     * ### Transition Options
     * You can specify [[TransitionOptions]] to pass to [[StateService.go]] by using the `ui-sref-opts` attribute.
     * Options are restricted to `location`, `inherit`, and `reload`.
     *
     * #### Example:
     * ```html
     * <a ui-sref="home" ui-sref-opts="{ reload: true }">Home</a>
     * ```
     *
     * ### Other DOM Events
     *
     * You can also customize which DOM events to respond to (instead of `click`) by
     * providing an `events` array in the `ui-sref-opts` attribute.
     *
     * #### Example:
     * ```html
     * <input type="text" ui-sref="contacts" ui-sref-opts="{ events: ['change', 'blur'] }">
     * ```
     *
     * ### Highlighting the active link
     * This directive can be used in conjunction with [[uiSrefActive]] to highlight the active link.
     *
     * ### Examples
     * If you have the following template:
     *
     * ```html
     * <a ui-sref="home">Home</a>
     * <a ui-sref="about">About</a>
     * <a ui-sref="{page: 2}">Next page</a>
     *
     * <ul>
     *     <li ng-repeat="contact in contacts">
     *         <a ui-sref="contacts.detail({ id: contact.id })">{{ contact.name }}</a>
     *     </li>
     * </ul>
     * ```
     *
     * Then (assuming the current state is `contacts`) the rendered html including hrefs would be:
     *
     * ```html
     * <a href="#/home" ui-sref="home">Home</a>
     * <a href="#/about" ui-sref="about">About</a>
     * <a href="#/contacts?page=2" ui-sref="{page: 2}">Next page</a>
     *
     * <ul>
     *     <li ng-repeat="contact in contacts">
     *         <a href="#/contacts/1" ui-sref="contacts.detail({ id: contact.id })">Joe</a>
     *     </li>
     *     <li ng-repeat="contact in contacts">
     *         <a href="#/contacts/2" ui-sref="contacts.detail({ id: contact.id })">Alice</a>
     *     </li>
     *     <li ng-repeat="contact in contacts">
     *         <a href="#/contacts/3" ui-sref="contacts.detail({ id: contact.id })">Bob</a>
     *     </li>
     * </ul>
     *
     * <a href="#/home" ui-sref="home" ui-sref-opts="{reload: true}">Home</a>
     * ```
     *
     * ### Notes
     *
     * - You can use `ui-sref` to change **only the parameter values** by omitting the state name and parentheses.
     * #### Example:
     * Sets the `lang` parameter to `en` and remains on the same state.
     *
     * ```html
     * <a ui-sref="{ lang: 'en' }">English</a>
     * ```
     *
     * - A middle-click, right-click, or ctrl-click is handled (natively) by the browser to open the href in a new window, for example.
     *
     * - Unlike the parameter values expression, the state name is not `$watch`ed (for performance reasons).
     * If you need to dynamically update the state being linked to, use the fully dynamic [[uiState]] directive.
     */
    var uiSrefDirective;
    uiSrefDirective = [
        '$uiRouter',
        '$timeout',
        function $StateRefDirective($uiRouter, $timeout) {
            var $state = $uiRouter.stateService;
            return {
                restrict: 'A',
                require: ['?^uiSrefActive', '?^uiSrefActiveEq'],
                link: function (scope, element, attrs, uiSrefActive) {
                    var type = getTypeInfo(element);
                    var active = uiSrefActive[1] || uiSrefActive[0];
                    var unlinkInfoFn = null;
                    var rawDef = {};
                    var getDef = function () { return processedDef($state, element, rawDef); };
                    var ref = parseStateRef(attrs.uiSref);
                    rawDef.uiState = ref.state;
                    rawDef.uiStateOpts = attrs.uiSrefOpts ? scope.$eval(attrs.uiSrefOpts) : {};
                    function update() {
                        var def = getDef();
                        if (unlinkInfoFn)
                            unlinkInfoFn();
                        if (active)
                            unlinkInfoFn = active.$$addStateInfo(def.uiState, def.uiStateParams);
                        if (def.href != null)
                            attrs.$set(type.attr, def.href);
                    }
                    if (ref.paramExpr) {
                        scope.$watch(ref.paramExpr, function (val) {
                            rawDef.uiStateParams = extend({}, val);
                            update();
                        }, true);
                        rawDef.uiStateParams = extend({}, scope.$eval(ref.paramExpr));
                    }
                    update();
                    scope.$on('$destroy', $uiRouter.stateRegistry.onStatesChanged(update));
                    scope.$on('$destroy', $uiRouter.transitionService.onSuccess({}, update));
                    if (!type.clickable)
                        return;
                    var hookFn = clickHook(element, $state, $timeout, type, getDef);
                    bindEvents(element, scope, hookFn, rawDef.uiStateOpts);
                },
            };
        },
    ];
    /**
     * `ui-state`: A fully dynamic directive for linking to a state
     *
     * A directive which links to a state (and optionally, parameters).
     * When clicked, this directive activates the linked state with the supplied parameter values.
     *
     * **This directive is very similar to [[uiSref]], but it `$observe`s and `$watch`es/evaluates all its inputs.**
     *
     * A directive which links to a state (and optionally, parameters).
     * When clicked, this directive activates the linked state with the supplied parameter values.
     *
     * ### Linked State
     * The attribute value of `ui-state` is an expression which is `$watch`ed and evaluated as the state to link to.
     * **This is in contrast with `ui-sref`, which takes a state name as a string literal.**
     *
     * #### Example:
     * Create a list of links.
     * ```html
     * <li ng-repeat="link in navlinks">
     *   <a ui-state="link.state">{{ link.displayName }}</a>
     * </li>
     * ```
     *
     * ### Relative Links
     * If the expression evaluates to a relative path, it is processed like [[uiSref]].
     * You just need to be aware that the path is relative to the state that *created* the link.
     * This allows a state to create relative `ui-state` which always targets the same destination.
     *
     * ### hrefs
     * If the linked state has a URL, the directive will automatically generate and
     * update the `href` attribute (using the [[StateService.href]]  method).
     *
     * ### Parameter Values
     * In addition to the state name expression, a `ui-state` can include parameter values which are applied when activating the state.
     * Param values should be provided using the `ui-state-params` attribute.
     * The `ui-state-params` attribute value is `$watch`ed and evaluated as an expression.
     *
     * #### Example:
     * This example renders a list of links with param values.
     * The state's `userId` parameter value comes from each user's `user.id` property.
     * ```html
     * <li ng-repeat="link in navlinks">
     *   <a ui-state="link.state" ui-state-params="link.params">{{ link.displayName }}</a>
     * </li>
     * ```
     *
     * ### Transition Options
     * You can specify [[TransitionOptions]] to pass to [[StateService.go]] by using the `ui-state-opts` attribute.
     * Options are restricted to `location`, `inherit`, and `reload`.
     * The value of the `ui-state-opts` is `$watch`ed and evaluated as an expression.
     *
     * #### Example:
     * ```html
     * <a ui-state="returnto.state" ui-state-opts="{ reload: true }">Home</a>
     * ```
     *
     * ### Other DOM Events
     *
     * You can also customize which DOM events to respond to (instead of `click`) by
     * providing an `events` array in the `ui-state-opts` attribute.
     *
     * #### Example:
     * ```html
     * <input type="text" ui-state="contacts" ui-state-opts="{ events: ['change', 'blur'] }">
     * ```
     *
     * ### Highlighting the active link
     * This directive can be used in conjunction with [[uiSrefActive]] to highlight the active link.
     *
     * ### Notes
     *
     * - You can use `ui-params` to change **only the parameter values** by omitting the state name and supplying only `ui-state-params`.
     *   However, it might be simpler to use [[uiSref]] parameter-only links.
     *
     * #### Example:
     * Sets the `lang` parameter to `en` and remains on the same state.
     *
     * ```html
     * <a ui-state="" ui-state-params="{ lang: 'en' }">English</a>
     * ```
     *
     * - A middle-click, right-click, or ctrl-click is handled (natively) by the browser to open the href in a new window, for example.
     * ```
     */
    var uiStateDirective;
    uiStateDirective = [
        '$uiRouter',
        '$timeout',
        function $StateRefDynamicDirective($uiRouter, $timeout) {
            var $state = $uiRouter.stateService;
            return {
                restrict: 'A',
                require: ['?^uiSrefActive', '?^uiSrefActiveEq'],
                link: function (scope, element, attrs, uiSrefActive) {
                    var type = getTypeInfo(element);
                    var active = uiSrefActive[1] || uiSrefActive[0];
                    var unlinkInfoFn = null;
                    var hookFn;
                    var rawDef = {};
                    var getDef = function () { return processedDef($state, element, rawDef); };
                    var inputAttrs = ['uiState', 'uiStateParams', 'uiStateOpts'];
                    var watchDeregFns = inputAttrs.reduce(function (acc, attr) { return ((acc[attr] = noop), acc); }, {});
                    function update() {
                        var def = getDef();
                        if (unlinkInfoFn)
                            unlinkInfoFn();
                        if (active)
                            unlinkInfoFn = active.$$addStateInfo(def.uiState, def.uiStateParams);
                        if (def.href != null)
                            attrs.$set(type.attr, def.href);
                    }
                    inputAttrs.forEach(function (field) {
                        rawDef[field] = attrs[field] ? scope.$eval(attrs[field]) : null;
                        attrs.$observe(field, function (expr) {
                            watchDeregFns[field]();
                            watchDeregFns[field] = scope.$watch(expr, function (newval) {
                                rawDef[field] = newval;
                                update();
                            }, true);
                        });
                    });
                    update();
                    scope.$on('$destroy', $uiRouter.stateRegistry.onStatesChanged(update));
                    scope.$on('$destroy', $uiRouter.transitionService.onSuccess({}, update));
                    if (!type.clickable)
                        return;
                    hookFn = clickHook(element, $state, $timeout, type, getDef);
                    bindEvents(element, scope, hookFn, rawDef.uiStateOpts);
                },
            };
        },
    ];
    /**
     * `ui-sref-active` and `ui-sref-active-eq`: A directive that adds a CSS class when a `ui-sref` is active
     *
     * A directive working alongside [[uiSref]] and [[uiState]] to add classes to an element when the
     * related directive's state is active (and remove them when it is inactive).
     *
     * The primary use-case is to highlight the active link in navigation menus,
     * distinguishing it from the inactive menu items.
     *
     * ### Linking to a `ui-sref` or `ui-state`
     * `ui-sref-active` can live on the same element as `ui-sref`/`ui-state`, or it can be on a parent element.
     * If a `ui-sref-active` is a parent to more than one `ui-sref`/`ui-state`, it will apply the CSS class when **any of the links are active**.
     *
     * ### Matching
     *
     * The `ui-sref-active` directive applies the CSS class when the `ui-sref`/`ui-state`'s target state **or any child state is active**.
     * This is a "fuzzy match" which uses [[StateService.includes]].
     *
     * The `ui-sref-active-eq` directive applies the CSS class when the `ui-sref`/`ui-state`'s target state is directly active (not when child states are active).
     * This is an "exact match" which uses [[StateService.is]].
     *
     * ### Parameter values
     * If the `ui-sref`/`ui-state` includes parameter values, the current parameter values must match the link's values for the link to be highlighted.
     * This allows a list of links to the same state with different parameters to be rendered, and the correct one highlighted.
     *
     * #### Example:
     * ```html
     * <li ng-repeat="user in users" ui-sref-active="active">
     *   <a ui-sref="user.details({ userId: user.id })">{{ user.lastName }}</a>
     * </li>
     * ```
     *
     * ### Examples
     *
     * Given the following template:
     * #### Example:
     * ```html
     * <ul>
     *   <li ui-sref-active="active" class="item">
     *     <a href ui-sref="app.user({user: 'bilbobaggins'})">@bilbobaggins</a>
     *   </li>
     * </ul>
     * ```
     *
     * When the app state is `app.user` (or any child state),
     * and contains the state parameter "user" with value "bilbobaggins",
     * the resulting HTML will appear as (note the 'active' class):
     *
     * ```html
     * <ul>
     *   <li ui-sref-active="active" class="item active">
     *     <a ui-sref="app.user({user: 'bilbobaggins'})" href="/users/bilbobaggins">@bilbobaggins</a>
     *   </li>
     * </ul>
     * ```
     *
     * ### Glob mode
     *
     * It is possible to pass `ui-sref-active` an expression that evaluates to an object.
     * The objects keys represent active class names and values represent the respective state names/globs.
     * `ui-sref-active` will match if the current active state **includes** any of
     * the specified state names/globs, even the abstract ones.
     *
     * #### Example:
     * Given the following template, with "admin" being an abstract state:
     * ```html
     * <div ui-sref-active="{'active': 'admin.**'}">
     *   <a ui-sref-active="active" ui-sref="admin.roles">Roles</a>
     * </div>
     * ```
     *
     * Arrays are also supported as values in the `ngClass`-like interface.
     * This allows multiple states to add `active` class.
     *
     * #### Example:
     * Given the following template, with "admin.roles" being the current state, the class will be added too:
     * ```html
     * <div ui-sref-active="{'active': ['owner.**', 'admin.**']}">
     *   <a ui-sref-active="active" ui-sref="admin.roles">Roles</a>
     * </div>
     * ```
     *
     * When the current state is "admin.roles" the "active" class will be applied to both the `<div>` and `<a>` elements.
     * It is important to note that the state names/globs passed to `ui-sref-active` override any state provided by a linked `ui-sref`.
     *
     * ### Notes:
     *
     * - The class name is interpolated **once** during the directives link time (any further changes to the
     * interpolated value are ignored).
     *
     * - Multiple classes may be specified in a space-separated format: `ui-sref-active='class1 class2 class3'`
     */
    var uiSrefActiveDirective;
    uiSrefActiveDirective = [
        '$state',
        '$stateParams',
        '$interpolate',
        '$uiRouter',
        function $StateRefActiveDirective($state, $stateParams, $interpolate, $uiRouter) {
            return {
                restrict: 'A',
                controller: [
                    '$scope',
                    '$element',
                    '$attrs',
                    function ($scope, $element, $attrs) {
                        var states = [];
                        var activeEqClass;
                        var uiSrefActive;
                        // There probably isn't much point in $observing this
                        // uiSrefActive and uiSrefActiveEq share the same directive object with some
                        // slight difference in logic routing
                        activeEqClass = $interpolate($attrs.uiSrefActiveEq || '', false)($scope);
                        try {
                            uiSrefActive = $scope.$eval($attrs.uiSrefActive);
                        }
                        catch (e) {
                            // Do nothing. uiSrefActive is not a valid expression.
                            // Fall back to using $interpolate below
                        }
                        uiSrefActive = uiSrefActive || $interpolate($attrs.uiSrefActive || '', false)($scope);
                        setStatesFromDefinitionObject(uiSrefActive);
                        // Allow uiSref to communicate with uiSrefActive[Equals]
                        this.$$addStateInfo = function (newState, newParams) {
                            // we already got an explicit state provided by ui-sref-active, so we
                            // shadow the one that comes from ui-sref
                            if (isObject(uiSrefActive) && states.length > 0) {
                                return;
                            }
                            var deregister = addState(newState, newParams, uiSrefActive);
                            update();
                            return deregister;
                        };
                        function updateAfterTransition(trans) {
                            trans.promise.then(update, noop);
                        }
                        $scope.$on('$destroy', setupEventListeners());
                        if ($uiRouter.globals.transition) {
                            updateAfterTransition($uiRouter.globals.transition);
                        }
                        function setupEventListeners() {
                            var deregisterStatesChangedListener = $uiRouter.stateRegistry.onStatesChanged(handleStatesChanged);
                            var deregisterOnStartListener = $uiRouter.transitionService.onStart({}, updateAfterTransition);
                            var deregisterStateChangeSuccessListener = $scope.$on('$stateChangeSuccess', update);
                            return function cleanUp() {
                                deregisterStatesChangedListener();
                                deregisterOnStartListener();
                                deregisterStateChangeSuccessListener();
                            };
                        }
                        function handleStatesChanged() {
                            setStatesFromDefinitionObject(uiSrefActive);
                        }
                        function setStatesFromDefinitionObject(statesDefinition) {
                            if (isObject(statesDefinition)) {
                                states = [];
                                forEach(statesDefinition, function (stateOrName, activeClass) {
                                    // Helper function to abstract adding state.
                                    var addStateForClass = function (stateOrName, activeClass) {
                                        var ref = parseStateRef(stateOrName);
                                        addState(ref.state, $scope.$eval(ref.paramExpr), activeClass);
                                    };
                                    if (isString(stateOrName)) {
                                        // If state is string, just add it.
                                        addStateForClass(stateOrName, activeClass);
                                    }
                                    else if (isArray(stateOrName)) {
                                        // If state is an array, iterate over it and add each array item individually.
                                        forEach(stateOrName, function (stateOrName) {
                                            addStateForClass(stateOrName, activeClass);
                                        });
                                    }
                                });
                            }
                        }
                        function addState(stateName, stateParams, activeClass) {
                            var state = $state.get(stateName, stateContext($element));
                            var stateInfo = {
                                state: state || { name: stateName },
                                params: stateParams,
                                activeClass: activeClass,
                            };
                            states.push(stateInfo);
                            return function removeState() {
                                removeFrom(states)(stateInfo);
                            };
                        }
                        // Update route state
                        function update() {
                            var splitClasses = function (str) { return str.split(/\s/).filter(identity); };
                            var getClasses = function (stateList) {
                                return stateList
                                    .map(function (x) { return x.activeClass; })
                                    .map(splitClasses)
                                    .reduce(unnestR, []);
                            };
                            var allClasses = getClasses(states).concat(splitClasses(activeEqClass)).reduce(uniqR, []);
                            var fuzzyClasses = getClasses(states.filter(function (x) { return $state.includes(x.state.name, x.params); }));
                            var exactlyMatchesAny = !!states.filter(function (x) { return $state.is(x.state.name, x.params); }).length;
                            var exactClasses = exactlyMatchesAny ? splitClasses(activeEqClass) : [];
                            var addClasses = fuzzyClasses.concat(exactClasses).reduce(uniqR, []);
                            var removeClasses = allClasses.filter(function (cls) { return !inArray(addClasses, cls); });
                            $scope.$evalAsync(function () {
                                addClasses.forEach(function (className) { return $element.addClass(className); });
                                removeClasses.forEach(function (className) { return $element.removeClass(className); });
                            });
                        }
                        update();
                    },
                ],
            };
        },
    ];
    ng
        .module('ui.router.state')
        .directive('uiSref', uiSrefDirective)
        .directive('uiSrefActive', uiSrefActiveDirective)
        .directive('uiSrefActiveEq', uiSrefActiveDirective)
        .directive('uiState', uiStateDirective);

    /** @publicapi @module ng1 */ /** */
    /**
     * `isState` Filter: truthy if the current state is the parameter
     *
     * Translates to [[StateService.is]] `$state.is("stateName")`.
     *
     * #### Example:
     * ```html
     * <div ng-if="'stateName' | isState">show if state is 'stateName'</div>
     * ```
     */
    $IsStateFilter.$inject = ['$state'];
    function $IsStateFilter($state) {
        var isFilter = function (state, params, options) {
            return $state.is(state, params, options);
        };
        isFilter.$stateful = true;
        return isFilter;
    }
    /**
     * `includedByState` Filter: truthy if the current state includes the parameter
     *
     * Translates to [[StateService.includes]]` $state.is("fullOrPartialStateName")`.
     *
     * #### Example:
     * ```html
     * <div ng-if="'fullOrPartialStateName' | includedByState">show if state includes 'fullOrPartialStateName'</div>
     * ```
     */
    $IncludedByStateFilter.$inject = ['$state'];
    function $IncludedByStateFilter($state) {
        var includesFilter = function (state, params, options) {
            return $state.includes(state, params, options);
        };
        includesFilter.$stateful = true;
        return includesFilter;
    }
    ng.module('ui.router.state').filter('isState', $IsStateFilter).filter('includedByState', $IncludedByStateFilter);

    /** @publicapi @module directives */ /** */
    /**
     * `ui-view`: A viewport directive which is filled in by a view from the active state.
     *
     * ### Attributes
     *
     * - `name`: (Optional) A view name.
     *   The name should be unique amongst the other views in the same state.
     *   You can have views of the same name that live in different states.
     *   The ui-view can be targeted in a View using the name ([[Ng1StateDeclaration.views]]).
     *
     * - `autoscroll`: an expression. When it evaluates to true, the `ui-view` will be scrolled into view when it is activated.
     *   Uses [[$uiViewScroll]] to do the scrolling.
     *
     * - `onload`: Expression to evaluate whenever the view updates.
     *
     * #### Example:
     * A view can be unnamed or named.
     * ```html
     * <!-- Unnamed -->
     * <div ui-view></div>
     *
     * <!-- Named -->
     * <div ui-view="viewName"></div>
     *
     * <!-- Named (different style) -->
     * <ui-view name="viewName"></ui-view>
     * ```
     *
     * You can only have one unnamed view within any template (or root html). If you are only using a
     * single view and it is unnamed then you can populate it like so:
     *
     * ```html
     * <div ui-view></div>
     * $stateProvider.state("home", {
     *   template: "<h1>HELLO!</h1>"
     * })
     * ```
     *
     * The above is a convenient shortcut equivalent to specifying your view explicitly with the
     * [[Ng1StateDeclaration.views]] config property, by name, in this case an empty name:
     *
     * ```js
     * $stateProvider.state("home", {
     *   views: {
     *     "": {
     *       template: "<h1>HELLO!</h1>"
     *     }
     *   }
     * })
     * ```
     *
     * But typically you'll only use the views property if you name your view or have more than one view
     * in the same template. There's not really a compelling reason to name a view if its the only one,
     * but you could if you wanted, like so:
     *
     * ```html
     * <div ui-view="main"></div>
     * ```
     *
     * ```js
     * $stateProvider.state("home", {
     *   views: {
     *     "main": {
     *       template: "<h1>HELLO!</h1>"
     *     }
     *   }
     * })
     * ```
     *
     * Really though, you'll use views to set up multiple views:
     *
     * ```html
     * <div ui-view></div>
     * <div ui-view="chart"></div>
     * <div ui-view="data"></div>
     * ```
     *
     * ```js
     * $stateProvider.state("home", {
     *   views: {
     *     "": {
     *       template: "<h1>HELLO!</h1>"
     *     },
     *     "chart": {
     *       template: "<chart_thing/>"
     *     },
     *     "data": {
     *       template: "<data_thing/>"
     *     }
     *   }
     * })
     * ```
     *
     * #### Examples for `autoscroll`:
     * ```html
     * <!-- If autoscroll present with no expression,
     *      then scroll ui-view into view -->
     * <ui-view autoscroll/>
     *
     * <!-- If autoscroll present with valid expression,
     *      then scroll ui-view into view if expression evaluates to true -->
     * <ui-view autoscroll='true'/>
     * <ui-view autoscroll='false'/>
     * <ui-view autoscroll='scopeVariable'/>
     * ```
     *
     * Resolve data:
     *
     * The resolved data from the state's `resolve` block is placed on the scope as `$resolve` (this
     * can be customized using [[Ng1ViewDeclaration.resolveAs]]).  This can be then accessed from the template.
     *
     * Note that when `controllerAs` is being used, `$resolve` is set on the controller instance *after* the
     * controller is instantiated.  The `$onInit()` hook can be used to perform initialization code which
     * depends on `$resolve` data.
     *
     * #### Example:
     * ```js
     * $stateProvider.state('home', {
     *   template: '<my-component user="$resolve.user"></my-component>',
     *   resolve: {
     *     user: function(UserService) { return UserService.fetchUser(); }
     *   }
     * });
     * ```
     */
    var uiView;
    // eslint-disable-next-line prefer-const
    uiView = [
        '$view',
        '$animate',
        '$uiViewScroll',
        '$interpolate',
        '$q',
        function $ViewDirective($view, $animate, $uiViewScroll, $interpolate, $q) {
            function getRenderer() {
                return {
                    enter: function (element, target, cb) {
                        if (ng.version.minor > 2) {
                            $animate.enter(element, null, target).then(cb);
                        }
                        else {
                            $animate.enter(element, null, target, cb);
                        }
                    },
                    leave: function (element, cb) {
                        if (ng.version.minor > 2) {
                            $animate.leave(element).then(cb);
                        }
                        else {
                            $animate.leave(element, cb);
                        }
                    },
                };
            }
            function configsEqual(config1, config2) {
                return config1 === config2;
            }
            var rootData = {
                $cfg: { viewDecl: { $context: $view._pluginapi._rootViewContext() } },
                $uiView: {},
            };
            var directive = {
                count: 0,
                restrict: 'ECA',
                terminal: true,
                priority: 400,
                transclude: 'element',
                compile: function (tElement, tAttrs, $transclude) {
                    return function (scope, $element, attrs) {
                        var onloadExp = attrs['onload'] || '', autoScrollExp = attrs['autoscroll'], renderer = getRenderer(), inherited = $element.inheritedData('$uiView') || rootData, name = $interpolate(attrs['uiView'] || attrs['name'] || '')(scope) || '$default';
                        var previousEl, currentEl, currentScope, viewConfig;
                        var activeUIView = {
                            $type: 'ng1',
                            id: directive.count++,
                            name: name,
                            fqn: inherited.$uiView.fqn ? inherited.$uiView.fqn + '.' + name : name,
                            config: null,
                            configUpdated: configUpdatedCallback,
                            get creationContext() {
                                // The context in which this ui-view "tag" was created
                                var fromParentTagConfig = parse('$cfg.viewDecl.$context')(inherited);
                                // Allow <ui-view name="foo"><ui-view name="bar"></ui-view></ui-view>
                                // See https://github.com/angular-ui/ui-router/issues/3355
                                var fromParentTag = parse('$uiView.creationContext')(inherited);
                                return fromParentTagConfig || fromParentTag;
                            },
                        };
                        trace.traceUIViewEvent('Linking', activeUIView);
                        function configUpdatedCallback(config) {
                            if (config && !(config instanceof Ng1ViewConfig))
                                return;
                            if (configsEqual(viewConfig, config))
                                return;
                            trace.traceUIViewConfigUpdated(activeUIView, config && config.viewDecl && config.viewDecl.$context);
                            viewConfig = config;
                            updateView(config);
                        }
                        $element.data('$uiView', { $uiView: activeUIView });
                        updateView();
                        var unregister = $view.registerUIView(activeUIView);
                        scope.$on('$destroy', function () {
                            trace.traceUIViewEvent('Destroying/Unregistering', activeUIView);
                            unregister();
                        });
                        function cleanupLastView() {
                            if (previousEl) {
                                trace.traceUIViewEvent('Removing (previous) el', previousEl.data('$uiView'));
                                previousEl.remove();
                                previousEl = null;
                            }
                            if (currentScope) {
                                trace.traceUIViewEvent('Destroying scope', activeUIView);
                                currentScope.$destroy();
                                currentScope = null;
                            }
                            if (currentEl) {
                                var _viewData_1 = currentEl.data('$uiViewAnim');
                                trace.traceUIViewEvent('Animate out', _viewData_1);
                                renderer.leave(currentEl, function () {
                                    _viewData_1.$$animLeave.resolve();
                                    previousEl = null;
                                });
                                previousEl = currentEl;
                                currentEl = null;
                            }
                        }
                        function updateView(config) {
                            var newScope = scope.$new();
                            var animEnter = $q.defer(), animLeave = $q.defer();
                            var $uiViewData = {
                                $cfg: config,
                                $uiView: activeUIView,
                            };
                            var $uiViewAnim = {
                                $animEnter: animEnter.promise,
                                $animLeave: animLeave.promise,
                                $$animLeave: animLeave,
                            };
                            /**
                             * @ngdoc event
                             * @name ui.router.state.directive:ui-view#$viewContentLoading
                             * @eventOf ui.router.state.directive:ui-view
                             * @eventType emits on ui-view directive scope
                             * @description
                             *
                             * Fired once the view **begins loading**, *before* the DOM is rendered.
                             *
                             * @param {Object} event Event object.
                             * @param {string} viewName Name of the view.
                             */
                            newScope.$emit('$viewContentLoading', name);
                            var cloned = $transclude(newScope, function (clone) {
                                clone.data('$uiViewAnim', $uiViewAnim);
                                clone.data('$uiView', $uiViewData);
                                renderer.enter(clone, $element, function onUIViewEnter() {
                                    animEnter.resolve();
                                    if (currentScope)
                                        currentScope.$emit('$viewContentAnimationEnded');
                                    if ((isDefined(autoScrollExp) && !autoScrollExp) || scope.$eval(autoScrollExp)) {
                                        $uiViewScroll(clone);
                                    }
                                });
                                cleanupLastView();
                            });
                            currentEl = cloned;
                            currentScope = newScope;
                            /**
                             * @ngdoc event
                             * @name ui.router.state.directive:ui-view#$viewContentLoaded
                             * @eventOf ui.router.state.directive:ui-view
                             * @eventType emits on ui-view directive scope
                             * @description           *
                             * Fired once the view is **loaded**, *after* the DOM is rendered.
                             *
                             * @param {Object} event Event object.
                             */
                            currentScope.$emit('$viewContentLoaded', config || viewConfig);
                            currentScope.$eval(onloadExp);
                        }
                    };
                },
            };
            return directive;
        },
    ];
    $ViewDirectiveFill.$inject = ['$compile', '$controller', '$transitions', '$view', '$q'];
    /** @hidden */
    function $ViewDirectiveFill($compile, $controller, $transitions, $view, $q) {
        var getControllerAs = parse('viewDecl.controllerAs');
        var getResolveAs = parse('viewDecl.resolveAs');
        return {
            restrict: 'ECA',
            priority: -400,
            compile: function (tElement) {
                var initial = tElement.html();
                tElement.empty();
                return function (scope, $element) {
                    var data = $element.data('$uiView');
                    if (!data) {
                        $element.html(initial);
                        $compile($element.contents())(scope);
                        return;
                    }
                    var cfg = data.$cfg || { viewDecl: {}, getTemplate: noop };
                    var resolveCtx = cfg.path && new ResolveContext(cfg.path);
                    $element.html(cfg.getTemplate($element, resolveCtx) || initial);
                    trace.traceUIViewFill(data.$uiView, $element.html());
                    var link = $compile($element.contents());
                    var controller = cfg.controller;
                    var controllerAs = getControllerAs(cfg);
                    var resolveAs = getResolveAs(cfg);
                    var locals = resolveCtx && getLocals(resolveCtx);
                    scope[resolveAs] = locals;
                    if (controller) {
                        var controllerInstance = ($controller(controller, extend({}, locals, { $scope: scope, $element: $element })));
                        if (controllerAs) {
                            scope[controllerAs] = controllerInstance;
                            scope[controllerAs][resolveAs] = locals;
                        }
                        // TODO: Use $view service as a central point for registering component-level hooks
                        // Then, when a component is created, tell the $view service, so it can invoke hooks
                        // $view.componentLoaded(controllerInstance, { $scope: scope, $element: $element });
                        // scope.$on('$destroy', () => $view.componentUnloaded(controllerInstance, { $scope: scope, $element: $element }));
                        $element.data('$ngControllerController', controllerInstance);
                        $element.children().data('$ngControllerController', controllerInstance);
                        registerControllerCallbacks($q, $transitions, controllerInstance, scope, cfg);
                    }
                    // Wait for the component to appear in the DOM
                    if (isString(cfg.component)) {
                        var kebobName = kebobString(cfg.component);
                        var tagRegexp_1 = new RegExp("^(x-|data-)?" + kebobName + "$", 'i');
                        var getComponentController = function () {
                            var directiveEl = [].slice
                                .call($element[0].children)
                                .filter(function (el) { return el && el.tagName && tagRegexp_1.exec(el.tagName); });
                            return directiveEl && ng.element(directiveEl).data("$" + cfg.component + "Controller");
                        };
                        var deregisterWatch_1 = scope.$watch(getComponentController, function (ctrlInstance) {
                            if (!ctrlInstance)
                                return;
                            registerControllerCallbacks($q, $transitions, ctrlInstance, scope, cfg);
                            deregisterWatch_1();
                        });
                    }
                    link(scope);
                };
            },
        };
    }
    /** @hidden */
    var hasComponentImpl = typeof ng.module('ui.router')['component'] === 'function';
    /** @hidden incrementing id */
    var _uiCanExitId = 0;
    /** @hidden TODO: move these callbacks to $view and/or `/hooks/components.ts` or something */
    function registerControllerCallbacks($q, $transitions, controllerInstance, $scope, cfg) {
        // Call $onInit() ASAP
        if (isFunction(controllerInstance.$onInit) &&
            !((cfg.viewDecl.component || cfg.viewDecl.componentProvider) && hasComponentImpl)) {
            controllerInstance.$onInit();
        }
        var viewState = tail(cfg.path).state.self;
        var hookOptions = { bind: controllerInstance };
        // Add component-level hook for onUiParamsChanged
        if (isFunction(controllerInstance.uiOnParamsChanged)) {
            var resolveContext = new ResolveContext(cfg.path);
            var viewCreationTrans_1 = resolveContext.getResolvable('$transition$').data;
            // Fire callback on any successful transition
            var paramsUpdated = function ($transition$) {
                // Exit early if the $transition$ is the same as the view was created within.
                // Exit early if the $transition$ will exit the state the view is for.
                if ($transition$ === viewCreationTrans_1 || $transition$.exiting().indexOf(viewState) !== -1)
                    return;
                var toParams = $transition$.params('to');
                var fromParams = $transition$.params('from');
                var getNodeSchema = function (node) { return node.paramSchema; };
                var toSchema = $transition$.treeChanges('to').map(getNodeSchema).reduce(unnestR, []);
                var fromSchema = $transition$.treeChanges('from').map(getNodeSchema).reduce(unnestR, []);
                // Find the to params that have different values than the from params
                var changedToParams = toSchema.filter(function (param) {
                    var idx = fromSchema.indexOf(param);
                    return idx === -1 || !fromSchema[idx].type.equals(toParams[param.id], fromParams[param.id]);
                });
                // Only trigger callback if a to param has changed or is new
                if (changedToParams.length) {
                    var changedKeys_1 = changedToParams.map(function (x) { return x.id; });
                    // Filter the params to only changed/new to params.  `$transition$.params()` may be used to get all params.
                    var newValues = filter(toParams, function (val, key) { return changedKeys_1.indexOf(key) !== -1; });
                    controllerInstance.uiOnParamsChanged(newValues, $transition$);
                }
            };
            $scope.$on('$destroy', $transitions.onSuccess({}, paramsUpdated, hookOptions));
        }
        // Add component-level hook for uiCanExit
        if (isFunction(controllerInstance.uiCanExit)) {
            var id_1 = _uiCanExitId++;
            var cacheProp_1 = '_uiCanExitIds';
            // Returns true if a redirect transition already answered truthy
            var prevTruthyAnswer_1 = function (trans) {
                return !!trans && ((trans[cacheProp_1] && trans[cacheProp_1][id_1] === true) || prevTruthyAnswer_1(trans.redirectedFrom()));
            };
            // If a user answered yes, but the transition was later redirected, don't also ask for the new redirect transition
            var wrappedHook = function (trans) {
                var promise;
                var ids = (trans[cacheProp_1] = trans[cacheProp_1] || {});
                if (!prevTruthyAnswer_1(trans)) {
                    promise = $q.when(controllerInstance.uiCanExit(trans));
                    promise.then(function (val) { return (ids[id_1] = val !== false); });
                }
                return promise;
            };
            var criteria = { exiting: viewState.name };
            $scope.$on('$destroy', $transitions.onBefore(criteria, wrappedHook, hookOptions));
        }
    }
    ng.module('ui.router.state').directive('uiView', uiView);
    ng.module('ui.router.state').directive('uiView', $ViewDirectiveFill);

    /** @publicapi @module ng1 */ /** */
    /** @hidden */
    function $ViewScrollProvider() {
        var useAnchorScroll = false;
        this.useAnchorScroll = function () {
            useAnchorScroll = true;
        };
        this.$get = [
            '$anchorScroll',
            '$timeout',
            function ($anchorScroll, $timeout) {
                if (useAnchorScroll) {
                    return $anchorScroll;
                }
                return function ($element) {
                    return $timeout(function () {
                        $element[0].scrollIntoView();
                    }, 0, false);
                };
            },
        ];
    }
    ng.module('ui.router.state').provider('$uiViewScroll', $ViewScrollProvider);

    /**
     * Main entry point for angular 1.x build
     * @publicapi @module ng1
     */ /** */
    var index$1 = 'ui.router';

    exports.$injector = $injector;
    exports.$q = $q;
    exports.BaseLocationServices = BaseLocationServices;
    exports.BaseUrlRule = BaseUrlRule;
    exports.BrowserLocationConfig = BrowserLocationConfig;
    exports.Glob = Glob;
    exports.HashLocationService = HashLocationService;
    exports.HookBuilder = HookBuilder;
    exports.MemoryLocationConfig = MemoryLocationConfig;
    exports.MemoryLocationService = MemoryLocationService;
    exports.NATIVE_INJECTOR_TOKEN = NATIVE_INJECTOR_TOKEN;
    exports.Ng1ViewConfig = Ng1ViewConfig;
    exports.Param = Param;
    exports.ParamFactory = ParamFactory;
    exports.ParamType = ParamType;
    exports.ParamTypes = ParamTypes;
    exports.PathNode = PathNode;
    exports.PathUtils = PathUtils;
    exports.PushStateLocationService = PushStateLocationService;
    exports.Queue = Queue;
    exports.RegisteredHook = RegisteredHook;
    exports.Rejection = Rejection;
    exports.Resolvable = Resolvable;
    exports.ResolveContext = ResolveContext;
    exports.StateBuilder = StateBuilder;
    exports.StateMatcher = StateMatcher;
    exports.StateObject = StateObject;
    exports.StateParams = StateParams;
    exports.StateProvider = StateProvider;
    exports.StateQueueManager = StateQueueManager;
    exports.StateRegistry = StateRegistry;
    exports.StateService = StateService;
    exports.TargetState = TargetState;
    exports.Trace = Trace;
    exports.Transition = Transition;
    exports.TransitionEventType = TransitionEventType;
    exports.TransitionHook = TransitionHook;
    exports.TransitionService = TransitionService;
    exports.UIRouter = UIRouter;
    exports.UIRouterGlobals = UIRouterGlobals;
    exports.UIRouterPluginBase = UIRouterPluginBase;
    exports.UrlConfig = UrlConfig;
    exports.UrlMatcher = UrlMatcher;
    exports.UrlMatcherFactory = UrlMatcherFactory;
    exports.UrlRouter = UrlRouter;
    exports.UrlRouterProvider = UrlRouterProvider;
    exports.UrlRuleFactory = UrlRuleFactory;
    exports.UrlRules = UrlRules;
    exports.UrlService = UrlService;
    exports.ViewService = ViewService;
    exports._extend = _extend;
    exports._inArray = _inArray;
    exports._pushTo = _pushTo;
    exports._removeFrom = _removeFrom;
    exports.all = all;
    exports.allTrueR = allTrueR;
    exports.ancestors = ancestors;
    exports.and = and;
    exports.any = any;
    exports.anyTrueR = anyTrueR;
    exports.applyPairs = applyPairs;
    exports.arrayTuples = arrayTuples;
    exports.assertFn = assertFn;
    exports.assertMap = assertMap;
    exports.assertPredicate = assertPredicate;
    exports.beforeAfterSubstr = beforeAfterSubstr;
    exports.buildUrl = buildUrl;
    exports.compose = compose;
    exports.copy = copy;
    exports.core = index;
    exports.createProxyFunctions = createProxyFunctions;
    exports.curry = curry;
    exports.default = index$1;
    exports.defaultResolvePolicy = defaultResolvePolicy;
    exports.defaultTransOpts = defaultTransOpts;
    exports.defaults = defaults;
    exports.deregAll = deregAll;
    exports.eq = eq;
    exports.equals = equals;
    exports.extend = extend;
    exports.filter = filter;
    exports.find = find;
    exports.flatten = flatten;
    exports.flattenR = flattenR;
    exports.fnToString = fnToString;
    exports.forEach = forEach;
    exports.fromJson = fromJson;
    exports.functionToString = functionToString;
    exports.getLocals = getLocals;
    exports.getNg1ViewConfigFactory = getNg1ViewConfigFactory;
    exports.getParams = getParams;
    exports.hashLocationPlugin = hashLocationPlugin;
    exports.hostRegex = hostRegex;
    exports.identity = identity;
    exports.inArray = inArray;
    exports.inherit = inherit;
    exports.invoke = invoke;
    exports.is = is;
    exports.isArray = isArray;
    exports.isDate = isDate;
    exports.isDefined = isDefined;
    exports.isFunction = isFunction;
    exports.isInjectable = isInjectable;
    exports.isNull = isNull;
    exports.isNullOrUndefined = isNullOrUndefined;
    exports.isNumber = isNumber;
    exports.isObject = isObject;
    exports.isPromise = isPromise;
    exports.isRegExp = isRegExp;
    exports.isString = isString;
    exports.isUndefined = isUndefined;
    exports.joinNeighborsR = joinNeighborsR;
    exports.kebobString = kebobString;
    exports.keyValsToObjectR = keyValsToObjectR;
    exports.locationPluginFactory = locationPluginFactory;
    exports.makeEvent = makeEvent;
    exports.makeStub = makeStub;
    exports.map = map;
    exports.mapObj = mapObj;
    exports.matchState = matchState;
    exports.maxLength = maxLength;
    exports.memoryLocationPlugin = memoryLocationPlugin;
    exports.mergeR = mergeR;
    exports.ng1ViewsBuilder = ng1ViewsBuilder;
    exports.noop = noop;
    exports.not = not;
    exports.omit = omit;
    exports.or = or;
    exports.padString = padString;
    exports.pairs = pairs;
    exports.parse = parse;
    exports.parseUrl = parseUrl$1;
    exports.pattern = pattern;
    exports.pick = pick;
    exports.pipe = pipe;
    exports.pluck = pluck;
    exports.prop = prop;
    exports.propEq = propEq;
    exports.pushR = pushR;
    exports.pushStateLocationPlugin = pushStateLocationPlugin;
    exports.pushTo = pushTo;
    exports.removeFrom = removeFrom;
    exports.resolvablesBuilder = resolvablesBuilder;
    exports.resolvePolicies = resolvePolicies;
    exports.root = root;
    exports.services = services;
    exports.servicesPlugin = servicesPlugin;
    exports.silenceUncaughtInPromise = silenceUncaughtInPromise;
    exports.silentRejection = silentRejection;
    exports.splitEqual = splitEqual;
    exports.splitHash = splitHash;
    exports.splitOnDelim = splitOnDelim;
    exports.splitQuery = splitQuery;
    exports.stringify = stringify;
    exports.stripLastPathElement = stripLastPathElement;
    exports.tail = tail;
    exports.toJson = toJson;
    exports.trace = trace;
    exports.trimHashVal = trimHashVal;
    exports.uniqR = uniqR;
    exports.unnest = unnest;
    exports.unnestR = unnestR;
    exports.val = val;
    exports.values = values;
    exports.watchDigests = watchDigests;

    Object.defineProperty(exports, '__esModule', { value: true });

})));
//# sourceMappingURL=angular-ui-router.js.map
