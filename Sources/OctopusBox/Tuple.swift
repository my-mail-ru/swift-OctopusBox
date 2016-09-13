import BinaryEncoding

enum PropertyInfo {
	case field(Field.Type)
	case storageInfo
}

var propertiesOfTuple: [ObjectIdentifier : [PropertyInfo]] = [:]

public protocol TupleProtocol {
	init()
	init(fromUnsafe tuple: UnsafeTuple) throws
}

extension TupleProtocol {
	public init(fromUnsafe tuple: UnsafeTuple) throws {
		self.init()
		var reader = tuple.reader()
		var ptr = propertiesUnsafeMutableRawPointer
		for info in Self.propertiesInfo {
			switch info {
				case .field(let type):
					guard let field = try reader.read(type) else { break }
					field.write(to: &ptr)
				case .storageInfo:
					skipStorageInfo(in: &ptr)
			}
		}
	}

	public mutating func field<T : Field>(_ field: UnsafePointer<T>) -> FieldNumber<T, Self> {
		var ptr = UnsafeRawPointer(propertiesUnsafeMutableRawPointer)
		let field = UnsafeRawPointer(field)
		var i = 0
		for info in Self.propertiesInfo {
			switch info {
				case .field(let type):
					type.align(in: &ptr)
					if ptr == field {
						return FieldNumber(i)
					}
					type.skip(in: &ptr)
					i += 1
				case .storageInfo:
					skipStorageInfo(in: &ptr)
			}
		}
		preconditionFailure()
	}

	private static var propertiesInfo: [PropertyInfo] {
		let selfId = ObjectIdentifier(self)
		if let fields = propertiesOfTuple[selfId] {
			return fields
		} else {
			var list: [PropertyInfo] = []
			let mirror = Mirror(reflecting: self.init())
			for (label, value) in mirror.children {
				switch value {
					case let val as Field:
						list.append(.field(type(of: val)))
					default:
						if label == "storageInfo" {
							list.append(.storageInfo)
						} else {
							preconditionFailure("\(type(of: value)) is not Field")
						}
				}
			}
			propertiesOfTuple[selfId] = list
			return list
		}
	}
	
	private var propertiesUnsafeMutableRawPointer: UnsafeMutableRawPointer {
		mutating get {
			if let obj = self as? AnyObject {
				return _getUnsafePointerToStoredProperties(obj)
			} else {
				return UnsafeMutableRawPointer(&self)
			}
		}
	}
}

private extension Field {
	func write(to ptr: inout UnsafeMutableRawPointer) {
		Self.align(in: &ptr)
		ptr.assumingMemoryBound(to: Self.self).pointee = self
		Self.skip(in: &ptr)
	}

	static func align(in ptr: inout UnsafeMutableRawPointer) {
		let d = UInt(bitPattern: ptr) % UInt(MemoryLayout<Self>.alignment)
		if d != 0 {
			ptr += MemoryLayout<Self>.alignment - Int(d)
		}
	}

	static func skip(in ptr: inout UnsafeMutableRawPointer) {
		ptr += MemoryLayout<Self>.size
	}

	static func align(in ptr: inout UnsafeRawPointer) {
		let d = UInt(bitPattern: ptr) % UInt(MemoryLayout<Self>.alignment)
		if d != 0 {
			ptr += MemoryLayout<Self>.alignment - Int(d)
		}
	}

	static func skip(in ptr: inout UnsafeRawPointer) {
		ptr += MemoryLayout<Self>.size
	}
}

private func skipStorageInfo(in ptr: inout UnsafeMutableRawPointer) {
	let d = UInt(bitPattern: ptr) % UInt(MemoryLayout<StorageInfo?>.alignment)
	if d != 0 {
		ptr += MemoryLayout<StorageInfo?>.alignment - Int(d)
	}
	ptr += MemoryLayout<StorageInfo?>.size
}

private func skipStorageInfo(in ptr: inout UnsafeRawPointer) {
	let d = UInt(bitPattern: ptr) % UInt(MemoryLayout<StorageInfo?>.alignment)
	if d != 0 {
		ptr += MemoryLayout<StorageInfo?>.alignment - Int(d)
	}
	ptr += MemoryLayout<StorageInfo?>.size
}

extension BinaryEncodedData {
	mutating func append(tuple value: TupleProtocol) {
		let mirror = Mirror(reflecting: value)
		var cardinalityAt = count
		var cardinality: UInt32 = 0
		append(cardinality, as: UInt32.self)
		for (label, value) in mirror.children {
			guard let val = value as? Field else {
				if label == "storageInfo" { continue }
				preconditionFailure("\(type(of: value)) is not Field")
			}
			append(field: val)
			cardinality += 1
		}
		write(cardinality, as: UInt32.self, at: &cardinalityAt)
	}
}

public struct UnsafeTuple {
	let cardinality: UInt32
	let data: UnsafeBufferRawPointer

	func reader() -> Reader {
		return Reader(reader: data.reader(), remains: cardinality)
	}

	struct Reader {
		var reader: UnsafeBufferRawPointer.Reader
		var remains: UInt32

		mutating func read(_ type: Field.Type) throws -> Field? {
			guard remains > 0 else { return nil }
			defer { remains -= 1 }
			return try reader.read(field: type)
		}
	}
}

extension UnsafeBufferRawPointer.Reader {
	mutating func read(_: UnsafeTuple.Type) throws -> UnsafeTuple {
		let size = Int(try read(UInt32.self))
		let cardinality = try read(UInt32.self)
		let buffer = try read(UnsafeBufferRawPointer.self, withSize: size)
		return UnsafeTuple(cardinality: cardinality, data: buffer)
	}
}
