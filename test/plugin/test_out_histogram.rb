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
    assert_raise(Fluent::ConfigError) {
      create_driver %[ sampling_rate -1 ]
    }
  end

  def test_small_increment_no_alpha
    bin_num = 100
    alpha = 0
    f = create_driver(%[
                        bin_num #{bin_num}
                        alpha #{alpha}],
                      "test.input")
    f.run do
      f.emit({"keys" => "input key"})
      f.emit({"keys" => "another key"})
      f.emit({"keys" => 12})
      f.emit({"keys" => ["1", "2", "3"]})
    end
    hist = f.instance.zero_hist.dup
    id = "input key"[0..9].codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 1
    id = "another key"[0..9].codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 1
    id = 12.to_s.codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 1
    ["1", "2", "3"].each do |k|
      id = k.ord % bin_num
      hist[id] += 1
    end

    act_hist = hist.dup.select{|v| v > 0}
    sd = act_hist.instance_eval do
      avg = inject(:+) / size
      sigmas = map { |n| (avg - n)**2 }
      Math.sqrt(sigmas.inject(:+) / size)
    end
    assert_equal({"test.input" => {:hist => hist, :sum => 6, :avg => 6/act_hist.size, :sd=>sd.to_i}},
                 f.instance.flush)
  end

  def test_small_increment_with_alpha
    bin_num = 10
    alpha = 1
    f = create_driver(%[
                        bin_num #{bin_num}
                        alpha #{alpha}],
                     "test.input")
    f.run do
      f.emit({"keys" => "A"})
      f.emit({"keys" => "B"})
      f.emit({"keys" => 12})
      f.emit({"keys" => ["1", "2", "3"]})
    end
    hist = f.instance.zero_hist.dup
    id = "A".ord % bin_num
    hist[id] += 2
    hist[(id + alpha) % bin_num] += 1
    hist[(id - alpha) % bin_num] += 1

    id = "B".ord % bin_num
    hist[id] += 2
    hist[(id + alpha) % bin_num] += 1
    hist[(id - alpha) % bin_num] += 1

    id = 12.to_s.codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 2
    hist[(id + alpha) % bin_num] += 1
    hist[(id - alpha) % bin_num] += 1

    ["1", "2", "3"].each do |k|
      id = k.ord % bin_num
      hist[id] += 2
      hist[(id + alpha) % bin_num] += 1
      hist[(id - alpha) % bin_num] += 1
    end

    act_hist = hist.select{|v| v > 0}
    sd = act_hist.instance_eval do
      avg = inject(:+) / size
      sigmas = map { |n| (avg - n)**2 }
      Math.sqrt(sigmas.inject(:+) / size)
    end
    assert_equal({"test.input" => {:hist => hist, :sum => 6, :avg => 6/act_hist.size, :sd=>sd.to_i}},
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
    act_hist = flushed["test.input"][:hist].select{|v| v > 0}
    assert_equal(1000, flushed["test.input"][:sum])
    assert_equal(1000/act_hist.size, flushed["test.input"][:avg])
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
    act_hist = flushed["test"][:hist].select{|v| v > 0}
    assert_equal(300, flushed["test"][:sum])
    assert_equal(300/act_hist.size, flushed["test"][:avg])
  end

  def test_some_hist_exist_case_tagging_with_emit
    f = create_driver
    data = "A"
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
                        bin_num        #{2**10}
                        tag_prefix     histo
                        tag_suffix     __HOSTNAME__
                        hostname       localhost
                        alpha          1
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

    assert_equal(true, flushed_even["histo.localhost"][:sd] < flushed_bias["histo.localhost"][:sd],
                 "expected
even:#{flushed_even["histo.localhost"]}
 <
bias:#{flushed_bias["histo.localhost"]}")
  end

  def test_sampling
    bin_num = 100
    sampling_rate = 10
    f = create_driver(%[
                      bin_num       #{bin_num}
                      sampling_rate #{sampling_rate}
                      alpha 0 ])
    f.run do
      sampling_rate.times do
        f.emit({"keys" => ["A"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(sampling_rate, flushed["test"][:sum])

    f.run do
      1.times do  # 1 < sampling_rate
        f.emit({"keys" => ["A"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(0, flushed["test"][:sum])

    f.run do
      100.times do
        f.emit({"keys" => ["A", "B", "C"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(100*3, flushed["test"][:sum])
  end

  def test_revalue
    f = create_driver(%[
                      alpha 1
                      disable_revalue true])
    f.run do
      100.times do  # 1 < sampling_rate
        f.emit({"keys" => ["A"]})
      end
    end
    flushed = f.instance.flush
    assert_equal(100*4, flushed["test"][:sum])
  end

  def test_not_include_hist
    f = create_driver(%[out_include_hist false])
    f.run do
      f.emit({"keys" => ["A"]})
    end
    flushed = f.instance.flush
    assert_equal(false, flushed["test"].has_key?("hist"))
  end

  def test_can_input_hash_record
    bin_num = 10
    f = create_driver(%[
                        bin_num #{bin_num}
                        alpha 0],
                      "test.input")
    f.run do
      f.emit({"keys" => {"a" => 1, "b" => 2, "c" => 3}})
    end
    hist = f.instance.zero_hist.dup
    id = "a"[0..9].codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 1
    id = "b"[0..9].codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 2
    id = "c"[0..9].codepoints.collect{|cp| cp}.join().to_i % bin_num
    hist[id] += 3

    act_hist = hist.dup.select{|v| v > 0}
    sd = act_hist.instance_eval do
      avg = inject(:+) / size
      sigmas = map { |n| (avg - n)**2 }
      Math.sqrt(sigmas.inject(:+) / size)
    end
    flushed = f.instance.flush
    assert_equal({"test.input" => {:hist => hist, :sum => 6, :avg => 6/act_hist.size, :sd=>sd.to_i}}, flushed)
  end

  def test_output_zero_length_hist
    bin_num = 5
    f = create_driver(%[ bin_num #{bin_num} ])
    flushed = f.instance.flush
    assert_equal({}, flushed)

    f.run do
      f.emit({"keys" => "a"})
    end
    f.instance.flush # flush
    flushed = f.instance.flush
    assert_equal([0]*5, flushed["test"][:hist])
    assert_equal(0, flushed["test"][:sum])
    assert_equal(0, flushed["test"][:avg])
    assert_equal(0, flushed["test"][:sd])
  end

end
