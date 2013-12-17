# fluent-plugin-histogram

Fluentd output plugin to count message keys, 
and make histogram to help detecting hotspot problems.


Example, if run below commands, 
```
$ echo '{"keys":["A",  "B",  "C",  "A"]}' | fluent-cat test.input
$ echo '{"keys":["A",  "B",  "D"]}' | fluent-cat test.input
```

output is
```

2013-12-18 03:19:48 +0900 histo: {"hist":[2,0,0,0,0,0,0,0,1,0,0,0,3,1,0,0,0,0,0,0],"sum":7,"avg":0,"sd":0}
```

run bench
```
$ ruby bench/genload.rb test.input 5000
```

output is, 
```
2013-12-18 03:14:29 +0900 histo: {
    "hist":[191,207,349,222,233,205,467,222,498,191,219,196,153,178,345,198,357,207,190,345,390,213,487,173,325,192,188,231,366,187,173,219,166,395,322,186,200,191,204,202,223,164,178,302,170,234,223,142,365,195,466,182,168,158,196,195,213,317,355,190,209,249,325,197,194,207,193,336,352,340,181,354,227,192,193,454,334,346,164,181,219,190,338,203,352,223,199,359,186,378,223,194,330,204,198,319,207,217,193,221],
    "sum":25000,
    "avg":250,
    "sd":85}
```

## Configuration

```
<match test.input.**>
    type        histogram
    count_key   keys        # input message tag to be counted
    flush_interval  10s     # flush interval[s] (:default 60s)
    tag_prefix  histo
    input_tag_remove_prefix test.input
</match>
```

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-histogram'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-histogram

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
