max-wave
========

.. dfhack-tool::
    :summary: Dynamically limit the next immigration wave.
    :tags: unavailable

Limit the number of migrants that can arrive in the next wave by
overriding the population cap value from data/init/d_init.txt.
Use with the `repeat` command to set a rolling immigration limit.
Original credit was for Loci.

If you edit the population caps using `gui/settings-manager` after
running this script, your population caps will be reset and you may
get more migrants than you expected.

Usage
-----

::

    max-wave <wave_size> [max_pop]

Examples
--------

::

    max-wave 5
    repeat -time 1 -timeUnits months -command [ max-wave 10 200 ]

The first example ensures the next migration wave has 5 or fewer
immigrants. The second example ensures all future seasons have a
maximum of 10 immigrants per wave, up to a total population of 200.
