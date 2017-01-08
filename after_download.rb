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

stop_torrent
movie = find_imdb_movie( sanitized_title(torrent_name) )

if movie
  title = get_original_title(movie)
  destionation_path = if is_serie?(movie, torrent_name)
    File.join(CONFIG['series_path'], title)
  else
    File.join(CONFIG['movies_path'])
  end
  downloaded_file = File.join(CONFIG['downloads_path'], torrent_name)
  FileUtils.mkdir_p(destionation_path)
  FileUtils.mv(downloaded_file, destionation_path)
end
#TESTS = [
#  "From [ WWW.TORRENTING.COM  ] - Designated.Survivor.S01E07.720p.HDTV.X264-DIMENSION",
#  "The.Accountant.2016.1080p.BluRay.x264-SPARKS[EtHD]",
#  "The.Intouchables.2011.1080p.BluRay.x264.[ExYu-Subs].mp4",
#  "Discovery.Channel.Nubia.The.Forgotten.Kingdom.XviD.AC3.MVGroup.org.avi",
#  "Shooter.S01E05.WEBRip.XviD-FUM[ettv]"
#]

#TESTS.each do |torrent_name|
#  movie = find_imdb_movie( sanitized_title(torrent_name) )
#  if movie
#    title = movie.title.gsub(/\(.*\)/, '').strip
#    puts "#{title} #{is_serie?(movie, torrent_name)}"
#  else
#    puts "No match found for #{torrent_name}"
#  end
#end

