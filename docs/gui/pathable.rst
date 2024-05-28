gui/pathable
============

.. dfhack-tool::
    :summary: Highlights tiles reachable from the selected tile.
    :tags: fort inspection map

This tool highlights each visible map tile to indicate whether it is possible to
path to that tile from the tile under the mouse cursor. You can move the mouse
(and the map) around and the highlight will change dynamically.

If graphics are enabled, then tiles show a small yellow box if they are pathable
and a small black box if not.

In ASCII mode, the tiles are highlighted in green if pathing is possible and red
if not.

While the UI is active, you can use the following hotkeys to change the
behavior:

- :kbd:`Ctrl`:kbd:`t`: Lock target: when enabled, you can move the map around
  and the target tile will not change. This is useful to check whether parts of
  the map far away from the target tile can be pathed to from the target tile.
- :kbd:`Ctrl`:kbd:`d`: Draw: allows temporarily disabling the highlighting
  entirely. This allows you to see the map without the highlights, if desired.
- :kbd:`Ctrl`:kbd:`u`: Skip unrevealed: when enabled, unrevealed tiles will not
  be highlighted at all instead of being highlighted as not pathable. This might
  be useful to turn off if you want to see the pathability of unrevealed cavern
  sections.

You can drag the informational panel around while it is visible if it's in the
way.

.. note::
    This tool uses a cache used by DF, which currently does *not* account for
    climbing or flying. If an area of the map is only accessible by climbing or
    flying, this tool may report it as inaccessible. Care should be taken when
    digging into the upper levels of caverns, for example.

Usage
-----

::

  gui/pathable
