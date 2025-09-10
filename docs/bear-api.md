[bear.app](https://bear.app/faq/x-callback-url-scheme-documentation/) 

# Bear 

12--15 minutes

---

Bear implements the [x-callback-url](http://x-callback-url.com/) protocol, which allow iOS and Mac developers to expose and document API methods they make available to other apps and return useful data. 

Bear URL Scheme actions look like this: 

`bear://x-callback-url/[action]?[action parameters]&[x-callback parameters]` 

with x-success and x-error as available x-callback parameters. 

## Actions 

* /open-note - /create
* /add-text - /add-file
* /tags - /open-tag - /rename-tag- /delete-tag
* /trash - /archive - /untagged - /todo- /today - /locked
* /search - /grab-url 

### /open-note 

Open a note identified by its title or id and return its content. 

**parameters** 

* **id** _optional_ note unique identifier.
* **title** _optional_ note title.
* **header** _optional_ an header inside the note.
* **exclude\_trashed** _optional_ if `yes` exclude trashed notes.
* **new\_window** _optional_ if `yes` open the note in an external window (MacOS only).
* **float** _optional_ if `yes` makes the external window float on top (MacOS only).
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **open\_note** _optional_ if `no` do not display the new note in Bear's main or external window.
* **selected** _optional_ if `yes` return the note currently selected in Bear (token required)
* **pin** _optional_ if `yes` pin the note to the top of the list.
* **edit** _optional_ if `yes` place the cursor inside the note editor.
* **search** _optional_ opens the in-note find&replace panel with the specified text 

**x-success** 

* **note** note text.
* **identifier** note unique identifier.
* **title** note title.
* **tags** note tags array
* **is\_trashed** `yes` if the note is trashed.
* **modificationDate** note modification date in [ISO 8601 format](https://en.wikipedia.org/wiki/ISO_8601).
* **creationDate** note creation date in [ISO 8601 format](https://en.wikipedia.org/wiki/ISO_8601). 

**example** 

`bear://x-callback-url/open-note?id=7E4B681B` `bear://x-callback-url/open-note?id=7E4B681B&header=Secondary%20Ttitle` 

Create and try /open-note actions in seconds with our [URL builder online](https://bear.app/xurl/open-note/) 

---

### /create 

Create a new note and return its unique identifier. Empty notes are not allowed. 

**parameters** 

* **title** _optional_ note title.
* **text** _optional_ note body.
* **clipboard** _optional_ if `yes` use the text currently available in the clipboard
* **tags** _optional_ a comma separated list of tags.
* **file** _optional_ base64 representation of a file.
* **filename** _optional_ file name with extension. Both _file_ and _filename_ are required to successfully add a file.
* **open\_note** _optional_ if `no` do not display the new note in Bear's main or external window.
* **new\_window** _optional_ if `yes` open the note in an external window (MacOS only).
* **float** _optional_ if `yes` make the external window float on top (MacOS only).
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **pin** _optional_ if `yes` pin the note to the top of the list.
* **edit** _optional_ if `yes` place the cursor inside the note editor.
* **timestamp** _optional_ if `yes` prepend the current date and time to the text
* **type** _optional_ if `html` the provided _text_ parameter is converted from html to markdown
* **url** _optional_ if _type_ is `html` this parameter is used to resolve relative image links 

**x-success** 

* **identifier** note unique identifier.
* **title** note title. 

**example** 

`bear://x-callback-url/create?title=My%20Note%20Title&text=First%20line&tags=home,home%2Fgroceries` 

**notes** 

The base64 **file** parameter have to be [encoded](https://www.w3schools.com/tags/ref_urlencode.asp) when passed as an url parameter. 

Create and try /create actions in seconds with our [URL builder online](https://bear.app/xurl/create/) 

---

### /add-text 

append or prepend text to a note identified by its title or id. Encrypted notes can't be accessed with this call. 

**parameters** 

* **id** _optional_ note unique identifier.
* **title** _optional_ title of the note.
* **selected** _optional_ if `yes` use the note currently selected in Bear (token required)
* **text** _optional_ text to add.
* **clipboard** _optional_ if `yes` use the text currently available in the clipboard
* **header** _optional_ if specified add the text to the corresponding header inside the note.
* **mode** _optional_ the allowed values are `prepend`, `append`, `replace_all` and `replace` (keep the note's title untouched).
* **new\_line** _optional_ if `yes` and `mode` is `append` force the text to appear on a new line inside the note
* **tags** _optional_ a comma separated list of tags.
* **exclude\_trashed** _optional_ if `yes` exclude trashed notes.
* **open\_note** _optional_ if `no` do not display the new note in Bear's main or external window.
* **new\_window** _optional_ if `yes` open the note in an external window (MacOS only).
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **edit** _optional_ if `yes` place the cursor inside the note editor.
* **timestamp** _optional_ if `yes` prepend the current date and time to the text 

**x-success** 

* **note** note text.
* **title** note title. 

**example** 

`bear://x-callback-url/add-text?text=new%20line&id=4EDAF0D1&mode=append` 

Create and try /add-text actions in seconds with our [URL builder online](https://bear.app/xurl/add-text/) 

---

### /add-file 

append or prepend a file to a note identified by its title or id. This call can't be performed if the app is a locked state. Encrypted notes can't be accessed with this call. 

**parameters** 

* **id** _optional_ note unique identifier.
* **title** _optional_ note title.
* **selected** _optional_ if `yes` use the note currently selected in Bear (token required)
* **file** _required_ base64 representation of a file.
* **header** _optional_ if specified add the file to the corresponding header inside the note.
* **filename** _required_ file name with extension. Both _file_ and _filename_ are required to successfully add a file.
* **mode** _optional_ the allowed values are `prepend`, `append`, `replace_all` and `replace` (keep the note's title untouched).
* **open\_note** _optional_ if `no` do not display the new note in Bear's main or external window.
* **new\_window** _optional_ if `yes` open the note in an external window (MacOS only).
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **edit** _optional_ if `yes` place the cursor inside the note editor. 

_x-success_ 

* **note** note text 

**example** 

`bear://x-callback-url/add-file?filename=test.gif&id=4EDAF0D1-2EFF-4190-BC1D-67D9BAE49BA9-28433-000187BAA3D182EF&mode=append&file=R0lGODlhAQABAIAAAP%2F%2F%2F%2F%2F%2F%2FyH5BAEKAAEALAAAAAABAAEAAAICTAEAOw%3D%3D` 

**notes** 

The base64 **file** parameter have to be [encoded](https://www.w3schools.com/tags/ref_urlencode.asp) when passed as an url parameter. 

Create and try /add-file actions in seconds with our [URL builder online](https://bear.app/xurl/add-file/) 

---

### /tags 

Return all the tags currently displayed in Bear's sidebar. 

**parameters** 

* **token** _required_ application token. 

_x-success_ 

* **tags** json array representing tags. `[{ name }, ...]` 

**example** 

`bear://x-callback-url/tags?token=123456-123456-123456` 

Create and try /tags actions in seconds with our [URL builder online](https://bear.app/xurl/tags/) 

---

### /open-tag 

Show all the notes which have a selected tag in bear. 

**parameters** 

* **name** _required_ tag name or a list of tags divided by comma
* **token** _optional_ application token. 

_x-success_ 

* **notes** json array representing the tag's notes. `[{ title, identifier, modificationDate, creationDate, pin }, ...]` 

Encrypted notes will be excluded from the notes array. If more than one tag is passed with the `name` parameter this action returns all the notes matching one of the tags passed. 

If _token_ is not provided nothing is returned. 

**example** 

`bear://x-callback-url/open-tag?name=work` `bear://x-callback-url/open-tag?name=todo%2Fwork` 

Create and try /open-tag actions in seconds with our [URL builder online](https://bear.app/xurl/open-tag/) 

---

### /rename-tag 

Rename an existing tag. This call can't be performed if the app is a locked state. If the tag contains any locked note this call will not be performed. 

**parameters** 

* **name** _required_ tag name.
* **new\_name** _required_ new tag name.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only). 

**example** 

`bear://x-callback-url/rename-tag?name=todo&new_name=done` 

Create and try /rename-tag actions in seconds with our [URL builder online](https://bear.app/xurl/rename-tag/) 

---

### /delete-tag 

Delete an existing tag. This call can't be performed if the app is a locked state. If the tag contains any locked note this call will not be performed. 

**parameters** 

* **name** _required_ tag name.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only). 

**example** 

`bear://x-callback-url/delete-tag?name=todo` 

Create and try /delete-tag actions in seconds with our [URL builder online](https://bear.app/xurl/delete-tag/) 

---

### /trash 

Move a note to bear trash and select the Trash sidebar item. This call can't be performed if the app is a locked state. Encrypted notes can't be used with this call. 

**parameters** 

* **id** _optional_ note unique identifier.
* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only). 

**example** 

`bear://x-callback-url/trash?id=7E4B681B` `bear://x-callback-url/trash?search=old` 

**notes** 

The **search** term is ignored if an **id** is provided. 

Create and try /trash actions in seconds with our [URL builder online](https://bear.app/xurl/trash/) 

---

### /archive 

Move a note to bear archive and select the Archive sidebar item. This call can't be performed if the app is a locked state. Encrypted notes can't be accessed with this call. 

**parameters** 

* **id** _optional_ note unique identifier.
* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only). 

**example** 

`bear://x-callback-url/archive?id=7E4B681B` `bear://x-callback-url/archive?search=projects` 

**notes** 

The **search** term is ignored if an **id** is provided. 

Create and try /archive actions in seconds with our [URL builder online](https://bear.app/xurl/archive/) 

---

### /untagged 

Select the Untagged sidebar item. 

**parameters** 

* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **token** _optional_ application token. 

_x-success_ 

* **notes** json array representing the untagged notes. `[{ title, identifier, [tag, ...], modificationDate, creationDate, pin }, ...]` 

Encrypted notes will be excluded from the notes array. 

If _token_ is not provided nothing is returned. 

**example** 

`bear://x-callback-url/untagged?search=home` 

Create and try /untagged actions in seconds with our [URL builder online](https://bear.app/xurl/untagged/) 

---

### /todo 

Select the Todo sidebar item. 

**parameters** 

* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **token** _optional_ application token. 

_x-success_ 

* **notes** json array representing the todo notes. `[{ title, identifier, [tag, ...], modificationDate, creationDate, pin }, ...]` 

Encrypted notes will be excluded from the note array. 

If _token_ is not provided nothing is returned. 

**example** 

`bear://x-callback-url/todo?search=home` 

Create and try /todo actions in seconds with our [URL builder online](https://bear.app/xurl/todo/) 

---

### /today 

Select the Today sidebar item. 

**parameters** 

* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **token** _optional_ application token. 

_x-success_ 

* **notes** json array representing the today notes. `[{ title, identifier, [tag, ...], modificationDate, creationDate, pin }, ...]`f 

Encrypted notes will be excluded from the note array. 

If _token_ is not provided nothing is returned. 

**example** 

`bear://x-callback-url/today?search=family` 

Create and try /today actions in seconds with our [URL builder online](https://bear.app/xurl/today/) 

---

### /locked 

Select the Locked sidebar item. 

**parameters** 

* **search** _optional_ string to search.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only). 

**example** 

`bear://x-callback-url/locked?search=data` 

Create and try /locked actions in seconds with our [URL builder online](https://bear.app/xurl/locked/) 

---

### /search 

Show search results in Bear for all notes or for a specific tag. 

**parameters** 

* **term** _optional_ string to search.
* **tag** _optional_ tag to search into.
* **show\_window** _optional_ if `no` the call don't force the opening of bear main window (MacOS only).
* **token** _optional_ application token. 

_x-success_ 

* **notes** json array representing the note results of the search. `[{ title, identifier, [tag, ...], modificationDate, creationDate, pin }, ...]` 

Encrypted notes will be excluded from the note array. 

If _token_ is not provided nothing is returned. 

**example** 

`bear://x-callback-url/search?term=nemo&tag=movies` 

Create and try /search actions in seconds with our [URL builder online](https://bear.app/xurl/search/) 

---

### /grab-url 

Create a new note with the content of a web page. 

**parameters** 

* **url** _required_ url to grab.
* **tags** _optional_ a comma separated list of tags. If tags are specified in the Bear's web content prefences this parameter is ignored.
* **pin** _optional_ if `yes` pin the note to the top of the list.
* **wait** _optional_ if `no` x-success is immediately called without _identifier_ and _title_. 

**x-success** 

* **identifier** note unique identifier.
* **title** note title. 

**available values** 

`yes` `no` 

**example** 

`bear://x-callback-url/grab-url?url=https://bear.app` 

Create and try /grab-url actions in seconds with our [URL builder online](https://bear.app/xurl/grab-url/) 

## Token Generation 

In order to extend their functionalties, some of the API calls allow an app generated token to be passed along with the other parameters. Please mind a Token generated on iOS is not valid for MacOS and vice-versa. 

On MacOS, select `Help` → `Advanced` →`API Token` → `Copy Token` and will be available in your pasteboard. 

On iOS go to the preferences → `Advanced`, locate the `API Token` section and tap the cell below to generate the token or copy it in your pasteboard. 

## Support 

To discuss URL scheme improvements or reporting bugs please use our [Support Form](https://bear.app/contact/) or [Bear's subreddit](https://reddit.com/r/bearapp).