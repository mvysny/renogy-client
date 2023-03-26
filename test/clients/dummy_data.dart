import 'package:renogy_client/clients/renogy_client.dart';

final dummySystemInfo = SystemInfo()
  ..maxVoltage = 24
  ..ratedChargingCurrent = 40
  ..ratedDischargingCurrent = 40
  ..productType = ProductType.Controller
  ..productModel = "RENOGY ROVER"
  ..softwareVersion = "v1.2.3"
  ..hardwareVersion = "v4.5.6"
  ..serialNumber = "1501FFFF";

final dummyPowerStatus = PowerStatus()
  ..batterySOC = 100
  ..batteryVoltage = 25.6
  ..chargingCurrentToBattery = 2.3
  ..batteryTemp = 23
  ..controllerTemp = 23
  ..solarPanelVoltage = 60.2
  ..solarPanelCurrent = 4.2
  ..solarPanelPower = (60.2 * 4.2).toInt();

final dummyDailyStats = DailyStats()
  ..batteryMinVoltage = 25.0
  ..batteryMaxVoltage = 28.0
  ..maxChargingCurrent = 10.0
  ..maxDischargingCurrent = 10.0
  ..maxChargingPower = 240
  ..maxDischargingPower = 240
  ..chargingAh = 100
  ..dischargingAh = 100;

final dummyHistoricalData = HistoricalData()
  ..daysUp = 20
  ..batteryOverDischargeCount = 1
  ..batteryFullChargeCount = 20
  ..totalChargingBatteryAH = 2000
  ..totalDischargingBatteryAH = 2000
  ..cumulativePowerGenerationWH = 2000
  ..cumulativePowerConsumptionWH = 2000;

final dummyStatus = RenogyStatus()
  ..chargingState = ChargingState.MpptChargingMode
  ..faults = {ControllerFaults.ControllerTemperatureTooHigh};

final dummyRenogyData = RenogyData()
  ..systemInfo = dummySystemInfo
  ..powerStatus = dummyPowerStatus
  ..dailyStats = dummyDailyStats
  ..historicalData = dummyHistoricalData
  ..status = dummyStatus;
