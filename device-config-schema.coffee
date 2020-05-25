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
      panelSensor:
        description: "Pimatic device id of panel MQTT presence sensor"
        type: "string"
  }
}
