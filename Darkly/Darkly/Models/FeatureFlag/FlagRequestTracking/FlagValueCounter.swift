//
//  FlagValueCounter.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagValueCounter {
    enum CodingKeys: String, CodingKey {
        case value, variation, version, unknown, count
    }

    let reportedValue: Any?
    let featureFlag: FeatureFlag?
    let isKnown: Bool
    var count: Int

    init(reportedValue: Any?, featureFlag: FeatureFlag?) {
        self.reportedValue = reportedValue
        self.featureFlag = featureFlag
        isKnown = featureFlag != nil
        count = 1
    }

    var dictionaryValue: [String: Any] {
        var counterDictionary = [String: Any]()
        counterDictionary[CodingKeys.value.rawValue] = reportedValue ?? NSNull()
        counterDictionary[CodingKeys.count.rawValue] = count
        if isKnown {
            counterDictionary[CodingKeys.variation.rawValue] = featureFlag?.variation
            counterDictionary[CodingKeys.version.rawValue] = featureFlag?.flagVersion ?? featureFlag?.version
        } else {
            counterDictionary[CodingKeys.unknown.rawValue] = true
        }

        return counterDictionary
    }
}
