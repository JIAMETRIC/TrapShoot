# GitHub Pages: link thumbnails for WhatsApp and other apps

How to give any page on the GitHub Pages site a preview image (thumbnail), title and description, so that a shared link shows a picture when it is sent in WhatsApp, iMessage or social apps.

Site: https://jiametric.github.io/TrapShooterPro/

The site is static HTML served from the `main` branch at the repository root. Nothing runs on a server, so the preview comes entirely from tags in each page's `<head>` and an image file in the repo.

## How a preview is built

Apps like WhatsApp fetch the shared URL once and read its Open Graph tags (`og:`) and Twitter tags (`twitter:`):

| Tag | What it gives | Required |
|---|---|---|
| `og:image` | The thumbnail. Must be an **absolute** URL (starts with `https://`) | yes |
| `og:title` | The bold title line | yes |
| `og:description` | The grey text under the title | yes |
| `og:url` | The canonical link | yes |
| `og:image:width`, `og:image:height` | Lets the app size the image before loading it | recommended |
| `twitter:card` = `summary_large_image` | Large image layout on X and other apps | recommended |

The image should be **1200 × 630 px**, PNG or JPG, under about 300 KB, with the important content in the middle, because apps crop the edges.

## Step 1: make the thumbnail image

The thumbnail is a screenshot of the page's hero at 1200 × 630. Microsoft Edge is already installed on the Windows machine and can take it headless.

From the repository root (Git Bash):

```bash
"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu --hide-scrollbars --window-size=1200,630 --screenshot="C:/Users/admin/Desktop/WIP/TrapShooterPro/og-image.png" "file:///C:/Users/admin/Desktop/WIP/TrapShooterPro/dashboard.html"
```

- Change the last path to the page you want to preview (for example `index.html`), and the `--screenshot=` path to the image name you want (for example `og-<page>.png`).
- Open the PNG and check it. The bottom of the image can show part of the next section; that is acceptable for a thumbnail, but check the text is readable at phone size.
- If the image is too large (over about 300 KB), shrink it or save it as JPG.

Each page should have its own image name, so a page's thumbnail is not overwritten by another page's. The shared hero image is `og-image.png`.

## Step 2: add the tags to the page

Put these in the `<head>` of the page, after the `<title>` line. Use the page's own title, description and image name:

```html
<meta name="description" content="One sentence about this page.">
<meta property="og:type" content="website">
<meta property="og:site_name" content="TrapShooterPro">
<meta property="og:title" content="Page title">
<meta property="og:description" content="One sentence about this page.">
<meta property="og:url" content="https://jiametric.github.io/TrapShooterPro/<page>">
<meta property="og:image" content="https://jiametric.github.io/TrapShooterPro/og-image.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
```

For the home page, `<page>` is empty (`https://jiametric.github.io/TrapShooterPro/`). For other pages, use the file name, for example `summary.html`.

Rules:

- `og:image` and `og:url` must be full `https://` URLs. A relative path like `og-image.png` will not work.
- Keep the title and description short: about 60 and 150 characters at most.
- Use the same tags on every page you want to share, so each page's preview is its own.

## Step 3: publish through a pull request

The `main` branch is protected by the CI rules in `docs/git-workflow.md`, so the change goes in through a pull request:

```bash
git switch -c og-<page>
git add <page>.html og-<page>.png
git commit -m "Add a link preview image and tags to <page>"
git push -u origin og-<page>
gh pr create --base main --head og-<page> --title "Add a link preview to <page>" --body "Adds the Open Graph tags and thumbnail image for <page>."
```

Then wait for the checks (`gh pr checks <number>`). The iOS job takes about 20 minutes; the Pages files do not touch the Swift packages, but CI must be green before merging. When green:

```bash
gh pr merge <number> --merge
git switch main && git pull --ff-only origin main
```

## Step 4: check the Pages build

GitHub Pages rebuilds a few minutes after the merge. Check that it finished:

```bash
gh api repos/JIAMETRIC/TrapShooterPro/pages/builds/latest --jq '.status'
```

Wait for `built`. Then confirm the live page has the tags and the image is reachable:

```bash
curl -s https://jiametric.github.io/TrapShooterPro/<page> | grep -c "og:image"
curl -s -o /dev/null -w "%{http_code}\n" https://jiametric.github.io/TrapShooterPro/og-<page>.png
```

The first command should print a number above 0, and the second should print `200`.

## Step 5: test in WhatsApp

WhatsApp keeps the preview it first fetched for a link. If a link was shared before the tags were live, it can keep showing no picture.

- Share a **new** link: add a version number to the end, for example `https://jiametric.github.io/TrapShooterPro/<page>?v=1`. Increase the number each time you need a fresh preview.
- Send it to yourself first, then to others.
- If the picture still doesn't appear, try a new `?v=` number. The bare link (without `?v=`) can keep its old preview for a while; it refreshes on its own.

## Checklist

- [ ] Thumbnail is 1200 × 630, under about 300 KB, and readable
- [ ] Image is named for its page (or is the shared `og-image.png`)
- [ ] Tags are in the page's `<head>` with absolute `https://` URLs
- [ ] Change is on a branch, the PR is merged after CI is green
- [ ] Pages build shows `built`; the live page shows the tags; the image returns `200`
- [ ] Shared with a new `?v=` link

## Notes

- The dashboard hero is rendered from `dashboard.html`, which is no longer used by `index.html`; it still works as the render source. Keep it in place until the hero moves elsewhere.
- Do not put personal data or secrets in the tags or the image. The site has no account and no server, and the image is public.
