import PackageDescription

let package = Package(
	name: "OctopusBox",
	dependencies: [
		.Package(url: "https://github.com/my-mail-ru/swift-BinaryEncoding.git", versions: Version(0, 2, 0)..<Version(0, .max, .max)),
		.Package(url: "https://github.com/my-mail-ru/swift-IProto.git", versions: Version(0, 1, 6)..<Version(0, .max, .max)),
		.Package(url: "https://github.com/my-mail-ru/swift-Octopus.git", majorVersion: 0),
	]
)
