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



@nouns = Wiktionary::Noun.new

def singularize_name_nouns(name, head)
  names = [name]
  singularized_heads = @nouns.singularize(head)
  if not singularized_heads.nil?
    singularized_heads.each do |singularized_head|
      names << name.sub(/\b#{Regexp.quote(head)}\b/, singularized_head)
    end
  end
  names
end

wikipedia_category_utils = Cyclopedio::Mapping::WikipediaCategoryUtils.new

count=0
CSV.open(options[:output], 'w') do |output|
  Category.with_progress do |category|
    next unless category.regular?
    next unless category.plural?

    names = [category.name] + wikipedia_category_utils.singularize_name(category.name, wikipedia_category_utils.category_head(category))
    wordnet_candidates = Set.new
    names.each do |name|
      lemmas = WordNet::Lemma.find_all(name.downcase.gsub(' ','_'))
      synsets = lemmas.map { |lemma| lemma.synsets }.flatten
      wordnet_candidates.merge(synsets)
      # p name, lemmas
      # break if !lemmas.empty?
    end

    # p wordnet_candidates.size, wordnet_candidates
    wordnet_candidates.reject!{|synset| synset.words.all?{|word| word!=word.downcase}}
    # p wordnet_candidates.size, wordnet_candidates
    # p
    if !wordnet_candidates.empty?
      count+=1
      p category.name
    end
    # p category, wordnet_candidates
  end
end

Database.instance.close_database

p count