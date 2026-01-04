![1st_place_medal](https://github.com/user-attachments/assets/9a21c5e8-1773-4471-9a15-d109211f4fef)
![confused](https://github.com/user-attachments/assets/b5ed7b93-b5ba-4a4b-9bd2-6cfc370d8cb2)
![crab](https://github.com/user-attachments/assets/43d8b011-94db-4945-9655-1dd415ab6969)


# discourse-moetwemoji-pack

Adds **Moetwemoji** animated emoji packs to Discourse as **Custom Emoji groups** 
This repo supports **three** variants:

- `emoji/gif/*.gif` (best compatibility)
- `emoji/avif/*.avif` (smaller files; relies on browser AVIF support)
- `emoji/fakepng/*.png` (**experimental**: AVIF content but named `.png`, useful mainly for static-file-replacement approaches; may fail in upload/import pipelines)

## Why include AVIF?

Discourse supports modern image uploads (including **avif**) by default, and admins can further control allowed extensions via site settings.  
See: "Understanding Uploads, Images, and Attachments" on Discourse Meta.


## Install on your Discourse (Docker)

Add to `/var/discourse/containers/app.yml`:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/constansino/discourse-moetwemoji-pack.git
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

## Import emojis

Run inside the container:

```bash
cd /var/discourse
./launcher enter app

su - discourse
cd /var/www/discourse

RAILS_ENV=production bundle exec rake moetwemoji:import
```

Import behavior is controlled by `moetwemoji_import_mode` (Admin → Settings):

- `gif_only`
- `avif_only`
- `fakepng_only` (default)
- `gif_and_avif` 
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

If assets are derived from Google Noto Emoji, keep the relevant license and attribution (Apache 2.0 for tools/most images; OFL for fonts; flags have their own notes).
