<p align="center"><img src="Assets/AppIcon.png" width="96" alt="Assignment Dates app icon"></p>

# When the F*ck Are My Assignments Due?

**For students whose degree apparently includes a minor in navigating Canvas.**

This app began with one extremely reasonable question:

> “When the f*ck are my assignments due?”

A date. A time. Ideally, some notice before both become the past.

Your next deadline lives in the Mac menu bar. Click for the rest of the damage.

<p align="center"><img src="Assets/Screenshots/menu-bar.jpg" width="560" alt="Menu-bar agenda showing sample upcoming assignments"></p>

Then the questions escalated.

## “How the f*ck do I find the important stuff quickly?”

The brief. The rubric. The feedback. That PDF your lecturer mentioned once, three weeks ago.

Bring them together on the assignment page. Search your subjects, see what’s coming up, and spend less time opening tabs called “Assessment information (updated) FINAL”.

<p align="center"><img src="Assets/Screenshots/assignments.jpg" width="1000" alt="Assignments window showing sample coursework and automatically collected assignment materials"></p>

## “How the f*ck do I download this stuff?”

One week. All weeks. Straight to Downloads.

Keep the module folders, grab the original PDFs and spreadsheets, and get on with it. Preview a file, save it, or drag a ready copy into another app.

Your mouse has suffered enough.

## “Can I get all my course stuff into AI for my assignments?”

Get the requirements and teaching materials together, then take the files to your AI of choice.

So your first fifteen messages can stop being:

> “Wait, there’s another PDF.”
>
> “And the rubric.”
>
> “Actually, that was last week’s rubric.”

Copy a complete rubric. Bring along feedback from a previous assessment when you need it. You choose what to share and where it goes.

<sub>Sample coursework shown.</sub>

## Build it

Apple Silicon · macOS 27 · Xcode with the macOS 27 SDK · University of Sydney Canvas.

```sh
./build.sh
open 'dist/Assignment Dates.app'
```

Add your Canvas access token in **Settings → Update API key…**, then click the menu bar countdown to get started.
