## Running list of user todo's

### Changes to request format

Currently we present two "Request" buttons [1080p] and [4K] for both Movies and TV Shows. This requires manual parsing of user's profiles for the two services (Radarr and Sonarr) which creates bug surface area and also isn't really necessary -- the user will always click [4K] anyway and this is what's configured as default for each service in Overseerr. So let's simplify it.

- instead of two buttons [1080p] and [4k] there is one button labeled [Request]
- tapping [Request] requests the title using default profile configured in Overseerr
- if a title is already requested, its Request Status appears in place of the [Request] button

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
