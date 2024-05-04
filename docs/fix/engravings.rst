fix/engravings
=============

.. dfhack-tool::
    :summary: Fixes unengravable corrupted tiles so they are able to be engraved.
    :tags: fort bugfix

When placing a new wall or new floor down where a previous engraved tiletype was, the tile may be corrupted and unengravable. 
This fix removes corrupted engravings from those tiles automatically so those tiletypes may be engraved again.

Usage
-----

::

    fix/engravings [<options>]

Options
-------

``-q``, ``--quiet``
    Only output status when something was actually fixed.