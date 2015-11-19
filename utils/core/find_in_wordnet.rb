#!/usr/bin/env ruby

require 'bundler/setup'
require 'slop'
require 'progress'
require 'cycr'
require 'colors'
require 'csv'
require 'set'
require 'rod/rest'
require 'wordnet'

require 'wiktionary/noun'
require 'cyclopedio/wiki'
require 'cyclopedio/syntax'
require 'cyclopedio/mapping'

options = Slop.new do
  banner "#{$PROGRAM_NAME} -o core_candidates.csv -d database_path\n"+
             'Generate WordNet candidates for core categories'

  on :d=, :database, 'ROD database with Wikipedia data', required: true
  on :o=, :output, 'Output candidates file', required: true
end

begin
  options.parse
rescue => ex
  puts ex
  puts options
  exit
end


# p WordNet::Lemma.find_all("programming_language")

include Cyclopedio::Wiki
include Cyclopedio::Mapping


Database.instance.open_database(options[:database])

nouns = Wiktionary::Noun.new
parse_tree_factory = Cyclopedio::Syntax::Stanford::Converter

CSV.open(options[:output], 'w') do |output|
  Category.with_progress do |category|
    next unless category.regular?
    next unless category.plural?


    names = [category.name] + nouns.singularize_name(category.name, Cyclopedio::Syntax::NameDecorator.new(category, parse_tree_factory: parse_tree_factory).category_head)
    wordnet_candidates = Set.new
    names.each do |name|
      lemmas = WordNet::Lemma.find_all(name.downcase.gsub(' ','_'))
      synsets = lemmas.map { |lemma| lemma.synsets }.flatten
      wordnet_candidates.merge(synsets)
    end


    wordnet_candidates.reject!{|synset| synset.words.all?{|word| word!=word.downcase}}

    if !wordnet_candidates.empty?
      output << [category.name]+ wordnet_candidates.flat_map{|synset| [synset.pos, synset.pos_offset, synset.gloss]}
    end
  end
end

Database.instance.close_database