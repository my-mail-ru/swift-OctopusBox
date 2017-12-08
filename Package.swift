// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "OctopusBox",
	products: [
		.library(name: "OctopusBox", targets: ["OctopusBox"]),
	],
	dependencies: [
		.package(url: "https://github.com/my-mail-ru/swift-BinaryEncoding.git", from: "0.2.1"),
		.package(url: "https://github.com/my-mail-ru/swift-IProto.git", from: "0.1.8"),
		.package(url: "https://github.com/my-mail-ru/swift-Octopus.git", from: "0.1.4"),
	],
	targets: [
		.target(name: "OctopusBox", dependencies: ["IProto", "Octopus", "BinaryEncoding"]),
		.testTarget(name: "OctopusBoxTests", dependencies: ["OctopusBox"]),
	]
)
