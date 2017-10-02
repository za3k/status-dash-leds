require 'open-uri'
require 'nokogiri'
require './laserstring.rb'

class Hash
    def map_value &block
        Hash[map do |(key, value)|
            [key, block.call(value)]
        end]
    end
    def compose other
        map_value &other.method(:[])
    end
end

class Za3k
    def self.expected_services 
        %i{avalanche_backup avalanche_za3k_com better_than_wolves blog_za3k_com burn_za3k_com comcast corrupt_backup ddns ddns_za3k_com deadtree_backup deadtree_xen_prgmr_com equilibrate_backup etherpad_za3k_com ghtorrent_downloader giant_ant_backup github_personal_backup github_repo_list github_repo_list_updater hermitpack irc_webchat irc_webchat irc_za3k_com jsfail_com library_za3k_com library_za3k_com_card_catalog logging_analog markdown minecraft_za3k_com moreorcs_com multiple_cgi_scripts nanowrimo_za3k_com petchat_za3k_com publishing_za3k_com stylish_view tarragon_backup thisisashell_supervisor transmission_moreorcs_com tron_alloscomp_com twitter_archive whoami xenu_za3k_com za3k_com znc}
    end
    def fetch timeout=5
        page = Nokogiri::HTML(open("https://status.za3k.com/?t=#{timeout}"))
        results = Hash[page.css('tr').map do |row|
            service = row.css('td[1]').text.gsub(/[- .]+/, "_").to_sym
            [service,
             {
                :service => service,
                :status => row.css('td[2]').text.to_sym,
                :details => row.css('td[3]').text
             }]
        end]
        Za3k.expected_services.each do |service|
            raise "Expected service #{service} missing" unless results.has_key? service
        end
        results
    end
end

class StatusPage
    def initialize
        @za3k = Za3k.new
        leds.each do |led|
            raise "LED #{led} is missing definition" unless respond_to? led
        end
    end
    def update
        @za3k_status = @za3k.fetch
        statuses
    end
    def statuses
        Hash[leds.map do |led|
            [led, (send led)]
        end]
    end
    def leds
        []
    end
    def status_to_color
        b = blink
        {
            :failure => :red,
            :success => :green,
            :timeout => :orange,
            :stale => :yellow,
            :extreme_failure => if b then :bright_red else :red end,
            :unfinished => :darkblue,
            :nothing => :black,
            :skip => :skip
        }
    end
    def blink
        Time.now.to_f % 2 > 1
    end
    def colors
        statuses.compose status_to_color
    end
    def self.light led, description, fetcher
        raise "LED #{led} already defined" if respond_to? led
        if method_defined? fetcher
            alias_method led, fetcher
        elsif Za3k.expected_services.include? fetcher
            define_method led do
                @za3k_status[fetcher][:status]
            end
        else
            raise "Implementation #{fetcher} is unknown"
        end
    end
    def self.urgent led
        old_led = instance_method led
        define_method(led) do
            status = old_led.bind(self).()
            status = :extreme_failure if status == :failure
            status
        end
    end
    #def relies_on led, *leds
    #    old_led = instance_method(led)
    #    define_method(led) do
    #        status = old_led.bind(self).()
    #end
    def not_done
        :unfinished
    end
    def left_blank
        :nothing
    end
    def out_of_scope
        :skip
    end
    def fail
        :failure
    end
    def pass
        :success
    end
    alias_method :succeed, :pass
end

class Za3kStatusPage < StatusPage
    def leds
        cols = %w(0 1 2 3)
        rows = %w(0 1 2 3 4 5 6 7 8 9 a b c d e f)
        cols.product(rows).map { |(col, row)| "l#{col}#{row}".to_sym }
    end

    light :l00, "LAN (wifi, ping 192.168.1.1)", :out_of_scope
    light :l01, "Status Service (update watchdog)", :out_of_scope
    light :l02, "status.za3k.com", :not_done
    urgent :l02
    # Uptime monitor
    light :l03, "avalanche.za3k.com", :avalanche_za3k_com
    light :l04, "burn.za3k.com", :burn_za3k_com
    urgent :l04
    #light :l02, "corrupt.za3k.com", :corrupt_za3k_com
    light :l05, "corrupt.za3k.com", :not_done
    #light :l03, "deadtree.za3k.com", :deadtree_za3k_com
    light :l06, "deadtree.za3k.com", :not_done
    #light :l04, "forget.za3k.com", :forget_za3k_com
    light :l07, "forget.za3k.com", :not_done
    light :l08, "xenu.za3k.com (linux)", :xenu_za3k_com
    #light :l06, "xenu.za3k.com (windows)", :xenu_windows_za3k_com
    light :l09, "xenu.za3k.com (windows)", :not_done
    light :l0a, "tarragon phonehome", :not_done
    light :l0b, "mac phonehome", :not_done
    light :l0c, "giant-ant phonehome", :not_done
    light :l0d, "giant-bee phonehome", :not_done
    light :l0e, "", :left_blank
    light :l0f, "", :left_blank


    light :l10, "Internet (ping 8.8.8.8, IPv6)", :not_done
    urgent :l10
    light :l11, "", :left_blank
    light :l12, "", :left_blank

    light :l13, "avalanche.backup", :avalanche_backup
    #light :l14, "burn.backup", :burn_backup
    light :l14, "burn.backup", :not_done
    light :l15, "corrupt.backup", :corrupt_backup
    light :l16, "deadtree.backup", :deadtree_backup
    #light :l14, "forget.backup", :forget_backup
    light :l17, "forget.backup", :not_done
    #light :l15, "xenu (linux) backup", :xenu_backup
    light :l18, "xenu (linux) backup", :not_done
    light :l19, "xenu (windows) backup", :fail
    light :l1a, "tarragon backup", :tarragon_backup
    #light :l18, "mac backup", :mac_backup
    light :l1b, "mac backup", :fail
    light :l1c, "giant-ant backup", :giant_ant_backup
    #light :l1a, "giant-bee backup", :giant_bee_backup
    light :l1d, "giant-bee backup", :not_done
    light :l1e, "", :left_blank
    light :l1f, "", :left_blank

    # Services monitor
    light :l20, "status.za3k.com", :not_done # note: repeat
    light :l21, "github repo list, webpage, downloader", :not_done
    light :l22, "non-vital: nanowrimo, petchat", :not_done
    light :l23, "publishing.za3k.com", :publishing_za3k_com
    light :l24, "moreorcs.com", :moreorcs_com
    light :l25, "jsfail.com", :jsfail_com
    light :l26, "za3k.com", :not_done
    #26 za3k.com (stylish.view, multiple cgi scripts, markdown)
    light :l27, "blog.za3k.com", :blog_za3k_com
    light :l28, "library.za3k.com", :library_za3k_com
    light :l29, "ddns + ddns.za3k.com", :not_done
    light :l2a, "twitter archive", :twitter_archive
    light :l2b, "etherpad.za3k.com", :etherpad_za3k_com
    light :l2c, "znc.za3k.com", :znc
    light :l2d, "logging - analog", :logging_analog
    light :l2e, "irc.za3k.com + webchat", :not_done
    light :l2f, "email (imap, smtp, filters)", :not_done
    urgent :l2f

    # Board 4
    light :l30, "minecraft.za3k.com", :minecraft_za3k_com
    light :l31, "colony on the moon (downloads)", :not_done
    light :l32, "better than wolves", :better_than_wolves
    light :l33, "minecraft (latest, 25565)", :pass
    light :l34, "", :left_blank
    light :l35, "", :left_blank
    light :l36, "", :left_blank
    light :l37, "ghtorrent downloader", :ghtorrent_downloader
    light :l38, "github personal backup", :github_personal_backup
    light :l39, "tron.alloscomp.com", :tron_alloscomp_com
    light :l3a, "transmission.moreorcs.com", :transmission_moreorcs_com
    light :l3b, "keystroked", :not_done
    light :l3c, "network logger", :not_done
    light :l3d, "comcast data usage", :not_done
    light :l3e, "current network usage", :not_done
    light :l3f, "", :left_blank
end

sp = Za3kStatusPage.new
ls = LaserString.new(offset: 2, num_lights: 50)
loop do
    sp.update
    lights = sp.colors.values.reject { |i| i==:skip }
    lights += Array.new(64, :black)
    ls.send_frame! lights
end

