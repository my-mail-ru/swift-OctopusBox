import XCTest
import IProto
import OctopusBox

class OctopusBoxTests : XCTestCase {
	static var allTests: [(String, (OctopusBoxTests) -> () throws -> Void)] {
		return [
			("testInplace", testInplace),
			("testInclude", testInclude),
			("testIncludeShards", testIncludeShards),
		]
	}

	func testInplace() throws {
		var data = Inplace(id: 1999999996, name: "Василий")
		try data.insert()
		XCTAssertEqual(data.storageInfo?.from, .master)

		let exists = try Inplace.select(id: 1999999996)
		XCTAssertEqual(exists?.name, "Василий")

		try data.update([data.field(&data.checkUp).set(10)])

		let check = try Inplace.select(id: 1999999996)
		XCTAssertEqual(check?.checkUp, 10)

		try data.delete()
		print("data: \(data)")

		let notExists = try Inplace.select(id: 1999999996)
		XCTAssertNil(notExists)
	}

	func testInclude() throws {
		var data = Include(id: 1999999996, name: "Василий")
		try data.insert()
		XCTAssertEqual(data.storageInfo?.from, .master)

		let exists = try Include.select(id: 1999999996)
		XCTAssertEqual(exists?.tuple.name, "Василий")

		try data.update([data.tuple.field(&data.tuple.checkUp).set(10)])

		let check = try Include.select(id: 1999999996)
		XCTAssertEqual(check?.tuple.checkUp, 10)

		try data.delete()
		print("data: \(data)")

		let notExists = try Include.select(id: 1999999996)
		XCTAssertNil(notExists)
	}

	func testIncludeShards() throws {
		var data = IncludeShards(id: 1999999996, name: "Василий")
		try data.insert(shard: 3)
		XCTAssertEqual(data.storageInfo?.from, .master)

		let exists = try IncludeShards.select(shard: 3, id: 1999999996)
		XCTAssertEqual(exists?.tuple.name, "Василий")

		try data.update([data.tuple.field(&data.tuple.checkUp).set(10)])

		let check = try IncludeShards.select(shard: 3, id: 1999999996)
		XCTAssertEqual(check?.tuple.checkUp, 10)

		try data.delete()
		print("data: \(data)")

		let notExists = try IncludeShards.select(shard: 3, id: 1999999996)
		XCTAssertNil(notExists)
	}
}

final class Inplace : RecordProtocol, TupleProtocol {
	static let cluster = Cluster(shards: [Shard(masters: [Server(host: "127.0.0.1", port: 33700)])])
	static let namespace = 22

	typealias PrimaryKey = Int32
	static let primaryKey = Inplace.uniqIndex(0) { $0.id }
	static let dupleKey = Inplace.index(1) { (one: $0.one, two: $0.two) }

	var id: Int32 = 0
	var one: UInt32 = 0
	var two: UInt32 = 0
	var checkUp: Int32 = 0
	var int2: Int32 = 0
	var name: String = ""

	var storageInfo: StorageInfo?

	init() {}

	init(id: Int32, name: String) {
		self.id = id
		self.name = name
	}

	static func select(id: Int32) throws -> Inplace? {
		return try select(index: primaryKey, key: id)
	}

	static func select(duple: (one: UInt32, two: UInt32)) throws -> [Inplace] {
		return try select(index: dupleKey, key: (duple.one, duple.two))
	}
}

final class Include : RecordProtocol {
	static let cluster = Cluster(shards: [Shard(masters: [Server(host: "127.0.0.1", port: 33700)])])
	static let namespace = 22

	typealias PrimaryKey = Int32
	static let primaryKey = Tuple.uniqIndex(0) { $0.id }
	static let dupleKey = Tuple.index(1) { (one: $0.one, two: $0.two) }

	struct Tuple : TupleProtocol {
		var id: Int32 = 0
		var one: UInt32 = 0
		var two: UInt32 = 0
		var checkUp: Int32 = 0
		var int2: Int32 = 0
		var name: String = ""
	}

	var tuple: Tuple
	var storageInfo: StorageInfo?

	init(tuple: Tuple, storageInfo: StorageInfo) {
		self.tuple = tuple
		self.storageInfo = storageInfo
	}

	init(id: Int32, name: String) {
		tuple = Tuple()
		tuple.id = id
		tuple.name = name
	}

	static func select(id: Int32) throws -> Include? {
		return try select(index: primaryKey, key: id)
	}

	static func select(duple: (one: UInt32, two: UInt32)) throws -> [Include] {
		return try select(index: dupleKey, key: (duple.one, duple.two))
	}
}

final class IncludeShards : RecordProtocol, Sharded {
	static let shardCount = 8
	static let cluster = Cluster(shards: (1...shardCount).map { _ in Shard(masters: [Server(host: "127.0.0.1", port: 33700)]) })
	static let namespace = 22

	typealias PrimaryKey = Int32
	static let primaryKey = Tuple.uniqIndex(0) { $0.id }
	static let dupleKey = Tuple.index(1) { (one: $0.one, two: $0.two) }

	struct Tuple : TupleProtocol {
		var id: Int32 = 0
		var one: UInt32 = 0
		var two: UInt32 = 0
		var checkUp: Int32 = 0
		var int2: Int32 = 0
		var name: String = ""
	}

	var tuple: Tuple
	var storageInfo: StorageInfo?

	init(tuple: Tuple, storageInfo: StorageInfo) {
		self.tuple = tuple
		self.storageInfo = storageInfo
	}

	init(id: Int32, name: String) {
		tuple = Tuple()
		tuple.id = id
		tuple.name = name
	}

	static func select(shard: Int, id: Int32) throws -> IncludeShards? {
		return try select(shard: shard, index: primaryKey, key: id)
	}

	static func select(shard: Int, duple: (one: UInt32, two: UInt32)) throws -> [IncludeShards] {
		return try select(shard: shard, index: dupleKey, key: (duple.one, duple.two))
	}
}
