# discourse-moetwemoji-pack

Adds **Moetwemoji** animated emoji packs to Discourse as **Custom Emoji groups** (does **not** replace your existing emoji set like openmoji/twemoji).

This repo supports **three** variants:

- `emoji/gif/*.gif` (best compatibility)
- `emoji/avif/*.avif` (smaller files; relies on browser AVIF support)
- `emoji/fakepng/*.png` (**experimental**: AVIF content but named `.png`, useful mainly for static-file-replacement approaches; may fail in upload/import pipelines)

## Why include AVIF?

Discourse supports modern image uploads (including **avif**) by default, and admins can further control allowed extensions via site settings.  
See: "Understanding Uploads, Images, and Attachments" on Discourse Meta.

## Prepare assets (Windows)

You have three source directories, for example:

- `C:\Users\1\love\moetwemoji72x72gif\100.gif`
- `C:\Users\1\love\moetwemoji72x72avif\100.avif`
- `C:\Users\1\love\moetwemoji72x72fakepng(avif)\100.png`

Copy them into the repo:

```powershell
$gifSrc     = "C:\Users\1\love\moetwemoji72x72gif"
$avifSrc    = "C:\Users\1\love\moetwemoji72x72avif"
$fakePngSrc = "C:\Users\1\love\moetwemoji72x72fakepng(avif)"

.\scripts\prepare-assets.ps1 -GifSource $gifSrc -AvifSource $avifSrc -FakePngSource $fakePngSrc
.\scripts\verify-assets.ps1
```

## Install on your Discourse (Docker)

Add to `/var/discourse/containers/app.yml`:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/<YOU>/discourse-moetwemoji-pack.git
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

## Import emojis

Run inside the container:

```bash
./launcher enter app
cd /var/www/discourse

RAILS_ENV=production bundle exec rake moetwemoji:import
# RAILS_ENV=production bundle exec rake moetwemoji:reimport
```

Import behavior is controlled by `moetwemoji_import_mode` (Admin → Settings):

- `gif_only`
- `avif_only`
- `fakepng_only` (experimental)
- `gif_and_avif` (default)
- `all_three`

## Shortcodes

Default:
- prefix: `moetwemoji`
- separator: `_`

A file named `alien.gif` becomes `:moetwemoji_alien:`.

## Notes on fakepng

`fakepng` exists because some communities use the “content is AVIF but filename ends with .png” trick when **replacing core emoji files**.  
When importing as **custom emoji uploads**, fakepng is **not guaranteed** to work on all servers/browsers. Use GIF for maximum compatibility.

## Licensing / attribution

If your assets are derived from Google Noto Emoji, keep the relevant license and attribution (Apache 2.0 for tools/most images; OFL for fonts; flags have their own notes).
