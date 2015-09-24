private enum Arg : CustomStringConvertible {
  /// A positional argument
  case Argument(String)

  /// A boolean like option, `--version`, `--help`, `--no-clean`.
  case Option(String)

  /// A flag
  case Flag(Set<Character>)

  var description:String {
    switch self {
    case .Argument(let value):
      return value
    case .Option(let key):
      return "--\(key)"
    case .Flag(let flags):
      return "-\(String(flags))"
    }
  }

  var type:String {
    switch self {
    case .Argument:
      return "argument"
    case .Option:
      return "option"
    case .Flag:
      return "flag"
    }
  }
}


public struct ArgumentParserError : ErrorType, CustomStringConvertible {
  public let description:String

  init(description:String) {
    self.description = description
  }
}


public final class ArgumentParser : ArgumentConvertible, CustomStringConvertible {
  private var arguments:[Arg]

  /// Initialises the ArgumentParser with an array of arguments
  public init(arguments: [String]) {
    self.arguments = arguments.map { argument in
      if argument.hasPrefix("-") {
        let flags = String(argument.substringFromIndex(argument.startIndex.successor()))

        if flags.hasPrefix("-") {
          let option = String(flags.substringFromIndex(argument.startIndex.successor()))
          return .Option(option)
        }

        return .Flag(Set(flags.characters))
      }

      return .Argument(argument)
    }
  }

  public init(parser: ArgumentParser) throws {
    arguments = parser.arguments
  }

  public var description:String {
    return ""
  }

  /// Returns the first positional argument in the remaining arguments.
  /// This will remove the argument from the remaining arguments.
  public func shift() -> String? {
    for (index, argument) in arguments.enumerate() {
      switch argument {
      case .Argument(let value):
        arguments.removeAtIndex(index)
        return value
      default:
        continue
      }
    }

    return nil
  }

  /// Returns the value for an option (--name Kyle, --name=Kyle)
  public func shiftValueForOption(name:String) throws -> String? {
    return try shiftValuesForOption(name)?.first
  }

  /// Returns the value for an option (--name Kyle, --name=Kyle)
  public func shiftValuesForOption(name:String, count:Int = 1) throws -> [String]? {
    var index = 0
    var hasOption = false

    for argument in arguments {
      switch argument {
      case .Option(let option):
        if option == name {
          hasOption = true
          break
        }
        fallthrough
      default:
        ++index
      }

      if hasOption {
        break
      }
    }

    if hasOption {
      arguments.removeAtIndex(index)  // Pop option
      return try (0..<count).map { i in
        if arguments.count > index {
          let argument = arguments.removeAtIndex(index)
          switch argument {
          case .Argument(let value):
            return value
          default:
            throw ArgumentParserError(description: "Unexpected \(argument.type) `\(argument)` as a value for `--\(name)`")
          }
        }

        throw ArgumentParserError(description: "Missing value for `--\(name)`")
      }
    }

    return nil
  }

  /// Returns whether an option was specified in the arguments
  public func hasOption(name:String) -> Bool {
    for argument in arguments {
      switch argument {
      case .Option(let option):
        if option == name {
          return true
        }
      default:
        continue
      }
    }

    return false
  }

  /// Returns whether a flag was specified in the arguments
  public func hasFlag(flag:Character) -> Bool {
    for argument in arguments {
      switch argument {
      case .Flag(let option):
        if option.contains(flag) {
          return true
        }
      default:
        continue
      }
    }

    return false
  }

  /// Returns the value for a flag (-n Kyle)
  public func shiftValueForFlag(flag:Character) throws -> String? {
    return try shiftValuesForFlag(flag)?.first
  }

  /// Returns the value for a flag (-n Kyle)
  public func shiftValuesForFlag(flag:Character, count:Int = 1) throws -> [String]? {
    var index = 0
    var hasFlag = false

    for argument in arguments {
      switch argument {
      case .Flag(let flags):
        if flags.contains(flag) {
          hasFlag = true
          break
        }
        fallthrough
      default:
        ++index
      }

      if hasFlag {
        break
      }
    }

    if hasFlag {
      ++index // Jump flags

      return try (0..<count).map { i in
        if arguments.count > index {
          let argument = arguments.removeAtIndex(index)
          switch argument {
          case .Argument(let value):
            return value
          default:
            throw ArgumentParserError(description: "Unexpected \(argument.type) `\(argument)` as a value for `-\(flag)`")
          }
        }

        throw ArgumentParserError(description: "Missing value for `-\(flag)`")
      }
    }
    
    return nil
  }
}
