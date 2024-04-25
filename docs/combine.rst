combine
=======

.. dfhack-tool::
    :summary: Combine items that can be stacked together.
    :tags: fort productivity items plants stockpiles

Usage
-----

::

    combine (all|here) [<options>]

Examples
--------

``combine``
    Displays help
``combine all --dry-run``
    Preview stack changes for all types in all stockpiles.
``combine all``
    Merge stacks for all stockpile and all types
``combine all --types=meat,plant``
    Merge ``meat`` and ``plant`` type stacks in all stockpiles.
``combine here``
    Merge stacks in the selected stockpile.

Commands
--------

``all``
    Search all stockpiles.
``here``
    Search the currently selected stockpile.

Options
-------

``-d``, ``--dry-run``
    Display the stack changes without applying them.

``-t``, ``--types <comma separated list of types>``
    Filter item types. Default is ``all``. Valid types are:

        ``all``:     all of the types listed here.
        ``ammo``:    AMMO. Qty max 25.
        ``drink``:   DRINK. Qty max 25.
        ``fat``:     GLOB and CHEESE. Qty max 5.
        ``fish``:    FISH, FISH_RAW and EGG. Qty max 5.
        ``food``:    FOOD. Qty max 20.
        ``meat``:    MEAT. Qty max 5.
        ``parts``:   CORPSEPIECE. Material max 30.
        ``plant``:   PLANT and PLANT_GROWTH. Qty max 5.
        ``powders``: POWDERS_MISC. Qty max 10.

``-q``, ``--quiet``
    Only print changes instead of a summary of all processed stockpiles.

``-v``, ``--verbose n``
    Print verbose output, n from 1 to 4.

Notes
-----

The following conditions prevent an item from being combined:
    1. An item is not in a stockpile.
    2. An item is sand or plaster.
    3. An item is rotten, forbidden, marked for dumping/melting, on fire, encased, owned by a trader/hostile/dwarf or is in a spider web.
    4. An item is part of a corpse and is not butchered.

The following categories are defined:
    1. Corpse pieces, grouped by piece type and race
    2. Items that have an associated race/caste, grouped by item type, race, and caste
    3. Ammo, grouped by ammo type, material, and quality. If the ammo is a masterwork, it is also grouped by who created it.
    4. Anything else, grouped by item type and material.
