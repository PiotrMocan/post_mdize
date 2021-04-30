# frozen_string_literal: true

require_relative "post_mdize/version"
require 'json'
require 'active_support/inflector/methods.rb'
require 'json_deep_parse'

module PostMdize
  class Error < StandardError; end

  include ActiveSupport::Inflector
  using ::JSONDeepParse

  input_file  = ARGV.first
  output_file = ARGV.last

  file = File.read(input_file)
  hash = JSON.deep_parse(file)

  def path_mdize(item)
    path_segs = item['request']['url']['path']
    path_segs.map!.with_index do |segment, index|
      segment.match?(/\-/) ? "{:#{singularize(path_segs[index-1])}_uuid}" : segment
    end

    "#{path_segs.join('/')}"
  end

  def body_mdize(item)
    item['request']['body']['raw'] || ''
  end

  def response_mdize(item)
    item['response'].first['body'] #unless item['response']['body'].empty?) || ''
  end

  def hash_mdize(hash, file, intense = 2)
    hash = {} if hash == ""
    space = ' ' * intense
    if hash.is_a?(Array)
      file.write("[\r\n")
      hash.each do |element|
        hash_mdize(element, file, intense + 2)
      end
      file.write("#{' ' * (intense - 2)}]")
    else
      file.write("#{' ' * (intense - 2)}{\r\n")
      strings =
      hash.map do |k, v|
        if v.is_a?(Hash) || v.is_a?(Array)
          file.write("#{space}\"#{k}\": ")
          hash_mdize(v, file, intense + 2)
        else
          file.write("#{space}\"#{k}\": \"#{v}\"")
          file.write(",\r\n") unless v == hash.values.last
          #file.write("\r\n}\r\n")
        end
      end
      file.write("\r\n#{' ' * (intense - 2)}}\r\n")
    end
  end

  outfile = File.open(output_file, "w") do |file|
    file.write("# README\r\n")
    hash['item'].each do |item|
      file.write("\r\n* __#{item['request']['method']}__ #{path_mdize(item)}\r\n")
      file.write("#### #{item['name']}\r\n")
      file.write("params\r\n")
      file.write("\r\n```\r\n")
      file.write("header:\r\n")
      file.write("#{item['header']}")
      file.write("body:\r\n")
      hash_mdize(body_mdize(item), file)
      file.write("\r\n```\r\n")
      file.write("RESPONSE:\r\n")
      file.write("\r\n```\r\n")
      hash_mdize(response_mdize(item), file)
      file.write("\r\n```\r\n")
    end
  end
end
