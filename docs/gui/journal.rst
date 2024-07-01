gui/journal
===========

.. dfhack-tool::
    :summary: Fort journal with a multi-line text editor.
    :tags: fort interface

The `gui/journal` interface makes it easy to take notes and document
important details for the fortresses.

With this multi-line text editor,
you can keep track of your fortress's background story, goals, notable events,
and both short-term and long-term plans.

This is particularly useful when you need to take a longer break from the game.
Having detailed notes makes it much easier to resume your game after
a few weekds or months, without losing track of your progress and objectives.

Supported Features
------------------

- Cursor Control: Navigate through text using arrow keys (left, right, up, down) for precise cursor placement.
- Fast Rewind: Use :kbd:`Shift+Left`/:kbd:`Ctrl+B` and :kbd:`Shift+Right`/:kbd:`Ctrl+F`to move the cursor one word back or forward
- Longest X Position Memory: The cursor remembers the longest x position when moving up or down, making vertical navigation more intuitive.
- Mouse Control: Use the mouse to position the cursor within the text, providing an alternative to keyboard navigation.
- New Lines: Easily insert new lines using the :kbd:`Enter` key, supporting multiline text input.
- Text Wrapping: Text automatically wraps within the editor, ensuring lines fit within the display without manual adjustments.
- Backspace Support: Use the backspace key to delete characters to the left of the cursor.
- Delete Character: :kbd:`Ctrl+D` deletes the character under the cursor.
- Line Navigation: :kbd:`Ctrl+H` (like "Home") moves the cursor to the beginning of the current line, and :kbd:`Ctrl+E` (like "End") moves it to the end.
- Delete Current Line: :kbd:`Ctrl+U` deletes the entire current line where the cursor is located.
- Delete Rest of Line: :kbd:`Ctrl+K` deletes text from the cursor to the end of the line.
- Delete Last Word: :kbd:`Ctrl+W` removes the word immediately before the cursor.
- Text Selection: Select text with the mouse, with support for replacing or removing selected text.
- Jump to Beginning/End: Quickly move the cursor to the beginning or end of the text using :kbd:`Shift+Up` and :kbd:`Shift+Down`.
- Select Word/Line: Use double click to select current word, or triple click to select current line
- Select All: Select entire text by :kbd:`Ctrl+A`
- Clipboard Operations: Perform OS clipboard cut, copy, and paste operations on selected text, allowing you to paste the copied content into other applications.
- Copy Text: Use :kbd:`Ctrl+C` to copy selected text.
  - copy selected text, if available
  - If no text is selected it copy the entire current line, including the terminating newline if present.
- Cut Text: Use :kbd:`Ctrl+X` to cut selected text.
  - cut selected text, if available
  - If no text is selected it will cut the entire current line, including the terminating newline if present
- Paste Text: Use :kbd:`Ctrl+V` to paste text from the clipboard into the editor.
  - replace selected text, if available
  - If no text is selected, paste text in the cursor position

Usage
-----

::

    gui/journal
