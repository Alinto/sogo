module.exports.readVersion = function (contents) {
  console.debug('readVersion = ' + contents.match(/([0-9]+)/mg).join('.'));
  return contents.match(/([0-9]+)/mg).join('.');
};

module.exports.writeVersion = function (contents, version) {
  console.debug('writeVersion = ' + version);
  const versions = version.split('.');
  return "MAJOR_VERSION=" + versions[0] + "\nMINOR_VERSION=" + versions[1] + "\nSUBMINOR_VERSION=" + versions[2];
};
