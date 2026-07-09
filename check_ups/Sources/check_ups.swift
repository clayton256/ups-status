/* check_ups - 
 * This program is a Nagios plugin that checks parameters of the connected UPS, 
 * specified by name. Optionally, the -list argument will list the names of the 
 * connected UPS units. The -help arguemnt displays the options and their syntax.
 * i.e. check_ups -name "CyperPower 1500" -capacity -warn 25 -crit 10
 * Command line arguments
 * -list : dumps a list of UPSes
 * -ups <name> : the ups to which the follow options pertain
 *       (-help, -list and -ups are mutually exclusive)
 * -online : boolean value reports TRUE or FALSE
 * -capacity : integer value that reports the current capacity in percent
 * -voltage : integer value that reports the current incoming voltage (div by 100 to get actual line voltage)
 * -charging : boolean value that reports the current charging state
 *       (use one of -online, -capacity, -voltaage or -charging when using -ups)
 * -warn : follows -online, -capacity, -voltaage or -charging as a warning value
 * -crit : follows -online, -capacity, -voltaage or -charging as a critical value
 * -help : displays the syntax and options
*/

import IOKit.ps
import ArgumentParser
import Foundation

enum ArgError: Error, CustomStringConvertible {
    case invalidSyntax(String)
    case missingValue(String)
    case unknownFlag(String)
    case mutuallyExclusive(String)
    case invalidInt(String)

    var description: String {
        switch self {
        case .invalidSyntax(let s): return "Invalid syntax: \(s)"
        case .missingValue(let s): return "Missing value: \(s)"
        case .unknownFlag(let s): return "Unknown flag: \(s)"
        case .mutuallyExclusive(let s): return "Mutually exclusive: \(s)"
        case .invalidInt(let s): return "Invalid integer: \(s)"
        }
    }
}

struct Config {
    enum Mode {
        case list
        case help
        case ups(name: String)
    }

    var mode: Mode = .help
    var metric: Metric? = nil
    var warn: Int? = nil
    var crit: Int? = nil
}

enum Metric: String {
    case online
    case capacity
    case voltage
    case charging
}

func usage() {
    let text = """
    check_ups -

    This program checks parameters of the connected UPS specified by name.
    Optionally, the -list argument will list the names of the connected UPS units.
    The -help argument displays the options and their syntax.

    Examples:
      check_ups -list
      check_ups -name "CyberPower 1500" -capacity -warn 25 -crit 10
      check_ups -ups "CyberPower 1500" -online -warn 0 -crit 0   (warn/crit ignored for online/charging)
      check_ups -ups "CyberPower 1500" -voltage -warn 102 -crit 100

    Command line arguments:
      -list                         Dumps a list of UPSes
      -ups <name>                   The ups to which the follow options pertain
                                     (-help, -list and -ups are mutually exclusive)
      -online                       Boolean value reports TRUE or FALSE
      -capacity                     Integer value that reports current capacity in percent
      -voltage                      Integer value reports incoming voltage/100
      -charging                     Boolean value reports charging state

      When using -ups, use exactly one of:
        -online, -capacity, -voltage, -charging

      -warn <value>                Warning threshold (used with capacity/voltage)
      -crit <value>                Critical threshold (used with capacity/voltage)
      -help                         Displays this syntax and options

    Note:
      This code includes placeholder UPS data (no system integration).
    """
    print(text)
}

func parseArgs(_ argv: [String]) throws -> Config {
    // argv includes executable at index 0
    let args = Array(argv.dropFirst())

    if args.isEmpty { throw ArgError.invalidSyntax("No arguments provided. Use -help."); }

    var cfg = Config(mode: .help)

    var sawHelp = false
    var sawList = false
    var upsName: String? = nil

    var metric: Metric? = nil
    var warn: Int? = nil
    var crit: Int? = nil

    func requireValue(_ flag: String, _ i: inout Int) throws -> String {
        if i + 1 >= args.count { throw ArgError.missingValue(flag) }
        i += 1
        return args[i]
    }

    var i = 0
    while i < args.count {
        let a = args[i]

        switch a {
        case "-help":
            sawHelp = true
        case "-list":
            sawList = true
        case "-ups", "-name":
            // Your comment shows "-name", but the spec says "-ups <name>".
            // Support both for convenience; normalize to -ups.
            upsName = try requireValue(a, &i)
        case "-online":
            metric = .online
        case "-capacity":
            metric = .capacity
        case "-voltage":
            metric = .voltage
        case "-charging":
            metric = .charging
        case "-warn":
            let v = try requireValue(a, &i)
            guard let iv = Int(v) else { throw ArgError.invalidInt(v) }
            warn = iv
        case "-crit":
            let v = try requireValue(a, &i)
            guard let iv = Int(v) else { throw ArgError.invalidInt(v) }
            crit = iv
        default:
            throw ArgError.unknownFlag(a)
        }

        i += 1
    }

    let exclusive = [sawHelp, sawList, upsName != nil].filter { $0 }.count
    if exclusive != 1 {
        throw ArgError.mutuallyExclusive("Use exactly one of: -help, -list, or -ups <name>.")
    }

    if sawHelp { cfg.mode = .help }
    if sawList { cfg.mode = .list }
    if let name = upsName { cfg.mode = .ups(name: name) }

    cfg.metric = metric
    cfg.warn = warn
    cfg.crit = crit

    // Validate metric usage when -ups
    switch cfg.mode {
    case .ups:
        guard metric != nil else {
            throw ArgError.invalidSyntax("When using -ups <name>, you must specify exactly one metric: -online, -capacity, -voltage, or -charging.")
        }
        // If both warn/crit are present with a boolean metric, allow but ignore in evaluation.
    default:
        // -help/-list should not carry metric thresholds
        break
    }

    return cfg
}

// Placeholder UPS store (replace with real UPS query, e.g. via Network UPS Tools /snmp/whatever you use)
struct UpsSnapshot: Codable {
    var name: String
    var online: Bool
    var capacity: Int          // percent
    var voltageTimes100: Int  // incoming voltage * 100
    var charging: Bool
}

let demoUpses: [UpsSnapshot] = [
    UpsSnapshot(name: "CyberPower 1500", online: true,  capacity: 82, voltageTimes100: 12150, charging: true),
    UpsSnapshot(name: "Eaton 5P 1100",   online: false, capacity: 12, voltageTimes100: 10990, charging: false),
]

func findUps(_ name: String) -> UpsSnapshot? {
	var snap: UpsSnapshot
	if let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
	    //CFShow(powerSourcesInfo)

	    if let sourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] {
			var sourceCount = CFArrayGetCount(sourcesList) as? Int ?? 0
			sourceCount -= 1
	        for src in 0...sourceCount {
	            guard let info = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue() as? [String: Any],
	                  info[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType as String else { continue }
	            snap.name = CFDictionaryGetValue(info as! CFDictionary, Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque())
				snap.capacity = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
	            snap.charging = info[kIOPSIsChargingKey as String] as? Bool ?? false
	            snap.voltageTimes100 = info[kIOPSVoltageKey as String] as? Int ?? 100
	        }
	    } else {
	        //print("IOPSCopyPowerSourcesList returned nil")
			return nil
	    }
	   
	    //if let nameValue = CFDictionaryGetValue(sourcesList,Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()) {
		//	//CFShow(nameValue)
	    //} else {
		//	return nil
	    //    //fatalError("Couldn't retrieve 'Name' key")
	    //}
	} else {
		return nil
	    //print("IOPSCopyPowerSourcesInfo returned nil")
	}
	return snap
    //demoUpses.first { $0.name == name }
}

func evaluate(cfg: Config, snapshot: UpsSnapshot) -> (status: String, message: String, perf: String) {
    guard let m = cfg.metric else {
        return ("UNKNOWN", "No metric selected", "")
    }

    switch m {
    case .online:
        let ok = snapshot.online
        return (ok ? "OK" : "CRITICAL",
                "online=\(ok ? "TRUE" : "FALSE") for \(snapshot.name)",
                "online=\(ok ? 1 : 0)")
    case .charging:
        let ok = snapshot.charging
        return (ok ? "OK" : "CRITICAL",
                "charging=\(ok ? "TRUE" : "FALSE") for \(snapshot.name)",
                "charging=\(ok ? 1 : 0)")
    case .capacity:
        let cap = snapshot.capacity
        let warn = cfg.warn
        let crit = cfg.crit

        if let crit = crit, cap <= crit {
            return ("CRITICAL", "capacity=\(cap)% <= crit=\(crit)% for \(snapshot.name)",
                    "capacity=\(cap);warn=\(warn ?? 0);crit=\(crit)")
        }
        if let warn = warn, cap <= warn {
            return ("WARNING", "capacity=\(cap)% <= warn=\(warn)% for \(snapshot.name)",
                    "capacity=\(cap);warn=\(warn);crit=\(crit ?? 0)")
        }
        return ("OK", "capacity=\(cap)% for \(snapshot.name)",
                "capacity=\(cap);warn=\(warn ?? 0);crit=\(crit ?? 0)")
    case .voltage:
        // Stored as voltageTimes100; display is voltage/100
        let v = snapshot.voltageTimes100
        let warn = cfg.warn
        let crit = cfg.crit

        if let crit = crit, v <= crit {
            return ("CRITICAL",
                    "voltage=\(Double(v)/100.0) <= crit=\(Double(crit)/100.0) for \(snapshot.name)",
                    "voltage=\(Double(v)/100.0);warn=\(warn.map { Double($0)/100.0 } ?? 0);crit=\(Double(crit)/100.0)")
        }
        if let warn = warn, v <= warn {
            return ("WARNING",
                    "voltage=\(Double(v)/100.0) <= warn=\(Double(warn)/100.0) for \(snapshot.name)",
                    "voltage=\(Double(v)/100.0);warn=\(Double(warn)/100.0);crit=\(crit.map { Double($0)/100.0 } ?? 0)")
        }
        return ("OK",
                "voltage=\(Double(v)/100.0) for \(snapshot.name)",
                "voltage=\(Double(v)/100.0);warn=\(warn.map { Double($0)/100.0 } ?? 0);crit=\(crit.map { Double($0)/100.0 } ?? 0)")
    }
}

do {
    let cfg = try parseArgs(CommandLine.arguments)

    switch cfg.mode {
    case .help:
        usage()

    case .list:
        for u in demoUpses {
            print(u.name)
        }

    case .ups(let name):
        guard let snap = findUps(name) else {
            print("UNKNOWN UPS not found: \(name)")
            exit(3)
        }
        let result = evaluate(cfg: cfg, snapshot: snap)
        if result.perf.isEmpty {
            print("\(result.status): \(result.message)")
        } else {
            print("\(result.status): \(result.message) | \(result.perf)")
        }
        switch result.status {
        case "OK": exit(0)
        case "WARNING": exit(1)
        case "CRITICAL": exit(2)
        default: exit(3)
        }
    }
} catch let e as ArgError {
    print(e.description)
    print("")
    usage()
    exit(3)
} catch {
    print("UNKNOWN error: \(error)")
    exit(3)
}



if let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
    CFShow(powerSourcesInfo)

    if let sourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() {
        CFShow(sourcesList)
    } else {
        print("IOPSCopyPowerSourcesList returned nil")
    }
/*    
    if let nameValue = CFDictionaryGetValue(sourcesList,Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()) {
		CFShow(nameValue)
    } else {
        fatalError("Couldn't retrieve 'Name' key")
    }*/
} else {
    print("IOPSCopyPowerSourcesInfo returned nil")
}


// // Global power source name (nil = match any)
// var gPowerSourceName: CFString? = nil
//
// func myLogger(_ level: Int, _ message: String) {
//     fputs(message + "\n", stderr)
// }
//
// /**
//  Copy the current power dictionary.
//  Caller must retain the returned dictionary if needed.
//  */
// func copyPowerDictionary(powerSourceName: CFString?) -> CFDictionary? {
//
//     guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
//         return nil
//     }
//
//     myLogger(6, "Got power_sources_info:")
//     CFShow(powerSourcesInfo)
//
//     if let sourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() {
//
//         let count = CFArrayGetCount(sourcesList)
//
//         for index in 0..<count {
//             let powerSource = CFArrayGetValueAtIndex(sourcesList, index)
//             myLogger(6, "Checking power source \(index + 1)/\(count)")
//             //CFShow(powerSource)
//
//             guard let dict = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSource)?
//                 .takeUnretainedValue() else {
//                 continue
//             }
//
//             let name = CFDictionaryGetValue(
//                 dict,
//                 Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()
//             )
//
//             if let name = name {
//                 let nameCF = unsafeBitCast(name, to: CFString.self)
//
//                 if powerSourceName == nil ||
//                    CFStringCompare(nameCF, powerSourceName, []) == .compareEqualTo {
//
//                     myLogger(5, "Matched power dictionary:")
//                     //CFShow(dict)
//                     return dict
//                 }
//             }
//         }
//     }
//
//     return nil
// }
//
// // MARK: - Main
//
// myLogger(1, "upsdrv_initinfo()")
//
// guard let powerDictionary = copyPowerDictionary(powerSourceName: gPowerSourceName) else {
//     fatalError("Failed to get power dictionary")
// }
//
// // Device type
// if let typeValue = CFDictionaryGetValue(
//     powerDictionary,
//     Unmanaged.passUnretained(kIOPSTypeKey as CFString).toOpaque()
// ) {
//     let typeCF = unsafeBitCast(typeValue, to: CFString.self)
//     if CFStringCompare(typeCF, kIOPSInternalBatteryType as CFString, []) == .compareEqualTo {
//         print("battery")
//     }
// }
//
// // Device name
// myLogger(2, "Getting 'Name' key")
//
// guard let nameValue = CFDictionaryGetValue(
//     powerDictionary,
//     Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()
// ) else {
//     fatalError("Couldn't retrieve 'Name' key")
// }
//
// let nameCF = unsafeBitCast(nameValue, to: CFString.self)
// let deviceName = nameCF as String
// myLogger(2, "Got name: \(deviceName)")
//
// // Max capacity
// if let maxCapValue = CFDictionaryGetValue(
//     powerDictionary,
//     Unmanaged.passUnretained(kIOPSMaxCapacityKey as CFString).toOpaque()
// ) {
//     let maxCapCF = unsafeBitCast(maxCapValue, to: CFNumber.self)
//     var maxCapacity: Double = 100.0
//
//     if CFNumberGetValue(maxCapCF, .doubleType, &maxCapacity) {
//         myLogger(3, "Max Capacity = \(maxCapacity) units (usually 100)")
//         if maxCapacity != 100.0 {
//             myLogger(1, "Max Capacity: \(maxCapacity) != 100")
//         }
//     }
// }
