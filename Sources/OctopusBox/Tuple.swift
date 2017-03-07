import BinaryEncoding

struct PropertyInfo {
	let type: Field.Type
	let offset: Int
}

var propertiesOfTuple: [ObjectIdentifier : [PropertyInfo]] = [:]

public protocol TupleProtocol {
	init()
	init(fromUnsafe tuple: UnsafeTuple) throws
}

extension TupleProtocol {
	public init(fromUnsafe tuple: UnsafeTuple) throws {
		self.init()
		defer { _fixLifetime(self) }
		var reader = tuple.reader()
		let start = propertiesUnsafeMutableRawPointer
		for info in Self.propertiesInfo {
			guard let field = try reader.read(info.type) else { break }
			field.write(to: start, at: info.offset)
		}
	}

	public mutating func field<T : Field>(_ field: UnsafePointer<T>) -> FieldNumber<T, Self> {
		defer { _fixLifetime(self) }
		let start = propertiesUnsafeRawPointer
		let field = UnsafeRawPointer(field)
		var i = 0
		for info in Self.propertiesInfo {
			if (start + info.offset) == field {
				return FieldNumber(i)
			}
			i += 1
		}
		preconditionFailure()
	}

	fileprivate static var propertiesInfo: [PropertyInfo] {
		let selfId = ObjectIdentifier(self)
		if let fields = propertiesOfTuple[selfId] {
			return fields
		} else {
			var list: [PropertyInfo] = []
			var offset = 0
			let mirror = Mirror(reflecting: self.init())
			for (label, value) in mirror.children {
				switch value {
					case let val as Field:
						let t = type(of: val)
						t.align(offset: &offset)
						list.append(PropertyInfo(type: t, offset: offset))
						t.skip(offset: &offset)
					default:
						switch label {
							case .some("storageInfo") where type(of: value) == Optional<StorageInfo>.self:
								skip(Optional<StorageInfo>.self, offset: &offset)
							case .some("updateQueue") where type(of: value) == Array<UpdateOperation<Self>>.self:
								skip(Array<UpdateOperation<Self>>.self, offset: &offset)
							default:
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
	
	fileprivate var propertiesUnsafeRawPointer: UnsafeRawPointer {
		mutating get {
			return UnsafeRawPointer(propertiesUnsafeMutableRawPointer)
		}
	}
}

private extension Field {
	static func align(offset: inout Int) {
		let d = offset % MemoryLayout<Self>.alignment
		if d != 0 {
			offset += MemoryLayout<Self>.alignment - d
		}
	}

	static func skip(offset: inout Int) {
		offset += MemoryLayout<Self>.size
	}

	func write(to start: UnsafeMutableRawPointer, at offset: Int) {
		(start + offset).assumingMemoryBound(to: Self.self).pointee = self
	}

	static func read(from start: UnsafeRawPointer, at offset: Int) -> Self {
		return (start + offset).assumingMemoryBound(to: Self.self).pointee
	}
}

private func skip<T>(_: T.Type, offset: inout Int) {
	let d = offset % MemoryLayout<T>.alignment
	if d != 0 {
		offset += MemoryLayout<T>.alignment - d
	}
	offset += MemoryLayout<T>.size
}

extension BinaryEncodedData {
	mutating func append(tuple value: TupleProtocol) {
		var value = value
		let propertiesInfo = type(of: value).propertiesInfo
		append(UInt32(propertiesInfo.count), as: UInt32.self)
		withExtendedLifetime(value) {
			let properties = value.propertiesUnsafeRawPointer
			for info in propertiesInfo {
				let field = info.type.read(from: properties, at: info.offset)
				append(field: field)
			}
		}
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
