import IProto
import Octopus
import BinaryEncoding

public protocol Record {
	associatedtype Tuple : TupleProtocol
	associatedtype PrimaryKey
	static var namespace: Int { get }
	static var cluster: Cluster { get }
	static var primaryKey: UniqIndex<Tuple, PrimaryKey> { get }
	var tuple: Tuple { get }
	var storageInfo: StorageInfo? { get set }
	init(tuple: Tuple, storageInfo: StorageInfo)
}

public protocol MutableRecord : Record {
	var tuple: Tuple { get set }
}

@available(*, deprecated, message: "Use 'Record' or 'MutableRecord' instead")
public typealias RecordProtocol = MutableRecord

public extension Record where Tuple == Self {
	var tuple: Tuple {
		get { return self }
	}

	init(tuple: Tuple, storageInfo: StorageInfo) {
		self = tuple
		self.storageInfo = storageInfo
	}
}

public extension MutableRecord where Tuple == Self {
	var tuple: Tuple {
		get { return self }
		set { }
	}
}

public extension Record {
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
		let message = Message(cluster: cluster, type: MessageType.select, data: data)
		message.options.shard = shard
		return message
	}

	static func select<Key>(shard: Int = 0, index: Index<Tuple, Key>, keys: [Key], offset: UInt32 = 0, limit: UInt32 = UInt32.max, options: OverridenOptions? = nil) throws -> [Self] {
		guard !keys.isEmpty else { return [] }
		let message = try selectRequest(shard: shard, index: index, keys: keys, offset: offset, limit: limit)
		options?.apply(to: message.options)
		exchange(message: message)
		return try processResponse(of: message)
	}

	static func select<Key>(shard: Int = 0, index: UniqIndex<Tuple, Key>, key: Key, offset: UInt32 = 0, limit: UInt32 = UInt32.max, options: OverridenOptions? = nil) throws -> Self? {
		let result = try select(shard: shard, index: index, keys: [key], offset: offset, limit: limit, options: options)
		guard result.count == 1 else {
			if result.count == 0 {
				return nil
			}
			throw OctopusBoxError.notSingleTuple(count: result.count)
		}
		return result[0]
	}

	static func select<Key>(shard: Int = 0, index: NonUniqIndex<Tuple, Key>, key: Key, offset: UInt32 = 0, limit: UInt32 = UInt32.max, options: OverridenOptions? = nil) throws -> [Self] {
		return try select(shard: shard, index: index, keys: [key], offset: offset, limit: limit, options: options)
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

	static func select<Key>(index: Index<Tuple, Key>, keys: [(shard: Int, key: Key)], options: OverridenOptions? = nil) throws -> [Self] {
		guard !keys.isEmpty else { return [] }
		let messages = try selectRequests(index: index, keys: keys)
		if let options = options {
			for message in messages {
				options.apply(to: message.options)
			}
		}
		exchange(messages: messages)
		var result = [Self]()
		for message in messages {
			let singleResult = try processResponse(of: message)
			result.append(contentsOf: singleResult)
		}
		return result
	}
}

public extension MutableRecord {
	func insertRequest(shard: Int = 0, action: InsertAction = .set, wantResult: Bool = false) -> Message {
		var flags: UInt32 = action.rawValue
		if wantResult {
			flags |= Flags.wantResult
		}
		var data = BinaryEncodedData(minimumCapacity: 2 * MemoryLayout<UInt32>.size)
		data.append(UInt32(Self.namespace), as: UInt32.self)
		data.append(flags, as: UInt32.self)
		data.append(tuple: tuple)
		let message = Message(cluster: Self.cluster, type: MessageType.insert, data: data)
		if self is Sharded {
			if shard != 0 {
				message.options.shard = shard
			} else if let si = storageInfo {
				message.options.shard = si.shard
			}
		}
		return message
	}

	mutating func insert(shard: Int = 0, action: InsertAction = .set, wantResult: Bool = false, options: OverridenOptions? = nil) throws {
		let message = insertRequest(shard: shard, action: action, wantResult: wantResult)
		options?.apply(to: message.options)
		exchange(message: message)
		if wantResult {
			try processResponse(of: message, wantResult: true)
		} else {
			_ = try Self.processResponse(of: message) { _, _, storageInfo in
				self.storageInfo = storageInfo
				return []
			}
		}
	}
}

public extension MutableRecord {
	static func deleteRequest(shard: Int = 0, key: PrimaryKey, wantResult: Bool = false) -> Message {
		var flags: UInt32 = 0
		if wantResult {
			flags |= Flags.wantResult
		}
		var data = BinaryEncodedData(minimumCapacity: 2 * MemoryLayout<UInt32>.size)
		data.append(UInt32(Self.namespace), as: UInt32.self)
		data.append(flags, as: UInt32.self)
		data.append(key: key)
		let message = Message(cluster: Self.cluster, type: MessageType.delete, data: data)
		if self is Sharded.Type {
			message.options.shard = shard
		}
		return message
	}

	func deleteRequest(wantResult: Bool = false) -> Message {
		return Self.deleteRequest(shard: storageInfo?.shard ?? 0, key: Self.primaryKey.extractKey(tuple), wantResult: wantResult)
	}

	mutating func delete(wantResult: Bool = false, options: OverridenOptions? = nil) throws {
		let message = deleteRequest(wantResult: wantResult)
		options?.apply(to: message.options)
		exchange(message: message)
		try processResponse(of: message, wantResult: wantResult)
		storageInfo = nil
	}
}

public extension Record {
	fileprivate static func processResponse(of message: Message, wantResult: (inout UnsafeRawBufferPointer.Reader, Int32, StorageInfo) throws -> [Self]) throws -> [Self] {
		switch message.response {
			case .ok(let response):
				return try response.withUnsafeBytes {
					guard $0.count > 0 else {
						throw OctopusBoxError.errcodeOmitted(message: message)
					}
					var reader = $0.reader()
					let errcode = try reader.read(UInt32.self)
					guard errcode == 0 else {
						let message = try reader.read(String.self, withSize: reader.count)
						throw OctopusError(rawValue: errcode, description: message)
					}
					return try wantResult(&reader, message.code, StorageInfo(from: response.from, shard: message.options.shard))
				}
			case .error(let error): throw error
		}
	}

	static func processResponse(of message: Message, wantResult: Bool = true) throws -> [Self] {
		return try processResponse(of: message, wantResult: wantResult ? { reader, code, storageInfo in
			let count = Int(try reader.read(UInt32.self))
			var result = [Self]()
			result.reserveCapacity(count)
			for _ in (0..<count) {
				let tuple = try reader.read(UnsafeTuple.self)
				result.append(try Self(tuple: Tuple(fromUnsafe: tuple), storageInfo: storageInfo))
				if message.code == MessageType.insert.rawValue { break } // For insert count of touched tuples returned instead of cardinality
			}
			return result
		} : { _, _, _ in [] })
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

public extension MutableRecord {
	mutating func processResponse(of message: Message, wantResult: Bool = true) throws {
		if wantResult {
			_ = try Self.processResponse(of: message) { reader, code, storageInfo in
				let count = Int(try reader.read(UInt32.self))
				if count > 0 {
					let tuple = try reader.read(UnsafeTuple.self)
					try self.tuple.syncFields(fromUnsafe: tuple)
					self.storageInfo = storageInfo
				}
				return [Self]()
			}
		} else {
			_ = try Self.processResponse(of: message) { _, _, _ in [] }
		}
	}
}
