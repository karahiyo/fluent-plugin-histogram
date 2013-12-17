require 'helper'

class HistogramOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  count_key      keys
  flush_interval 60s
  bin_num        100
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::HistogramOutput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      create_driver %[ bin_num 0]
    }
  end

  def test_small_increment
    bin_num = 100
    f = create_driver %[ bin_num #{bin_num}]
    f.instance.increment("test.input", "A")
    f.instance.increment("test.input", "B")
    zero = f.instance.zero_hist
    zero["A".hash % bin_num] += 1
    zero["B".hash % bin_num] += 1
    assert_equal({"test.input" => {:hist => zero, :sum => 2, :ave => 2.0/bin_num, :len=>2}}, 
                 f.instance.flush)
  end

  def test_tag_add_remove
    f = create_driver(%[tag_prefix histo])
    f.instance.increment("test",  "A")
    flushed = f.instance.flush
    assert_equal(true, flushed.key?("histo.test"))

    f = create_driver(%[
                      tag_prefix histo
                      input_tag_remove_prefix test])
    f.instance.increment("test", "A")
    flushed = f.instance.flush
    assert_equal(true, flushed.key?("histo"))
  end

  def test_increment_sum
    bin_num = 100
    f = create_driver %[ bin_num #{bin_num}]
    1000.times do |i|
      f.instance.increment("test.input", i.to_s)
    end
    flushed = f.instance.flush
    assert_equal(1000, flushed["test.input"][:sum])
    assert_equal(1000.to_f / bin_num, flushed["test.input"][:ave])
  end

  def test_emit
    bin_num = 100
    f = create_driver(%[bin_num #{bin_num}])
    f.run do
      100.times do 
        f.emit({"keys" => ["A", "B", "C"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(100*3, flushed["test"][:sum])
    assert_equal(100*3.to_f / bin_num, flushed["test"][:ave])
    assert_equal(3, flushed["test"][:len])
  end

end
