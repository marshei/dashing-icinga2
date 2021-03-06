#/******************************************************************************
# * Icinga 2 Dashing Job                                                       *
# * Copyright (C) 2015-2016 Icinga Development Team (https://www.icinga.org)   *
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

require './lib/icinga2'

# initialize data provider
icinga = Icinga2.new('config/icinga2.json') # fixed path

SCHEDULER.every '15s', allow_overlapping: false, :first_in => 0 do |job|
  # shallow copy of the icinga object to detect changes in values
  icinga_previous = icinga.dup
  # run data provider
  icinga.run

  #puts "App Info: " + icinga.app_data.to_s + " Version: " + icinga.version
  #puts "CIB Info: " + icinga.cib_data.to_s

  # icinga stats
  icinga_stats = [
    {"label" => "Uptime", "value" => icinga.uptime},
    {"label" => "Avg latency in ms", "value" => icinga.avg_latency},
    {"label" => "Host checks/min", "value" => icinga.host_active_checks_1min},
    {"label" => "Service checks/min", "value" => icinga.service_active_checks_1min},
  ]

  wqStats, clusterStats = icinga.getIcingaStats()

  wqStats.each do |name, value|
    if value != 0
      icinga_stats.push( { "label" => name, "value" => value.round(2).to_s } )
    elsif
      icinga_stats.push( { "label" => name, "value" => "0" } )
    end
  end
  #clusterStats.each do |name, value|
  #  icinga_stats.push( { "label" => name, "value" => "%0.2f" % value } )
  #end

  #puts "Stats: " + icinga_stats.to_s

  ### Events
  if icinga.host_count_all != icinga_previous.host_count_all or
     icinga.host_count_problems != icinga_previous.host_count_problems or
     icinga.host_count_problems_down != icinga_previous.host_count_problems_down

    moreinfo_msg = ""
    if icinga.host_count_problems > 0
      moreinfo_msg = "Problems: " + icinga.host_count_problems.to_s + ", " +
                     "Down: " + icinga.host_count_problems_down.to_s
    end

    send_event('icinga-host-meter', {
      value: icinga.host_count_all - icinga.host_count_problems,
      min: 0,
      max: icinga.host_count_all,
      moreinfo: moreinfo_msg })
  end

  if icinga.service_count_all != icinga_previous.service_count_all or
     icinga.service_count_problems != icinga_previous.service_count_problems or
     icinga.service_count_problems_warning != icinga_previous.service_count_problems_warning or
     icinga.service_count_problems_critical != icinga_previous.service_count_problems_critical or
     icinga.service_count_problems_unknown != icinga_previous.service_count_problems_unknown

    send_event('icinga-service-meter', {
      value_ok: icinga.service_count_all - icinga.service_count_problems,
      value_warning: icinga.service_count_problems_warning,
      value_critical: icinga.service_count_problems_critical,
      value_unknown: icinga.service_count_problems_unknown,
      min:   0,
      max:   icinga.service_count_all})
  end

  send_event('icinga-stats', {
   title: "Icinga " + icinga.version,
   items: icinga_stats,
   color: 'blue' })

  #### Doughnuts
  if icinga.host_count_all != icinga_previous.host_count_all or
     icinga.host_count_problems_down != icinga_previous.host_count_problems_down

    moreinfo_msg = "Total hosts: " + icinga.host_count_all.to_s
    if icinga.host_count_problems_down > 0
      moreinfo_msg += " (Down: " + icinga.host_count_problems_down.to_s + ")"
    end

    send_event('doughnut-pie-hosts', {
      type: "doughnut",
      header: "Hosts",
      labels: [ "UP", "Down" ],
      datasets: [ icinga.host_count_all, icinga.host_count_problems_down ],
      moreinfo: moreinfo_msg,
    })
  end

  if icinga.service_count_all != icinga_previous.service_count_all or
     icinga.service_count_problems != icinga_previous.service_count_problems or

    moreinfo_msg = "Total services: " + icinga.service_count_all.to_s
    if icinga.service_count_problems > 0
      moreinfo_msg += " (Not OK: " + icinga.service_count_problems.to_s + ")"
    end

    send_event('doughnut-pie-services', {
      type: "doughnut",
      header: "Services",
      labels: [ "OK", "Warning", "Critical", "Unknown" ],
      datasets: [ icinga.service_count_all, icinga.service_count_problems_warning, icinga.service_count_problems_critical, icinga.service_count_problems_unknown ],
      moreinfo: moreinfo_msg,
    })
  end

  send_event('bar-chart-endpoints', {
    header: "Endpoints",
    labels: [ "Connected", "Not Connected" ],
    datasets: [ clusterStats["num_conn_endpoints"], clusterStats["num_not_conn_endpoints"] ],
  })

  #### Bar Charts
  if icinga.host_active_checks_1min != icinga_previous.host_active_checks_1min or
     icinga.service_active_checks_1min != icinga_previous.service_active_checks_1min
    send_event('bar-chart-checks', {
      #type: "horizontalBar",
      type: "bar",
      header: "Active Checks",
      labels: [ "Hosts/min", "Services/min" ],
      datasets: [ icinga.host_active_checks_1min, icinga.service_active_checks_1min ],
    })
  end

  if icinga.host_count_in_downtime != icinga_previous.host_count_in_downtime or
     icinga.service_count_in_downtime != icinga_previous.service_count_in_downtime
    send_event('bar-chart-downtimes', {
      #type: "horizontalBar",
      type: "bar",
      header: "Downtimes",
      labels: [ "Hosts", "Services" ],
      datasets: [ icinga.host_count_in_downtime, icinga.service_count_in_downtime ],
    })
  end

  if icinga.host_count_acknowledged != icinga_previous.host_count_acknowledged or
     icinga.service_count_acknowledged != icinga_previous.service_count_acknowledged
    send_event('bar-chart-acks', {
      #type: "horizontalBar",
      type: "bar",
      header: "Acknowledgements",
      labels: [ "Hosts", "Services" ],
      datasets: [ icinga.host_count_acknowledged, icinga.service_count_acknowledged ],
    })
  end

  # problem services
  severity_stats = []
  icinga.service_problems_severity.each do |name, state|
    severity_stats.push({
      "label" => icinga.formatService(name),
      "color" => icinga.stateToColor(state.to_int, false),
      "state" => state.to_int
    })
  end

  order = [ 2,1,3 ]
  result = severity_stats.sort do |a, b|
    order.index(a['state']) <=> order.index(b['state'])
  end

  #puts "Severity: " + result.to_s

  send_event('icinga-severity', {
   items: result,
   color: 'blue' })

  # Combined view of unhandled host problems (only if there are some)
  unhandled_host_problems = []

  if (icinga.host_count_problems_down > 0)
    unhandled_host_problems.push(
      { "color" => icinga.stateToColor(1, true), "value" => icinga.host_count_problems_down },
    )
  end

  send_event('icinga-host-problems', {
    items: unhandled_host_problems,
    moreinfo: "All Problems: " + icinga.host_count_problems_down.to_s
  })

  # Combined view of unhandled service problems (only if there are some)
  unhandled_service_problems = []

  if (icinga.service_count_problems_critical > 0)
    unhandled_service_problems.push(
      { "color" => icinga.stateToColor(2, false), "value" => icinga.service_count_problems_critical },
    )
  end
  if (icinga.service_count_problems_warning > 0)
    unhandled_service_problems.push(
      { "color" => icinga.stateToColor(1, false), "value" => icinga.service_count_problems_warning },
    )
  end
  if (icinga.service_count_problems_unknown > 0)
    unhandled_service_problems.push(
      { "color" => icinga.stateToColor(3, false), "value" => icinga.service_count_problems_unknown }
    )
  end

  send_event('icinga-service-problems', {
    items: unhandled_service_problems,
    moreinfo: "All Problems: " + (icinga.service_count_problems_critical + icinga.service_count_problems_warning + icinga.service_count_problems_unknown).to_s
  })

  if icinga.room_climate_temperature != icinga_previous.room_climate_temperature or
     icinga.room_climate_humidity != icinga_previous.room_climate_humidity
    send_event('icinga-room-climate', {
      temperature: icinga.room_climate_temperature,
      temperatureUnit: "°C",
      humidity: icinga.room_climate_humidity.round,
      humidityUnit: "%H"
    })
  end

  if icinga.isp_downstream != icinga_previous.isp_downstream or
     icinga.isp_upstream != icinga_previous.isp_upstream or
     icinga.isp_connection_uptime != icinga_previous.isp_connection_uptime
    send_event('icinga-isp', {
      downstream: icinga.isp_downstream.round,
      upstream: icinga.isp_upstream.round,
      uptimeinfo: "Link Uptime: " + icinga.isp_connection_uptime,
      unitinfo: "MBit/s"
    })
  end

  if icinga.isp_connection_totals_received != icinga_previous.isp_connection_totals_received or
     icinga.isp_connection_totals_received_hourly_rate != icinga_previous.isp_connection_totals_received_hourly_rate or
     icinga.isp_connection_totals_sent != icinga_previous.isp_connection_totals_sent or
     icinga.isp_connection_totals_sent_hourly_rate != icinga_previous.isp_connection_totals_sent_hourly_rate
    send_event('icinga-isp-usage', {
      downstream: icinga.isp_connection_totals_received_hourly_rate.round(2),
      upstream: icinga.isp_connection_totals_sent_hourly_rate.round(2),
      totaldown: icinga.isp_connection_totals_received.round(1),
      totalup: icinga.isp_connection_totals_sent.round(1),
      totalsuffix: " " + icinga.isp_connection_totals_unit,
      unitinfo: icinga.isp_connection_totals_unit + "/h"
    })
  end

  if icinga.dns_number_of_queries_today != icinga_previous.dns_number_of_queries_today or
     icinga.dns_blocked_percentage_today != icinga_previous.dns_blocked_percentage_today or
     icinga.dns_service_status_enabled != icinga_previous.dns_service_status_enabled

    if icinga.dns_service_status_enabled then info = "" else info = "- OFF - " end
    send_event('dns-stats', {
      queriesToday: icinga.dns_number_of_queries_today,
      queriesInfo: info + "Last 24 Hr: ",
      blockedToday: icinga.dns_blocked_percentage_today.round(1),
      blockedUnit: "%",
      enabled: icinga.dns_service_status_enabled
    })
  end
end

