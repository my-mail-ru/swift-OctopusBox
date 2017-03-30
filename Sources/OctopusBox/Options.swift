import BinaryEncoding
import IProto
import var CIProto.TEMPORARY_ERR_CODE_FLAG

public struct OverridenOptions {
	public var from: Message.Options.From?

	public struct Retry {
		public var early: Bool?
		public var safe: Bool?
		public var same: Bool?
		public var maxTries: Int?
		public init() {}
	}
	public var retry: Retry?

	public var timeout: Double?
	public var earlyTimeout: Double?

	public init() {}

	public init(from: Message.Options.From? = nil, retry: Retry? = nil, timeout: Double? = nil, earlyTimeout: Double? = nil) {
		self.from = from
		self.retry = retry
		self.timeout = timeout
		self.earlyTimeout = earlyTimeout
	}

	public func apply(to options: Message.Options) {
		if let from = from {
			options.from = from
		}
		if let retry = retry {
			options.retry.toggle(.early, retry.early)
			options.retry.toggle(.safe, retry.safe)
			options.retry.toggle(.same, retry.same)
			if let n = retry.maxTries {
				options.maxTries = n
			}
		}
		if let timeout = timeout {
			options.timeout = timeout
		}
		if let earlyTimeout = earlyTimeout {
			options.earlyTimeout = earlyTimeout
		}
	}
}

private extension Message.Options.Retry {
	mutating func toggle(_ member: Element, _ on: Bool?) {
		guard let on = on else { return }
		if on {
			insert(member)
		} else {
			remove(member)
		}
	}
}

extension Message {
	convenience init(cluster: Cluster, type: MessageType, data: BinaryEncodedData) {
		self.init(cluster: cluster, code: type.rawValue, data: data)
		options.from = type == .select ? .masterThenReplica : .master
		options.retry.toggle(.safe, type == .update)
		switch type {
			case .select:
				options.timeout = 0.2
			case .execLua:
				options.timeout = 0.5
			default:
				options.timeout = 23
				options.softRetryDelay = (min: 0.5, max: 1.5)
		}
		options.softRetryCallback = { message in
			switch message.response {
				case .ok(let response):
					return response.withUnsafeBytes {
						guard $0.count > 0 else { return false }
						var reader = $0.reader()
						guard let errcode = try? reader.read(UInt32.self) else { return false }
						return errcode & UInt32(bitPattern: TEMPORARY_ERR_CODE_FLAG) != 0
					}
				case .error:
					return false
			}
		}
	}
}
