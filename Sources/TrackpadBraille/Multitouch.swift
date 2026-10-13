import Foundation
import CoreFoundation

/// One finger sample, already converted to millimetres, origin top-left.
struct TouchSample {
    var x: Double
    var y: Double
    var touching: Bool
}

/// Thin wrapper over Apple's PRIVATE MultitouchSupport.framework, loaded at runtime.
/// The touch struct layout and device-id offset follow https://github.com/MatMercer/mactic
/// (tested there on an M3 MacBook Pro). They may differ on newer macOS or an M5.
final class Multitouch {
    typealias Dev = UnsafeMutableRawPointer
    typealias CreateListFn = @convention(c) () -> UnsafeMutableRawPointer?
    typealias ActCreateFn = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    typealias ActOpenFn = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    typealias ActCloseFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    typealias ActuateFn = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, UInt32, UInt32) -> Int32
    typealias ContactCB = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void
    typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer, ContactCB) -> Void
    typealias StartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    typealias StopFn = @convention(c) (UnsafeMutableRawPointer) -> Void
    typealias GetDimsFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    typealias GetIDFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32

    static let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    static let touchStride = 96

    private var handle: UnsafeMutableRawPointer?
    private var createList: CreateListFn?
    private var actCreate: ActCreateFn?
    private var actOpen: ActOpenFn?
    private var actClose: ActCloseFn?
    private var actuate: ActuateFn?
    private var register: RegisterFn?
    private var start: StartFn?
    private var stop: StopFn?
    private var getID: GetIDFn?
    private var getDims: GetDimsFn?
    private let pendingLock = NSLock()
    private var pendingTaps = 0

    private(set) var device: Dev?
    private(set) var deviceID: UInt64 = 0
    private var actuator: UnsafeMutableRawPointer?
    private let hapticQueue = DispatchQueue(label: "braille.haptic")

    /// Called on the multitouch thread for every frame from the chosen trackpad.
    nonisolated(unsafe) static var onFrame: ((_ touches: UnsafeMutableRawPointer?, _ count: Int) -> Void)?
    nonisolated(unsafe) static var chosenDevice: UnsafeMutableRawPointer?

    private func sym<T>(_ name: String, as: T.Type) -> T? {
        guard let h = handle, let s = dlsym(h, name) else { return nil }
        return unsafeBitCast(s, to: T.self)
    }

    /// Returns nil on success, or a plain-language error message.
    func open() -> String? {
        handle = dlopen(Multitouch.path, RTLD_LAZY)
        guard handle != nil else { return "Could not load MultitouchSupport.framework." }
        createList = sym("MTDeviceCreateList", as: CreateListFn.self)
        actCreate = sym("MTActuatorCreateFromDeviceID", as: ActCreateFn.self)
        actOpen = sym("MTActuatorOpen", as: ActOpenFn.self)
        actClose = sym("MTActuatorClose", as: ActCloseFn.self)
        actuate = sym("MTActuatorActuate", as: ActuateFn.self)
        register = sym("MTRegisterContactFrameCallback", as: RegisterFn.self)
        start = sym("MTDeviceStart", as: StartFn.self)
        stop = sym("MTDeviceStop", as: StopFn.self)
        getID = sym("MTDeviceGetDeviceID", as: GetIDFn.self)
        getDims = sym("MTDeviceGetSensorSurfaceDimensions", as: GetDimsFn.self)
        guard let createList, let actCreate, let actOpen, actClose != nil, actuate != nil,
              register != nil, start != nil else {
            return "This macOS version is missing a multitouch function the app needs."
        }
        guard let raw = createList() else { return "No multitouch devices found." }
        let list = Unmanaged<CFArray>.fromOpaque(raw).takeRetainedValue()
        let n = CFArrayGetCount(list)
        for i in 0..<n {
            guard let p = CFArrayGetValueAtIndex(list, i) else { continue }
            let dev = UnsafeMutableRawPointer(mutating: p)
            var id: UInt64 = 0
            if let getID, getID(dev, &id) == 0, id != 0 {
                // ok
            } else {
                id = dev.load(fromByteOffset: 64, as: UInt64.self) // fallback from mactic
            }
            guard let act = actCreate(id) else { continue }
            if actOpen(act, 0) == 0 {
                device = dev
                deviceID = id
                actuator = act
                // keep `list` alive: the device pointer belongs to it
                _ = Unmanaged.passRetained(list)
                return nil
            }
        }
import CoreFoundation

/// One finger sample, already converted to millimetres, origin top-left.
struct TouchSample {
    var x: Double
    var y: Double
    var touching: Bool
}

/// Thin wrapper over Apple's PRIVATE MultitouchSupport.framework, loaded at runtime.
/// The touch struct layout and device-id offset follow https://github.com/MatMercer/mactic
/// (tested there on an M3 MacBook Pro). They may differ on newer macOS or an M5.
final class Multitouch {
    typealias Dev = UnsafeMutableRawPointer
    typealias CreateListFn = @convention(c) () -> UnsafeMutableRawPointer?
    typealias ActCreateFn = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    typealias ActOpenFn = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    typealias ActCloseFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    typealias ActuateFn = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, UInt32, UInt32) -> Int32
    typealias ContactCB = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Void
    typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer, ContactCB) -> Void
    typealias StartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    typealias StopFn = @convention(c) (UnsafeMutableRawPointer) -> Void
    typealias GetDimsFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    typealias GetIDFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32

    static let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    static let touchStride = 96

    private var handle: UnsafeMutableRawPointer?
    private var createList: CreateListFn?
    private var actCreate: ActCreateFn?
    private var actOpen: ActOpenFn?
    private var actClose: ActCloseFn?
    private var actuate: ActuateFn?
    private var register: RegisterFn?
    private var start: StartFn?
    private var stop: StopFn?
    private var getID: GetIDFn?
    private var getDims: GetDimsFn?
    private let pendingLock = NSLock()
    private var pendingTaps = 0

    private(set) var device: Dev?
    private(set) var deviceID: UInt64 = 0
    private var actuator: UnsafeMutableRawPointer?
    private let hapticQueue = DispatchQueue(label: "braille.haptic")

    /// Called on the multitouch thread for every frame from the chosen trackpad.
    nonisolated(unsafe) static var onFrame: ((_ touches: UnsafeMutableRawPointer?, _ count: Int) -> Void)?
    nonisolated(unsafe) static var chosenDevice: UnsafeMutableRawPointer?

    private func sym<T>(_ name: String, as: T.Type) -> T? {
        guard let h = handle, let s = dlsym(h, name) else { return nil }
        return unsafeBitCast(s, to: T.self)
    }

    /// Returns nil on success, or a plain-language error message.
    func open() -> String? {
        handle = dlopen(Multitouch.path, RTLD_LAZY)
        guard handle != nil else { return "Could not load MultitouchSupport.framework." }
        createList = sym("MTDeviceCreateList", as: CreateListFn.self)
        actCreate = sym("MTActuatorCreateFromDeviceID", as: ActCreateFn.self)
        actOpen = sym("MTActuatorOpen", as: ActOpenFn.self)
        actClose = sym("MTActuatorClose", as: ActCloseFn.self)
        actuate = sym("MTActuatorActuate", as: ActuateFn.self)
        register = sym("MTRegisterContactFrameCallback", as: RegisterFn.self)
        start = sym("MTDeviceStart", as: StartFn.self)
        stop = sym("MTDeviceStop", as: StopFn.self)
        getID = sym("MTDeviceGetDeviceID", as: GetIDFn.self)
        getDims = sym("MTDeviceGetSensorSurfaceDimensions", as: GetDimsFn.self)
        guard let createList, let actCreate, let actOpen, actClose != nil, actuate != nil,
              register != nil, start != nil else {
            return "This macOS version is missing a multitouch function the app needs."
        }
        guard let raw = createList() else { return "No multitouch devices found." }
        let list = Unmanaged<CFArray>.fromOpaque(raw).takeRetainedValue()
        let n = CFArrayGetCount(list)
        for i in 0..<n {
            guard let p = CFArrayGetValueAtIndex(list, i) else { continue }
            let dev = UnsafeMutableRawPointer(mutating: p)
            var id: UInt64 = 0
            if let getID, getID(dev, &id) == 0, id != 0 {
                // ok
            } else {
                id = dev.load(fromByteOffset: 64, as: UInt64.self) // fallback from mactic
            }
            guard let act = actCreate(id) else { continue }
            if actOpen(act, 0) == 0 {
                device = dev
                deviceID = id
                actuator = act
                // keep `list` alive: the device pointer belongs to it
                _ = Unmanaged.passRetained(list)
                return nil
            }
        }
        return "No trackpad with a haptic actuator was found."
    }

    func startTouches(_ handler: @escaping (_ touches: UnsafeMutableRawPointer?, _ count: Int) -> Void) {
        guard let device, let register, let start else { return }
        Multitouch.onFrame = handler
        Multitouch.chosenDevice = device
        register(device) { dev, touches, count, _, _ in
            guard dev == Multitouch.chosenDevice else { return }
            Multitouch.onFrame?(touches, Int(count))
        }
        start(device, 0)
    }

    func stopTouches() {
        if let device, let stop { stop(device) }
        Multitouch.onFrame = nil
    }

    /// Physical size of the trackpad surface in millimetres, if the system reports it
    /// (MTDeviceGetSensorSurfaceDimensions returns hundredths of a millimetre).
    func surfaceSizeMM() -> (width: Double, height: Double)? {
        guard let device, let getDims else { return nil }
        var w: Int32 = 0, h: Int32 = 0
        guard getDims(device, &w, &h) == 0, w > 2000, h > 1500 else { return nil }
        return (Double(w) / 100.0, Double(h) / 100.0)
    }

    /// Fire `count` short pulses in a row, `gapMS` apart.
    /// Waveform ids (from mactic): 1 weak click, 2 strong click, 3 buzz, 4 light tap,
    /// 5 medium tap, 6 strong tap, 15 soft thud, 16 strong thud.
    func fire(_ waveform: Int32, count: Int = 1, gapMS: Int = 50) {
        pendingLock.lock()
        if pendingTaps > 9 { pendingLock.unlock(); return } // fast swipe: don't build a backlog
        pendingTaps += count
        pendingLock.unlock()
        hapticQueue.async { [self] in
            for i in 0..<count {
                if let actuator, let actuate, let actOpen, let actClose {
                    if actuate(actuator, waveform, 0, 0, 0) != 0 {
                        _ = actClose(actuator)
                        _ = actOpen(actuator, 0)
                        _ = actuate(actuator, waveform, 0, 0, 0)
                    }
                }
                pendingLock.lock(); pendingTaps -= 1; pendingLock.unlock()
                if i < count - 1 { usleep(UInt32(gapMS) * 1000) }
            }
        }
    }
}
