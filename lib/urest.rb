require 'riddl/server'
require 'json'
require 'typhoeus'
if $dev
  require_relative '../../ur-sock/lib/ur-sock'
else
  require 'ur-sock'
end
require 'net/ssh'
require 'net/scp'

module UREST
  SERVER = File.expand_path(File.join(__dir__,'urest.xml'))

  def self::start_dash(opts) #{{{
    opts['dash'] = UR::Dash.new(opts['ipadress']).connect rescue nil
  end #}}}

  def self::start_psi(opts) #{{{
    opts['psi'] = UR::Psi.new(opts['ipadress']).connect rescue nil
  end #}}}

  def self::start_rtde(opts) #{{{
    ### Loading config file
    conf = UR::XMLConfigFile.new opts['rtde_config']
    output_names, output_types = conf.get_recipe opts['rtde_config_recipe_base']
    opts['rtde'] = UR::Rtde.new(opts['ipadress']).connect

    ### Set Speed
    if opts['rtde_config_recipe_speed']
      speed_names, speed_types = conf.get_recipe opts['rtde_config_recipe_speed']
      opts['speed'] = opts['rtde'].send_input_setup(speed_names, speed_types)
      opts['speed']['speed_slider_mask'] = 1
    end

    ### Set register
    if opts['rtde_config_recipe_inbit']
      bit_names, bit_types = conf.get_recipe opts['rtde_config_recipe_inbit']
      opts['inbit'] = opts['rtde'].send_input_setup(bit_names,bit_types)
    end
    if opts['rtde_config_recipe_inint']
      int_names, int_types = conf.get_recipe opts['rtde_config_recipe_inint']
      opts['inint'] = opts['rtde'].send_input_setup(int_names,int_types)
    end
    if opts['rtde_config_recipe_indoub']
      doub_names, doub_types = conf.get_recipe opts['rtde_config_recipe_indoub']
      opts['indoub'] = opts['rtde'].send_input_setup(doub_names,doub_types)
    end

    ### Setup output
    if not opts['rtde'].send_output_setup(output_names, output_types,10)
      puts 'Unable to configure output'
    end
    if not opts['rtde'].send_start
      puts 'Unable to start synchronization'
    end

    ###Initialize all inputs
    bit_names.each do |i|
      opts['inbit'][i] = false
    end
    int_names.each do |i|
      opts['inint'][i] = 0
    end
    doub_names.each do |i|
      opts['indoub'][i] = 0.0
    end
  end #}}}

  def self::protect_reconnect_run(opts) #{{{
    tries = 0
    begin
      yield
    rescue UR::Dash::Reconnect => e
      puts e.message
      tries += 1
      if tries < 2
        UREST::start_dash opts
        retry
      end
    rescue UR::Psi::Reconnect => e
      puts e.message
      tries += 1
      if tries < 2
        UREST::start_psi opts
        retry
      end
    end
  end #}}}

  def self::ssh_start(opts) #{{{
    if opts['certificate']
      opts['ssh'] = Net::SSH.start(opts['ipadress'], opts['username'], :port => opts['sshport'], :keys => [ opts['certificate'] ])
    else
      opts['ssh'] = opts['password'] ? Net::SSH.start(opts['ipadress'], opts['username'], :port => opts['sshport'], auth_methods: ['password'], password: opts['password']) : Net::SSH.start(opts['ipadress'], opts['username'], :port => opts['sshport'])
    end
  end #}}}

  def self::download_program(opts,name) #{{{
    counter = 0
    begin
      opts['ssh'].scp.download! name
    rescue => e
      counter += 1
      UREST::ssh_start opts
      retry if counter < 3
    end
  end #}}}

  def self::upload_program(opts,name,program) #{{{
    counter = 0
    begin
      opts['ssh'].scp.upload StringIO.new(program), File.join(opts['dir'],name)
    rescue => e
      counter += 1
      UREST::ssh_start opts
      retry if counter < 3
    end
    nil
  end #}}}

  def self::get_robot_programs(opts) #{{{
    progs = []
    once  = false
    begin
      progs = opts['ssh'].exec!('ls ' + File.join(opts['dir'],'*.urp') + ' ' + File.join(opts['dir'],'**','*.urp') + ' 2>/dev/null').split("\n")
      progs.shift if progs[0] =~ /^bash:/
    rescue => e
      UREST::ssh_start opts
      unless once
        once = true
        retry
      end
    end
    progs
  end #}}}

  def self::robotprogram_running?(opts) #{{{
    opts['ps']== 'Playing'
  end #}}}

  def self::start_program(opts,fname) #{{{
    unless UREST::robotprogram_running?(opts)
      UREST::protect_reconnect_run(opts) do
        opts['dash'].load_program(fname)
        opts['dash'].start_program
      end
    end
  end #}}}

  class GetValue < Riddl::Implementation #{{{
    def response
      Riddl::Parameter::Complex.new('value','text/plain',@a[0])
    end
  end  #}}}
  class GetValues < Riddl::Implementation #{{{
    def response
      Riddl::Parameter::Complex.new('values','application/json',JSON::generate(@a[0]))
    end
  end  #}}}

  class GetProg < Riddl::Implementation #{{{
    def response
      opts = @a[0]
      fname = File.join(opts['dir'],@r[1..-1].join('/'))
      if opts['progs'].include? fname
        return Riddl::Parameter::Complex.new('file','application/octet-stream',UREST::download_program(opts,fname),File.basename(fname))
      else
        @status = 403
      end
      nil
    end
  end  #}}}
  class ForkProg < Riddl::Implementation #{{{
    def response
      opts = @a[0]
      fname = File.join(opts['dir'],@r[1..-2].join('/'))
      if opts['progs'].include? fname
        UREST::start_program(opts,fname)
      else
        @status = 403
      end
      nil
    end
  end  #}}}
  class WaitProg < Riddl::Implementation #{{{
    def response
      opts = @a[0]
      fname = File.join(opts['dir'],@r[1..-2].join('/'))
      if opts['progs'].include? fname
        if @h['CPEE_CALLBACK']
          EM.defer do
            UREST::start_program(opts,fname)
            sleep 2
            while UREST::robotprogram_running?(opts)
              sleep 0.25
            end
            Typhoeus.put(@h['CPEE_CALLBACK'])
          end
          @headers << Riddl::Header.new("CPEE-CALLBACK", 'true')
        else
          UREST::start_program(opts,fname)
        end
      else
        @status = 403
      end
      nil
    end
  end  #}}}

  class DeleteSafetyMessage < Riddl::Implementation #{{{
    def response
      opts = @a[0]
      UREST::protect_reconnect_run(opts) do
        opts['dash'].close_safety_popup
      end
      nil
    end
  end  #}}}

  class SetInt < Riddl::Implementation #{{{
    def response
      opts = @a[0]
      value = @p[0].value
      z = @r[-1].to_i
      if z < 10
        opts['inint']["input_int_register_" + z.to_s] = value.to_i
        opts['rtde'].send(opts['inint'])
      else
        @status = 403
      end
      nil
    end
  end  #}}}

  def self::implementation(opts)
    Proc.new do
      startup do #{{{ # Init RTDE and DASH
        opts['sshport'] ||= 22
        opts['frequency'] ||= 0.5

        opts['rtde_config'] ||= File.join(__dir__,'rtde.conf.xml')
        opts['rtde_config_recipe_base'] ||= 'out'
        opts['rtde_config_recipe_speed'] ||= 'speed'
        opts['rtde_config_recipe_inbit'] ||= 'inbit'
        opts['rtde_config_recipe_inint'] ||= 'inint'
        opts['rtde_config_recipe_indoub'] ||= 'indoub'

        opts['dash'] = nil
        opts['rtde'] = nil
        opts['programs'] = nil
        opts['psi'] = nil

        ### Connecting to universal robot
        UREST::start_rtde opts
        UREST::start_dash opts
        UREST::start_psi opts

        ### check if interfaces are ok
        raise if !opts['dash'] || !opts['rtde'] || !opts['psi']

        # Functionality for threading in loop
        opts['doit_state'] = Time.now.to_i
        opts['doit_progs'] = Time.now.to_i - 11
        opts['doit_rtde'] = Time.now.to_i

        # Serious comment (we do the obvious stuff)
        opts['speed'] = {}
        opts['sn'] = opts['dash'].get_serial_number
        opts['model'] = opts['dash'].get_robot_model

        ### Manifest programs
        opts['semaphore'] = Mutex.new
        opts['progs'] = []
      rescue Errno::ECONNREFUSED => e
        print 'ECONNREFUSED: '
        puts e.message
      rescue UR::Dash::Reconnect => e
        UREST::start_dash opts
        puts e.message
        puts e.backtrace
      rescue UR::Psi::Reconnect => e
        UREST::start_psi opts
        puts e.message
        puts e.backtrace
      rescue => e
        puts e.message
        puts e.backtrace
        raise
      end # }}}

      parallel do #{{{ periodic reading of data from UR
        EM.add_periodic_timer(opts[:frequency]) do
          if Time.now.to_i - 1 > opts['doit_state']
            opts['doit_state'] = Time.now.to_i
            opts['cp'] = opts['dash'].get_loaded_program
            opts['rs'] = opts['dash'].get_program_state.split(' ')[0]
            # update remote control state from dashboard server
            opts['mo'] = opts['dash'].is_in_remote_control
            opts['op'] = opts['dash'].get_operational_mode
          end

          if Time.now.to_i - 10 > opts['doit_progs']
            opts['doit_progs'] = Time.now.to_i
            Thread.new do
              opts['semaphore'].synchronize do
                # Content of thread
                # check every 10 seconds for new programs
                opts['progs'] = UREST::get_robot_programs(opts)
              end unless opts['semaphore'].locked?
            end
          end

          data = opts['rtde'].receive
          if data
            opts['ss'] = data['speed_scaling']

            # State objects
            opts['rm'] = UR::Rtde::ROBOTMODE[data['robot_mode']]
            opts['sm'] = UR::Rtde::SAFETYMODE[data['safety_mode']]
            opts['ps'] = UR::Rtde::PROGRAMSTATE[data['runtime_state']]

            #speed slider or override
            if opts['ov'] != (data['target_speed_fraction'] * 100).to_i
              opts['ov'] = (data['target_speed_fraction'] * 100).to_i
            end
          else
            if Time.now.to_i - 10 > opts['doit_rtde']
              opts['doit_rtde'] = Time.now.to_i
              UREST::start_rtde opts
            end
          end
        rescue Errno::ECONNREFUSED => e
          print 'ECONNREFUSED: '
          puts e.message
        rescue UR::Dash::Reconnect => e
          UREST::start_dash opts
          puts e.message
          puts e.backtrace
        rescue UR::Psi::Reconnect => e
          UREST::start_psi opts
          puts e.message
          puts e.backtrace
        rescue => e
          puts e.message
          puts e.backtrace
          raise
        end
      end #}}}

      on resource do
        run GetValues, [ 'messages', 'registers', 'model', 'serialnumber', 'state', 'programs'] if get
        on resource 'model' do #{{{
          run GetValue, opts['model'] if get
        end #}}}
        on resource 'messages' do #{{{
          on resource 'safety' do
            run DeleteSafetyMessage, opts if delete
          end
        end #}}}
        on resource 'serialnumber' do #{{{
          run GetValue, opts['sn'] if get
        end #}}}
        on resource 'state' do #{{{
          run GetValues, {
            :mode => opts['rm'].downcase,
            :power => opts['rm'] == 'Running' ? 'on' : 'off',
            :remote => opts['mo'] || 'false',
            :program => File.basename(opts['cp'] || ''),
            :program_state => (opts['rs'] || 'stopped').downcase,
            :safety_mode => opts['sm'].downcase,
            :speed => opts['ov'],
            :speed_scaling => opts['ss']
          } if get
          on resource 'mode' do
            run GetValue, opts['rm'].downcase if get
          end
          on resource 'power' do
            run GetValue, opts['rm'] == 'Running' ? 'on' : 'off' if get
          end
          on resource 'remote' do
            run GetValue, opts['mo'] || 'false' if get
          end
          on resource 'program' do
            run GetValue, File.basename(opts['cp'] || '') if get
          end
          on resource 'program_state' do
            run GetValue, (opts['rs'] || 'stopped').downcase if get
          end
          on resource 'safety_mode' do
            run GetValue, opts['sm'].downcase if get
          end
          on resource 'speed' do
            run GetValue, opts['ov'] if get
          end
          on resource 'speed_scaling' do
            run GetValue, opts['ss'] if get
          end
        end #}}}
        on resource 'programs' do |r|
          run GetValues, opts['progs'].filter{ |e| e =~ /^\/#{r[:r].join('/')}\/[a-zA-Z0-9_-]+\.urp/ }.map{ |e| File.basename(e) } if get
          on resource '[a-zA-Z0-9_-]+' do |r|
            run GetValues, opts['progs'].filter{ |e| e =~ /^\/#{r[:r].join('/')}\/[a-zA-Z0-9_-]+\.urp/ }.map{ |e| File.basename(e) } if get
            on resource '[a-zA-Z0-9_-]+\.urp' do
              run GetProg, opts if get
              on resource 'fork' do
                run ForkProg, opts if put
              end
              on resource 'wait' do
                run WaitProg, opts if put
              end
            end
          end
        end
        on resource 'registers' do
          on resource 'input' do
            on resource 'int' do
              on resource '\d+' do
                run SetInt, opts if put 'tint'
              end
            end
          end
        end
      end
    end
  end

end
