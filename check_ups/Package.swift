// swift-tools-version:6.0
import PackageDescription


let package = Package(
    name: "check_ups",
    dependencies: [
    	.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
    ],
    targets: [
    	.executableTarget(
        	name: "check_ups",
                dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]),
    ]
)