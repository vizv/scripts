adaptation
==========

.. dfhack-tool::
    :summary: Adjust a unit's cave adaptation level.
    :tags: unavailable

View or set level of cavern adaptation for the selected unit or the whole fort.

Usage
-----

::

    adaptation show him|all
    adaptation set him|all <value>

The ``value`` must be between 0 and 800,000 (inclusive), with higher numbers
representing greater levels of cave adaptation.

Examples
--------

``adaptation set all 0``
    Clear the cave adaptation levels for all dwarves.
