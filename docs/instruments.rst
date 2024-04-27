instruments
===========

.. dfhack-tool::
    :summary: Show how to craft instruments, create instrument work orders.
    :tags: fort inspection workorders


This tool is used to query information about instruments, and create work orders for them.

The list subcommand provides information on how to craft the instruments used by the
player civilization. For single-piece instruments, it shows the skill and
material needed to craft it. For multi-piece instruments, it displays the skill
used in its assembly as well as information on how to craft the necessary
pieces. It also shows whether the instrument is handheld or placed as a
building.

The order subcommand is used to create work orders for an instrument and all of it's parts.
The final assemble instrument -order waits for the part orders to complete before starting.

Usage
-----

``instruments``, ``instruments list``
List instruments and their recipes

``instruments order <instrument_name> [<amount>]``
Creates work orders for the specified instrument. Default amount is 1.

Examples
--------

``instruments order givel 10``
Creates a total of 5 work orders. One for assembling 10 givels, and one to create 10 of
each of the givel parts. (Note: Instruments are randomly generated, so you probably won't have the same givel in your game)

``instruments order ilul``
Creates work orders to assemble one ïlul. Spelling doesn't need to include the special ï character.
