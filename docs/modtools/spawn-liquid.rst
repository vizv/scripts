modtools/spawn-liquid
=====================

.. dfhack-tool::
    :summary: Spawn a liquid at a given position.
    :tags: dev

This script spawns liquid at the given coordinates.

Usage
-----

::

    modtools/spawn-liquid --type <type> --level <level> --position <x>,<y>,<z>

Options
-------

``--type <type>``
    Liquid tile type:
        Water
        Magma
``--level <level>``
    The amount of liquid units to spawn from 1-7.
``--position <x>,<y>,<z>``
    The position at which to spawn the liquid.

Examples
--------

``modtools/spawn-liquid --type Water --level 7 --position 60,60,143``
    Spawn 7/7 Water on tile coordinates 60, 60, 143
