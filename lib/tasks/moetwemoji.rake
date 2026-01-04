# frozen_string_literal: true

require "fileutils"
require "digest"

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

  def column_limit(model, col)
    if model.respond_to?(:columns_hash) && model.columns_hash[col]
      model.columns_hash[col].limit
    end
  rescue
    nil
  end

  def fit_group_name(group_name)
    limit = column_limit(CustomEmoji, "group") || 20
    g = group_name.to_s
    g = g[0, limit] if g.length > limit
    g
  end

  def fit_emoji_name(name)
    limit = column_limit(CustomEmoji, "name") || 20
    return name if name.length <= limit

    # Deterministic shorten: keep prefix part, add hash suffix.
    # Example: moetwemoji_1st_pl_a1b2
    hash = Digest::SHA1.hexdigest(name)[0, 4]
    # Leave room for "_" + hash
    room = limit - (1 + hash.length)
    if room <= 0
      return hash[0, limit]
    end

    short = name[0, room]
    short = short.sub(/_+$/, "") # avoid trailing underscore pileups
    "#{short}_#{hash}"[0, limit]
  end

  def build_shortcode(base_name)
    prefix = sanitize_name(SiteSetting.moetwemoji_prefix.to_s)
    sep_raw = SiteSetting.moetwemoji_separator.to_s
    sep = (sep_raw || "").to_s.gsub(SAFE, "")
    name = sanitize_name(base_name)
    full = "#{prefix}#{sep}#{name}"

    if SiteSetting.moetwemoji_enforce_name_limit
      fit_emoji_name(full)
    else
      full
    end
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
      when "gif" then ["*.gif"]
      when "avif" then ["*.avif"]
      when "fakepng" then ["*.png"]
      else
        raise "Unknown variant: #{variant}"
      end
    files = patterns.flat_map { |p| Dir.glob(File.join(dir, p)) }.uniq.sort
    [dir, files]
  end

  def import_variant!(variant:, group_name:)
    ensure_enabled!

    group = fit_group_name(group_name)

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
          CustomEmoji.create!(name: shortcode, upload: upload, group: group)
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

    Emoji.clear_cache if defined?(Emoji)

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

    puts "NOTE: Custom emoji do NOT appear in the Emoji Set dropdown. They appear as custom groups near the bottom of the picker."
  end

  desc "Delete emojis created by this plugin (matches prefix and configured groups)"
  task delete: :environment do
    ensure_enabled!

    prefix = sanitize_name(SiteSetting.moetwemoji_prefix.to_s)
    sep = SiteSetting.moetwemoji_separator.to_s.gsub(SAFE, "")
    like_prefix = "#{prefix}#{sep}%"

    groups = [
      fit_group_name(SiteSetting.moetwemoji_group_name_gif.to_s),
      fit_group_name(SiteSetting.moetwemoji_group_name_avif.to_s),
      fit_group_name(SiteSetting.moetwemoji_group_name_fakepng.to_s)
    ].uniq

    scope = CustomEmoji.where("name LIKE ?", like_prefix).where(group: groups)
    count = scope.count
    scope.find_each(&:destroy!)
    Emoji.clear_cache if defined?(Emoji)
    puts "Deleted #{count} custom emojis."
  end

  desc "Reimport: delete then import"
  task reimport: :environment do
    Rake::Task["moetwemoji:delete"].invoke
    Rake::Task["moetwemoji:import"].invoke
  end

  task import_gif: :environment do
    import_variant!(variant: "gif", group_name: SiteSetting.moetwemoji_group_name_gif)
  end

  task import_avif: :environment do
    import_variant!(variant: "avif", group_name: SiteSetting.moetwemoji_group_name_avif)
  end

  task import_fakepng: :environment do
    import_variant!(variant: "fakepng", group_name: SiteSetting.moetwemoji_group_name_fakepng)
  end
end
