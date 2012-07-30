fs   = require 'fs'
proc = require 'proc'

STATEMAP = {R: "running", S:"sleeping", D:"disk sleep", Z:"zombie", T:"stopped", W:"paging"}


class Monitor
  checkInterval: 5000
  psData = {}
  
  constructor: (services, opts={}) ->
    return (new Monitor services, opts) if this is global
    [@services, @opts] = [services, opts]

    for k in "checkInterval".split ' '
      @[k] = @opts[k] if @opts[k]?

    for service in @services
      do (service) =>
        console.log "monitoring service", service.name
    
    setInterval @check, @checkInterval


  check: (service) =>
    proc (err, procs) =>
      for service in @services
        do (service) =>
          running = service.pid? && procs[service.pid]
          console.log "checking #{service.name} (#{service.pid})"
          if !running
            console.log "starting #{service.name}"
            service.start()
          else
            p = procs[service.pid]
            
            service.stateCode = p.state 
            service.state = STATEMAP[p.state]

            service.threadCount = p.num_threads
            service.childCount = p.children?.length or 0

            service.memUsage = p.rss
            service.vmUsage = p.vsize

            service.oldTicks = service.ticks
            service.ticks = parseInt(p.utime) + parseInt(p.stime)
            if service.oldTicks?
              service.cpuUsage = (service.ticks - service.oldTicks) / (100 * (@checkInterval / 1000))
            console.log "#{service.name} #{service.state}: #{service.threadCount} thread(s), #{service.childCount} child(ren), #{Math.round service.cpuUsage*100}% CPU"



module.exports = Monitor