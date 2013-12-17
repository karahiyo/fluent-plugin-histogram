module Fluent
  class HistogramOutput < Fluent::Output
    Fluent::Plugin.register_output('histogram', self)

    config_param :tag_prefix, :string, :default => 'histo'
    config_param :input_tag_remove_prefix, :string, :default => nil
    config_param :flush_interval, :time, :default => 60
    config_param :count_key, :string, :default => 'keys'
    config_param :bin_num, :integer, :default => 100

    attr_accessor :flush_interval
    attr_accessor :hists
    attr_accessor :zero_hist

    ## fluentd output plugin's methods

    def initialize
      super
    end

    def configure(conf)
      super

      raise Fluent::ConfigError, "bin_num must be > 0" if @bin_num <= 0

      @tag_prefix_string = @tag_prefix + '.' if @tag_prefix
      if @input_tag_remove_prefix
        @remove_prefix_string = @input_tag_remove_prefix + '.'
        @remove_prefix_length = @remove_prefix_string.length
      end

      @zero_hist = @bin_num.times.map{0}
      @hists = initialize_hists
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
          flush_emit(now - @last_checked)
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
          hists[tag] = {:data => @zero_hist.dup}
        end
      end
      hists
    end

    def increment(tag, key)
      @hists[tag] ||= {:data => @zero_hist.dup}
      hashed = key.hash % @bin_num
      @hists[tag][:data][hashed] += 1
    end

    def emit(tag, es, chain)
      es.each do |time, record|
         keys = record[@count_key]
         [keys].flatten.each {|k| increment(tag, k)}
      end

      chain.next
    end

    def flush
      flushed, @hists = @hists, initialize_hists(@hists.keys.dup)
      flushed
    end

    def flush_emit
      flushed = flush
      now = Fluent::Engine.now
      flushed.each do |tag, data|
        Fluent::Engine.emit(tag, now, data)
      end
    end


  end
end
