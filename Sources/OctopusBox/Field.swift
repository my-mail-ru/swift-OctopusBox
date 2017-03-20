import BinaryEncoding

public protocol Field {
	init(readAsFieldFrom: inout UnsafeRawBufferPointer.Reader) throws
	func appendAsField(to: inout BinaryEncodedData)
}

extension BinaryEncodedData {
	mutating func append(field: Field) {
		field.appendAsField(to: &self)
	}
}

extension UnsafeRawBufferPointer.Reader {
	mutating func read(field type: Field.Type) throws -> Field {
		return try type.init(readAsFieldFrom: &self)
	}
}

public protocol NativeField : Field, NativeBinaryEncoding {}

extension Int8 : NativeField {}
extension Int16 : NativeField {}
extension Int32 : NativeField {}
extension Int64 : NativeField {}
extension UInt8 : NativeField {}
extension UInt16 : NativeField {}
extension UInt32 : NativeField {}
extension UInt64 : NativeField {}

extension NativeField {
	public init(readAsFieldFrom reader: inout UnsafeRawBufferPointer.Reader) throws {
		let size = Int(try reader.read(VarUInt.self))
		guard size == MemoryLayout<Self>.size else { throw OctopusBoxError.invalidFieldSize }
		self = try reader.read(Self.self)
	}

	public func appendAsField(to: inout BinaryEncodedData) {
		to.append(UInt(MemoryLayout<Self>.size), as: VarUInt.self)
		to.append(self, as: Self.self)
	}
}

extension BinaryEncodedData : Field {
	public init(readAsFieldFrom reader: inout UnsafeRawBufferPointer.Reader) throws {
		self = try reader.read(BinaryEncodedData.self, withSizeOf: VarUInt.self)
	}

	public func appendAsField(to: inout BinaryEncodedData) {
		to.append(self, withSizeOf: VarUInt.self)
	}
}

extension String : Field {
	public init(readAsFieldFrom reader: inout UnsafeRawBufferPointer.Reader) throws {
		self = try reader.read(String.self, withSizeOf: VarUInt.self)
	}

	public func appendAsField(to: inout BinaryEncodedData) {
		to.append(self, as: String.self, withSizeOf: VarUInt.self)
	}
}
