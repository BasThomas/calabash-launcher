import Foundation

private extension Collection where Element == String {
    var formattedLocalizationKeys: String {
        return map { "\($0)" }.joined(separator: " / ")
    }
}

class LocalizationHandler {
    
    let applicationStateHandler = ApplicationStateHandler()
    let jsonFilePaths: [String]
    let localizedStringsFilePaths: [String]
    
    init() {
        jsonFilePaths = LocalizationHandler.allFiles(withFileExtension: "json")
        localizedStringsFilePaths = LocalizationHandler.allFiles(withFileExtension: "strings")
    }
    
    func formattedKeys(for string: String) -> String {
        return localizationKeys(for: string).formattedLocalizationKeys
    }
    
    /// Returns localization keys for a given value
    /// localizedStringKeys has a priority, if any keys will be found in localizedStrings the function will immediately return
    func localizationKeys(for value: String) -> [String] {
        guard let value = parseResponse(value) else { return [] }
        
        let resultForLocalizedStrings = localizedStringKeys(for: value)
        
        if !resultForLocalizedStrings.isEmpty {
            return resultForLocalizedStrings
        } else {
            return jsonKeys(for: value)
        }
    }
    
    /// This function parses the string and return everything that is between 'marked:' and the last quote.
    /// For example "XNGButton marked:'Login'" will return "Login" string.
    func parseResponse(_ response: String) -> String? {
        return RegexHandler().matches(for: "\\marked:'(.*?)\\\'", in: response).last
    }
    
    /// Transfers dictionary from [String: Any] to [String: String]
    func filterDictionary(_ dictionary: [String: Any]) -> [String: String] {
        let dictionaryWithStrings: [String: String] = dictionary.reduce(into: [:]) { dict, item in
            guard let value = item.value as? String else { return }
            dict[item.key] = value
        }
        return dictionaryWithStrings
    }
    
    func localizedStringKeys(for value: String) -> [String] {
        return localizedStringsFilePaths.compactMap { path -> [String]? in
            guard
                let filePath = applicationStateHandler.filePath?.appendingPathComponent(path),
                let stringsDict = NSDictionary(contentsOf: filePath) as? [String: String] else { return nil }
            return stringsDict.keysForValue(value)
            }.flatMap { $0 }
    }
    
    func jsonKeys(for value: String) -> [String] {
        var resultingKeys: [String] = []
        
        jsonFilePaths.forEach { path in
            var jsonResults: [String: Any] = [:]
            
            if let path = applicationStateHandler.filePath?.appendingPathComponent(path),
                let data = try? Data(contentsOf: path, options: .mappedIfSafe),
                let jsonResult = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? NSDictionary,
                let jsonKeys = jsonResult?.allKeys
            {
                jsonKeys.forEach { key in
                    if let jsonDictionary = jsonResult?[key] as? [String: Any] {
                        jsonResults.append(dictionary: jsonDictionary )
                    }
                }
                
                let resultDictionary = filterDictionary(jsonResults)
                
                resultingKeys.append(contentsOf: resultDictionary.keysForValue(value))
            }
        }
        return resultingKeys
    }
    
    static func allFiles(withFileExtension fileExtension: String) -> [String] {
        let applicationStateHandler = ApplicationStateHandler()
        let fileManager = FileManager.default
        
        guard let path = applicationStateHandler.filePath?.absoluteString,
            let enumerator = fileManager.enumerator(atPath: path.replacingOccurrences(of: "file://", with: "")) else { return [] }
        var filePaths = [""]
        while let element = enumerator.nextObject() as? String {
            if element.hasSuffix(fileExtension) {
                filePaths.append(element)
            }
        }
        return filePaths
    }
}
