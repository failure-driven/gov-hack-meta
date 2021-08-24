require "colorize"
require "nokogiri"
require "net/https"

def fetch_using_cache(uri, cache_dir, cached: false, cache_key: nil) # rubocop:disable Metrics/AbcSize
  path = uri.path
  path = "/index" if path == "/"
  uri_filename = [path, uri.query]
                 .compact
                 .join("?")
                 .gsub(%r{^/}, "")
                 .gsub(%r{/}, "-")
                 .gsub(/\?/, "-")
                 .gsub("&", "-")
                 .gsub(/=/, "-")
  cache_key ||= uri_filename
  cache_key = File.join(cache_dir, cache_key)
  if !cached && !(File.exist? cache_key)
    request = Net::HTTP::Get.new uri
    request["user-agent"] = "Mozilla/5.0"
    request["Cookie"] = ""
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
    ) do |http|
      http.request request
    end
    if response.is_a?(Net::HTTPSuccess)
      File.open(cache_key, "wb") do |io|
        io.write response.body
      end
    end
    sleep(rand(1..5)) # random sleep 1 - 5 seconds
  end
  File.open(cache_key).read if File.exist? cache_key
  # TODO: what to do if there is no file still?
end

namespace :data do
  # rake data:slurp[https://hackerspace.govhack.org/,tmp,]
  desc "slurp [start_location,cache_dir=tmp,cached]"
  task :slurp, [:start_location, :cache_dir, :cached] do |_task, args|
    cache_dir = args[:cache_dir] || "tmp/location_scraper"
    cached = !args[:cached].nil? || false
    FileUtils.mkdir_p cache_dir

    uri = URI.parse(args[:start_location])
    body = fetch_using_cache(uri, cache_dir, cached: cached)
    doc = Nokogiri::HTML.parse(body)
    sections = doc
      .css("header nav li a")
      .map do |section|
        section_uri = uri.clone
        section_uri.path = section.attr("href")
        {
          name: section.text.strip.downcase,
          link: section_uri.to_s
        }
      end
    sections
      .filter {|section| %w[challenges projects profiles].include? section[:name]}
      .each do |section|
      body = fetch_using_cache(
        URI.parse(URI::DEFAULT_PARSER.escape(section[:link])), # NOTE: because URI.escape is obsolete
        cache_dir,
        cached: cached,
      )
      if section[:name] == "challenges"
        doc = Nokogiri::HTML(body)
        table_uri = uri.clone
        table_uri.path = doc.css("h3 a.dataset_nav").find{|a| a.text == "Table"}["href"]
        body = fetch_using_cache(
          table_uri,
          cache_dir,
          cached: cached,
        )
        doc = Nokogiri::HTML(body)
        csv_uri = uri.clone
        csv_uri.path = doc.css("a.download-csv").first["href"]
        fetch_using_cache(
          csv_uri,
          cache_dir,
          cached: cached,
        )
      end
      if section[:name] == "projects"
        doc = Nokogiri::HTML(body)
        csv_uri = uri.clone
        csv_uri.path = doc.css("a.download-csv").first["href"]
        fetch_using_cache(
          csv_uri,
          cache_dir,
          cached: cached,
        )
      end
      if section[:name] == "profiles"
        fetch_using_cache(
          URI.parse(section[:link] + ".csv"),
          cache_dir,
          cached: cached,
        )
      end
    end
  end
end
