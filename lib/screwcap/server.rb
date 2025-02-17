module Screwcap
  class Server < Screwcap::Base

    # ====A *server* is the address(es) that you run a *:task* on.
    #   server :myserver, :address => "abc.com", :password => "xxx"
    #   server :app_servers, :addresses => ["abc.com","def.com"], :keys => "~/.ssh/my_key"
    #
    # ==== Options
    # * A server must have a *:user*.
    # * Specify *:address* or *:addresses*
    # * A *:gateway*.  See the section about gateways for more info.
    # * All Other options will be passed directly to Net::SSH.
    #   * *:keys* can be used to specify the key to use to connect to the server
    #   * *:password* specify the password to connect with.  Not recommended.  Use keys.
    def initialize(opts = {})
      super
      self.__options = opts
      self.__name = opts.delete(:name)
      self.__user = opts.delete(:user)
      self.__options[:keys] = [opts.delete(:key)] if opts[:key]

      servers = opts.delete(:servers)
      self.__gateway = servers.select {|s| s.__options[:is_gateway] == true }.find {|s| s.__name == opts[:gateway] } if servers
      self.__connections = []


      if self.__options[:address] and self.__options[:addresses].nil?
        self.__addresses = [self.__options.delete(:address)] 
      else
        self.__addresses = self.__options[:addresses]
      end

      validate

      self
    end

    def connect!
      self.__addresses.each  do |address|

        # do not re-connect.  return if we have already been connected
        next if self.__connections.any? {|conn| conn[:address] == address }

        begin
          if self.__gateway
            self.__connections << {:address => address, :connection => __gateway.__get_gateway_connection.ssh(address, self.__user, options_for_net_ssh) }
          else
            self.__connections << {:address => address, :connection => Net::SSH.start(address, self.__user, options_for_net_ssh) }
          end
        rescue Net::SSH::AuthenticationFailed => e
          raise Net::SSH::AuthenticationFailed, "Authentication failed for server named #{self.name}.  Please check your authentication credentials."
        end
      end
      self.__connections
    end

    def upload! (local, remote)
      self.__connections.each do |conn|
        conn[:connection].scp.upload! local, remote
      end
    end

    protected

    def __get_gateway_connection
      self.__connection ||= Net::SSH::Gateway.new(self.__addresses.first, self.__user, self.__options.reject {|k,v| [:user,:addresses, :gateway, :name, :servers, :is_gateway].include?(k)})
    end

    private

    def validate
      raise Screwcap::InvalidServer, "Please specify an address for the server #{self.__options[:name]}." if self.__addresses.nil? or self.__addresses.size == 0
      raise Screwcap::InvalidServer, "Please specify a username to use for the server #{self.__name}." if self.__user.nil?
      raise Screwcap::InvalidServer, "A gateway can have only one address" if self.__addresses.size > 1 and self.__options[:is_gateway] == true
    end

    def options_for_net_ssh
      self.__options.reject {|k,v| [:user,:addresses, :gateway, :is_gateway, :name, :silent, :servers].include?(k)}
    end
  end
end
