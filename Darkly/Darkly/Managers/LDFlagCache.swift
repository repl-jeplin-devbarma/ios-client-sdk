//
//  LDFlagCache.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

private struct CachedFlags {
    enum CodingKeys: String, CodingKey {
        case flags, lastUpdated
    }

    let flags: [String: Any]
    let lastUpdated: Date

    init(flags: [String: Any], lastUpdated: Date) {
        self.flags = flags
        self.lastUpdated = lastUpdated
    }

    init(user: LDUser) {
        self = CachedFlags(flags: user.flagStore.featureFlags, lastUpdated: user.lastUpdated)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.flags.rawValue: flags, CodingKeys.lastUpdated.rawValue: lastUpdated]
    }

    init?(dictionary: [String: Any]) {
        guard let flags = dictionary[CodingKeys.flags.rawValue] as? [String: Any],
            let lastUpdated = dictionary[CodingKeys.lastUpdated.rawValue] as? Date
            else { return nil }
        self = CachedFlags(flags: flags, lastUpdated: lastUpdated)
    }

    init?(object: Any) {
        guard let dictionary = object as? [String: Any],
            let flags = CachedFlags(dictionary: dictionary)
        else { return nil }

        self = flags
    }
}

final class LDFlagCache {
    struct Constants {
        public static let maxCachedValues = 5
    }

    struct Keys {
        fileprivate static let cachedUsers = "ldUserModelDictionary"
        fileprivate static let cachedFlags = "LDFlagCacheDictionary"
    }

    let maxCachedValues: Int

    init(maxCachedValues: Int = Constants.maxCachedValues) {
        self.maxCachedValues = maxCachedValues
    }

    func storeFlags(for user: LDUser) {
        var flags = cachedFlags
        flags[user.key] = CachedFlags(user: user)
        cache(flags: flags)
    }
    
    func retrieveFlags(for user: LDUser) -> [String: Any]? {
        return cachedFlags[user.key]?.flags
    }
    
    //TODO: Should this retrieve a tuple (userKey, flags)?
    func retrieveLatest() -> [String: Any]? {
        let flags = cachedFlags
        guard !flags.isEmpty else { return nil }
        return flags.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated < pair2.value.lastUpdated })?.value.flags
    }

    private var cachedFlags: [String: CachedFlags] {
        guard let flagCache = UserDefaults.standard.dictionary(forKey: Keys.cachedFlags)
            else { return [:] }

        return flagCache.flatMapValues { flagDictionary in CachedFlags(object: flagDictionary) }
    }

    private func cache(flags: [String: CachedFlags]) {
        var flags = flags
        while flags.count > maxCachedValues { flags.removeOldest() }
        UserDefaults.standard.set(flags.mapValues { (userFlags) in userFlags.dictionaryValue }, forKey: Keys.cachedFlags)
        UserDefaults.standard.synchronize()
    }

    // MARK: - User caching

    private var cachedUsers: [String: LDUser] {
        guard let userCache = UserDefaults.standard.dictionary(forKey: Keys.cachedUsers)
        else { return [:] }

        return Dictionary(uniqueKeysWithValues: userCache.map { (keyObjectPair) in (keyObjectPair.key, LDUser(userObject: keyObjectPair.value, usingKeyIfMissing: keyObjectPair.key)) })
    }

    func convertUserCacheToFlagCache() {
        let userCache = cachedUsers
        guard !userCache.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: Keys.cachedUsers)
        let flagCache = userCache.mapValues { (user) in CachedFlags(user: user).dictionaryValue }
        UserDefaults.standard.set(flagCache, forKey: Keys.cachedFlags)
        UserDefaults.standard.synchronize()
    }
}

extension LDUser {
    fileprivate init(userObject: Any, usingKeyIfMissing key: String) {
        self = LDUser(dataObject: userObject) ?? LDUser(dictionaryObject: userObject) ?? LDUser(key: key)
    }

    private init?(dictionaryObject: Any) {
        guard let userDictionary = dictionaryObject as? [String: Any]
        else { return nil }
        self = LDUser(jsonDictionary: userDictionary)
    }

    private init?(dataObject: Any) {
        guard let userData = dataObject as? Data,
            let wrapper = NSKeyedUnarchiver.unarchiveObject(with: userData) as? LDUserWrapper
        else { return nil }
        self = wrapper.wrapped
    }
}

extension Dictionary where Key == String, Value == CachedFlags {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty else { return }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated > pair2.value.lastUpdated }) else { return }
        self.removeValue(forKey: oldestPair.key)
    }
}

// MARK: - Test Support
#if DEBUG
    extension LDFlagCache {
        var cachedUsersForTesting: [String: LDUser] { return cachedUsers }
        static var userCacheKey: String { return Keys.cachedUsers }
        static var flagCacheKey: String { return Keys.cachedFlags }
    }
#endif