# When the F*ck Are My Assignments Due?

**A native macOS menu bar app for Canvas, born from one extremely reasonable question.**

The app is officially called **Assignment Dates**. Its original project brief was:

> “When the f*ck are my assignments due?”

A date. A time. Ideally, some notice before both of those things become the past.

Then the scope developed in the traditional manner: someone used the software.

## The increasingly ambitious student questions

### 1. “When the f*ck are my assignments due?”

Your next deadline lives in the menu bar. Click it for an agenda grouped by day, with subject codes and actual Canvas due dates.

Sydney time, including daylight saving. Because discovering an assignment exists at 11:58 pm is exciting enough without also discovering a time zone.

### 2. “How the f*ck do I find the important stuff quickly?”

Open **Assignments** for searchable subjects and **Upcoming**, **Feedback** and **All** filters. Each assignment has **Materials**, **Feedback** and **Submission** tabs.

Find the brief, complete marking rubric, lecturer comments, released marks and feedback attachments in one place. Copy the rubric—including the rating descriptions hiding inside collapsed sections—or reuse feedback from an earlier assessment.

The rubric can finally leave its little accordion prison.

### 3. “How the f*ck do I download this stuff?”

Open **Module Files**, choose a subject, then save one week or every module to Downloads.

Original documents stay together in module folders. Page images, readable Canvas page copies and source links are available too. Preview a file, save a copy, or drag a ready file into another app.

Repeated saves create new folders. Your lovingly edited previous export survives another enthusiastic click.

Downloads run in parallel, with a shared queue, automatic retries and backoff when Canvas asks everyone to calm down. The app handles that conversation. You have an assignment to avoid thinking about.

### 4. “With all this AI around, can I just get my course stuff into it?”

Yes: collect the assignment requirements and teaching materials, then take the available files to your AI of choice.

So your first fifteen messages can stop being:

> “Wait, there’s another PDF.”
>
> “And the rubric.”
>
> “Actually, that was last week’s rubric.”

Assignment materials appear directly on the assignment page and fetch automatically from Canvas. Your own submissions and lecturer feedback stay separate from the default teaching-material bundle, with their own copy/save actions.

**You choose where the files go.** The app does not automatically upload your coursework or send it to an AI service.

## The boring bits that make the funny bits useful

- **Native Mac windows:** opening Assignments, Module Files or Settings brings the app into the Dock. Minimise and restore normally; closing the last window returns to menu bar mode.
- **Readable controls:** adjustable 100–200% reading size, wrapping file rows, labelled actions and full-width disclosure targets. The little arrow is no longer your entire target.
- **Proper file actions:** native Quick Look, Save panels, Finder reveal, sharing and file-transfer representations.
- **Useful offline copies:** previously saved information remains available when Canvas, Wi-Fi or your motivation takes the afternoon off.
- **Honest missing-material states:** locked files and external tools get collection notes. The app cannot download a PDF that your lecturer has not made available, even if you stare at it with academic urgency.
- **A saved key that stays saved:** the Canvas token lives in macOS Keychain. App features share a cached credential read; builds and ordinary updates do not reset it.

## Get it running

Currently built for **University of Sydney Canvas**, **Sydney dates**, and an **Apple Silicon Mac running macOS 27**. Other Canvas institutions need configuration changes; this is not yet a universal Canvas client.

To build, install Xcode with the macOS 27 SDK, then run:

```sh
./test.sh
./build.sh
open 'dist/Assignment Dates.app'
```

Use **Settings → Update API key…** to supply your Canvas access token. Keep it out of Git. If a key is already saved, the app continues using it.

Click the menu bar countdown/calendar to open the agenda. Choose **Assignments…** or **Module Files…** for the larger windows. **⌘,** opens Settings; **⌘⇧M** opens Assignments. Use **View → Larger Text / Smaller Text / Actual Size** or the text-size toolbar menu to adjust reading size.

Build somewhere else with:

```sh
ASSIGNMENT_DATES_OUTPUT_DIR=/absolute/output/folder ./build.sh
```

See the [technical guide](docs/technical-guide.md) for storage, API behaviour and test details.

## Verification, without the interpretive dance

Automated checks cover Canvas pagination, course boundaries, retries, throttling, bounded concurrency, cancellation, offline preservation, complete rubric copies and exact exported file bytes/names. All test academic data is synthetic.

For the native window and menu checks, run this in a logged-in macOS session:

```sh
./test-windows.sh
```

These check Dock/minimise/restore behaviour and the app’s reading-size menu commands. Native file-transfer receiver tests pass. A completed pointer drag into Finder still needs manual verification: the automation tool left a drag gesture unfinished. Full VoiceOver and measured contrast verification also remain open.

## Next episodes of “surely this should be one click”

Planned, rather than secretly switched on:

- Choose subjects to keep offline during onboarding.
- Download their teaching materials in one initial pass.
- Opt into hourly, daily or weekly checks for changes.
- Keep background download progress easy to find after navigating elsewhere.

Existing deadline refreshes already run every 30 minutes while the app is running, with additional wake/open checks. Configurable teaching-material schedules are future work.

## Why this exists

University already gives you enough reading.

Finding the reading should not be an additional assessment.
