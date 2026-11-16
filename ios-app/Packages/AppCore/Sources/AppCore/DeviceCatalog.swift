/// Turns Apple's internal model code (for example "iPhone16,1") into the name
/// people know ("iPhone 15 Pro").
///
/// This is only used to make the diagnostics easier to read. It never decides
/// whether a feature is available: that always comes from asking ARKit on the
/// device itself. Unknown codes simply show the raw code.
public enum DeviceCatalog {

    /// The marketing name for a model code, or `nil` if the code is not in the list.
    public static func marketingName(forIdentifier identifier: String) -> String? {
        names[identifier]
    }

    /// A label for the diagnostics screen: "iPhone 15 Pro (iPhone16,1)",
    /// or just the raw code when the model is not in the list.
    public static func displayName(forIdentifier identifier: String) -> String {
        guard let name = marketingName(forIdentifier: identifier) else {
            return identifier
        }
        return "\(name) (\(identifier))"
    }

    /// iPhones that can run iOS 17 or later.
    static let names: [String: String] = [
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
    ]
}
