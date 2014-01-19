# fluent-plugin-histogram

Fluentd output plugin. 

Count up input keys, and make **scalable and rough histogram** to help detecting hotspot problems.

"Scalable rough histogram" fit for cases there are an enormous variety of keys.

We refered ["Strauss,  O.: Rough histograms for robust statistics, Pattern Recogniti, 2000. Proceedings. 15th International Conference on (Volume:2)"](http://ieeexplore.ieee.org/xpl/mostRecentIssue.jsp?punumber=7237) for "rough histogram". 
In this approarch, a increment unit is not one value(`.`), increment some values like this shape `△ `.
To use this, please set `alpha >= 1`(default 1) option in fluent.conf.

Moreover, we optimized that histogram for enormous variety of keys by fix histogram width.
To use this, please set `bin_num`(default 100) in fluent.conf. 

Be careful, our plugin's output histogram is not correct count-up result about provided data. But this plugin can handle 25,000 records/sec inputs data, and that outputted histogram is enough to use for detecting hotspot problem.

## Examples

##### Example 1

if run below commands, 
```
$ echo '{"keys":["A",  "B",  "C",  "A"]}' | fluent-cat input.sample
$ echo '{"keys":["A",  "B",  "D"]}' | fluent-cat input.sample
```

output is
```
2013-12-21T11:08:25+09:00       histo.sample.localhost   {"hist":[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 6, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 2, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0], "sum":28, "avg":0, "sd":0}
```

count up about you specified key, and make **histogramatic something**.

And calculate,

* Sum(**sum**)
* Average(**avg**)
* Standard Deviation(**sd**)

##### Example 2

run bench
```
$ ruby bench/genload.rb input.sample 5000
```

output is, 
```
2013-12-21T11:09:52+09:00       histo.sample.localhost   
{"hist":
[859, 963, 1224, 1252, 957, 764, 746, 929, 1406, 1519, 1072, 955, 1069, 916, 797, 948, 1090, 915, 727, 730, 898, 1051, 918, 780, 751, 890, 1104, 976, 949, 1138, 996, 959, 1100, 964, 840, 832, 1020, 1196, 969, 756, 750, 939, 1108, 928, 883, 1154, 1173, 951, 871, 837, 776, 896, 1048, 961, 825, 780, 959, 1113, 1034, 1019, 1090, 1274, 1370, 1207, 930, 898, 1029, 907, 951, 1113, 921, 992, 1422, 1509, 1253, 924, 941, 1099, 898, 775, 994, 1182, 1170, 1515, 1788, 1216, 870, 1038, 938, 744, 826, 969, 892, 843, 883, 840, 800, 966, 1115, 978], 
"sum":100000, 
"avg":1000, 
"sd":193}
```

## Configuration

```
<match input.**>
    type            histogram
    count_key       keys            # input message tag to be counted
    flush_interval  10s             # flush interval[s] (:default 60s)
    tag_prefix      histo
    tag_suffix      __HOSTNAME__    # this plugin mixined fluent-mixin-config-placeholders
    input_tag_remove_prefix input
    alpha           2
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
