# Contributing to SOGo

## Reporting Bugs and Suggesting Enhancements

If you encounter a possible bug with SOGo, you can access our
[bug tracking system](https://bugs.sogo.nu/).

Please make sure to respect the following guidelines when reporting a bug:

* verify that the bug you found is not already known or even fixed in the `master` version
* make the actual facts very clear; be precise, we need to be able to reproduce the problem
* explain your speculations, if any
* add a screenshot to the ticket if appropriate

## Submitting a Pull Request

Begin by reading [SOGo Developer's Guide](../Documentation/SOGoDevelopersGuide.asciidoc).

### Translations

Three type of files must be translated. The first type are **Localizable.strings**; they can be
translated online using **[Transifex](https://www.transifex.com/alinto/sogo/)**. To use Transifex,
you must first sign up for a [free account](https://www.transifex.com/signup/). Once registered,
[request a new team](https://www.transifex.com/alinto/teams/) for your language. Once authorized,
you'll be able to start/continue translating SOGo in your language.

The second type are **wox and html templates**. Only words outside the tags (<>) must be
translated. Start by duplicating the English templates:

* [UI/Templates/SOGoACLEnglishAdditionAdvisory.wox](https://raw.githubusercontent.com/alinto/sogo/master/UI/Templates/SOGoACLEnglishAdditionAdvisory.wox)
* [UI/Templates/SOGoACLEnglishRemovalAdvisory.wox](https://raw.githubusercontent.com/alinto/sogo/master/UI/Templates/SOGoACLEnglishRemovalAdvisory.wox)
* [UI/Templates/SOGoACLEnglishModificationAdvisory.wox](https://raw.githubusercontent.com/alinto/sogo/master/UI/Templates/SOGoACLEnglishModificationAdvisory.wox)
* [UI/Templates/SOGoFolderEnglishAdditionAdvisory.wox](https://raw.githubusercontent.com/alinto/sogo/master/UI/Templates/SOGoFolderEnglishAdditionAdvisory.wox)
* [UI/Templates/SOGoFolderEnglishRemovalAdvisory.wox](https://raw.githubusercontent.com/alinto/sogo/master/UI/Templates/SOGoFolderEnglishRemovalAdvisory.wox)
* [SoObjects/Mailer/SOGoMailEnglishForward.wo/SOGoMailEnglishForward.html](https://raw.githubusercontent.com/alinto/sogo/master/SoObjects/Mailer/SOGoMailEnglishForward.wo/SOGoMailEnglishForward.html)
* [SoObjects/Mailer/SOGoMailEnglishReply.wo/SOGoMailEnglishReply.html](https://raw.githubusercontent.com/alinto/sogo/master/SoObjects/Mailer/SOGoMailEnglishReply.wo/SOGoMailEnglishReply.html)

The third type is the locale file formatted as a **plist**. Duplicate the English locale. Beware that words with other characters than [a-zA-Z] (accents, non-latin...) must be between double quotes ("). You can look at other files as arabic or french to have an example:

* [UI/MainUI/English.lproj/Locale](https://raw.githubusercontent.com/alinto/sogo/master/UI/MainUI/English.lproj/Locale)

Once translated, create an archive with all the files and [contact
us](https://sogo.nu/support.html#/commercial). We'll integrate it in the next version of SOGo.

### Git Commit Guidelines

We have very precise rules over how our git commit messages can be formatted. This leads to **more
readable messages** that are easy to follow when looking through the **project history**.

It is important to note that we use the git commit messages to **generate** the
[CHANGELOG](../CHANGELOG.md) document. Improperly formatted commit messages may result in your
change not appearing in the CHANGELOG of the next release.

### Commit Message Format
Each commit message consists of a **header**, a **body** and a **footer**. The header has a special
format that includes a **type**, a **scope** and a **subject**:

```html
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

> Any line of the commit message cannot be longer than 100 characters.
> This allows the message to be easier to read on GitHub as well as in various Git tools.

#### Type
Must be one of the following:

* **feat**: A new feature
* **fix**: A bug fix
* **docs**: Documentation only changes
* **i18n**: Change in localizable strings
* **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing
  semi-colons, etc)
* **refactor**: A code change that neither fixes a bug nor adds a feature
* **perf**: A code change that improves performance
* **test**: Adding missing tests
* **chore**: Changes to the build and packaging process or auxiliary tools (sogo-tool,
  sogo-ealarms-notify) and libraries such as documentation generation

#### Scope
The scope could be anything that helps specifying the scope (or feature) that is changing.

Examples

* mail
* mail(js)
* calendar(css)
* addressbook
* preferences(js)
* core
* eas

#### Subject
The subject contains a succinct description of the change:

* use the imperative, present tense: "change" not "changed" nor "changes"
* don't capitalize first letter
* no dot (.) at the end

#### Body
Just as in the **subject**, use the imperative, present tense: "change" not "changed" nor "changes"
The body should include the motivation for the change and contrast this with previous behavior.

#### Footer
The footer should contain any information about **Breaking Changes** and is also the
place to reference [Mantis](https://bugs.sogo.nu) issues that this commit **Fixes** or **Resolves**.

> Breaking Changes are intended to be highlighted in the CHANGELOG as changes that will require
> community users to modify their code after updating to a version that contains this commit.

#### Sample Commit messages
```text
fix(calendar): don't raise exception when renaming with same name

this would break Apple Calendar.app when creating a new calendar

Fixes #4813
```
```text
feat(calendar(js)): optionally expand LDAP groups in attendees editor

* add `/members` action for LDIF groups
* add button to expand invited LDAP groups

Fixes #2506
```
```text
fix(core): set default Sieve port to 4190

BREAKING CHANGE: the default port for the SOGoSieveServer configuration default is now 4190 (was
2000).

You need to explicitly set the port if you use a different port.

Closes #4826
```
