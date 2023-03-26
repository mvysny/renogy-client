import 'package:renogy_client/clients/renogy_client.dart';

final dummySystemInfo = SystemInfo()
..maxVoltage = 24
..ratedChargingCurrent = 40
..ratedDischargingCurrent = 40
..productType = ProductType.Controller
..productModel = "RENOGY ROVER"
    ..softwareVersion="v1.2.3"
        ..hardwareVersion="v4.5.6"
..serialNumber="1501FFFF";

val dummyPowerStatus = PowerStatus(100.toUShort(), 25.6f, 2.3f, 23, 23, 0f, 0f, 0.toUShort(), 60.2f, 4.2f, (60.2f * 4.2f).toInt().toUShort())
val dummyDailyStats = DailyStats(25.0f, 28.0f, 10.0f, 10.0f, 240.toUShort(), 240.toUShort(), 100.toUShort(), 100.toUShort(), 0.toUShort(), 0.toUShort())
val dummyHistoricalData = HistoricalData(20.toUShort(), 1.toUShort(), 20.toUShort(), 2000.toUInt(), 2000.toUInt(), 2000.toUInt(), 2000.toUInt())
val dummyStatus = RenogyStatus(false, 0.toUByte(), ChargingState.MpptChargingMode, setOf(
    ControllerFaults.ControllerTemperatureTooHigh))
val dummyRenogyData = RenogyData(
    dummySystemInfo,
    dummyPowerStatus,
    dummyDailyStats,
    dummyHistoricalData,
    dummyStatus
)
