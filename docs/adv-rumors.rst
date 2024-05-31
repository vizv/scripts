adv-rumors
==========

.. dfhack-tool::
    :summary: Improves the conversation menus in Adventure mode.
    :tags: adventure interface

In adventure mode, start a conversation with someone. This tool will:

- Add all words to keywords for easier filtering/searching everywhere
- Additional 'slay' and 'kill' keywords for choices where someone was slain

Overlay
-------

This script also provides an overlay that is managed by the `gui/overlay` framework.
When the `adv-rumors.conversation` overlay is enabled, the script will automatically run on the convesration screen,
introducing additional keywords.
