gui/journal
===========

.. dfhack-tool::
    :summary: Fort journal with a multi-line rich text editor.
    :tags: fort interface

The `gui/journal` plugin provides a handy tool to document
the important details for the fortresses.

With this multi-line rich text editor,
you can keep track of your fortress's background story, goals, notable events,
and both short-term and long-term plans.

This is particularly useful when you need to take a longer break from the game.
Having detailed notes makes it much easier to resume your game after
a few weekds or months, without losing track of your progress and objectives.

Supported Features
------------------

- Cursor Control: Navigate through text using arrow keys (left, right, up, down) for precise cursor placement.
- Fast Rewind: Quickly move the cursor by using 'Shift+Left'/'Alt+B' to jump backward and 'Shift+Right'/'Alt+F' to jump forward by words.
- Longest X Position Memory: The cursor remembers the longest x position when moving up or down, making vertical navigation more intuitive.
- Mouse Control: Use the mouse to position the cursor within the text, providing an alternative to keyboard navigation.
- New Lines: Easily insert new lines using the submit key, supporting multiline text input.
- Text Wrapping: Text automatically wraps within the editor, ensuring lines fit within the display without manual adjustments.
- Backspace Support: Use the backspace key to delete characters to the left of the cursor.
- Delete Character: 'Ctrl+D' deletes the character under the cursor.
- Line Navigation: 'Ctrl+A' moves the cursor to the beginning of the current line, and 'Ctrl+E' moves it to the end.
- Delete Current Line: 'Ctrl+U' deletes the entire current line where the cursor is located.
- Delete Last Word: 'Ctrl+W' removes the word immediately before the cursor.
- Text Selection: Select text with the mouse, with support for replacing or removing selected text.
- Clipboard Operations: Perform local cut, copy, and paste operations on selected text or the current line using 'Ctrl+X', 'Ctrl+C', and 'Ctrl+V'.
- Jump to Beginning/End: Quickly move the cursor to the beginning or end of the text using 'Shift+Up' and 'Shift+Down'.

Usage
-----

::

    gui/journal
