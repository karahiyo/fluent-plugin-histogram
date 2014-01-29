# -*- coding: utf-8 -*-

require 'fluent/mixin/config_placeholders'

module Fluent
  class HistogramOutput < Fluent::Output
    Fluent::Plugin.register_output('histogram', self)

    config_param :tag, :string, :default => nil
    config_param :tag_prefix, :string, :default => nil
    config_param :tag_suffix, :string, :default => nil
    config_param :input_tag_remove_prefix, :string, :default => nil
    config_param :flush_interval, :time, :default => 60
    config_param :count_key, :string, :default => 'keys'
    config_param :bin_num, :integer, :default => 100
    config_param :alpha, :integer, :default => 1
    config_param :sampling_rate, :integer, :default => 1

    include Fluent::Mixin::ConfigPlaceholders

    attr_accessor :flush_interval
    attr_accessor :hists
    attr_accessor :zero_hist
    attr_accessor :remove_prefix_string

    ## fluentd output plugin's methods

    def initialize
      super
    end

    def configure(conf)
      super

      raise Fluent::ConfigError, 'bin_num must be > 0' if @bin_num <= 0
      $log.warn %Q[too small "bin_num(=#{@bin_num})" may raise unexpected outcome] if @bin_num < 100

      @tag_prefix_string = @tag_prefix + '.' if @tag_prefix
      @tag_suffix_string = '.' + @tag_suffix if @tag_suffix
      if @input_tag_remove_prefix
        @remove_prefix_string = @input_tag_remove_prefix + '.'
        @remove_prefix_length = @remove_prefix_string.length
      end

      @zero_hist = [0] * @bin_num

      @hists = initialize_hists
      @sampling_counter = 0
      @tick = @sampling_rate.to_i > 1 ? @sampling_rate : 1

      @mutex = Mutex.new

    end

    def start
      super
      @watcher = Thread.new(&method(:watch))
    end

    def watch
      @last_checked = Fluent::Engine.now
      while true
        sleep 0.5
        if Fluent::Engine.now - @last_checked >= @flush_interval
          now = Fluent::Engine.now
          flush_emit(now)
          @last_checked = now
        end
      end
    end

    def shutdown
      super
      @watcher.terminate
      @watcher.join
    end


    ## Histogram plugin's method

    def initialize_hists(tags=nil)
      hists = {}
      if tags
        tags.each do |tag|
          hists[tag] = @zero_hist.dup
        end
      end
      hists
    end

    def increment(tag, key)
      @hists[tag] ||= @zero_hist.dup
      id = key.hash % @bin_num
      @mutex.synchronize {
        (0..@alpha).each do |alpha|
          (-alpha..alpha).each do |al|
            @hists[tag][(id + al) % @bin_num] += @tick
          end
        end
      }
    end

    def emit(tag, es, chain)
      chain.next

      es.each do |time, record|
        keys = record[@count_key]
        [keys].flatten.each do |k| 
          if @sampling_rate == 1
            increment(tag, k)
          else
            @sampling_counter += 1
            if @sampling_counter >= @sampling_rate 
              increment(tag, k) 
              @sampling_counter = 0
            end
          end
        end
      end
    end
    
    def tagging(flushed)
      tagged = {}
      tagged = Hash[ flushed.map do |tag, hist|
        tagged_tag = tag.dup
        if @tag 
          tagged_tag = @tag
        else
          if @input_tag_remove_prefix &&
            ( ( tag.start_with?(@remove_prefix_string) && 
               tag.length > @remove_prefix_length ) ||
               tag == @input_tag_remove_prefix)
            tagged_tag = tagged_tag[@input_tag_remove_prefix.length..-1]
          end
          
          tagged_tag = @tag_prefix_string + tagged_tag if @tag_prefix
          tagged_tag << @tag_suffix_string if @tag_suffix

          tagged_tag.gsub!(/(^\.)|(\.+$)/, '')
          tagged_tag.gsub!(/(\.\.+)/, '.')
        end

        [tagged_tag, hist]
      end ]
      tagged
    end

    def generate_output(flushed)
      output = {}
      flushed.each do |tag, hist|
        output[tag] = {}
        sum = hist.inject(:+)
        avg = sum / hist.size
        sd = hist.instance_eval do
          sigmas = map { |n| (avg - n)**2 }
          Math.sqrt(sigmas.inject(:+) / size)
        end
        output[tag][:hist] = hist
        output[tag][:sum] = sum
        output[tag][:avg] = avg
        output[tag][:sd] = sd.to_i
      end
      output
    end

    def flush
      flushed, @hists = generate_output(@hists), initialize_hists(@hists.keys.dup)
      tagging(flushed)
    end

    def flush_emit(now)
      flushed = flush
      flushed.each do |tag, data|
        Fluent::Engine.emit(tag, now, data)
      end
    end

  end
end
