module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  request = require 'request'

  #Sunnyboy = require('./sunnyboy.js')

  class SmaPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>

      deviceConfigDef = require("./device-config-schema.coffee")
      @framework.deviceManager.registerDeviceClass("SmaInverter", {
        configDef: deviceConfigDef["SmaInverter"],
        createCallback: (deviceConfig, lastState) => new SmaInverter(deviceConfig, lastState, @framework, this)
      })

      ###
      @framework.deviceManager.on 'discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-dashboard', "scan for databases ..."
        @Connector.getDatabaseNames().then( (dbase) =>
          for db in dbase
            if db is @database
              @framework.deviceManager.discoverMessage 'pimatic-dashboard', "scan for databases ... database #{@database} found!"

            do (db) =>
              @Connector.getMeasurements(db).then( (names) =>
                for nam in names
                  do (nam) =>
                    @framework.deviceManager.discoverMessage 'pimatic-dashboard', "scan for databases ... found: #{nam}"
              )
        )
      ###


  class SmaInverter extends env.devices.Device

    constructor: (@config, lastState, @framework, plugin) ->
      @id = @config.id
      @name = @config.name

      @_solarActualPower = 0

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
      @_createGetter("solaractualpower", =>Promise.resolve(@_solarActualPower))

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
            env.logger.debug "_currentPower: " + _currentPower
            @_solarActualPower = _currentPower
            @emit "solaractualpower", _currentPower
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
            if presence
              env.logger.debug "Starting updates"
              @getDashValues()
            else
              env.logger.debug "Stopping updates"
      )


      super()


    destroy: ->
      clearTimeout(@dashValueTimer)
      if @panelSensor?
        @panelSensor.removeListener 'presence', @panelSensorHandler
      super()


  smaPlugin = new SmaPlugin()
  return smaPlugin
