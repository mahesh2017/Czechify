# Public store pages

These static pages are intended for the privacy-policy and account-deletion
URLs required by the app stores, plus a branded public landing page at
`/index.html`.

## Publish with GitHub Pages

1. Push the repository to GitHub.
2. In **Settings → Pages**, choose **GitHub Actions** as the source.
3. After the workflow runs, use the URLs `/privacy.html` and
   `/delete-account.html` in Play Console.

Upload `app-icon.png` beside both HTML files when publishing to another host;
the pages use it for branded headers and browser-tab icons. Keep
`czechify-hero.jpg` and `czechify-copybook.jpg` beside `index.html` as well.

The app's primary deletion path is **Settings → Account & data**. The web page
explains that path and provides the maintainer's public contact route for users
who cannot open the app.
