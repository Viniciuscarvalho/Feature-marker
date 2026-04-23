public struct SampleApp {
    public init() {}

    public func run() {
        let greeter = Greeter(name: "World")
        print(greeter.greet())
    }
}

public struct Greeter {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public func greet() -> String {
        return "Hello, \(name)!"
    }
}

public protocol Runnable {
    func run()
}

public typealias AppRunner = SampleApp
