fix/gifted-pets
===============

.. dfhack-tool::
    :summary: Fixes pets you gift in adventure mode.
    :tags: adventure bugfix

For companions, this script fixes their pets not being added to your adventurer party,
preventing their pets from getting lost in fast-travel and being forced to follow you as a separate army.

If run after you gift a pet to a unit outside of your party, this script prevents those pets from being lost in the site and ignoring their pet owner's associated
home building. It also removes the link the pet erroneously retains to your companion data.

Usage
-----

::

    fix/gifted-pets
