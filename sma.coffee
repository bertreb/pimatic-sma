module.exports = (env) ->

  Promise = env.require 'bluebird'
  request = require 'request'
  CronJob = env.CronJob or require('cron').CronJob

  everyDay = "23 0 0 * * *" # at 23:00

  class SmaPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      deviceConfigDef = require("./device-config-schema.coffee")
      @framework.deviceManager.registerDeviceClass("SmaInverter", {
        configDef: deviceConfigDef["SmaInverter"],
        createCallback: (deviceConfig, lastState) => new SmaInverter(deviceConfig, lastState, @framework, this)
      })

  class SmaInverter extends env.devices.Device

    constructor: (@config, lastState, @framework, plugin) ->
      @id = @config.id
      @name = @config.name

      @_solarActualPower = 0
      @_solarTotalPower = 0

      if @_destroyed then return

      @serial = null
      @ip = @config.ip
      @reqHeaders = {
        "Content-Type": 'application/x-www-form-urlencoded',
        "Accept": 'application/json, text/plain, */*',
        "Content-Type": 'application/json;charset=UTF-8',
      }

      @attributes = {}
      @attributes["solaractualpower"] =
        description: "Actual value of the generated solar power"
        type: "number"
        acronym: "actual power"
        unit: "W"
      @_createGetter("solaractualpower", => Promise.resolve(@_solarActualPower))
      @attributes["solartotalpower"] =
        description: "Total generated solar power"
        type: "number"
        acronym: "total power"
        unit: "W"
      @_createGetter("solartotalpower", => Promise.resolve(@_solarTotalPower))

      options = {
        url: 'https://'+ @ip + '/dyn/getDashValues.json',
        rejectUnauthorized: false,
        method: 'GET',
        headers: @reqHeaders,
        gzip: true
      }

      @getDashValues = () =>
        request(options, (error,response,body) =>
          if !error && response.statusCode == 200
            jsonResp = JSON.parse(body)
            @serial = Object.keys(jsonResp.result)[0] unless @serial?
            _currentPower = Number jsonResp.result[@serial]["6100_40263F00"]["1"][0]["val"]
            _totalPower = Number jsonResp.result[@serial]["6400_00260100"]["1"][0]["val"]
            env.logger.debug "_currentPower: " + _currentPower
            env.logger.debug "_totalPower: " + _totalPower
            @_solarActualPower = _currentPower
            @_solarTotalPower = _totalPower
            @emit "solaractualpower", _currentPower
            @emit "solartotalpower", _totalPower
        )
        @dashValueTimer = setTimeout(@getDashValues,5000)

      @getDashValues()

      @framework.variableManager.waitForInit()
      .then(()=>
        @panelSensor = @framework.deviceManager.getDeviceById(@config.panelSensor)
        if @panelSensor?
          env.logger.debug "PanelSensor added: " + @panelSensor.id
          @panelSensor.on 'presence', @panelSensorHandler = (presence) =>
            env.logger.debug "PanelSensor presence " + presence
            clearTimeout(@dashValueTimer)
            @dashValueTimer = null
            if presence
              env.logger.debug "Starting updates"
              @getDashValues()
            else
              env.logger.debug "Stopping updates"
       )

      @dailyProductionJob = new CronJob
        cronTime:  everyDay
        start: true
        onTick: => @getDashValues()

      super()

    destroy: ->
      clearTimeout(@dashValueTimer)
      if @panelSensor?
        @panelSensor.removeListener 'presence', @panelSensorHandler
      @dailyProductionJob.stop()
      super()

  smaPlugin = new SmaPlugin()
  return smaPlugin
