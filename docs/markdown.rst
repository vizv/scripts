markdown
========

.. dfhack-tool::
    :summary: Export displayed text to a Markdown file.
    :tags: dfhack items units

Saves the description of a selected unit or item to a Markdown file encoded in UTF-8

By default, data is stored in `/markdown_{YourWorldName}.md`
file in the root game directory.

For units, the script retrieves:
#. Name, race, age, profession
#. Description from the Unit/Health/Description screen
#. Traits from the Unit/Personality/Traits screen
For items, it retrieves:
#. Decorated name (e.g., "☼«☼Chalk Statue of Dakas☼»☼")
#. Full description from the item's view sheet
The script works for most items with in-game descriptions and names, including those in storage,
on the ground, installed as a building, or worn/carried by units.

By default, entries are appended, not overwritten, allowing the ``markdown`` command
to compile descriptions of multiple items & units in a single document.

Usage
-----

::

    markdown [-o | --overwrite] [<filename>]

Appends the description of the selected unit/item
to ``markdown_{world_name}.md`` file by default.

Specifying a filename will append to ``markdown_{filename}.md`` instead,
which is useful for organizing data by category or topic.
To include whitespace, quote the ``<filename>`` in double quotes ``"``.

The [-o] argument tells the script to overwrite the output file.

Hotkeys
-----

::

    Shift-R

Calls the ``markdown`` command when unit or item is selected.

You can create your own keybinding to save descriptions to a custom filename:

- With the ``gui/quickcmd`` tool:
Go to call the tool with Ctrl-Shift-A, then Add command:
::

    markdown -o descriptions


If "markdown -o descriptions" is the first entry in the list of hotkeys,
then clicking ``a`` while the ``gui/quickcmd`` (Ctrl-Shift-A) is open
will overwrite the description to the "markdown_descriptions" file.

- With the ``keybinding`` tool:

::

    keybinding add [hotkey]@dwarfmode/ViewSheets/UNIT|dwarfmode/ViewSheet "markdown [arguments]"


Specify the ``[hotkey]``, which is a case-sensitive combination of keys,
and ``[arguments]``, which are your regular markdown arguments.
You have to put ``markdown`` and its arguments into double quotes for
arguments to be processed.

One example can be:
::

    keybinding add Ctrl-Shift-S@dwarfmode/ViewSheets/UNIT|dwarfmode/ViewSheet "markdown -o descriptions"



Options
-------

``-o``, ``--overwrite``
    Overwrite the output file, deleting previous entries.

Examples
--------

::

    markdown

Example output for a selected chalk statue in the world "Orid Tamun", appended to the default ``markdown_Orid_Tamun.md`` file:

    [...previous entries...]

    ### ☼Chalk Statue of Bìlalo Bandbeach☼

    #### Description:
    This is a well-crafted chalk statue of Bìlalo Bandbeach. The item is an image of
    Bìlalo Bandbeach the elf and Lani Lyricmonks the Learned the ettin in chalk by
    Domas Uthmiklikot. Lani Lyricmonks the Learned is striking down Bìlalo Bandbeach.
    The artwork relates to the killing of the elf Bìlalo Bandbeach by the
    ettin Lani Lyricmonks the Learned with Hailbite in The Forest of Indignation in 147.

    ---
::

    ``markdown -o descriptions``

Example output for a selected unit Lokum Alnisendok, written to the newly overwritten ``markdown_descriptions.md`` file:
::

    ### Lokum Alnisendok, dwarf, 27 years old Presser.

    #### Description:
    A short, sturdy creature fond of drink and industry.

    He is very quick to tire.

    His very long beard is neatly combed.  His very long sideburns are braided.
    His very long moustache is neatly combed.  His hair is clean-shaven.  He is average in size.
    His nose is sharply hooked.  His nose bridge is convex.  His gold eyes are slightly wide-set.
    His somewhat tall ears are somewhat narrow.  His hair is copper.  His skin is copper.

    #### Personality:
    He has an amazing memory, but he has a questionable spatial sense and poor focus.

    He doesn't generally think before acting.  He feels a strong need to reciprocate any favor done for him.
    He enjoys the company of others.  He does not easily hate or develop negative feelings.  He generally
    finds himself quite hopeful about the future.  He tends to be swayed by the emotions of others.
    He finds obligations confining, though he is conflicted by this for more than one reason.  He doesn't
    tend to hold on to grievances.  He has an active imagination.

    He needs alcohol to get through the working day.

    ---
