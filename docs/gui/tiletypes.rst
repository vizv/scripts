gui/tiletypes
=============

.. dfhack-tool::
    :summary: Interactively paint tiles of specified types onto the map.
    :tags: fort armok map

This tool is a gui for placing and modifying tiles and tile properties,
allowing you to click and paint the specified options onto the map.

.. warning::

    There is **no undo support**. This tool can be dangerous, be sure
    to save your game before making any changes.

Usage
-----

::

    gui/tiletypes [<options>]

Options
-------

``-f``, ``--unrestricted``
    Include non-standard materials in the list when choosing a tile material.
