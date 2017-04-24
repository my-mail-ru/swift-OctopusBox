public protocol EqualWidthInteger {
	associatedtype Signed: SignedInteger
	associatedtype Unsigned: UnsignedInteger
}

extension Int : EqualWidthInteger {
	public typealias Signed = Int
	public typealias Unsigned = UInt
}

extension Int8 : EqualWidthInteger {
	public typealias Signed = Int8
	public typealias Unsigned = UInt8
}

extension Int16 : EqualWidthInteger {
	public typealias Signed = Int16
	public typealias Unsigned = UInt16
}

extension Int32 : EqualWidthInteger {
	public typealias Signed = Int32
	public typealias Unsigned = UInt32
}

extension Int64 : EqualWidthInteger {
	public typealias Signed = Int64
	public typealias Unsigned = UInt64
}

extension UInt : EqualWidthInteger {
	public typealias Signed = Int
	public typealias Unsigned = UInt
}

extension UInt8 : EqualWidthInteger {
	public typealias Signed = Int8
	public typealias Unsigned = UInt8
}

extension UInt16 : EqualWidthInteger {
	public typealias Signed = Int16
	public typealias Unsigned = UInt16
}

extension UInt32 : EqualWidthInteger {
	public typealias Signed = Int32
	public typealias Unsigned = UInt32
}

extension UInt64 : EqualWidthInteger {
	public typealias Signed = Int64
	public typealias Unsigned = UInt64
}
