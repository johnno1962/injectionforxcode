//
//  Internals.swift
//  XprobeSwift
//
//  Created by John Holdsworth on 22/12/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

import Foundation

/** pointer to a function implementing a Swift method */
public typealias SIMP = @convention(c) (_: AnyObject) -> Void

/**
 Layout of a class instance. Needs to be kept in sync with ~swift/include/swift/Runtime/Metadata.h
 */
public struct ClassMetadataSwift {

    public let MetaClass: uintptr_t = 0, SuperClass: uintptr_t = 0
    public let CacheData1: uintptr_t = 0, CacheData2: uintptr_t = 0

    public let Data: uintptr_t = 0

    /// Swift-specific class flags.
    public let Flags: UInt32 = 0

    /// The address point of instances of this type.
    public let InstanceAddressPoint: UInt32 = 0

    /// The required size of instances of this type.
    /// 'InstanceAddressPoint' bytes go before the address point;
    /// 'InstanceSize - InstanceAddressPoint' bytes go after it.
    public let InstanceSize: UInt32 = 0

    /// The alignment mask of the address point of instances of this type.
    public let InstanceAlignMask: UInt16 = 0

    /// Reserved for runtime use.
    public let Reserved: UInt16 = 0

    /// The total size of the class object, including prefix and suffix
    /// extents.
    public let ClassSize: UInt32 = 0

    /// The offset of the address point within the class object.
    public let ClassAddressPoint: UInt32 = 0

    /// An out-of-line Swift-specific description of the type, or null
    /// if this is an artificial subclass.  We currently provide no
    /// supported mechanism for making a non-artificial subclass
    /// dynamically.
    public let Description: uintptr_t = 0

    /// A function for destroying instance variables, used to clean up
    /// after an early return from a constructor.
    public var IVarDestroyer: SIMP? = nil

    // After this come the class members, laid out as follows:
    //   - class members for the superclass (recursively)
    //   - metadata reference for the parent, if applicable
    //   - generic parameters for this class
    //   - class variables (if we choose to support these)
    //   - "tabulated" virtual methods

}

#if swift(>=3.0)
// not public in Swift3
@_silgen_name("swift_demangle")
private
func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<UInt8>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
    ) -> UnsafeMutablePointer<CChar>?

public func _stdlib_demangleName(_ mangledName: String) -> String {
    return mangledName.utf8CString.withUnsafeBufferPointer {
        (mangledNameUTF8) in

        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)

        if let demangledNamePtr = demangledNamePtr {
            let demangledName = String(cString: demangledNamePtr)
            free(demangledNamePtr)
            return demangledName
        }
        return mangledName
    }
}
#endif

