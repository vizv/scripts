advtools
========

.. dfhack-tool::
    :summary: A collection of useful adventure mode tools.
    :tags: adventure interface gameplay units

Usage
-----

::

    advtools party
    advtools pets

Party
-----

``advtools party``
    Shows a dialog prompt to promote your extra party members to your core (controllable) party.

``party`` Command
-----------------

When you run this command, you will get a list of your extra party members and can choose
who to promote into your "core party", aka let you control them in the tactics mode, not
dissimilar to what you get if you create a group of adventurers during character creation.

Pets
----

``advtools pets``
    Fixes companion pets and pets you have gifted to prevent buggy behavior and crashes.

``pets`` Command
----------------

Run this command after you gift a pet or after you hire a companion who has their own pets following them.
This should fix pets not joining you during fast travel, potential duplication issues, and gifted pets
still being part of your party despite being given away.

For companions, this script fixes their pets not being added to your adventurer party,
preventing their pets from getting lost in fast-travel and being forced to follow you as a separate army.

If run after you gift a pet to a unit outside of your party, this script prevents those pets from being lost in the site and
ignoring their pet owner's associated home building. It also removes the link the pet erroneously retains to your companion data.

Overlays
--------

This tool provides several functions that are managed by the overlay
framework. They can be repositioned via `gui/overlay` or toggled via
`gui/control-panel`.

``advtools.conversation``
~~~~~~~~~~~~~~~~~~~~~~~~~

When enabled, this overlay will automatically add additional searchable
keywords to conversation topics. In particular, topics that relate to slain
enemies will gain the ``slay`` and ``kill`` keywords. It will also add additional
conversation options for asking whereabouts of your relationships - in vanilla,
you can only ask whereabouts of historical figures involved in rumors you personally
witnessed or heard about.
