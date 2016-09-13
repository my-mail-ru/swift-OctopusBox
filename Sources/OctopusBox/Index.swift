import BinaryEncoding

public class Index<Tuple : TupleProtocol, Key> {
	let number: UInt32
	let extractKey: (Tuple) -> Key

	init(number: UInt32, extractKey: @escaping (Tuple) -> Key) {
		self.number = number
		self.extractKey = extractKey
	}
}

public final class UniqIndex<Tuple : TupleProtocol, Key> : Index<Tuple, Key> {}
public final class NonUniqIndex<Tuple : TupleProtocol, Key> : Index<Tuple, Key> {}

public extension TupleProtocol {
	static func uniqIndex<K : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> K) -> UniqIndex<Self, K> {
		return UniqIndex(number: number, extractKey: body)
	}

	static func uniqIndex<K0 : Field, K1 : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> (K0, K1)) -> UniqIndex<Self, (K0, K1)> {
		return UniqIndex(number: number, extractKey: body)
	}

	static func uniqIndex<K0 : Field, K1 : Field, K2 : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> (K0, K1, K2)) -> UniqIndex<Self, (K0, K1, K2)> {
		return UniqIndex(number: number, extractKey: body)
	}

	static func index<K : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> K) -> NonUniqIndex<Self, K> {
		return NonUniqIndex(number: number, extractKey: body)
	}

	static func index<K0 : Field, K1 : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> (K0, K1)) -> NonUniqIndex<Self, (K0, K1)> {
		return NonUniqIndex(number: number, extractKey: body)
	}

	static func index<K0 : Field, K1 : Field, K2 : Field>(_ number: UInt32, uniq: Bool = true, _ body: @escaping (Self) -> (K0, K1, K2)) -> NonUniqIndex<Self, (K0, K1, K2)> {
		return NonUniqIndex(number: number, extractKey: body)
	}
}

extension BinaryEncodedData {
	mutating func append<K>(key: K) {
		switch key {
			case let k as Field:
				append(1, as: UInt32.self)
				append(field: k)
			case let k as (Field, Field):
				append(2, as: UInt32.self)
				append(field: k.0)
				append(field: k.1)
			case let k as (Field, Field, Field):
				append(3, as: UInt32.self)
				append(field: k.0)
				append(field: k.1)
				append(field: k.2)
			default:
				preconditionFailure("Unsupported index")
		}
	}

	mutating func append<T : TupleProtocol, K>(key: Index<T, K>, from tuple: T) {
		append(key: key.extractKey(tuple))
	}
}
