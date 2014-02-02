# fluent-plugin-histogram

Fluentd output plugin.

Count up input keys, and make **scalable and rough histogram** to help detecting hotspot problems.

"Scalable rough histogram" fit for cases there are an enormous variety of keys.

We refered ["Strauss,  O.: Rough histograms for robust statistics, Pattern Recogniti, 2000. Proceedings. 15th International Conference on (Volume:2)"](http://ieeexplore.ieee.org/xpl/mostRecentIssue.jsp?punumber=7237) for "rough histogram".
In this approarch, a increment unit is not one value(`.`), increment some values like this shape `△ `.
To use this, please set `alpha >= 1`(default 1) option in fluent.conf.

Moreover, we optimized that histogram for enormous variety of keys by fix histogram width.
To use this, please set `bin_num`(default 100) in fluent.conf.

Be careful, our plugin's output histogram is not correct count-up results about provided data. But this plugin can scale out - can handle 25,000 records/sec inputs data -, and that output histogram is enough to use for detecting a hotspot problem.

## Examples

##### Example 1

if run below commands,
```
$ echo '{"keys":"a key"}' | fluent-cat input.sample
$ echo '{"keys":["one",  "two",  "takusan",  "takusan", "takusan", "takusan"]}' | fluent-cat input.sample
$ echo '{"keys":{"Q":2,  "Y":2,  "X":1,  "D":1}}' | fluent-cat input.sample
```

output is
```
2014-02-02 23:08:58 +0900 histo.sample.localhost: {
    "hist":[0,0,2,4,2,0,0,0,0,1,5,7,3,0,1,7,12,7,1,0,0,0,0,0,0,0],
    "sum":13,
    "avg":0,
    "sd":3
}
```

count up about you specified key, and make **histogramatic something**.

And calculate,

* Sum(**sum**)
* Average(**avg**)
* Standard Deviation(**sd**)

##### Example 2

run bench
```
$ ruby bench/genload.rb input.sample 7000 -l 5
```

output is,
```
2014-02-01 18:39:52 +0900 histo.sample.localhost: {
    "hist":[0,0,0,0,0,0,0,13,36,38,31,36,37,32,32,32,30,25,10,0,0,0,0,0,0,0,0,76,221,275,248,242,274,302,293,281,274,200,66,0,0,0,0,0,0,0,0,222,655,875,899,917,907,869,851,864,859,640,230,21,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,69,203,261,189,62,0,0,3,7,6,6,7,6,7,8,7,8,10,5,0,225,681,909,873,811,820,873,870,886,923,913,902,902,921,940,900,874,892,899,901,869,839,844,827,809,805,592,192,0,0,0,51,150,193,190,198,200,201,209,203,205,168,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,20,22,16,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,104,147,118,41,0,0,1,5,9,8,4,3,7,10,8,6,5,2,0,0,0,0,0,0,0,0,0,0,0,0,5,13,16,19,21,22,23,18,20,33,31,11,0,0,0,0,0,0,0,0,35,107,152,148,124,122,146,168,172,163,117,38,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,9,22,29,13,0,0,0,0,0,0,1,2,1,0,1,2,1,0,0,38,102,127,100,37,0,0,1,5,9,10,11,11,11,13,14,14,10,4,2,1,1,2,1,0,0,0,0,1,2,2,7,17,24,29,34,36,29,28,41,41,25,8,1,2,1,1,2,2,2,2,30,79,97,95,99,114,122,126,132,122,93,37,2,3,3,2,2,2,3,3,2,2,2,2,1,0,0,0,1,8,22,29,20,7,2,2,2,3,5,8,10,7,3,2,1,0,1,3,3,30,94,138,112,42,4,4,11,14,9,6,5,8,12,8,3,1,1,4,8,12,13,11,10,9,9,9,8,7,3,0,7,20,27,27,22,22,29,27,25,25,16,10,8,6,4,4,7,6,4,3,18,60,94,110,121,110,90,95,116,128,98,38,12,11,11,13,7,2,5,10,11,8,5,4,3,3,8,10,6,12,21,20,19,18,14,11,10,10,13,16,13,9,9,8,5,4,5,9,11,41,95,106,70,26,7,6,4,15,26,19,12,12,14,16,17,15,10,8,6,4,5,5,3,5,8,7,8,10,9,6,7,15,22,25,24,22,29,37,35,27,16,12,11,8,10,12,16,21,18,9,23,72,107,99,108,150,158,135,139,166,148,95,69,71,59,25,10,11,9,8,7,8,13,14,12,13,10,3,1,11,28,37,35,25,15,10,7,9,15,18,13,12,23,26,18,14,15,13,10,38,83,85,54,42,58,68,52,25,15,20,19,17,19,17,12,11,11,9,13,20,22,19,12,13,24,23,15,16,14,13,18,27,38,35,26,26,32,42,47,44,37,26,17,13,16,18,13,13,16,11,29,75,95,94,108,142,171,172,155,139,121,91,73,67,52,36,28,20,11,10,17,27,26,11,4,15,31,36,31,31,37,38,34,33,32,25,19,16,13,13,13,16,22,22,20,24,34,31,14,27,71,105,98,62,57,77,66,34,26,31,28,29,38,39,26,23,30,29,27,29,27,17,10,20,35,36,25,20,24,23,20,27,41,42,33,34,41,45,44,42,40,36,32,29,28,20,20,35,41,40,35,31,34,33,31,46,61,65,74,80,81,79,84,94,77,44,31,31,33,30,17,21,33,30,28,37,51,56,43,30,32,37,34,29,32,33,32,37,39,39,41,41,37,24,20,39,54,51,37,37,51,51,67,118,159,164,148,125,105,101,100,97,102,123,144,131,110,95,81,92,98,96,112,116,107,89,83,111,133,130,126,128,125,139,162,152,131,122,111,120,148,133,100,100,107,121,133,129,115,91,89,117,136,140,139,142,174,193,182,198,206,180,174,194,192,150,126,147,169,170,151,132,129,113,293,719,955,929,902,923,907,876,884,874,676,324,161,165,149,129,99,81,92,100,98,104,121,95,66,108,144,144,139,156,188,177,151,140,115,98,119,135,132,138,137,129,137,150,141,121,126,106,76,278,646,849,716,352,157,160,161,166,182,191,172,143,155,183,179,181,188,171,157,156,153,112,100,187,231,218,229,221,208,208,216,245,271,268,247,245,254,234,221,244,245,218,203,195,188,141,154,285,327,306,417,629,755,757,732,708,707,704,643,615,556,376,280,279,267,250,256,284,266,175,220,457,581,596,617,603,551,522,550,563,553,567,565,512,476,472,468,464,454,429,423,453,447,306,95,0,0,0,0,91,283,386,287,93,0,0,4,12,14,15,20,21,16,9,7,9,9,4,0,0,0,0,0],
    "sum":28415,
    "avg":27,
    "sd":202
}
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
    bin_num         1024
    alpha           1               # count up like this,  (■ = +1)
                                    #                             ■
                                    #                  ■        ■ ■ ■
                                    #          ■     ■ ■ ■    ■ ■ ■ ■ ■
                                    # alpha:   0,      1,         2

    sampling_rate   10              # input datas be thin outed to 1/10.
</match>
```

##### Adbanced Configuration

* 'tag'
* 'out_include_histo'
* 'disable_revalue'
* 'hostname'

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
