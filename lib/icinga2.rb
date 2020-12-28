#/******************************************************************************
# * Icinga 2 Dashing Job Library                                               *
# * Copyright (C) 2016-2017 Icinga Development Team (https://www.icinga.com)   *
# *                                                                            *
# * This program is free software; you can redistribute it and/or              *
# * modify it under the terms of the GNU General Public License                *
# * as published by the Free Software Foundation; either version 2             *
# * of the License, or (at your option) any later version.                     *
# *                                                                            *
# * This program is distributed in the hope that it will be useful,            *
# * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
# * GNU General Public License for more details.                               *
# *                                                                            *
# * You should have received a copy of the GNU General Public License          *
# * along with this program; if not, write to the Free Software Foundation     *
# * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.             *
# ******************************************************************************/

require 'json'
require 'rest-client'
require 'openssl'
require 'logger'
require 'time'

class Icinga2
  # general info
  attr_reader :version
  attr_reader :node_name
  attr_reader :app_starttime
  attr_reader :uptime
  attr_reader :icingaweb2_url
  attr_reader :time_zone

  # general stats
  attr_reader :avg_latency
  attr_reader :avg_execution_time
  attr_reader :host_active_checks_1min
  attr_reader :host_passive_checks_1min
  attr_reader :service_active_checks_1min
  attr_reader :service_passive_checks_1min

  attr_reader :service_problems_severity

  # host stats
  attr_reader :host_count_all
  attr_reader :host_count_problems
  attr_reader :host_count_problems_down
  attr_reader :host_count_up
  attr_reader :host_count_down
  attr_reader :host_count_in_downtime
  attr_reader :host_count_acknowledged

  # service stats
  attr_reader :service_count_all
  attr_reader :service_count_problems
  attr_reader :service_count_problems_warning
  attr_reader :service_count_problems_critical
  attr_reader :service_count_problems_unknown
  attr_reader :service_count_ok
  attr_reader :service_count_warning
  attr_reader :service_count_critical
  attr_reader :service_count_unknown
  attr_reader :service_count_in_downtime
  attr_reader :service_count_acknowledged

  attr_reader :room_climate_service_enabled
  attr_reader :room_climate_service
  attr_reader :room_climate_temperature
  attr_reader :room_climate_humidity

  attr_reader :isp_service_enabled
  attr_reader :isp_downstream_service
  attr_reader :isp_downstream
  attr_reader :isp_upstream_service
  attr_reader :isp_upstream

  # data providers
  attr_reader :app_data
  attr_reader :cib_data
  attr_reader :all_hosts_data
  attr_reader :all_services_data

  def initialize(configFile)
    # add logger
    file = File.open('/tmp/dashing-icinga2.log', File::WRONLY | File::APPEND | File::CREAT)
    @log = Logger.new(file, 'daily', 1024000)
    @log.level = Logger::INFO
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    @log.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime(@log.datetime_format)}] #{severity.ljust(5)} : #{msg}\n"
    end

    # get configuration settings
    begin
      puts "First trying to read environment variables"
      getConfEnv()
    rescue
      puts "Environment variables not found, falling back to configuration file " + configFile
      getConfFile(configFile)
    end

    @apiVersion = "v1"
    @apiUrlBase = sprintf('https://%s:%d/%s', @host, @port, @apiVersion)

    @hasCert = false
    checkCert()

    @headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def getConfEnv()
    # prefer environment variables over the configuration file
    @host = ENV['ICINGA2_API_HOST']
    @port = ENV['ICINGA2_API_PORT']
    @user = ENV['ICINGA2_API_USERNAME']
    @password = ENV['ICINGA2_API_PASSWORD']
    @pkiPath = ENV['ICINGA2_API_CERT_PATH']
    @nodeName = ENV['ICINGA2_API_NODENAME']

    # external attribute
    @icingaweb2_url = ENV['ICINGAWEB2_URL']

    # dashboards
    @showOnlyHardStateProblems = ENV['DASHBOARD_SHOW_ONLY_HARD_STATE_PROBLEMS']
    @time_zone = ENV['DASHBOARD_TIMEZONE']

    # check for the least required variables, the rest is read later on
    if [@host, @port].all? {|value| value.nil? or value == ""}
      raise ArgumentError.new('Required environment variables not found!')
    end

    puts "Using environment variable configuration on '" + @host + ":" + @port + "'."
  end

  def getConfFile(configFile)
    configFile = File.expand_path(configFile)
    @log.debug(sprintf( '  config file   : %s', configFile))

    # Allow to use 'icinga2.local.json' or any other '.local.json' defined in jobs
    configFileLocal = File.dirname(configFile) + "/" + File.basename(configFile,File.extname(configFile)) + ".local" + File.extname(configFile)

    puts "Detecting local config file '" + configFileLocal + "'."

    if (File.exist?(configFileLocal))
      realConfigFile = configFileLocal
    else
      realConfigFile = configFile
    end

    @log.info(sprintf('Using config file \'%s\'', realConfigFile))
    puts "Using config file '" + realConfigFile + "'."

    begin
      if (File.exist?(realConfigFile))
        file = File.read(realConfigFile)
        @config = JSON.parse(file)

        puts "Reading config" + @config.to_s

        if @config.key? 'icinga2'
          config_icinga2 = @config['icinga2']

          if config_icinga2.key? 'api'
            @host = @config["icinga2"]["api"]["host"]
            @port = @config["icinga2"]["api"]["port"]
            @user = @config["icinga2"]["api"]["user"]
            @password = @config["icinga2"]["api"]["password"]
            @pkiPath = @config["icinga2"]["api"]["pki_path"]
            @nodeName = @config['icinga2']['api']['node_name']
          end
        end

        if @config.key? 'dashboard'
          config_dashboard = @config['dashboard']

          if config_dashboard.key? 'show_only_hard_state_problems' # retire this check later
            @showOnlyHardStateProblems = config_dashboard['show_only_hard_state_problems']
          end

          if config_dashboard.key? 'timezone'
            @time_zone = config_dashboard['timezone']
          end

          @room_climate_service_enabled = false
          if config_dashboard.key? 'room_climate_service'
            if config_dashboard['room_climate_service'].size > 0
              @room_climate_service = config_dashboard['room_climate_service']
              @room_climate_service_enabled = true
            end
          end

          @isp_service_enabled = false
          if config_dashboard.key? 'isp_downstream_service' and config_dashboard.key? 'isp_upstream_service'
            if config_dashboard['isp_downstream_service'].size > 0 and config_dashboard['isp_upstream_service'].size > 0
              @isp_downstream_service = config_dashboard['isp_downstream_service']
              @isp_upstream_service = config_dashboard['isp_upstream_service']
              @isp_service_enabled = true
            end
          end
        end

        if @config.key? 'icingaweb2'
          # external attribute
          @icingaweb2_url = @config['icingaweb2']['url']
        end
      else
        @log.warn(sprintf('Config file %s not found! Using default config.', configFile))
        @host = "localhost"
        @port = 5665
        @user = "dashing"
        @password = "icinga2ondashingr0xx"
        @pkiPath = "pki/"
        @nodeName = nil
        @showOnlyHardStateProblems = false
        @time_zone = "UTC"
        @room_climate_service = ""
        @room_climate_service_enabled = false

        # external attribute
        @icingaweb2_url = 'http://localhost/icingaweb2'
      end

    rescue JSON::ParserError => e
      @log.error('wrong result (no json)')
      @log.error(e)
    end
  end

  def checkCert()
    unless @nodeName
      begin
        @nodeName = Socket.gethostbyname(Socket.gethostname).first
        @log.debug(sprintf('node name: %s', @nodeName))
      rescue SocketError => error
        @log.error(error)
      end
    end

    if File.file?(sprintf('%s/%s.crt', @pkiPath, @nodeName))
      @log.debug("PKI found, using client certificates for connection to Icinga 2 API")
      certFile = File.read(sprintf('%s/%s.crt', @pkiPath, @nodeName))
      keyFile = File.read(sprintf('%s/%s.key', @pkiPath, @nodeName))
      caFile = File.read(sprintf('%s/ca.crt', @pkiPath))

      cert = OpenSSL::X509::Certificate.new(certFile)
      key = OpenSSL::PKey::RSA.new(keyFile)

      @options = {
        :ssl_client_cert => cert,
        :ssl_client_key => key,
        :ssl_ca_file => caFile,
        :verify_ssl => OpenSSL::SSL::VERIFY_NONE # FIXME
      }

      @hasCert = true
    else
      @log.debug("PKI not found, using basic auth for connection to Icinga 2 API")

      @options = {
        :user => @user,
        :password => @password,
        :verify_ssl => OpenSSL::SSL::VERIFY_NONE # FIXME
      }

      @hasCert = false
    end
  end

  def getApiData(apiUrl, requestBody = nil)
    restClient = RestClient::Resource.new(URI.encode(apiUrl), @options)

    maxRetries = 30
    retried = 0

    begin
      if requestBody
        @headers["X-HTTP-Method-Override"] = "GET"
        payload = JSON.generate(requestBody)

        # debug
        #puts "Payload: " + payload
        res = restClient.post(payload, @headers)
      else
        res = restClient.get(@headers)
      end
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      if (retried < maxRetries)
        retried += 1
        $stderr.puts(format("Cannot execute request against '%s': '%s' (retry %d / %d)", apiUrl, e, retried, maxRetries))
        sleep(2)
        retry
      else
        $stderr.puts("Maximum retries (%d) against '%s' reached. Giving up ...", maxRetries, apiUrl)
        return nil
      end
    end

    body = res.body
    # debug
    #puts "Body: " + body
    data = JSON.parse(body)

    return data
  end

  def getIcingaApplicationData()
    apiUrl = sprintf('%s/status/IcingaApplication', @apiUrlBase)
    data = getApiData(apiUrl)

    if not data or not data.has_key?('results') or data['results'].empty? or not data['results'][0].has_key?('status')
      return nil
    end

    return data['results'][0]['status'] #there's only one row
  end

  def getCIBData()
    apiUrl = sprintf('%s/status/CIB', @apiUrlBase)
    data = getApiData(apiUrl)

    if not data or not data.has_key?('results') or data['results'].empty? or not data['results'][0].has_key?('status')
      return nil
    end

    return data['results'][0]['status'] #there's only one row
  end

  def getStatusData()
    apiUrl = sprintf('%s/status', @apiUrlBase)
    data = getApiData(apiUrl)

    if not data or not data.has_key?('results')
      return nil
    end

    return data['results']
  end

  def getHostObjects(attrs = nil, filter = nil, joins = nil)
    apiUrl = sprintf('%s/objects/hosts', @apiUrlBase)

    requestBody = {}

    if (attrs)
      requestBody["attrs"] = attrs
    end

    if (filter)
      requestBody["filter"] = filter
    end

    if (joins)
      requestBody["joins"] = joins
    end

    # fetch data with requestBody (which means X-HTTP-Method-Override: GET)
    data = getApiData(apiUrl, requestBody)

    if not data or not data.has_key?('results')
      return nil
    end

    return data['results']
  end

  def getServiceObjects(attrs = nil, filter = nil, joins = nil)
    apiUrl = sprintf('%s/objects/services', @apiUrlBase)

    requestBody = {}

    if (attrs)
      requestBody["attrs"] = attrs
    end

    if (filter)
      requestBody["filter"] = filter
    end

    tmpJoin = [ "host" ]

    if (joins)
      requestBody["joins"] = joins
    end

    #puts "request body: " + requestBody.to_s

    # fetch data with requestBody (which means X-HTTP-Method-Override: GET)
    data = getApiData(apiUrl, requestBody)

    if not data or not data.has_key?('results')
      return nil
    end

    return data['results']
  end

  def formatService(name)
    service_map = name.split('!', 2)
    return service_map[0].to_s
    # + " - " + service_map[1].to_s
  end

  def stateFromString(stateStr)
    if (stateStr == "Down" or stateStr == "Warning")
      return 1
    elif (stateStr == "Up" or stateStr == "OK")
      return 0
    elif (stateStr == "Critical")
      return 2
    elif (stateStr == "Unknown")
      return 3
    end

    return "Undefined state. Programming error."
  end

  def stateToString(state, is_host = false)
    if (is_host && state >= 1)
      return "Down"
    elsif (is_host && state == 0)
      return "Up"
    elsif (state == 0)
      return "OK"
    elsif (state == 1)
      return "Warning"
    elsif (state == 2)
      return "Critical"
    elsif (state == 3)
      return "Unknown"
    end

    return "Undefined state. Programming error."
  end

  def stateToColor(state, is_host = false)
    if (is_host && state >= 1)
      return "red"
    elsif (is_host && state == 0)
      return "green"
    elsif (state == 0)
      return "green"
    elsif (state == 1)
      return "yellow"
    elsif (state == 2)
      return "red"
    elsif (state == 3)
      return "purple"
    end

    return "Undefined state. Programming error."
  end

  def countProblems(objects, states = nil)
    problems = 0

    compStates = []

    if not states
      compStates = [ 1, 2, 3]
    end

    if states.is_a?(Integer)
      compStates.push(states)
    end

    objects.each do |item|
      item.each do |k, d|
        if (k != "attrs")
          next
        end

        if @showOnlyHardStateProblems
          if (compStates.include?(d["state"]) && d["downtime_depth"] == 0 && d["acknowledgement"] == 0 && d['last_hard_state'] != 0.0)
            problems = problems + 1
          end
        else
          if (compStates.include?(d["state"]) && d["downtime_depth"] == 0 && d["acknowledgement"] == 0)
            problems = problems + 1
          end
        end
      end
    end

    return problems
  end

  def countProblemsServices(objects, states = nil)
    problems = 0

    compStates = []

    if not states
      compStates = [ 1, 2, 3]
    end

    if states.is_a?(Integer)
      compStates.push(states)
    end

    objects.each do |item|
      item.each do |k, d|
        if (k != "attrs")
          next
        end

        if @showOnlyHardStateProblems
          if (compStates.include?(d["state"]) && d["downtime_depth"] == 0 && d["acknowledgement"] == 0 && d['last_hard_state'] != 0.0)
            if (item["joins"]["host"]["state"] == 0.0)
              problems = problems + 1
            end
          end
        else
          if (compStates.include?(d["state"]) && d["downtime_depth"] == 0 && d["acknowledgement"] == 0)
            problems = problems + 1
          end
        end
      end
    end

    return problems
  end

  # use last_check here, takes less traffic than the entire check result
  def getObjectHasBeenChecked(object)
    return object["attrs"]["last_check"] > 0
  end

  # stolen from Icinga Web 2, ./modules/monitoring/library/Monitoring/Backend/Ido/Query/ServicestatusQuery.php
  def getHostSeverity(host)
    attrs = host["attrs"]

    severity = 0

    if (attrs["state"] == 0)
      if (getObjectHasBeenChecked(host))
        severity += 16
      end

      if (attrs["acknowledgement"] != 0)
        severity += 2
      elsif (attrs["downtime_depth"] > 0)
        severity += 1
      else
        severity += 4
      end
    else
      if (getObjectHasBeenChecked(host))
        severity += 16
      elsif (attrs["state"] == 1)
        severity += 32
      elsif (attrs["state"] == 2)
        severity += 64
      else
        severity += 256
      end

      if (attrs["acknowledgement"] != 0)
        severity += 2
      elsif (attrs["downtime_depth"] > 0)
        severity += 1
      else
        severity += 4
      end
    end

    return severity
  end

  # stolen from Icinga Web 2, ./modules/monitoring/library/Monitoring/Backend/Ido/Query/ServicestatusQuery.php
  def getServiceSeverity(service)
    attrs = service["attrs"]

    severity = 0

    if (attrs["state"] == 0)
      if (getObjectHasBeenChecked(service))
        severity += 16
      end

      if (attrs["acknowledgement"] != 0)
        severity += 2
      elsif (attrs["downtime_depth"] > 0)
        severity += 1
      else
        severity += 4
      end
    else
      if (getObjectHasBeenChecked(service))
        severity += 16
      elsif (attrs["state"] == 1)
        severity += 32
      elsif (attrs["state"] == 2)
        severity += 128
      elsif (attrs["state"] == 3)
        severity += 64
      else
        severity += 256
      end

      # requires joins
      host_attrs = service["joins"]["host"]

      if (host_attrs["state"] > 0)
        severity += 1024
      elsif (attrs["acknowledgement"])
        severity += 512
      elsif (attrs["downtime_depth"] > 0)
        severity += 256
      else
        severity += 2048
      end
    end

    return severity
  end

  def getProblemServices(all_services_data, all_hosts_data, max_items = 30)
    service_problems = {}
    host_problems = {}

    if(all_hosts_data != nil)
      testw = "not nil."
    else
      testw = "nil."
    end

    #service_problems[] = "failed"


    #service_problems["dies ist ein Test"] = 500

    all_services_data.each do |service|
      #puts "Severity for " + service["name"] + ": " + getServiceSeverity(service).to_s

      if (service["attrs"]["state"] == 0) or
        (service["attrs"]["downtime_depth"] > 0) or
        (service["attrs"]["acknowledgement"] > 0) or
        (service["joins"]["host"]["state"] == 1.0)
        next
      end

      if @showOnlyHardStateProblems and (service["attrs"]["last_hard_state"] == 0.0)
        next
      end

      service_problems[service] = getServiceSeverity(service)
    end

    count = 0
    service_problems_severity = {}

    # debug
    #@service_problems.sort_by {|k, v| v}.reverse.each do |obj, severity|
    #  puts obj["name"] + ": " + severity.to_s
    #end

    # debug
    #service_problems_severity["dies 6 ist ein Test-Host der Down ist"] = 2.0
    all_hosts_data.each do |host|
        if (host["attrs"]["state"] == 0) or
          (host["attrs"]["downtime_depth"] > 0) or
          (host["attrs"]["acknowledgement"] > 0)
            next
        end

        if @showOnlyHardStateProblems and (host["attrs"]["last_hard_state"] == 0.0)
          next
        end

        host_display_name = host["attrs"]["display_name"]
        host_display_name_clean = host_display_name.split('(')[0].split('|')[0]
        host_display_name_clean_split = host_display_name_clean.split(': ')
        host_display_name_for_display = host_display_name_clean_split[0] + ' (' + host_display_name_clean_split[1] + ')'

        service_problems_severity[host_display_name_for_display + " is DOWN"] = 2.0
    end

    service_problems.sort_by {|k, v| v}.reverse.each do |obj, severity|
      if (count >= max_items)
        break
      end

      test2 = obj["joins"]["host"]["state"].to_s

      host_display_name = obj["joins"]["host"]["display_name"]
      host_display_name_clean = host_display_name.split('(')[0].split('|')[0]
      host_display_name_clean_split = host_display_name_clean.split(': ')
      host_display_name_for_display = host_display_name_clean_split[0] + ' (' + host_display_name_clean_split[1] + ')'
      service_display_name = obj["attrs"]["display_name"]
      name = host_display_name_for_display + " - " + service_display_name

      service_problems_severity[name] = obj["attrs"]["state"]

      count += 1
    end

    return service_problems, service_problems_severity
  end

  def getIcingaStats()
    results = getStatusData()

    wqStats = {}
    clusterStats = {}

    results.each do |r|
      status = r["status"]

      wqKeyList = [ "work_queue_item_rate", "query_queue_item_rate" ]
      clusterKeyList = [ "num_conn_endpoints", "num_not_conn_endpoints", "anonymous_clients", "clients" ]

      # structure is "type" - "name"
      # api - json_rpc
      # api - http
      # idomysqlconnection - ido-mysql
      status.each do |type, typeval|
        if not typeval.is_a?(Hash)
          next
        end

        typeval.each do |attr, val|
          # puts attr + " " + val.to_s

          # collect top level matches, e.g. num_conn_endpoints
          clusterKeyList.each do |key|
            # puts "Matching top level key " + key + " with attr " + attr + " val " + val.to_s
            if key == attr
              clusterStats[attr] = val
            end
          end

          if not val.is_a?(Hash)
            next
          end

          # collect inner parts, e.g. json_rpc.anonymous_clients
          clusterKeyList.each do |key|
            if val.has_key? key
              clusterStats[attr] = val[key]
            end
          end

          wqKeyList.each do |key|
            if val.has_key? key
              attrName = attr + " queue rate"
              wqStats[attrName] = val[key]
            end
          end

        end
      end
    end

    return wqStats, clusterStats
  end

  def fetchVersion(version)
    #version = "v2.4.10-504-gab4ba18"
    #version = "2.11.0-1"
    # strip v2.4.10 (default) and r2.4.10 (Debian)
    # icinga2/lib/base/utility.cpp - ParseVersion

    version_str = version[/^[vr]?(2\.\d+\.\d+).*$/,1]

    @version = version_str
  end

  def getServicePerfData(service_name, service_result, perf_data_name, unit_to_delete)
    ret_value = 0.0
    service_result.each do |service|
      service["attrs"]["last_check_result"]["performance_data"].each do |perf|
        if perf.start_with?(perf_data_name)
          if unit_to_delete.size > 0
            ret_value = perf.split('=')[1].split(';')[0].delete(unit_to_delete).to_f
          elsif
            ret_value = perf.split('=')[1].split(';')[0].to_f
          end
          # puts perf_data_name + " for " + service_name + ": " + ret_value.to_s
        end
      end
    end
    return ret_value
  end

  def initializeAttributes()
    @version = "Not running"
    @node_name = ""
    @app_starttime = 0
    @uptime = 0

    @avg_latency = 0
    @avg_execution_time = 0
    @host_active_checks_1min = 0
    @host_passive_checks_1min = 0
    @service_active_checks_1min = 0
    @service_passive_checks_1min = 0

    @service_problems_severity = 0

    @host_count_all = 0
    @host_count_problems = 0
    @host_count_problems_down = 0
    @host_count_up = 0
    @host_count_down = 0
    @host_count_in_downtime = 0
    @host_count_acknowledged = 0

    @service_count_all = 0
    @service_count_problems = 0
    @service_count_problems_warning = 0
    @service_count_problems_critical = 0
    @service_count_problems_unknown = 0
    @service_count_ok = 0
    @service_count_warning = 0
    @service_count_critical = 0
    @service_count_unknown = 0
    @service_count_unknown = 0
    @service_count_in_downtime = 0
    @service_count_acknowledged = 0

    @room_climate_temperature = 0
    @room_climate_humidity = 0

    @isp_downstream = 0
    @isp_upstream = 0

    @app_data = nil
    @cib_data = nil
    @all_hosts_data = nil
    @all_services_data = nil
  end

  def run
    # initialize attributes to provide some semi-useful data
    initializeAttributes()

    ## App data
    @app_data = getIcingaApplicationData()

    unless(@app_data.nil?)
      fetchVersion(@app_data['icingaapplication']['app']['version'])
      @node_name = @app_data['icingaapplication']['app']['node_name']
      @app_starttime = Time.at(@app_data['icingaapplication']['app']['program_start'].to_f)
    end

    ## CIB data
    @cib_data = getCIBData() #exported

    unless(@cib_data.nil?)
      uptimeTmp = cib_data["uptime"].round(2)
      @uptime = Time.at(uptimeTmp).utc.strftime("%H:%M:%S")

      @avg_latency = cib_data["avg_latency"].round(2)
      @avg_execution_time = cib_data["avg_execution_time"].round(2)

      @host_count_up = cib_data["num_hosts_up"].to_int
      @host_count_down = cib_data["num_hosts_down"].to_int
      @host_count_in_downtime = cib_data["num_hosts_in_downtime"].to_int
      @host_count_acknowledged = cib_data["num_hosts_acknowledged"].to_int

      @service_count_ok = cib_data["num_services_ok"].to_int
      @service_count_warning = cib_data["num_services_warning"].to_int
      @service_count_critical = cib_data["num_services_critical"].to_int
      @service_count_unknown = cib_data["num_services_unknown"].to_int
      @service_count_in_downtime = cib_data["num_services_in_downtime"].to_int
      @service_count_acknowledged = cib_data["num_services_acknowledged"].to_int

      # check stats
      @host_active_checks_1min = cib_data["active_host_checks_1min"]
      @host_passive_checks_1min = cib_data["passive_host_checks_1min"]
      @service_active_checks_1min = cib_data["active_service_checks_1min"]
      @service_passive_checks_1min = cib_data["passive_service_checks_1min"]
    end

    ## Objects data
    # fetch the minimal attributes for problem calculation
    all_hosts_data = nil
    all_services_data = nil

    # if filtering is needed a hostgroup may be passed to getHostObjects or getServiceObjects
    if @showOnlyHardStateProblems
      all_hosts_data = getHostObjects([ "name", "display_name", "state", "acknowledgement", "downtime_depth", "last_check", "last_hard_state" ], nil, nil)
      all_services_data = getServiceObjects([ "name", "display_name", "host_name", "state", "acknowledgement", "downtime_depth", "last_check", "last_hard_state" ], nil, [ "host.name", "host.display_name", "host.state", "host.acknowledgement", "host.downtime_depth", "host.last_check" ])
    else
      all_hosts_data = getHostObjects([ "name", "display_name", "state", "acknowledgement", "downtime_depth", "last_check" ], nil, nil)
      all_services_data = getServiceObjects([ "name", "display_name", "host_name", "state", "acknowledgement", "downtime_depth", "last_check" ], nil, [ "host.name", "host.display_name", "host.state", "host.acknowledgement", "host.downtime_depth", "host.last_check" ])
    end

    unless(all_hosts_data.nil?)
      @host_count_all = all_hosts_data.size
      @host_count_problems = countProblems(all_hosts_data)
      @host_count_problems_down = countProblems(all_hosts_data, 1)
    end

    unless(all_services_data.nil?)
      @service_count_all = all_services_data.size
      @service_count_problems = countProblemsServices(all_services_data)
      @service_count_problems_warning = countProblemsServices(all_services_data, 1)
      @service_count_problems_critical = countProblemsServices(all_services_data, 2)
      @service_count_problems_unknown = countProblemsServices(all_services_data, 3)

      # severity
      @service_problems, @service_problems_severity = getProblemServices(all_services_data, all_hosts_data)
    end

    # get room climate information
    if @room_climate_service_enabled
      room_climate_result = getServiceObjects(["last_check_result"],
                               "match(\"*" + @room_climate_service + "*\",service.name)", nil)
      @room_climate_temperature = getServicePerfData(@room_climate_service, room_climate_result, "temperature", "")
      @room_climate_humidity =  getServicePerfData(@room_climate_service, room_climate_result, "humidity", "%")
    end

    # get the ISP information
    if @isp_service_enabled
      isp_service_result = getServiceObjects(["last_check_result"],
                              "match(\"*" + @isp_downstream_service + "*\",service.name)", nil)
      @isp_downstream = getServicePerfData(@isp_downstream_service, isp_service_result, "downstream_max", "")

      isp_service_result = getServiceObjects(["last_check_result"],
                              "match(\"*" + @isp_upstream_service + "*\",service.name)", nil)
      @isp_upstream = getServicePerfData(@isp_upstream_service, isp_service_result, "upstream_max", "")
    end
  end
end
