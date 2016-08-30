# firepox
A small Firefox session utility for FVWM and others

PURPOSE:
Probably most FVWM users have noticed that the windows no longer get restored correctly on FVWMs virtual screens.

This bad behavior is the consequence of a semi-failed bugfix.
This bug caused windows to get negative coordinates mainly when Flash crashed in full screen mode.
This made them disappear when non-maximized.

Later a regression worsened the situation.
The coordinates stored in the session file no longer were absolute ones, but relative ones.
So they depend on which virtual screen Firefox was started/closed.

I looked a bit into the Firefox code.
Fixing it would cost me too much time to understand it sufficiently.
Thus I decided to write a Firefox starter helper script that fixes/repairs the session file as a small Perl exercise.

USAGE: 
firepox [-w [<URI>] ]

first option: -w indicates that the configuration file actually gets (re)written. 
second option is the URI.
Without options: the script does only a dry run, outputting analytic information about the session file. A present session file will not be modified.

BUGS:
-Windows will be restored on the active desktop. 'Cause Firefox does not store the desktop number in the session file...
-A few others, being fixed in next upload

TRIVIA:
Why this stupid name?
I love Firefox. It is my favorite browser.
Its only major annoyance, its only "pox" is just its inability to restore windows correctly.
Sadly all good names like "Firefix", "Fixfox" etc seem trademarked.
