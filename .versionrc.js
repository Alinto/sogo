const tracker = {
  filename: "Version",
  updater: require("./Scripts/standard-version-updater.js")
}

module.exports = {
  tagPrefix: "SOGo-",
  issueUrlFormat: "https://bugs.sogo.nu/view.php?id={{id}}",
  compareUrlFormat: "{{host}}/{{owner}}/{{repository}}/compare/{{previousTag}}...{{currentTag}}",
  types: [
    {type: "feat",     section: "Features"},
    {type: "refactor", section: "Enhancements"},
    {type: "perf",     section: "Enhancements"},
    {type: "i18n",     section: "Localization"},
    {type: "fix",      section: "Bug Fixes"},
    {type: "chore",    hidden:  true},
    {type: "docs",     hidden:  true},
    {type: "style",    hidden:  true},
    {type: "test",     hidden:  true}
  ],
  skip: {
    commit: true,
    tag: true
  },
  packageFiles: [tracker],
  bumpFiles: [tracker]
}
