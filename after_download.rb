#! /usr/bin/env ruby
require 'yaml'
require 'fileutils'
require 'similar_text'
require 'imdb'
require 'deluge'
#SERIES_PATH = File.path()
#MOVIES_PATH = File.path()
IGNORED_WORDS = YAML.load_file('ignored_words.yml')[:words]
SIMILARITY_THRESHOLD = 90
SEASON_MATCH = /S[0-9]{1,2}E[0-9]{1,2}/i
CONFIG = YAML.load_file('config.yml')
torrent_id, torrent_name, folder = ARGV[0..2]


def sanitized_title(torrent_name)
  sanitized_title = torrent_name.downcase.scan(/[[:alnum:]]+/).reject do |word|
    if word.length > 3
      IGNORED_WORDS.any? {|ignored_word| word.similar(ignored_word) > SIMILARITY_THRESHOLD}
    else
      IGNORED_WORDS.include?(word)
    end
  end

  sanitized_title.reject {|word| word =~ SEASON_MATCH}
end

def find_imdb_movie(title)
  title = title.join(' ')
  search= Imdb::Search.new( title )
  search.movies.detect do |movie|
    #found_title = movie.title.gsub(/\(.*\)/, '').strip.downcase
    found_title = get_original_title(movie).downcase
    match = title.similar( found_title )
    puts "A #{match}% with '#{title}' and '#{found_title}'"
    match > 50
  end
end

def get_original_title(movie)
  title = movie.also_known_as.detect do |hash|
    hash[:version].include?('original title')
  end
  (title && title[:title]) || movie.title.gsub(/\(.*\)/, '').strip
end

def is_serie?(movie, torrent_name = nil)
  !!(movie.title =~ /TV Series/i) || (torrent_name && torrent_name =~ SEASON_MATCH)
end

def stop_torrent
  deluge = Deluge.new(CONFIG['deluge_host'], CONFIG['deluge_port'])
  deluge.login(CONFIG['deluge_username'], CONFIG['deluge_password'])
  deluge.remove_torrent(torrent_id, remove_data: false)
end

puts "=== Processing #{torrent_name}"
stop_torrent
puts "* Torrent stopped"
movie = find_imdb_movie( sanitized_title(torrent_name) )

if movie
  title = get_original_title(movie)
  puts "* Movie found: #{title}"
  destionation_path = if is_serie?(movie, torrent_name)
    puts "* Recognized as a TV-serie."
    File.join(CONFIG['series_path'], title)
  else
    puts "* Recognized as a movie"
    File.join(CONFIG['movies_path'])
  end
  puts "* Copy to #{destionation_path}"
  downloaded_file = File.join(CONFIG['downloads_path'], torrent_name)
  FileUtils.mkdir_p(destionation_path)
  FileUtils.mv(downloaded_file, destionation_path)
else
  puts "* No match found"
end

