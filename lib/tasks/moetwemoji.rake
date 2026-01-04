# frozen_string_literal: true
require "fileutils"

namespace :moetwemoji do
  def plugin_root
    File.expand_path("../../..", __FILE__)
  end

  SAFE = /[^a-z0-9_+\-]/i

  def sanitize_name(str)
    s = str.to_s.downcase
    s = s.gsub(SAFE, "_")
    s = s.gsub(/_+/, "_")
    s = s.sub(/^_+/, "").sub(/_+$/, "")
    s = "emoji" if s.empty?
    s
  end

  def build_shortcode(base_name)
    prefix = sanitize_name(SiteSetting.moetwemoji_prefix.to_s)
    sep_raw = SiteSetting.moetwemoji_separator.to_s
    # separator is used verbatim but sanitized to safe chars (or empty)
    sep = sep_raw.to_s
    sep = "" if sep.nil?
    sep = sep.gsub(SAFE, "")
    name = sanitize_name(base_name)

    "#{prefix}#{sep}#{name}"
  end

  def ensure_enabled!
    unless SiteSetting.moetwemoji_enabled
      puts "Plugin disabled: moetwemoji_enabled = false"
      exit 1
    end
  end

  def files_for_variant(variant)
    dir = File.join(plugin_root, "emoji", variant)
    patterns =
      case variant
      when "gif"
        ["*.gif"]
      when "avif"
        ["*.avif"]
      when "fakepng"
        ["*.png"]
      else
        raise "Unknown variant: #{variant}"
      end

    files = patterns.flat_map { |p| Dir.glob(File.join(dir, p)) }.uniq.sort
    [dir, files]
  end

  def import_variant!(variant:, group_name:)
    ensure_enabled!

    group = CustomEmojiGroup.find_or_create_by!(name: group_name)
    system_user = Discourse.system_user

    dir, files = files_for_variant(variant)
    if files.empty?
      puts "No files found for variant=#{variant} in #{dir}"
      return { imported: 0, skipped: 0, failed: 0 }
    end

    imported = 0
    skipped = 0
    failed  = 0

    files.each do |path|
      base = File.basename(path, File.extname(path))
      shortcode = build_shortcode(base)

      if CustomEmoji.exists?(name: shortcode)
        skipped += 1
        next
      end

      File.open(path, "rb") do |f|
        upload = UploadCreator.new(f, "custom_emoji").create_for(system_user.id)
        if upload&.persisted?
          CustomEmoji.create!(name: shortcode, upload: upload, custom_emoji_group: group)
          imported += 1
        else
          failed += 1
          puts "Failed upload: #{path}"
        end
      end
    rescue => e
      failed += 1
      puts "Error importing #{path}: #{e.class} #{e.message}"
    end

    { imported: imported, skipped: skipped, failed: failed }
  end

  desc "Import Moetwemoji based on site setting moetwemoji_import_mode"
  task import: :environment do
    ensure_enabled!

    mode = SiteSetting.moetwemoji_import_mode.to_s
    results = {}

    case mode
    when "gif_only"
      results["gif"] = import_variant!(variant: "gif", group_name: SiteSetting.moetwemoji_group_name_gif)
    when "avif_only"
      results["avif"] = import_variant!(variant: "avif", group_name: SiteSetting.moetwemoji_group_name_avif)
    when "fakepng_only"
      results["fakepng"] = import_variant!(variant: "fakepng", group_name: SiteSetting.moetwemoji_group_name_fakepng)
    when "gif_and_avif"
      results["gif"]  = import_variant!(variant: "gif",  group_name: SiteSetting.moetwemoji_group_name_gif)
      results["avif"] = import_variant!(variant: "avif", group_name: SiteSetting.moetwemoji_group_name_avif)
    when "all_three"
      results["gif"]     = import_variant!(variant: "gif",     group_name: SiteSetting.moetwemoji_group_name_gif)
      results["avif"]    = import_variant!(variant: "avif",    group_name: SiteSetting.moetwemoji_group_name_avif)
      results["fakepng"] = import_variant!(variant: "fakepng", group_name: SiteSetting.moetwemoji_group_name_fakepng)
    else
      raise "Unknown moetwemoji_import_mode: #{mode}"
    end

    puts "Done:"
    results.each do |k, v|
      puts "  #{k}: imported=#{v[:imported]} skipped=#{v[:skipped]} failed=#{v[:failed]}"
    end

    if mode.include?("fakepng")
      puts "NOTE: fakepng is experimental. If imports fail or animations break, use GIF for max compatibility."
    end

    puts "Tip: Custom emoji groups show near the bottom of the emoji picker in the composer UI."
  end

  desc "Delete emojis created by this plugin (matches prefix and configured groups)"
  task delete: :environment do
    prefix = sanitize_name(SiteSetting.moetwemoji_prefix.to_s)
    sep = SiteSetting.moetwemoji_separator.to_s.gsub(SAFE, "")
    like_prefix = "#{prefix}#{sep}%"

    groups = [
      SiteSetting.moetwemoji_group_name_gif.to_s,
      SiteSetting.moetwemoji_group_name_avif.to_s,
      SiteSetting.moetwemoji_group_name_fakepng.to_s
    ].uniq

    scope = CustomEmoji.where("name LIKE ?", like_prefix)
    group_ids = CustomEmojiGroup.where(name: groups).pluck(:id)
    scope = scope.where(custom_emoji_group_id: group_ids) unless group_ids.empty?

    count = scope.count
    scope.find_each(&:destroy!)
    puts "Deleted #{count} custom emojis."
  end

  desc "Reimport: delete then import"
  task reimport: :environment do
    Rake::Task["moetwemoji:delete"].invoke
    Rake::Task["moetwemoji:import"].invoke
  end
end
