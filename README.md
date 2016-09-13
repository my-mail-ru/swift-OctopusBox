# OctopusBox

![Swift: 3.0](https://img.shields.io/badge/Swift-3.0-orange.svg)
![OS: Linux](https://img.shields.io/badge/OS-Linux-brightgreen.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

This package contains client for
[Octopus/box](https://github.com/delamonpansie/octopus/tree/mod_box)
in-memory key/value storage.
The client implements active record pattern and supports
automagical encoding/decoding of tuples into structs using
reflection.

## Usage

```swift
import IProto
import OctopusBox

final class MyData : RecordProtocol {
	static let cluster = Cluster(shards: [Shard(masters: [Server(host: "127.0.0.1", port: 33700)])])
	static let namespace = 42

	typealias PrimaryKey = Int32
	static let primaryKey = Tuple.uniqIndex(0) { $0.id }

	struct Tuple : TupleProtocol {
		var id: Int32 = 0
		var one: UInt32 = 0
		var two: UInt8 = 0
		var name: String = ""
		var raw = BinaryEncodedData()
		var quad: UInt64 = 0
	}

	var tuple: Tuple
	var storageInfo: StorageInfo?

	init(tuple: Tuple, storageInfo: StorageInfo) {
		self.tuple = tuple
		self.storageInfo = storageInfo
	}

	static func select(id: Int32) throws -> MyData? {
		return try select(index: primaryKey, key: id)
	}

	static func select(id: [Int32]) throws -> [MyData] {
		return try select(index: primaryKey, keys: id)
	}
}

func test() throws {
	var data = Include(id: 100500, name: "Василий")
	try data.insert()

	data = try Include.select(id: 100500)

	try data.update([data.tuple.field(&data.tuple.quad).set(10)])

	try data.delete()
}
```

See [tests](Tests/OctopusBoxTests/OctopusBoxTests.swift)
for more information about provided API.
