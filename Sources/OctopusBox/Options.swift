import IProto

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
