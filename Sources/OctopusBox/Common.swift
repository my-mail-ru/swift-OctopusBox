import IProto
import BinaryEncoding

enum MessageType : Int32 {
	case insert = 13
	case select = 17
	case update = 19
	case delete = 21
	case execLua = 22
}

struct Flags {
	static let wantResult: UInt32 = 0x1
}

public enum InsertAction : UInt32 {
	case set = 0x0
	case add = 0x2
	case replace = 0x4
}

public protocol Sharded {}

public struct StorageInfo {
	public let from: Message.Response.From
	public internal(set) var shard: Int = 0
}

public enum OctopusBoxError : Error {
	case errcodeOmitted(message: Message)
	case invalidFieldSize(is: Int, must: Int)
	case notSingleTuple(count: Int)
	case invalidTuple(tuple: BinaryEncodedData, field: (no: Int, name: String), error: Error)
}
