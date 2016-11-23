import PackageDescription

let package = Package(
	name: "OctopusBox",
	dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swift-BinaryEncoding.git", majorVersion: 0),
		.Package(url: "https://github.com/my-mail-ru/swift-IProto.git", majorVersion: 0),
		.Package(url: "https://github.com/my-mail-ru/swift-Octopus.git", majorVersion: 0),
	]
)
