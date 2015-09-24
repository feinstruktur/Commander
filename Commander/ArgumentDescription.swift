public enum ArgumentType {
  case Argument
  case Option
}

public protocol ArgumentDescriptor {
  typealias ValueType

  /// The arguments name
  var name:String { get }

  /// The arguments description
  var description:String? { get }

  var type:ArgumentType { get }

  /// Parse the argument
  func parse(parser:ArgumentParser) throws -> ValueType
}

extension ArgumentConvertible {
  init(string: String) throws {
    try self.init(parser: ArgumentParser(arguments: [string]))
  }
}

public class Argument<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = T

  public let name:String
  public let description:String?

  public var type:ArgumentType { return .Argument }

  public init(_ name:String, description:String? = nil) {
    self.name = name
    self.description = description
  }

  public func parse(parser:ArgumentParser) throws -> ValueType {
    return try T(parser: parser)
  }
}


public class Option<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = T

  public let name:String
  public let description:String?
  public let `default`:ValueType
  public var type:ArgumentType { return .Option }

  public init(_ name:String, _ `default`:ValueType, description:String? = nil) {
    self.name = name
    self.description = description
    self.`default` = `default`
  }

  public func parse(parser:ArgumentParser) throws -> ValueType {
    if let value = try parser.shiftValueForOption(name) {
      return try T(string: value)
    }

    return `default`
  }
}

public class Options<T : ArgumentConvertible> : ArgumentDescriptor {
  public typealias ValueType = [T]

  public let name:String
  public let description:String?
  public let count:Int
  public let `default`:ValueType
  public var type:ArgumentType { return .Option }

  public init(_ name:String, _ `default`:ValueType, count: Int, description:String? = nil) {
    self.name = name
    self.`default` = `default`
    self.count = count
    self.description = description
  }

  public func parse(parser:ArgumentParser) throws -> ValueType {
    let values = try parser.shiftValuesForOption(name, count: count)
    return try values?.map { try T(string: $0) } ?? `default`
  }
}

public class Flag : ArgumentDescriptor {
  public typealias ValueType = Bool

  public let name:String
  public let flag:Character?
  public let description:String?
  public let `default`:ValueType
  public var type:ArgumentType { return .Option }

  public init(_ name:String, flag:Character? = nil, description:String? = nil, `default`:Bool = false) {
    self.name = name
    self.flag = flag
    self.description = description
    self.`default` = `default`
  }

  public func parse(parser:ArgumentParser) throws -> ValueType {
    if parser.hasOption("no-\(name)") {
      return false
    }

    if parser.hasOption(name) {
      return true
    }

    if let flag = flag {
      if parser.hasFlag(flag) {
        return true
      }
    }

    return `default`
  }
}

class BoxedArgumentDescriptor {
  let name:String
  let description:String?
  let `default`:String?
  let type:ArgumentType

  init<T : ArgumentDescriptor>(value:T) {
    name = value.name
    description = value.description
    type = value.type

    if let value = value as? Flag {
      `default` = value.`default`.description
    } else {
      // TODO, default for Option and Options
      `default` = nil
    }
  }
}

class Help : ErrorType, CustomStringConvertible {
  let command:String?
  let group:Group?
  let descriptors:[BoxedArgumentDescriptor]

  init(_ descriptors:[BoxedArgumentDescriptor], command:String? = nil, group:Group? = nil) {
    self.command = command
    self.group = group
    self.descriptors = descriptors
  }

  func reraise(command:String? = nil) -> Help {
    if let oldCommand = self.command, newCommand = command {
      return Help(descriptors, command: "\(newCommand) \(oldCommand)")
    }
    return Help(descriptors, command: command ?? self.command)
  }

  var description:String {
    var output = [String]()

    let arguments = descriptors.filter { $0.type == ArgumentType.Argument }
    let options = descriptors.filter   { $0.type == ArgumentType.Option }

    if let command = command {
      let args = arguments.map { $0.name }
      let usage = ([command] + args).joinWithSeparator(" ")

      output.append("Usage:")
      output.append("")
      output.append("    \(usage)")
      output.append("")
    }

    if let group = group {
      output.append("Commands:")
      output.append("")
      for (name, _) in group.commands {
        output.append("    + \(name)")
      }
      output.append("")
    }

    if !options.isEmpty {
      output.append("Options:")
      for option in options {
        // TODO: default, [default: `\(`default`)`]

        if let description = option.description {
          output.append("    --\(option.name) - \(description)")
        } else {
          output.append("    --\(option.name)")
        }
      }
    }

    return output.joinWithSeparator("\n")
  }
}


public func command<A : ArgumentDescriptor>(descriptor:A, closure:((A.ValueType) -> ())) -> CommandType {
  return AnonymousCommand { parser in
    if parser.hasOption("help") {
      throw Help([BoxedArgumentDescriptor(value: descriptor)])
    }

    closure(try descriptor.parse(parser))
  }
}

public func command<A:ArgumentDescriptor, B:ArgumentDescriptor>(descriptorA:A, _ descriptorB:B, closure:((A.ValueType, B.ValueType) -> ())) -> CommandType {
  return AnonymousCommand { parser in
    if parser.hasOption("help") {
      throw Help([
        BoxedArgumentDescriptor(value: descriptorA),
        BoxedArgumentDescriptor(value: descriptorB),
      ])
    }

    closure(try descriptorA.parse(parser), try descriptorB.parse(parser))
  }
}

public func command<A:ArgumentDescriptor, B:ArgumentDescriptor, C:ArgumentDescriptor>(descriptorA:A, _ descriptorB:B, _ descriptorC:C, closure:((A.ValueType, B.ValueType, C.ValueType) -> ())) -> CommandType {
  return AnonymousCommand { parser in
    if parser.hasOption("help") {
      throw Help([
        BoxedArgumentDescriptor(value: descriptorA),
        BoxedArgumentDescriptor(value: descriptorB),
        BoxedArgumentDescriptor(value: descriptorC),
      ])
    }

    closure(try descriptorA.parse(parser), try descriptorB.parse(parser), try descriptorC.parse(parser))
  }
}

public func command<A:ArgumentDescriptor, B:ArgumentDescriptor, C:ArgumentDescriptor, D:ArgumentDescriptor>(a:A, _ b:B, _ c:C, _ d:D, closure:((A.ValueType, B.ValueType, C.ValueType, D.ValueType) -> ())) -> CommandType {
  return AnonymousCommand { parser in
    if parser.hasOption("help") {
      throw Help([
        BoxedArgumentDescriptor(value: a),
        BoxedArgumentDescriptor(value: b),
        BoxedArgumentDescriptor(value: c),
        BoxedArgumentDescriptor(value: d),
      ])
    }

    closure(try a.parse(parser), try b.parse(parser), try c.parse(parser), try d.parse(parser))
  }
}

public func command<A:ArgumentDescriptor, B:ArgumentDescriptor, C:ArgumentDescriptor, D:ArgumentDescriptor, E:ArgumentDescriptor>(a:A, _ b:B, _ c:C, _ d:D, _ e:E, closure:((A.ValueType, B.ValueType, C.ValueType, D.ValueType, E.ValueType) -> ())) -> CommandType {
  return AnonymousCommand { parser in
    if parser.hasOption("help") {
      throw Help([
        BoxedArgumentDescriptor(value: a),
        BoxedArgumentDescriptor(value: b),
        BoxedArgumentDescriptor(value: c),
        BoxedArgumentDescriptor(value: d),
        BoxedArgumentDescriptor(value: e),
      ])
    }

    closure(try a.parse(parser), try b.parse(parser), try c.parse(parser), try d.parse(parser), try e.parse(parser))
  }
}