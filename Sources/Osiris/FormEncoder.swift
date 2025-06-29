//
// Lifted from Alamofire (ParameterEncoding.swift): https://github.com/Alamofire/Alamofire
//

import Foundation

extension NSNumber {

    /// [From Argo](https://github.com/thoughtbot/Argo/blob/3da833411e2633bc01ce89542ac16803a163e0f0/Argo/Extensions/NSNumber.swift)
    ///
    /// - Returns: `true` if this instance represent a `CFBoolean` under the hood, as opposed to say a double or integer.
    var isBool: Bool {
        return CFBooleanGetTypeID() == CFGetTypeID(self)
    }
}

/// URL-encoded form data encoder adapted from Alamofire.
///
/// FormEncoder converts Swift dictionaries into URL-encoded form data strings
/// suitable for application/x-www-form-urlencoded requests. It handles nested
/// dictionaries, arrays, and various data types including proper boolean encoding.
///
/// ## Usage
///
/// ```swift
/// let parameters = [
///     "name": "Jane Doe",
///     "email": "jane@example.net",
///     "age": 30,
///     "active": true,
///     "preferences": ["color": "blue", "theme": "dark"]
/// ]
///
/// let encoded = FormEncoder.encode(parameters)
/// // Result: "active=1&age=30&email=jane%40example.net&name=Jane%20Doe&preferences%5Bcolor%5D=blue&preferences%5Btheme%5D=dark"
/// ```
public final class FormEncoder: CustomStringConvertible {

    /// Encodes a dictionary of parameters into a URL-encoded form string.
    ///
    /// The encoding follows these rules:
    /// - Keys are sorted alphabetically for consistent output
    /// - Nested dictionaries use bracket notation: `key[subkey]=value`
    /// - Arrays use empty brackets: `key[]=value1&key[]=value2`
    /// - Booleans are encoded as "1" for true, "0" for false
    /// - All keys and values are percent-escaped according to RFC 3986
    ///
    /// - Parameter parameters: The dictionary to encode
    /// - Returns: A URL-encoded form string ready for use in HTTP requests
    public class func encode(_ parameters: [String: any Sendable]) -> String {
        var components: [(String, String)] = []

        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += pairs(from: key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }

    /// Creates percent-escaped, URL encoded query string components from the given key-value pair using recursion.
    ///
    /// - parameter key:   The key of the query component.
    /// - parameter value: The value of the query component.
    ///
    /// - returns: The percent-escaped, URL encoded query string components.
    static func pairs(from key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []

        if let dictionary = value as? [String: any Sendable] {
            for (nestedKey, value) in dictionary {
                components += pairs(from: "\(key)[\(nestedKey)]", value: value)
            }
        }
        else if let array = value as? [Any] {
            for value in array {
                components += pairs(from: "\(key)[]", value: value)
            }
        }
        else if let value = value as? NSNumber {
            if value.isBool {
                components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
            }
            else {
                components.append((escape(key), escape("\(value)")))
            }
        }
        else if let bool = value as? Bool {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        }
        else {
            components.append((escape(key), escape("\(value)")))
        }

        return components
    }

    /// Returns a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    ///
    /// - parameter string: The string to be percent-escaped.
    ///
    /// - returns: The percent-escaped string.
    private static func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        // FIXME: should we fail instead of falling back the unescaped string here? probably...
        let escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        return escaped
    }

    public var description: String {
        "FormEncoder"
    }
}
