require 'helper'

class HistogramOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  count_key      keys
  flush_interval 5s
  bin_num        5
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::HistogramOutput, tag).configure(conf)
  end

  def test_configure
    create_driver
  end

  def test_one_increment
    bin_num = 5
    f = create_driver %[ bin_num #{bin_num}]
    f.instance.increment("test.input", "A")
    zero = f.instance.zero_hist
    zero["A".hash % bin_num] += 1
    assert_equal({"test.input" => {:data => zero}}, f.instance.flush)
  end

  def test_increment_sum
    bin_num = 5
    f = create_driver %[ bin_num #{bin_num}]
    100.times do |i|
      f.instance.increment("test.input", i.to_s)
    end
    flushed = f.instance.flush
    assert_equal(100, flushed["test.input"][:data].inject(:+))
  end

end
