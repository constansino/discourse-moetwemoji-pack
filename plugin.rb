# frozen_string_literal: true

# name: discourse-moetwemoji-pack
# about: Adds Moetwemoji animated emoji packs (GIF/AVIF/experimental fakepng) as Custom Emoji groups with a configurable prefix.
# version: 0.2.0
# authors: your-name
# url: https://github.com/yourname/discourse-moetwemoji-pack

enabled_site_setting :moetwemoji_enabled

after_initialize do
  # Import is done via rake tasks (see lib/tasks/moetwemoji.rake) to avoid heavy work on boot.
end
