# What is a ruby light? A laser.
require 'color'
require 'socket'

class LaserString
    @@socket_semaphore = Mutex.new
    def initialize host: nil, port: nil, num_lights: nil, offset: nil
        @host = host || ENV["HOST"] || "192.168.1.70"
        @port = port || ENV["PORT"] || 10000
        @num_lights=num_lights
        @offset=offset
    end

    def send_stream! thing
        self.with_socket do |socket|
            thing.each { |frame| self.send_frame! thing }
        end
    end

    def send_frame! thing
        self.with_socket do |socket|
            thing = Frame.new(thing, @num_lights, @offset) unless thing.is_a? Frame
            @socket.puts thing.binary
        end
    end

    def with_socket &block
        if @socket.nil?
            @socket = TCPSocket.new @host, @port
            block.call @socket
            @socket.close
        end
    end

    attr_accessor :host, :port, :num_lights
end

class Frame
    @@brightness = ARGV[2] || -96
    def initialize colors, num_lights=nil, offset=nil
        colors = [colors] unless colors.respond_to? :each
        @lights = colors.map { |color| self.color color }
        @start_index=offset
        unless @num_lights.nil?
            @lights += (colors.length..num_lights).each { self.color(:black) }
        end
        @delay = 0
        @start_index = 0
    end
    def binary
        header = ['w'.ord, @delay, @start_index, @lights.length].pack("CCCC")
        body = (@lights.map { |color| [color.red, color.green, color.blue] }).flatten().pack("C*")
        command = [(header + body).length].pack("n") + header + body
        command + "\0"
    end
    def color color
        begin
            color = Color::RGB.by_name(color)
        rescue ArgumentError, KeyError
            color = Color::RGB.from_html(color)
        end
        color = color.adjust_brightness(@@brightness)
    end
end
