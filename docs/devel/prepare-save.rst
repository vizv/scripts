devel/prepare-save
==================

.. dfhack-tool::
    :summary: Set internal game state to known values for memory analysis.
    :tags: unavailable

.. warning::

    THIS SCRIPT IS STRICTLY FOR DFHACK DEVELOPERS.

This script prepares the current savegame to be used with `devel/find-offsets`.
It **CHANGES THE GAME STATE** to predefined values, and initiates an immediate
`quicksave`, thus PERMANENTLY MODIFYING the save.

Usage
-----

::

    devel/prepare-save
