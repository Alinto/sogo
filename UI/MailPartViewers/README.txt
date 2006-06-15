SOGo MailPartViewers
====================

TODO

This product bundle contains components for displaying certain parts of an
email, like the text content, attachments or embedded images.

All the contained classes inherit from UIxMailPartViewer which provides the
majority of the functionality. Subclasses usually only add methods for the
presentation of the content (which in turn is usually done in the templates).

The "master object" which selects appropriate classes and coordinates the
rendering is the UIxMailRenderingContext. The context also maintains a cache
of components for rendering which can then be reused for similiar parts in the
mail. Note that this only works for leaf-content (eg not for recursive ones
like multipart/* viewers).
