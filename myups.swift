import Foundation
import IOKit.ps

// Global power source name (nil = match any)
var gPowerSourceName: CFString? = nil

func myLogger(_ level: Int, _ message: String) {
    fputs(message + "\n", stderr)
}

/**
 Copy the current power dictionary.
 Caller must retain the returned dictionary if needed.
 */
func copyPowerDictionary(powerSourceName: CFString?) -> CFDictionary? {

    guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
        return nil
    }

    myLogger(6, "Got power_sources_info:")
    CFShow(powerSourcesInfo)

    if let sourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() {

        let count = CFArrayGetCount(sourcesList)

        for index in 0..<count {
            let powerSource = CFArrayGetValueAtIndex(sourcesList, index)
            myLogger(6, "Checking power source \(index + 1)/\(count)")
            CFShow(powerSource)

            guard let dict = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSource)?
                .takeUnretainedValue() else {
                continue
            }

            let name = CFDictionaryGetValue(
                dict,
                Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()
            )

            if let name = name {
                let nameCF = unsafeBitCast(name, to: CFString.self)

                if powerSourceName == nil ||
                   CFStringCompare(nameCF, powerSourceName, []) == .compareEqualTo {

                    myLogger(5, "Matched power dictionary:")
                    CFShow(dict)
                    return dict
                }
            }
        }
    }

    return nil
}

// MARK: - Main

myLogger(1, "upsdrv_initinfo()")

guard let powerDictionary = copyPowerDictionary(powerSourceName: gPowerSourceName) else {
    fatalError("Failed to get power dictionary")
}

// Device type
if let typeValue = CFDictionaryGetValue(
    powerDictionary,
    Unmanaged.passUnretained(kIOPSTypeKey as CFString).toOpaque()
) {
    let typeCF = unsafeBitCast(typeValue, to: CFString.self)
    if CFStringCompare(typeCF, kIOPSInternalBatteryType as CFString, []) == .compareEqualTo {
        print("battery")
    }
}

// Device name
myLogger(2, "Getting 'Name' key")

guard let nameValue = CFDictionaryGetValue(
    powerDictionary,
    Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()
) else {
    fatalError("Couldn't retrieve 'Name' key")
}

let nameCF = unsafeBitCast(nameValue, to: CFString.self)
let deviceName = nameCF as String
myLogger(2, "Got name: \(deviceName)")

// Max capacity
if let maxCapValue = CFDictionaryGetValue(
    powerDictionary,
    Unmanaged.passUnretained(kIOPSMaxCapacityKey as CFString).toOpaque()
) {
    let maxCapCF = unsafeBitCast(maxCapValue, to: CFNumber.self)
    var maxCapacity: Double = 100.0

    if CFNumberGetValue(maxCapCF, .doubleType, &maxCapacity) {
        myLogger(3, "Max Capacity = \(maxCapacity) units (usually 100)")
        if maxCapacity != 100.0 {
            myLogger(1, "Max Capacity: \(maxCapacity) != 100")
        }
    }
}
