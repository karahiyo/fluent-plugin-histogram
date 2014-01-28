# -*- coding: utf-8 -*-

require 'helper'

class HistogramOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  count_key      keys
  flush_interval 60s
  bin_num        100
  tag_prefix     histo
  input_tag_remove_prefix test.input
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::HistogramOutput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      create_driver %[ bin_num 0]
    }
  end

  def test_small_increment_no_alpha
    bin_num = 100
    alpha = 0
    f = create_driver(%[ 
                        bin_num #{bin_num}
                        alpha #{alpha}])
    f.instance.increment("test.input", "A")
    f.instance.increment("test.input", "B")
    zero = f.instance.zero_hist.dup
    id = "A".hash % bin_num
    zero[id] += 1
    id = "B".hash % bin_num
    zero[id] += 1
    assert_equal({"test.input" => {:hist => zero, :sum => 2, :avg => 2/bin_num, :sd=>0}}, 
                 f.instance.flush)
  end

  def test_small_increment_with_alpha
    bin_num = 100
    alpha = 1
    f = create_driver(%[ 
                        bin_num #{bin_num}
                        alpha #{alpha}])
    f.instance.increment("test.input", "A")
    f.instance.increment("test.input", "B")
    zero = f.instance.zero_hist.dup
    id = "A".hash % bin_num
    zero[id] += 2
    zero[(id + alpha) % bin_num] += 1
    zero[id - alpha] += 1
    id = "B".hash % bin_num
    zero[id] += 2
    zero[(id + alpha) % bin_num] += 1
    zero[id - alpha] += 1
    assert_equal({"test.input" => {:hist => zero, :sum => 2*3+2, :avg => (2*3+2)/bin_num, :sd=>0}}, 
                 f.instance.flush)
  end

  def test_tagging_with_flush
    f = create_driver(%[tag_prefix histo])
    f.instance.increment("test",  "A")
    flushed = f.instance.flush
    assert_equal("histo.test", flushed.keys.join(''))

    f = create_driver(%[
                      tag_prefix histo
                      input_tag_remove_prefix test])
    f.instance.increment("test", "A")
    flushed = f.instance.flush
    assert_equal("histo", flushed.keys.join(''))
  end

  def test_tagging
    f = create_driver(%[
                      hostname localhost
                      tag_prefix histo
                      input_tag_remove_prefix test
                      tag_suffix __HOSTNAME__ ])

    # input tag is one
    data = {"test.input" => [1, 2, 3, 4, 5]}
    tagged = f.instance.tagging(data)
    assert_equal("histo.input.localhost", tagged.keys.join(''))

    # input tag is more than one
    data = {"test.a" => [1, 2, 3], "test.b" => [1, 2]}
    tagged = f.instance.tagging(data)
    assert_equal(true, tagged.key?("histo.a.localhost"))
    assert_equal(true, tagged.key?("histo.b.localhost"))
  end

  def test_tagging_use_tag
    f = create_driver(%[ tag histo ])
    data = {"test.input" => [1, 2, 3, 4, 5]}
    tagged = f.instance.tagging(data)
    assert_equal("histo", tagged.keys.join(''))
  end

  def test_increment_sum
    bin_num = 100
    f = create_driver(%[ 
                        bin_num #{bin_num}
                        alpha   1 ])
    1000.times do |i|
      f.instance.increment("test.input", i.to_s)
    end
    flushed = f.instance.flush
    assert_equal(1000*4, flushed["test.input"][:sum])
    assert_equal(1000*4/bin_num, flushed["test.input"][:avg])
  end

  def test_emit
    bin_num = 100
    f = create_driver(%[ 
                      bin_num #{bin_num}
                      alpha 1 ])
    f.run do
      100.times do 
        f.emit({"keys" => ["A", "B", "C"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(300*4, flushed["test"][:sum])
    assert_equal(300*4/bin_num, flushed["test"][:avg])
  end

  def test_some_hist_exist_case_tagging_with_emit
    f = create_driver
    data = {"keys" => ["A", "B", "C"]}
    f.run do
      ["test.a", "test.b", "test.c"].each do |tag|
        f.instance.increment(tag, data)
      end
    end

    f.instance.flush # clear hist
    flushed = f.instance.flush
    assert_equal(true, flushed.key?("histo.test.a"))
    assert_equal(true, flushed.key?("histo.test.b"))
    assert_equal(true, flushed.key?("histo.test.c"))
  end

  def test_can_detect_hotspot
    f = create_driver(%[
                        count_key      keys
                        flush_interval 10s
                        bin_num        100
                        tag_prefix     histo
                        tag_suffix     __HOSTNAME__
                        hostname       localhost
                        input_tag_remove_prefix test])
    # ("A".."ZZ").to_a.size == 702
    data = ("A".."ZZ").to_a.shuffle
    f.run do 
      100.times do 
        data.each_slice(10) do |d|
          f.emit({"keys" => d})
        end
      end
    end
    flushed_even = f.instance.flush
    
    #('A'..'ZZ').to_a.shuffle.size == 702
    # In here, replace 7 values of ('A'..'ZZ') to 'D' as example hotspot.
    data.size.times {|i| data[i] = 'D' if i%100 == 0 }
    f.run do 
      100.times do 
        data.each_slice(10) do |d|
          f.emit({"keys" =>  d})
        end
      end
    end
    flushed_bias = f.instance.flush

    assert_equal(true, flushed_even["histo.localhost"][:sd] < flushed_bias["histo.localhost"][:sd])
  end

  def test_sampling
    bin_num = 100
    sampling_rate = 10
    f = create_driver(%[ 
                      bin_num #{bin_num}
                      sampling_rate #{sampling_rate}
                      alpha 0 ])
    f.run do
      100.times do 
        f.emit({"keys" => ["A", "B", "C"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(300, flushed["test"][:sum])
    assert_equal(300/bin_num, flushed["test"][:avg])
  end

end
