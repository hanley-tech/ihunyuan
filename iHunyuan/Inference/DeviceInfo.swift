import Foundation
import Darwin
import Darwin.Mach

enum DeviceInfo {
    static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.compactMap { element in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
    }

    /// Best-effort tier label for the perf badge. Errs toward "Newer iPhone" for unknown ids.
    static var tierLabel: String {
        let id = modelIdentifier
        if id.hasPrefix("iPhone17,") || id.hasPrefix("iPhone18,") { return "A19 Pro / Neural GPU" }
        if id.hasPrefix("iPhone16,") { return "A18 Pro" }
        if id.hasPrefix("iPhone15,") { return "A17 Pro" }
        if id.hasPrefix("iPad14,") || id.hasPrefix("iPad16,") { return "M-series iPad" }
        return id.isEmpty ? "iPhone" : id
    }

    static var residentMemoryMB: Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576.0
    }
}
