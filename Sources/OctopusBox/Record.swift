import IProto
import Octopus
import BinaryEncoding

public protocol RecordProtocol {
	associatedtype Tuple : TupleProtocol
	associatedtype PrimaryKey
	static var namespace: Int { get }
	static var cluster: Cluster { get }
	static var primaryKey: UniqIndex<Tuple, PrimaryKey> { get }
	var tuple: Tuple { get }
	var storageInfo: StorageInfo? { get set }
	init(tuple: Tuple, storageInfo: StorageInfo)
}

public extension RecordProtocol where Tuple == Self {
	var tuple: Tuple {
		get { return self }
	}

	init(tuple: Tuple, storageInfo: StorageInfo) {
		self = tuple
		self.storageInfo = storageInfo
	}
}

public extension RecordProtocol {
	static func selectRequest<Key>(shard: Int = 0, index: Index<Tuple, Key>, keys: [Key], offset: UInt32 = 0, limit: UInt32 = UInt32.max) throws -> Message {
		let headerSize = 5 * MemoryLayout<UInt32>.size
		let approximateKeysSize = keys.count * (MemoryLayout<UInt32>.size + 1 + MemoryLayout<Key>.size)
		var data = BinaryEncodedData(minimumCapacity: headerSize + approximateKeysSize)
		data.append(UInt32(namespace), as: UInt32.self)
		data.append(index.number, as: UInt32.self)
		data.append(offset, as: UInt32.self)
		data.append(limit, as: UInt32.self)
		data.append(UInt32(keys.count), as: UInt32.self)
		for key in keys {
			data.append(key: key)
		}
		let message = Message(cluster: cluster, code: MessageType.select.rawValue, data: data)
		message.options.shard = shard
		return message
	}

	static func select<Key>(shard: Int = 0, index: Index<Tuple, Key>, keys: [Key], offset: UInt32 = 0, limit: UInt32 = UInt32.max) throws -> [Self] {
		let message = try selectRequest(shard: shard, index: index, keys: keys, offset: offset, limit: limit)
		exchange(message: message)
		return try processResponse(of: message)
	}

	static func select<Key>(shard: Int = 0, index: UniqIndex<Tuple, Key>, key: Key, offset: UInt32 = 0, limit: UInt32 = UInt32.max) throws -> Self? {
		let result = try select(shard: shard, index: index, keys: [key], offset: offset, limit: limit)
		guard result.count == 1 else {
			if result.count == 0 {
				return nil
			}
			throw OctopusBoxError.notSingleTuple(result.count)
		}
		return result[0]
	}

	static func select<Key>(shard: Int = 0, index: NonUniqIndex<Tuple, Key>, key: Key, offset: UInt32 = 0, limit: UInt32 = UInt32.max) throws -> [Self] {
		return try select(shard: shard, index: index, keys: [key], offset: offset, limit: limit)
	}

	static func selectRequests<Key>(index: Index<Tuple, Key>, keys: [(shard: Int, key: Key)]) throws -> [Message] {
		var byShard = [Int : [Key]]()
		for k in keys {
			byShard[k.shard]?.append(k.key) ?? (byShard[k.shard] = [k.key])
		}
		var messages = [Message]()
		messages.reserveCapacity(byShard.count)
		for (shard, keys) in byShard {
			messages.append(try selectRequest(shard: shard, index: index, keys: keys))
		}
		return messages
	}

	static func select<Key>(index: Index<Tuple, Key>, keys: [(shard: Int, key: Key)]) throws -> [Self] {
		let messages = try selectRequests(index: index, keys: keys)
		exchange(messages: messages)
		var result = [Self]()
		for message in messages {
			let singleResult = try processResponse(of: message)
			result.append(contentsOf: singleResult)
		}
		return result
	}
}

public extension RecordProtocol {
	func insertRequest(shard: Int = 0, action: InsertAction = .set, wantResult: Bool = false) -> Message {
		var flags: UInt32 = action.rawValue
		if wantResult {
			flags |= Flags.wantResult
		}
		var data = BinaryEncodedData(minimumCapacity: 2 * MemoryLayout<UInt32>.size)
		data.append(UInt32(Self.namespace), as: UInt32.self)
		data.append(flags, as: UInt32.self)
		data.append(tuple: tuple)
		let message = Message(cluster: Self.cluster, code: MessageType.insert.rawValue, data: data)
		if self is Sharded {
			if shard != 0 {
				message.options.shard = shard
			} else if let si = storageInfo {
				message.options.shard = si.shard
			}
		}
		return message
	}

	mutating func insert(shard: Int = 0, action: InsertAction = .set) throws {
		let message = insertRequest(shard: shard, action: action, wantResult: true)
		exchange(message: message)
		let result = try Self.processResponse(of: message, wantResult: true)
		guard result.count == 1 else {
			throw OctopusBoxError.notSingleTuple(result.count)
		}
		self = result[0]
	}
}

public extension RecordProtocol {
	static func deleteRequest(shard: Int = 0, key: PrimaryKey, wantResult: Bool = false) -> Message {
		var flags: UInt32 = 0
		if wantResult {
			flags |= Flags.wantResult
		}
		var data = BinaryEncodedData(minimumCapacity: 2 * MemoryLayout<UInt32>.size)
		data.append(UInt32(Self.namespace), as: UInt32.self)
		data.append(flags, as: UInt32.self)
		data.append(key: key)
		let message = Message(cluster: Self.cluster, code: MessageType.delete.rawValue, data: data)
		if self is Sharded.Type {
			message.options.shard = shard
		}
		return message
	}

	func deleteRequest(wantResult: Bool = false) -> Message {
		return Self.deleteRequest(shard: storageInfo?.shard ?? 0, key: Self.primaryKey.extractKey(tuple), wantResult: wantResult)
	}

	mutating func delete() throws {
		let message = deleteRequest()
		exchange(message: message)
		_ = try Self.processResponse(of: message, wantResult: false)
		storageInfo = nil
	}
}

public extension RecordProtocol {
	static func processResponse(of message: Message, wantResult: Bool = true) throws -> [Self] {
		switch message.response {
			case .ok(let response):
				return try response.withUnsafeBufferRawPointer {
					var reader = $0.reader()
					let errcode = try reader.read(UInt32.self)
					guard errcode == 0 else {
						let message = try reader.read(String.self, withSize: reader.count)
						throw OctopusError(rawValue: errcode, description: message)
					}
					let storageInfo = StorageInfo(from: response.from, shard: message.options.shard)
					var result = [Self]()
					if wantResult {
						let count = Int(try reader.read(UInt32.self))
						result.reserveCapacity(count)
						for _ in (0..<count) {
							let tuple = try reader.read(UnsafeTuple.self)
							result.append(try Self(tuple: Tuple(fromUnsafe: tuple), storageInfo: storageInfo))
							if message.code == MessageType.insert.rawValue { break } // For insert count of touched tuples returned instead of cardinality
						}
					}
					return result
				}
			case .error(let error): throw error
		}
	}

	static func processResponses(of messages: [Message], wantResult: Bool = true) throws -> [Self] {
		var result: [Self] = []
		for message in messages {
			result.append(contentsOf: try processResponse(of: message, wantResult: wantResult))
		}
		return result
	}

	static func processResponses<Key>(of messages: [Message], groupBy: UniqIndex<Tuple, Key>, wantResult: Bool = true) throws -> [Key : Self] {
		let records = try processResponses(of: messages, wantResult: wantResult)
		var result = [Key: Self](minimumCapacity: records.count)
		for record in records {
			result[groupBy.extractKey(record.tuple)] = record
		}
		return result
	}
}
