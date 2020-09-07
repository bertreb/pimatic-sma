module.exports = {
  title: "SmaInverter"
  SmaInverter: {
    title: "SmaInverter config"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      ip:
        description: "The ip adres of the inverter"
        type: "string"
      pollTimer:
        description: "The polling time in ms"
        type: "number"
        default: 5000
      panelSensor:
        description: "Legacy parameter, not used anymore"
        type: "string"
  }
}
