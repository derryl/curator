## Running list of user todo's

### Fixes to request format

When tapping "4K" to request a Movie title, the Movie is being requested using Radarr's "4K UltraHD" profile. This is incorrect, please use the Profile labeled "4K" as returned by Overseer.

Expected behavior for the 2 request buttons are as follows:

- Movies: 1080p button = "1080p" Radarr profile, 4K = "4K" Radarr profile
- TV Shows: 1080p button = "1080p" Sonarr profile, 4K = "4K or 1080" Sonarr profile

### Navigation Fixes

There are currently numerous issues with navigation state. The BACK button is still very unreliable at returning to previous screens, and frequently aggressive at exiting the app. Do a thorough review of the navigation structure and implement a more bullet-proof approach to navigation, adhering to the following principles:

For instance consider the following flow.

1. Beginning at App HOME screen
2. navigate to BROWSE
3. navigate to "Action" Movies genre
   x. scroll down the page a ways
4. load a Movie title
5. click one of the Actors to view their Actor Detail page
6. click a Movie the Actor is featured in

Now I start pressing the BACK button. Observe that the flow is reversed: 6. Beginning on Movie detail 5. Pressing BACK returns me to the actor's detail page 4. Pressing BACK returns me to the Movie title 3. ... Browse: "Action" Movies genre, with scroll location preserved 2. ... top of BROWSE tab

1. Finally pressing BACK from BROWSE tab returns me to the App HOME screen

AT NO POINT ON ANY SCREEN does pressing BACK button cause the app to be minimized. The ultimate destination for ANY number of BACK button presses is the App Home screen.

### YouTube Trailer Optimizations

Bug 1) Trailers are still maxing out at 720p quality. Ensure we are always pulling the highest available format that's compatible for playback

Bug 2) Additionally sometimes there is a Youtube "unauthorized" error when attempting to load a Trailer. After closing the error modal and loading the Trailer again it works without a YouTube auth error.

===============================================

#### Finished todo's

- [x] example finished todo
