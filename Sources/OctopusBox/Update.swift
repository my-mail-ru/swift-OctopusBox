import BinaryEncoding
import IProto

public extension RecordProtocol {
	mutating func updateRequest(_ ops: [UpdateOperation<Tuple>], wantResult: Bool = false) -> Message {
		var flags: UInt32 = 0
		if wantResult {
			flags |= Flags.wantResult
		}
		var data = BinaryEncodedData(minimumCapacity: 3 * MemoryLayout<UInt32>.size)
		data.append(UInt32(Self.namespace), as: UInt32.self)
		data.append(flags, as: UInt32.self)
		data.append(key: Self.primaryKey, from: tuple)
		data.append(UInt32(ops.count), as: UInt32.self)
		for op in ops {
			data.append(op)
		}
		let message = Message(cluster: Self.cluster, code: MessageType.update.rawValue, data: data)
		if self is Sharded {
			message.options.shard = storageInfo!.shard
		}
		return message
	}

	mutating func update(_ ops: [UpdateOperation<Tuple>]) throws {
		let message = updateRequest(ops)
		exchange(message: message)
		_ = try Self.processResponse(of: message, wantResult: false)
	}
}

public struct FieldNumber<Value : Field, Tuple : TupleProtocol> {
	let number: Int

	init(_ n: Int) {
		number = n
	}

	public func set(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .set(value))
	}

	public func delete() -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .delete)
	}

	public func insert(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .insert(value))
	}
}

public extension FieldNumber where Value : Integer {
	func add(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .add(value))
	}

	func and(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .and(value))
	}

	func xor(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .xor(value))
	}

	func or(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .or(value))
	}

	func setBit(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .or(value))
	}

	func clearBit(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .and(~value))
	}
}

public extension FieldNumber where Value : SignedInteger {
	func sub(_ value: Value) -> UpdateOperation<Tuple> {
		return UpdateOperation(field: number, op: .add(-value))
	}
}

enum UpdateOp {
	case set(Field)
	case add(Field)
	case and(Field)
	case xor(Field)
	case or(Field)
	case splice(Int, Int, Field)
	case delete
	case insert(Field)

	var rawValue: UInt8 {
		switch self {
			case .set: return 0
			case .add: return 1
			case .and: return 2
			case .xor: return 3
			case .or: return 4
			case .splice: return 5
			case .delete: return 6
			case .insert: return 7
		}
	}
}

public struct UpdateOperation<Tuple : TupleProtocol> {
	let field: Int
	let op: UpdateOp
}

extension BinaryEncodedData {
	mutating func append<T : TupleProtocol>(_ op: UpdateOperation<T>) {
		append(UInt32(op.field), as: UInt32.self)
		append(op.op)
	}

	mutating func append(_ op: UpdateOp) {
		append(op.rawValue, as: UInt8.self)
		switch op {
			case .set(let v):
				append(field: v)
			case .add(let v):
				append(field: v)
			case .and(let v):
				append(field: v)
			case .xor(let v):
				append(field: v)
			case .or(let v):
				append(field: v)
			case .splice(let offset, let length, let value):
				append(Int32(offset), as: Int32.self)
				append(Int32(length), as: Int32.self)
				append(field: value)
			case .delete:
				break
			case .insert(let v):
				append(field: v)
		}
	}
}