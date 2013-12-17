module Fluent
  class HistogramOutput < Fluent::Output
    Fluent::Plugin.register_output('histogram', self)

    def initialize
      super
    end

    def configure(conf)
      super
    end

    def start
      super
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      records = []
      chunk.msgpack_each { |record|
        # records << record
      }
      # write records
    end
  end
end
