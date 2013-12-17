require 'optparse'
require 'fluent/env'

op = OptionParser.new

op.banner += " <tag> <num>"

port = Fluent::DEFAULT_LISTEN_PORT
host = '127.0.0.1'
unix = false
socket_path = Fluent::DEFAULT_SOCKET_PATH
send_timeout = 20.0
repeat = 1
para = 1
multi = 1
record_len = 5
packed = true

config_path = Fluent::DEFAULT_CONFIG_PATH

op.on('-p', '--port PORT', "fluent tcp port (default: #{port})", Integer) {|i|
  port = s
}

op.on('-h', '--host HOST', "fluent host (default: #{host})") {|s|
  host = s
}

op.on('-u', '--unix', "use unix socket instead of tcp", TrueClass) {|b|
  unix = b
}

op.on('-P', '--path PATH', "unix socket path (default: #{socket_path})") {|s|
  socket_path = s
}

op.on('-r', '--repeat NUM', "repeat number (default: 1)", Integer) {|i|
  repeat = i
}

op.on('-m', '--multi NUM', "send multiple records at once (default: 1)", Integer) {|i|
  multi = i
}

op.on('-l', '--record_len NUM', "a record to be send have NUM keys (default: 5)", Integer) {|i|
  record_len = i
}

op.on('-c', '--concurrent NUM', "number of threads (default: 1)", Integer) {|i|
  para = i
}

op.on('-G', '--no-packed', "don't use lazy deserialization optimize") {|i|
  packed = false
}

(class<<self;self;end).module_eval do
  define_method(:usage) do |msg|
    puts op.to_s
    puts "error: #{msg}" if msg
    exit 1
  end
end

begin
  op.parse!(ARGV)

  if ARGV.length != 2
    usage nil
  end

  tag = ARGV.shift
  num = ARGV.shift.to_i

rescue
  usage $!.to_s
end

require 'socket'
require 'msgpack'
require 'benchmark'

def gen_word(len=nil)
  len = rand(5) + 1 unless len
  rand(36**len).to_s(36)
end

def gen_record(num=5, w_len=nil)
  (1..num).reduce([]) {|ret| ret << gen_word(w_len)}
end


connector = Proc.new {
  if unix
    sock = UNIXSocket.open(socket_path)
  else
    sock = TCPSocket.new(host, port)
  end

  opt = [1, send_timeout.to_i].pack('I!I!')  # { int l_onoff; int l_linger; }
  sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, opt)

  opt = [send_timeout.to_i, 0].pack('L!L!')  # struct timeval
  sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, opt)

  sock
}

def gen_data(tag, multi=1, r_len=5)
  time = Time.now.to_i
  data = ''
  multi.times do
    record = {"keys"=>gen_record(r_len)}
    [time, record].to_msgpack(data)
  end
  data = [tag, data].to_msgpack
end

size = 0 # sum of data.bytesize
repeat.times do
  puts "--- #{Time.now}"
  Benchmark.bm do |x|
    start = Time.now

    lo = num / para / multi
    lo = 1 if lo == 0

    x.report do
      (1..para).map {
        Thread.new do
          sock = connector.call
          lo.times do
            data = gen_data(tag, multi, record_len)
            size += data.bytesize
            sock.write data
          end
          sock.close
        end
      }.each {|t|
        t.join
      }
    end

    finish = Time.now
    elapsed = finish - start

    puts "% 10.3f Mbps" % [size*lo*para/elapsed/1000/1000]
    puts "% 10.3f records/sec" % [lo*para*multi/elapsed]
  end

end

