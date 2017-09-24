//
//  XprobeSwift.swift
//  XprobeSwift
//
//  Created by John Holdsworth on 23/04/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

import Foundation

@_silgen_name("swift_EnumCaseName")
func _getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

@_silgen_name("xprobeGenericPointer")
func _getAnyPointer<T>(_ value: T) -> UnsafeRawPointer?

@objc (XprobeSwift)
class XprobeSwift: NSObject {

    #if swift(>=3.0)
    @objc class func string( _ stringPtr: UnsafePointer<Int8> ) -> NSString {
        return stringPtr.withMemoryRebound(to: String.self, capacity: 1) {
            "\($0.pointee)" as NSString
        }
    }

    @objc class func stringOpt( _ stringPtr: UnsafePointer<Int8> ) -> NSString {
        return stringPtr.withMemoryRebound(to: Optional<String>.self, capacity: 1) {
            (stringPtr) in
            if let string = stringPtr.pointee {
                return "\(string)" as NSString
            } else {
                return "nil"
            }
        }
    }

    @objc class func array( _ arrayPtr: UnsafePointer<Int8> ) -> NSString {
        return arrayPtr.withMemoryRebound(to: Array<AnyObject>.self, capacity: 1) {
            (arrayPtr) in
            let s = arrayPtr.pointee.count == 1 ? "" : "s"
            return "[\(arrayPtr.pointee.count) element\(s)]" as NSString
        }
    }

    @objc class func arrayOpt( _ arrayPtr: UnsafePointer<Int8> ) -> NSString {
        return arrayPtr.withMemoryRebound(to: Optional<Array<AnyObject>>.self, capacity: 1) {
            (arrayPtr) in
            if let array = arrayPtr.pointee {
                let s = array.count == 1 ? "" : "s"
                return "[\(array.count) element\(s)]" as NSString
            } else {
                return "nil"
            }
        }
    }

    #else

    @objc class func string( stringPtr: UnsafePointer<Void> ) -> NSString {
        return "\"\(UnsafePointer<String>( stringPtr ).memory)\""
    }

    @objc class func stringOpt( stringPtr: UnsafePointer<Void> ) -> NSString {
        if let string = UnsafePointer<String?>( stringPtr ).memory {
            return "\"\(string)\""
        } else {
            return "nil"
        }
    }

    @objc class func array( arrayPtr: UnsafePointer<Void> ) -> NSString {
        let array = UnsafePointer<Array<AnyObject>>( arrayPtr ).memory
        let s = array.count == 1 ? "" : "s"
        return "[\(array.count) element\(s)]"
    }

    @objc class func arrayOpt( arrayPtr: UnsafePointer<Void> ) -> NSString {
        if let array = UnsafePointer<Array<AnyObject>?>( arrayPtr ).memory {
            let s = array.count == 1 ? "" : "s"
            return "[\(array.count) element\(s)]"
        } else {
            return "nil"
        }
    }

    #endif

    @objc class func demangle( _ name: NSString ) -> NSString {
        return _stdlib_demangleName(name as String) as NSString
    }

    @objc class func traceBundle( _ bundle: Bundle ) {
        Xtrace.trace( bundle )
    }

    @objc class func traceClass( _ aClass: AnyClass ) {
        Xtrace.traceClass( aClass )
    }

    @objc class func traceInstance( _ instance: AnyObject ) {
        Xtrace.traceInstance( instance )
    }

    @objc class func injectionSweep( _ instance: AnyObject, forClass: AnyClass ) {
        var out: IvarOutputStream? = nil
        dumpMembers( instance, target: &out, indent: "", aClass: forClass, processInstance: {
            (obj) in
            obj.bsweep?()
        })
    }

//    @objc class func xprobeSweep( _ instance: AnyObject, forClass: AnyClass ) {
//        var out: IvarOutputStream? = nil
//        dumpMembers( instance, target: &out, indent: "", aClass: forClass, processInstance: {
//            (obj) in
//            obj.xsweep?()
//        })
//    }
//
//    @objc class func dumpMethods( _ aClass: AnyClass, into: NSMutableString ) {
//        into.append("<br><b>Swift vtable:</b><br>")
//        Swizzler.scanSlots(of: aClass ) {
//            (number, slot, demangled) -> Int? in
//            into.append(demangled)
//            into.append("<br>")
//            return nil
//        }
//    }
//
//    @objc class func dumpIvars( _ instance: AnyObject, forClass: AnyClass, into: NSMutableString ) {
//        var out: IvarOutputStream? = IvarOutputStream()
//        dumpMembers( instance, target: &out, indent: "", aClass: forClass, processInstance: {
//            (obj) in
//            let path = XprobeRetained()
//            path.setObject(obj)
//            let link = NSMutableString()
//            obj.xlink(forCommand: "open", withPathID: path.xadd(), into: link)
//            out?.write("\(link)")
//        } )
//        into.append(out!.out
//            .replacingOccurrences(of: "= '", with: "= \\'")
//            .replacingOccurrences(of: "';", with: "\\';"))
//        into.append("<br>")
//    }

    struct IvarOutputStream: TextOutputStream {
        var out = ""
        mutating func write(_ string: String)  {
            out += string
        }
    }

    class func dumpMembers(_ instance: Any, target: inout IvarOutputStream?, indent: String?,
                           aClass: AnyClass? = nil, separator: String = "<br>",
                           processInstance: (AnyObject) -> Void ) {
        let indent = indent != nil ? "&#160; &#160; " : nil
        var mirror = Mirror(reflecting: instance)
        while aClass != nil, let thisClass = mirror.subjectType as? AnyClass,
            aClass != thisClass, let superMirror = mirror.superclassMirror {
            mirror = superMirror
        }

        var count = 0
        for (name, value) in mirror.children {
            if count != 0 {
                target?.write(separator)
            }
            count += 1

            var mirror = Mirror(reflecting: value), opt = ""
            while mirror.displayStyle == .optional,
                let value = mirror.children.first?.value {
                    mirror = Mirror(reflecting: value)
                    opt += "?"
            }

            let type = _typeName(mirror.subjectType)
                .replacingOccurrences(of: "__C.", with: "")
                .replacingOccurrences(of: "Swift.", with: "")
            target?.write( "\(indent ?? "")<span class=letStyle>let</span> \((name ?? "noname")): <span class=typeStyle>\(htmlEscape(type))</span>\(opt) = ")
            dumpValue( value, target: &target, indent: indent, processInstance:  processInstance )
        }
    }

    static var maxItems = 100

    class func dumpValue(_ value: Any, target: inout IvarOutputStream?, indent: String?,
                         separator: String? = nil, processInstance: (AnyObject) -> Void ) {
        let mirror = Mirror(reflecting: value)
        if var style = mirror.displayStyle {
            if _typeName(mirror.subjectType).hasPrefix("Swift.ImplicitlyUnwrappedOptional<") {
                style = .optional
            }
            switch style {
            case .set:
                fallthrough
            case .collection:
                target?.write("[")
                var count = 0
                for (_, child) in mirror.children {
                    if count > maxItems {
                        target?.write(" ...")
                        break
                    }
                    if count > 0 {
                        target?.write(", ")
                    }
                    dumpValue( child, target: &target, indent: indent, processInstance:  processInstance )
                    count += 1
                }
                target?.write("]")
                return
            case .dictionary:
                target?.write("[")
                var count = 0
                for (_, child) in mirror.children {
                    if count > maxItems {
                        target?.write(" ...")
                        break
                    }
                    if count > 0 {
                        target?.write(", ")
                    }
                    var between = false
                    for (_, element) in Mirror(reflecting: child).children {
                        if between {
                            target?.write(": ")
                        }
                        dumpValue( element, target: &target, indent: indent, processInstance:  processInstance )
                        between = true
                    }
                    count += 1
                }
                target?.write("]")
                return
            case .class:
//                if let obj = value as? AnyObject {
                    processInstance( value as AnyObject )
//                }
//                else {
//                    target?.write("{<br>")
//                    dumpMembers( value, target: &target, indent: indent, processInstance:  processInstance )
//                    target?.write("\(indent)}")
//                }
                return
            case .optional:
                if let some = mirror.children.first?.value {
                    dumpValue( some, target: &target, indent: indent, processInstance:  processInstance )
                }
                else {
                    target?.write("nil")
                }
                return
            default:
                break
            }
        }

        if let debugPrintableObject = value as? CustomDebugStringConvertible {
            var t1 = IvarOutputStream()
            debugPrintableObject.debugDescription.write(to: &t1)
            target?.write(htmlEscape(t1.out))
        }
        else if let printableObject = value as? CustomStringConvertible {
            var t1 = IvarOutputStream()
            printableObject.description.write(to: &t1)
            target?.write(htmlEscape(t1.out))
        }
        else if let streamableObject = value as? TextOutputStreamable {
            var t1 = IvarOutputStream()
            streamableObject.write(to: &t1)
            target?.write(htmlEscape(t1.out))
        }
        else if let style = mirror.displayStyle {
            switch style {
            case .enum:
                if let cString = _getEnumCaseName(value),
                    let caseName = String(validatingUTF8: cString) {
                    target?.write("."+caseName)
                    if let evals = mirror.children.first?.value {
                        if Mirror(reflecting: evals).displayStyle == .tuple {
                            dumpValue( evals, target: &target, indent: indent, separator: ", ", processInstance:  processInstance )
                        }
                        else {
                            target?.write("(")
                            dumpValue( evals, target: &target, indent: indent, processInstance:  processInstance )
                            target?.write(")")
                        }
                    }
                }
                else if let eval = _getAnyPointer(value)?.assumingMemoryBound(to: UInt32.self) {
                    target?.write("\(eval.pointee)")
                }
            case .tuple:
                target?.write("(")
                dumpMembers( value, target: &target, indent: nil, separator: ", ", processInstance:  processInstance )
                target?.write(")")
            case .struct:
                target?.write("(<br>")
                dumpMembers( value, target: &target, indent: indent, processInstance:  processInstance )
                target?.write("\(indent ?? "")\(separator ?? ""))")
            default:
                target?.write("??")
                break
            }
        }
        else if let fptr = _getAnyPointer(value)?.assumingMemoryBound(to: uintptr_t.self) {
            target?.write(String(format: "<span id=L%ld onmouseover=\\'lookupSym(this)\\'>%p()</span>",
                                fptr.pointee, fptr.pointee))
        }
    }

    class func htmlEscape(_ str: String ) -> String {
        return str.contains("<") || str.contains("&") ?
            str.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;") : str
    }

}
