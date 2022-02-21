# Tests

This directory holds automated tests for SOGo.

 - `spec` and `lib`: hold JavaScript driven interated tests that are used to validate overall DAV functionality
 - `Unit`: holds all unit tests

The configuration is found in `lib/config.js`. 

## Tools

* [Jasmin](https://jasmine.github.io/) - testing framework
* [tsdav](https://tsdav.vercel.app/) - webdav request helper
* [ical.js](https://github.com/mozilla-comm/ical.js) - ics and vcard parser
* [cross-fetch](https://github.com/lquixada/cross-fetch) - fetch API
* [xml-js](https://github.com/nashwaan/xml-js) - convert JS object to XML
