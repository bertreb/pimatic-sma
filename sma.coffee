module.exports = (env) ->

  Promise = env.require 'bluebird'
  request = require 'request'

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

      @pollTime = @config.pollTime ? 5000

      @_solarActualPower = 0
      @_solarTotalPower = 0
      @_gridOutPower = 0
      @_gridInPower = 0
      @errorKnown = false

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
        unit: "Wh"
      @_createGetter("solartotalpower", => Promise.resolve(@_solarTotalPower))
      @attributes["gridoutpower"] =
        description: "Actual grid out power"
        type: "number"
        acronym: "grid out power"
        unit: "W"
      @_createGetter("gridoutpower", => Promise.resolve(@_gridOutPower))
      @attributes["gridinpower"] =
        description: "Actual grid in power"
        type: "number"
        acronym: "grid in power"
        unit: "W"
      @_createGetter("gridinpower", => Promise.resolve(@_gridInPower))

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
            @_gridOutPower = _currentPowerGridOut
            @_gridInPower = _currentPowerGridIn
            @emit "solaractualpower", _currentPower
            @emit "solartotalpower", _totalPower
            # try if PowerGrid In and Out are available
            try
              _currentPowerGridOut = Number jsonResp.result[@serial]["6100_40463600"]["1"][0]["val"]
              _currentPowerGridIn = Number jsonResp.result[@serial]["6100_40463700"]["1"][0]["val"]
              env.logger.debug "_gridOutPower: " + _currentPowerGridOut
              env.logger.debug "_gridInPower: " + _currentPowerGridIn
              @emit "gridoutpower", _currentPowerGridOut
              @emit "gridinpower", _currentPowerGridIn
              @errorKnown = false
            catch err
              unless @errorKnown
                env.logger.info "GridPower IN and OUT are not available"
                @errorKnown = true
        )
        @dashValueTimer = setTimeout(@getDashValues,@pollTime)

      @getDashValues()

      super()

    destroy: ->
      clearTimeout(@dashValueTimer)
      super()

  smaPlugin = new SmaPlugin()
  return smaPlugin
