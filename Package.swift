// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "phoneme-synthesizer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PhonemeSynthesizer", targets: ["PhonemeSynthesizer"]),
        .executable(name: "phoneme-synth", targets: ["PhonemeSynthCLI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "5c19d5e12320e22bbfb7a1877b089d2665a69add"
        ),
    ],
    targets: [
        .target(
            name: "PhonemeSynthesizer",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .executableTarget(
            name: "PhonemeSynthCLI",
            dependencies: ["PhonemeSynthesizer", .product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .testTarget(
            name: "PhonemeSynthesizerTests",
            dependencies: ["PhonemeSynthesizer"]
        ),
    ]
)
