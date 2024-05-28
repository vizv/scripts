fix/item-occupancy
==================

.. dfhack-tool::
    :summary: Fixes errors with phantom items occupying site.
    :tags: unavailable

This tool diagnoses and fixes issues with nonexistent 'items occupying site',
usually caused by hacking mishaps with items being improperly moved about.

Usage
-----

::

    fix/item-occupancy

Technical details
-----------------

This tool checks that:

#. Item has ``flags.on_ground`` <=> it is in the correct block item list
#. A tile has items in block item list <=> it has ``occupancy.item``
#. The block item lists are sorted
