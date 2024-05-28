suspend
=======

.. dfhack-tool::
    :summary: Suspends building construction jobs.
    :tags: fort productivity jobs

This tool will suspend jobs. It can either suspend all the current jobs, or only
construction jobs that are likely to block other jobs. When building walls, it's
common that wall corners get stuck because dwarves build the two adjacent walls
before the corner. The ``--onlyblocking`` option will only suspend jobs that can
potentially lead to this situation.

See `suspendmanager` in `gui/control-panel` to automatically suspend and
unsuspend jobs.

Usage
-----

::

    suspend

Options
-------

``-b``, ``--onlyblocking``
    Only suspend jobs that are likely to block other jobs.

.. note::

    ``--onlyblocking`` does not check pathing (which would be very expensive); it only
    looks at immediate neighbours. As such, it is possible that this tool will miss
    suspending some jobs that prevent access to other farther away jobs, for example
    when building a large rectangle of solid walls.
