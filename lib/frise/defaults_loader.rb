# frozen_string_literal: true

require 'frise/parser'

module Frise
  # Provides the logic for merging config defaults into pre-loaded configuration objects.
  #
  # The merge_defaults and merge_defaults_at entrypoint methods provide ways to read files with
  # defaults and apply them to configuration objects.
  class DefaultsLoader
    SYMBOLS = %w[$all $optional].freeze

    def initialize(include_sym: '$include', content_include_sym: '$content_include', schema_sym: '$schema', delete_sym: '$delete')
      @include_sym = include_sym
      @content_include_sym = content_include_sym
      @schema_sym = schema_sym
      @delete_sym = delete_sym
    end

    def widened_class(obj)
      class_name = obj.class.to_s
      return 'String' if class_name == 'Hash' && !obj[@content_include_sym].nil?
      return 'Boolean' if %w[TrueClass FalseClass].include? class_name
      return 'Integer' if %w[Fixnum Bignum].include? class_name
      class_name
    end

    def merge_defaults_obj(config, defaults)
      puts ""
      puts ""
      puts ""
      puts ""
      puts config.inspect
      puts defaults.inspect
      config_class = widened_class(config)
      defaults_class = widened_class(defaults)

      result = if defaults.nil?
        puts "--> 1"
        config

      elsif config.nil?
        puts "--> 2"
        if defaults_class != 'Hash' then defaults
        elsif defaults['$optional'] then nil
        else merge_defaults_obj({}, defaults)
        end

      elsif config == @delete_sym
        puts "--> 3"
        config

      elsif defaults_class == 'Array' && config_class == 'Array'
        puts "--> 4"
        defaults + config

      elsif defaults_class == 'Hash' && defaults['$all'] && config_class == 'Array'
        puts "--> 5"
        config.map { |elem| merge_defaults_obj(elem, defaults['$all']) }

      elsif defaults_class == 'Hash' && config_class == 'Hash'
        puts "--> 6"
        new_config = {}
        (config.keys + defaults.keys).uniq.each do |key|
          next if SYMBOLS.include?(key)

          new_config[key] = config[key]
          puts config[key].inspect, defaults[key]
          new_config[key] = merge_defaults_obj(new_config[key], defaults[key]) if defaults.key?(key)
          puts config[key].inspect
          new_config[key] = merge_defaults_obj(new_config[key], defaults['$all']) unless new_config[key].nil?
          puts config[key].inspect
          new_config.delete(key) if new_config[key].nil?
        end
        new_config

      elsif defaults_class != config_class
        puts "--> 7"
        raise "Cannot merge config #{config.inspect} (#{widened_class(config)}) " \
          "with default #{defaults.inspect} (#{widened_class(defaults)})"

      else
        config
               end

      puts "FINAL RESULT: ", result.inspect
      result
    end

    def merge_defaults_obj_at(config, at_path, defaults)
      at_path.reverse.each { |key| defaults = { key => defaults } }
      merge_defaults_obj(config, defaults)
    end

    def merge_defaults(config, defaults_file, symbol_table = config)
      defaults = Parser.parse(defaults_file, symbol_table) || {}
      merge_defaults_obj(config, defaults)
    end

    def merge_defaults_at(config, at_path, defaults_file, symbol_table = config)
      defaults = Parser.parse(defaults_file, symbol_table) || {}
      merge_defaults_obj_at(config, at_path, defaults)
    end
  end
end
