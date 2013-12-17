module Fluent
  class HistogramOutput < Fluent::Output
    Fluent::Plugin.register_output('histogram', self)

    config_param :tag_prefix, :string, :default => 'histo'
    config_param :input_tag_remove_prefix, :string, :default => nil
    config_param :flush_interval, :time, :default => 60
    config_param :count_key, :string, :default => 'keys'
    config_param :bin_num, :integer, :default => 100

    attr_accessor :flush_interval

    def initialize
      super
    end

    def configure(conf)
      super



      @tag_prefix_string = @tag_prefix + '.' if @tag_prefix
      if @input_tag_remove_prefix
        @remove_prefix_string = @input_tag_remove_prefix + '.'
        @remove_prefix_length = @remove_prefix_string.length
      end
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

  end
end
