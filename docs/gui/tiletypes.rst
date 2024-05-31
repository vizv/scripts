gui/tiletypes
=============

.. dfhack-tool::
    :summary: Interactively paint tiles of specified types onto the map.
    :tags: fort armok map

This tool is a gui for placing and modifying tiles and tile properties,
allowing you to click and paint the specified options onto the map.

.. warning::

    There is **no undo support**. This tool can be dangerous, be sure
    you know what you are doing before making any changes.

Usage
-----

::

    gui/tiletypes
    gui/tiletypes --unrestricted

Options
-------

``-f``, ``--unrestricted``
    Include world-gen materials as available options.
