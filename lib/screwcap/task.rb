class Task < Screwcap::Base
  def initialize(opts = {}, &block)
    super
    self.__name = opts[:name]
    self.__options = opts
    self.__commands = []
    self.__command_sets = []
    self.__server_names = []


    if opts[:server] and opts[:servers].nil?
      self.__server_names << opts[:server]
    else
      self.__server_names = opts[:servers]
    end

    validate(opts[:deployment_servers])
  end

  # run a command. basically just pass it a string containing the command you want to run.
  def run arg, options = {}, &block
    if arg.class == Symbol
      self.__commands << self.send(arg)
    else
      self.__commands << arg
    end
  end

  def execute!
    threads = []
    self.__servers.each do |_server|
      _server.__addresses.each do |_address|
        if self.__options[:parallel] == false
          execute_on(_server, _address)
        else
          threads << Thread.new(_server, _address) { |server, address| execute_on(server, address) }
        end
      end
    end
    threads.each {|t| t.join }
  end

  protected

  def method_missing(m, *args)
    if m.to_s[0..1] == "__" or [:run].include?(m) or m.to_s.reverse[0..0] == "="
      super(m, args.first) 
    else
      if cs = self.__command_sets.find {|cs| cs.name == m }
        # eval what is in the block
        clone_table_for(cs)
        cs.__commands = []
        cs.instance_eval(&cs.__block)
        self.__commands += cs.__commands
      else
        raise NoMethodError, "Undefined method '#{m.to_s}' for task :#{self.name.to_s}"
      end
    end
  end

  private

  def clone_table_for(object)
    self.table.each do |k,v|
      object.set(k, v) unless [:__command_sets, :name, :__commands, :__options].include?(k)
    end
  end

  def validate(servers)
    raise Screwcap::ConfigurationError, "Could not find a server to run this task on.  Please specify :server => :servername or :servers => [:server1, :server2] in the task_for directive." if self.__server_names.blank?

    self.__server_names.each do |server_name|
      raise Screwcap::ConfigurationError, "Could not find a server to run this task on.  Please specify :server => :servername or :servers => [:server1, :server2] in the task_for directive." unless servers.map(&:name).include?(server_name)
    end

    # finally map the actual server objects via name
    self.__servers = self.__server_names.map {|name| servers.find {|s| s.name == name } }
  end

  def execute_on(server, address) 
    begin
      log "\n*** BEGIN executing task #{self.__name} on server #{server.name} with address #{address}\n" unless self.__options[:silent] == true

      server.__with_connection_for(address) do |ssh|
        error = false
        self.__commands.each do |command|
          next if error and self.__options[:stop_on_errors]
          log "    I: (#{address}):  #{command}\n" unless self.__options[:silent] == true

            ssh.exec! command do |ch,stream,data|
              if stream == :stderr
                error = true
              errorlog "    E: #{data}"
            else
              log "    O: (#{address}):  #{data}" unless self.__options[:silent] == true
            end
          end # ssh.exec
        end # commands.each
      end # net.ssh start
    rescue Net::SSH::AuthenticationFailed => e
      raise Net::SSH::AuthenticationFailed, "Authentication failed for server named #{server.name}.  Please check your authentication credentials."
    rescue Exception => e
      errorlog "    F: #{e}"
    ensure
      log "\n*** END executing task #{self.__name} on server #{server.name} with address #{address}\n\n" unless self.__options[:silent] == true
    end
  end

end
