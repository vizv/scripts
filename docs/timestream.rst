timestream
==========

.. dfhack-tool::
    :summary: Fix FPS death.
    :tags: fort gameplay fps

Do you remember when you first start a new fort, your initial 7 dwarves zip
around the screen and get things done so quickly? As a player, you never had
to wait for your initial dwarves to move across the map. Do you wish that your
fort of 200 dwarves and 800 animals could be as zippy? This tool can help.

``timestream`` keeps the game running quickly by tweaking the game simulation
according to the frames per second that your computer can support. This means
that your dwarves spend the same amount of time relative to the in-game
calendar to do their tasks, but the time that you, the player, have to wait for
the dwarves to do get things done is reduced. The result is that the dwarves in
your fully developed fort appear as energetic as the dwarves in a newly created
fort, and mature forts are much more fun to play.

Note that whereas your dwarves zip around like you're running at 100 FPS, the
onscreen FPS counter, if enabled, will still show a lower number. See the
`Technical details`_` section below if you're interested in what's going on
under the hood.

You can also use this tool to change the in-game calendar speed. Your dwarves
will be able to get less/more done per season (depending on whether you speed
up or slow down the calendar).

Usage
-----

::

    enable timestream
    timestream [status]
    timestream set <key> <value>
    timestream reset

Examples
--------

``enable timestream``
    Start adjusting the simulation to run at the currently configured apparent
    FPS (default is whatever you have the FPS cap set to in the DF settings,
    which is usually 100).

``timestream set fps 50``
    Tweak the simulation so dwarves move at an apparent 50 frames per second.

``timestream set calendar-rate 0.5``
    Make the days twice as long and allow dwarves to accomplish twice as much
    per day.

``timestream set fps -1``
``timestream set calendar-rate 2``
    Don't change the granularity of the simulation, but make the in-game days
    pass twice as quickly, as if the sun sped up across the sky. Units will get
    half as much done as usual per game day.

``timestream reset``
    Reset settings to defaults: the vanilla FPS cap with no calendar speed
    advantage or disadvantage.

Settings
--------

:fps: Set the target simulated FPS. The default target FPS is whatever you have
    the FPS cap set to in the DF settings, and the minimum is 10. Setting the
    target FPS *below* your current actual FPS will have no effect. You have
    to set the vanilla FPS cap for that. Set a target FPS of -1 to make no
    adjustment at all to the apparent FPS of the game.

:calendar-rate: Set the calendar rate in relation to the target FPS. A calendar
    rate factor of 1 means time flows "normally" for the units in the game.
    Values between 0 and 1 slow the calendar relative to the world, allowing
    units to get more done per day, and values above 1 speed the calendar
    relative to the world, causing the days to pass quicker and preventing
    units from getting as much done per day.

:max-frame-skip: Set the maximum number of ticks that can be skipped in one
    step. Dwarves can perform at most one action per step, and if too many
    frames are skipped in one step, dwarves will "lose time" compared to the
    movement of the calendar. The default is 4, which allows a target FPS of up
    to 4x your actual FPS while still allowing dwarves to walk at full speed.
    Raise this value if speed of the simulation is more important to you than
    its accuracy and smoothness.

Technical details
-----------------

So what is this magic? How does this tool make it look like the game is
suddenly running so much faster?

Maybe an analogy would help. Pretend you're standing at the bottom of a
staircase and you want to walk up the stairs. You can walk up one stair every
second, and there are 100 stairs, so it will take you 100 seconds to walk up
all the stairs.

Now let's use the Hand of Armok and fiddle with reality a bit. Let's say that
instead of walking up one step, you walk up 5 steps at once. At the same time
we move the wall clock 5 seconds ahead. If you look at the clock after reaching
the top of the stairs, it will still look like it took 100 seconds, but you did
it all in fewer "steps".

That's essentially what ``timestream`` is doing to the game. All "actions" in
DF have counters associated with them. For example, when a dwarf wants to walk
to the next tile, a counter is initialized to 500. Every "tick" of the game
(the "frame" in FPS) decrements that counter by by a certain amount. When the
counter gets to zero, the dwarf appears on the next tile.

When ``timestream`` is active, it monitors all those counters and makes them
decrement more per tick. It then balances things out by proportionally
advancing the in-game calendar. Therefore, more "happens" per step, and DF has
to simulate fewer "steps" for the same amount of work to get done.

The cost of this simplification is that the world becomes less "smooth". As the
discrepancy between the "natural" and simulated FPS grows, more and more
dwarves will move to their next tiles at *exactly* the same time. Moreover, the
rate of action completion per unit is effectively capped at the granularity of
the simulation, so very fast units will lose some of their advantage. In the
extreme case, with the computer struggling to run at 1 FPS and ``timestream``
simulating thousands of FPS (and the ``max-frame-skip`` cap increased to 20),
all units will perform exactly one action per frame. This would make the game
look robotic. With default settings, it will never get this bad, but you can
always choose to alter the ``timestream`` configuration to your preferred
balance of speed vs. accuracy.

Limitations
-----------

Right now, not all aspects of the game are perfectly adjusted. For example,
armies on world map will move at the same (real-time) rate regardless of
changes that ``timestream`` is making to the calendar.

Here is a (likely incomplete) list of game elements that are not affected by
``timestream``:

- Army movement across the world map (including raids sent out from the fort)
- Liquid movement and evaporation
- Time that caravans stay at the trade depot
- Crop growth rates
