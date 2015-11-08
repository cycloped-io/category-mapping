#!/usr/bin/env ruby

require 'bundler/setup'
$:.unshift 'lib'
require 'slop'
require 'progress'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'

require 'wiktionary/noun'
require 'cyclopedio/wiki'
require 'cyclopedio/syntax'
require 'cyclopedio/mapping'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o core_candidates.csv -d database_path -r\n"+
             'Generate Cyc candidates for core categories'

  on :d=, :database, 'ROD database with Wikipedia data', required: true
  on :o=, :output, 'Output candidates file', required: true
  on :p=, :port, 'Cyc port', as: Integer, default: 3601
  on :h=, :host, 'Cyc host', default: 'localhost'
  on :c=, :'category-filters', "Filters for categories: c - collection, s - most specific,\n" +
            'n - noun, r - rewrite of, l - lower case, f - function, c|i - collection or individual, b - black list, d - ill-defined', default: 'c:r:f:l:d'
  on :a=, :'article-filters', 'Filters for articles: as above', default: 'c|i:r:f:l:d'
  on :b=, :'black-list', 'File with black list of Cyc abstract types'
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end

include Cyclopedio::Wiki
include Cyclopedio::Mapping


cyc = Cyc::Client.new(port: options[:port], host: options[:host], cache: true)
name_service = Cyc::Service::NameService.new(cyc)
black_list_reader = BlackListReader.new(options[:"black-list"])
filter_factory = Filter::Factory.new(cyc: cyc, black_list: black_list_reader.read)
candidate_generator = CandidateGenerator.
    new(cyc: cyc, name_service: name_service,
        category_filters: filter_factory.filters(options[:"category-filters"]),
        article_filters: filter_factory.filters(options[:"article-filters"]),
        nouns: Wiktionary::Noun.new,
        category_exact_match: true
    )


Database.instance.open_database(options[:database])

CSV.open(options[:output], 'w') do |output|
  Category.with_progress do |category|
    next unless category.regular?
    next unless category.plural?

    candidate_set = candidate_generator.category_candidates(category)

    output << [category.name] if !candidate_set.empty?
  end
end

Database.instance.close_database
