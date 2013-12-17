# fluent-plugin-histogram

Fluentd output plugin to count message keys, 
and make histogram to help detecting hotspot problems.

```
$ echo '{"keys":["A",  "B",  "C",  "A"]}' | fluent-cat test.combine.input
$ echo '{"keys":["A",  "B",  "D"]}' | fluent-cat test.combine.input
```

output is
```
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
