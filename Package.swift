import PackageDescription

let package = Package(
	name: "OctopusBox",
	dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swift-BinaryEncoding", majorVersion: 0),
		.Package(url: "https://github.com/my-mail-ru/swift-IProto", majorVersion: 0),
		.Package(url: "https://github.com/my-mail-ru/swift-Octopus", majorVersion: 0),
	]
)
