//
// EncryptionKeyStoreService.swift
// Proton Authenticator - Created on 11/03/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Authenticator.
//
// Proton Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

import CommonUtilities
import Foundation

public protocol EncryptionKeyStoring: Sendable {
    func store(keyId: String, data: Data, shouldSync: Bool)
    func clear(keyId: String, shouldSync: Bool)
    func retrieve(keyId: String, shouldSync: Bool) -> Data?
    func clearAll(shouldSync: Bool)
}

public extension EncryptionKeyStoring {
    func store(keyId: String, data: Data, shouldSync: Bool = true) {
        store(keyId: keyId, data: data, shouldSync: shouldSync)
    }

    func clear(keyId: String, shouldSync: Bool = true) {
        clear(keyId: keyId, shouldSync: shouldSync)
    }

    func retrieve(keyId: String, shouldSync: Bool = true) -> Data? {
        retrieve(keyId: keyId, shouldSync: shouldSync)
    }

    func clearAll(shouldSync: Bool = true) {
        clearAll(shouldSync: shouldSync)
    }
}

// swiftlint:disable type_body_length line_length file_length
public final class EncryptionKeyStoreService: EncryptionKeyStoring {
    private let service: String
    private let accessGroup: String
    private let logger: LoggerProtocol?

    public init(service: String = AppConstants.service,
                accessGroup: String = AppConstants.keychainGroup,
                logger: LoggerProtocol? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        self.logger = logger
    }
}

public extension EncryptionKeyStoreService {
    func store(keyId: String, data: Data, shouldSync: Bool) {
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keyId,
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrSynchronizable: shouldSync,
            kSecAttrAccessGroup: accessGroup
        ]
        SecItemDelete(addQuery as CFDictionary)
        let status: OSStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger?.dataLogger
                .warning("\(type(of: self)) - \(#function) - Failed to store encryption key: \(status.toError.description)")
            return
        }
    }

    func clear(keyId: String, shouldSync: Bool) {
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: keyId,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: shouldSync,
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(addQuery as CFDictionary)
    }

    func retrieve(keyId: String, shouldSync: Bool) -> Data? {
        let getQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyId,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: shouldSync,
            kSecAttrAccessGroup as String: accessGroup
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(getQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            logger?.dataLogger
                .warning("\(type(of: self)) - \(#function) - Failed retrieve data linked to keyId \(keyId): \(status.toError.description)")
            return nil
        }

        guard let data = item as? Data? else {
            logger?.dataLogger.warning("\(type(of: self)) - \(#function) - Empty data linked to keyId \(keyId)")
            return nil
        }

        return data
    }

    func clearAll(shouldSync: Bool) {
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        for secItemClass in secItemClasses {
            let query: NSDictionary = [
                kSecClass as String: secItemClass,
                kSecAttrSynchronizable as String: shouldSync
            ]
            SecItemDelete(query)
        }
    }
}

extension OSStatus {
    var toError: Status {
        let error = Status(status: self)
        return error
    }
}

enum Status: OSStatus, Error {
    case success = 0
    case unimplemented = -4
    case diskFull = -34
    case io = -36
    case opWr = -49
    case param = -50
    case wrPerm = -61
    case allocate = -108
    case userCanceled = -128
    case badReq = -909
    case internalComponent = -2_070
    case notAvailable = -25_291
    case readOnly = -25_292
    case authFailed = -25_293
    case noSuchKeychain = -25_294
    case invalidKeychain = -25_295
    case duplicateKeychain = -25_296
    case duplicateCallback = -25_297
    case invalidCallback = -25_298
    case duplicateItem = -25_299
    case itemNotFound = -25_300
    case bufferTooSmall = -25_301
    case dataTooLarge = -25_302
    case noSuchAttr = -25_303
    case invalidItemRef = -25_304
    case invalidSearchRef = -25_305
    case noSuchClass = -25_306
    case noDefaultKeychain = -25_307
    case interactionNotAllowed = -25_308
    case readOnlyAttr = -25_309
    case wrongSecVersion = -25_310
    case keySizeNotAllowed = -25_311
    case noStorageModule = -25_312
    case noCertificateModule = -25_313
    case noPolicyModule = -25_314
    case interactionRequired = -25_315
    case dataNotAvailable = -25_316
    case dataNotModifiable = -25_317
    case createChainFailed = -25_318
    case invalidPrefsDomain = -25_319
    case inDarkWake = -25_320
    case aclNotSimple = -25_240
    case policyNotFound = -25_241
    case invalidTrustSetting = -25_242
    case noAccessForItem = -25_243
    case invalidOwnerEdit = -25_244
    case trustNotAvailable = -25_245
    case unsupportedFormat = -25_256
    case unknownFormat = -25_257
    case keyIsSensitive = -25_258
    case multiplePrivKeys = -25_259
    case passphraseRequired = -25_260
    case invalidPasswordRef = -25_261
    case invalidTrustSettings = -25_262
    case noTrustSettings = -25_263
    case pkcs12VerifyFailure = -25_264
    case invalidCertificate = -26_265
    case notSigner = -26_267
    case policyDenied = -26_270
    case invalidKey = -26_274
    case decode = -26_275
    case `internal` = -26_276
    case unsupportedAlgorithm = -26_268
    case unsupportedOperation = -26_271
    case unsupportedPadding = -26_273
    case itemInvalidKey = -34_000
    case itemInvalidKeyType = -34_001
    case itemInvalidValue = -34_002
    case itemClassMissing = -34_003
    case itemMatchUnsupported = -34_004
    case useItemListUnsupported = -34_005
    case useKeychainUnsupported = -34_006
    case useKeychainListUnsupported = -34_007
    case returnDataUnsupported = -34_008
    case returnAttributesUnsupported = -34_009
    case returnRefUnsupported = -34_010
    case returnPersitentRefUnsupported = -34_011
    case valueRefUnsupported = -34_012
    case valuePersistentRefUnsupported = -34_013
    case returnMissingPointer = -34_014
    case matchLimitUnsupported = -34_015
    case itemIllegalQuery = -34_016
    case waitForCallback = -34_017
    case missingEntitlement = -34_018
    case upgradePending = -34_019
    case mpSignatureInvalid = -25_327
    case otrTooOld = -25_328
    case otrIDTooNew = -25_329
    case serviceNotAvailable = -67_585
    case insufficientClientID = -67_586
    case deviceReset = -67_587
    case deviceFailed = -67_588
    case appleAddAppACLSubject = -67_589
    case applePublicKeyIncomplete = -67_590
    case appleSignatureMismatch = -67_591
    case appleInvalidKeyStartDate = -67_592
    case appleInvalidKeyEndDate = -67_593
    case conversionError = -67_594
    case appleSSLv2Rollback = -67_595
    case quotaExceeded = -67_596
    case fileTooBig = -67_597
    case invalidDatabaseBlob = -67_598
    case invalidKeyBlob = -67_599
    case incompatibleDatabaseBlob = -67_600
    case incompatibleKeyBlob = -67_601
    case hostNameMismatch = -67_602
    case unknownCriticalExtensionFlag = -67_603
    case noBasicConstraints = -67_604
    case noBasicConstraintsCA = -67_605
    case invalidAuthorityKeyID = -67_606
    case invalidSubjectKeyID = -67_607
    case invalidKeyUsageForPolicy = -67_608
    case invalidExtendedKeyUsage = -67_609
    case invalidIDLinkage = -67_610
    case pathLengthConstraintExceeded = -67_611
    case invalidRoot = -67_612
    case crlExpired = -67_613
    case crlNotValidYet = -67_614
    case crlNotFound = -67_615
    case crlServerDown = -67_616
    case crlBadURI = -67_617
    case unknownCertExtension = -67_618
    case unknownCRLExtension = -67_619
    case crlNotTrusted = -67_620
    case crlPolicyFailed = -67_621
    case idpFailure = -67_622
    case smimeEmailAddressesNotFound = -67_623
    case smimeBadExtendedKeyUsage = -67_624
    case smimeBadKeyUsage = -67_625
    case smimeKeyUsageNotCritical = -67_626
    case smimeNoEmailAddress = -67_627
    case smimeSubjAltNameNotCritical = -67_628
    case sslBadExtendedKeyUsage = -67_629
    case ocspBadResponse = -67_630
    case ocspBadRequest = -67_631
    case ocspUnavailable = -67_632
    case ocspStatusUnrecognized = -67_633
    case endOfData = -67_634
    case incompleteCertRevocationCheck = -67_635
    case networkFailure = -67_636
    case ocspNotTrustedToAnchor = -67_637
    case recordModified = -67_638
    case ocspSignatureError = -67_639
    case ocspNoSigner = -67_640
    case ocspResponderMalformedReq = -67_641
    case ocspResponderInternalError = -67_642
    case ocspResponderTryLater = -67_643
    case ocspResponderSignatureRequired = -67_644
    case ocspResponderUnauthorized = -67_645
    case ocspResponseNonceMismatch = -67_646
    case codeSigningBadCertChainLength = -67_647
    case codeSigningNoBasicConstraints = -67_648
    case codeSigningBadPathLengthConstraint = -67_649
    case codeSigningNoExtendedKeyUsage = -67_650
    case codeSigningDevelopment = -67_651
    case resourceSignBadCertChainLength = -67_652
    case resourceSignBadExtKeyUsage = -67_653
    case trustSettingDeny = -67_654
    case invalidSubjectName = -67_655
    case unknownQualifiedCertStatement = -67_656
    case mobileMeRequestQueued = -67_657
    case mobileMeRequestRedirected = -67_658
    case mobileMeServerError = -67_659
    case mobileMeServerNotAvailable = -67_660
    case mobileMeServerAlreadyExists = -67_661
    case mobileMeServerServiceErr = -67_662
    case mobileMeRequestAlreadyPending = -67_663
    case mobileMeNoRequestPending = -67_664
    case mobileMeCSRVerifyFailure = -67_665
    case mobileMeFailedConsistencyCheck = -67_666
    case notInitialized = -67_667
    case invalidHandleUsage = -67_668
    case pvcReferentNotFound = -67_669
    case functionIntegrityFail = -67_670
    case internalError = -67_671
    case memoryError = -67_672
    case invalidData = -67_673
    case mdsError = -67_674
    case invalidPointer = -67_675
    case selfCheckFailed = -67_676
    case functionFailed = -67_677
    case moduleManifestVerifyFailed = -67_678
    case invalidGUID = -67_679
    case invalidHandle = -67_680
    case invalidDBList = -67_681
    case invalidPassthroughID = -67_682
    case invalidNetworkAddress = -67_683
    case crlAlreadySigned = -67_684
    case invalidNumberOfFields = -67_685
    case verificationFailure = -67_686
    case unknownTag = -67_687
    case invalidSignature = -67_688
    case invalidName = -67_689
    case invalidCertificateRef = -67_690
    case invalidCertificateGroup = -67_691
    case tagNotFound = -67_692
    case invalidQuery = -67_693
    case invalidValue = -67_694
    case callbackFailed = -67_695
    case aclDeleteFailed = -67_696
    case aclReplaceFailed = -67_697
    case aclAddFailed = -67_698
    case aclChangeFailed = -67_699
    case invalidAccessCredentials = -67_700
    case invalidRecord = -67_701
    case invalidACL = -67_702
    case invalidSampleValue = -67_703
    case incompatibleVersion = -67_704
    case privilegeNotGranted = -67_705
    case invalidScope = -67_706
    case pvcAlreadyConfigured = -67_707
    case invalidPVC = -67_708
    case emmLoadFailed = -67_709
    case emmUnloadFailed = -67_710
    case addinLoadFailed = -67_711
    case invalidKeyRef = -67_712
    case invalidKeyHierarchy = -67_713
    case addinUnloadFailed = -67_714
    case libraryReferenceNotFound = -67_715
    case invalidAddinFunctionTable = -67_716
    case invalidServiceMask = -67_717
    case moduleNotLoaded = -67_718
    case invalidSubServiceID = -67_719
    case attributeNotInContext = -67_720
    case moduleManagerInitializeFailed = -67_721
    case moduleManagerNotFound = -67_722
    case eventNotificationCallbackNotFound = -67_723
    case inputLengthError = -67_724
    case outputLengthError = -67_725
    case privilegeNotSupported = -67_726
    case deviceError = -67_727
    case attachHandleBusy = -67_728
    case notLoggedIn = -67_729
    case algorithmMismatch = -67_730
    case keyUsageIncorrect = -67_731
    case keyBlobTypeIncorrect = -67_732
    case keyHeaderInconsistent = -67_733
    case unsupportedKeyFormat = -67_734
    case unsupportedKeySize = -67_735
    case invalidKeyUsageMask = -67_736
    case unsupportedKeyUsageMask = -67_737
    case invalidKeyAttributeMask = -67_738
    case unsupportedKeyAttributeMask = -67_739
    case invalidKeyLabel = -67_740
    case unsupportedKeyLabel = -67_741
    case invalidKeyFormat = -67_742
    case unsupportedVectorOfBuffers = -67_743
    case invalidInputVector = -67_744
    case invalidOutputVector = -67_745
    case invalidContext = -67_746
    case invalidAlgorithm = -67_747
    case invalidAttributeKey = -67_748
    case missingAttributeKey = -67_749
    case invalidAttributeInitVector = -67_750
    case missingAttributeInitVector = -67_751
    case invalidAttributeSalt = -67_752
    case missingAttributeSalt = -67_753
    case invalidAttributePadding = -67_754
    case missingAttributePadding = -67_755
    case invalidAttributeRandom = -67_756
    case missingAttributeRandom = -67_757
    case invalidAttributeSeed = -67_758
    case missingAttributeSeed = -67_759
    case invalidAttributePassphrase = -67_760
    case missingAttributePassphrase = -67_761
    case invalidAttributeKeyLength = -67_762
    case missingAttributeKeyLength = -67_763
    case invalidAttributeBlockSize = -67_764
    case missingAttributeBlockSize = -67_765
    case invalidAttributeOutputSize = -67_766
    case missingAttributeOutputSize = -67_767
    case invalidAttributeRounds = -67_768
    case missingAttributeRounds = -67_769
    case invalidAlgorithmParms = -67_770
    case missingAlgorithmParms = -67_771
    case invalidAttributeLabel = -67_772
    case missingAttributeLabel = -67_773
    case invalidAttributeKeyType = -67_774
    case missingAttributeKeyType = -67_775
    case invalidAttributeMode = -67_776
    case missingAttributeMode = -67_777
    case invalidAttributeEffectiveBits = -67_778
    case missingAttributeEffectiveBits = -67_779
    case invalidAttributeStartDate = -67_780
    case missingAttributeStartDate = -67_781
    case invalidAttributeEndDate = -67_782
    case missingAttributeEndDate = -67_783
    case invalidAttributeVersion = -67_784
    case missingAttributeVersion = -67_785
    case invalidAttributePrime = -67_786
    case missingAttributePrime = -67_787
    case invalidAttributeBase = -67_788
    case missingAttributeBase = -67_789
    case invalidAttributeSubprime = -67_790
    case missingAttributeSubprime = -67_791
    case invalidAttributeIterationCount = -67_792
    case missingAttributeIterationCount = -67_793
    case invalidAttributeDLDBHandle = -67_794
    case missingAttributeDLDBHandle = -67_795
    case invalidAttributeAccessCredentials = -67_796
    case missingAttributeAccessCredentials = -67_797
    case invalidAttributePublicKeyFormat = -67_798
    case missingAttributePublicKeyFormat = -67_799
    case invalidAttributePrivateKeyFormat = -67_800
    case missingAttributePrivateKeyFormat = -67_801
    case invalidAttributeSymmetricKeyFormat = -67_802
    case missingAttributeSymmetricKeyFormat = -67_803
    case invalidAttributeWrappedKeyFormat = -67_804
    case missingAttributeWrappedKeyFormat = -67_805
    case stagedOperationInProgress = -67_806
    case stagedOperationNotStarted = -67_807
    case verifyFailed = -67_808
    case querySizeUnknown = -67_809
    case blockSizeMismatch = -67_810
    case publicKeyInconsistent = -67_811
    case deviceVerifyFailed = -67_812
    case invalidLoginName = -67_813
    case alreadyLoggedIn = -67_814
    case invalidDigestAlgorithm = -67_815
    case invalidCRLGroup = -67_816
    case certificateCannotOperate = -67_817
    case certificateExpired = -67_818
    case certificateNotValidYet = -67_819
    case certificateRevoked = -67_820
    case certificateSuspended = -67_821
    case insufficientCredentials = -67_822
    case invalidAction = -67_823
    case invalidAuthority = -67_824
    case verifyActionFailed = -67_825
    case invalidCertAuthority = -67_826
    case invaldCRLAuthority = -67_827
    case invalidCRLEncoding = -67_828
    case invalidCRLType = -67_829
    case invalidCRL = -67_830
    case invalidFormType = -67_831
    case invalidID = -67_832
    case invalidIdentifier = -67_833
    case invalidIndex = -67_834
    case invalidPolicyIdentifiers = -67_835
    case invalidTimeString = -67_836
    case invalidReason = -67_837
    case invalidRequestInputs = -67_838
    case invalidResponseVector = -67_839
    case invalidStopOnPolicy = -67_840
    case invalidTuple = -67_841
    case multipleValuesUnsupported = -67_842
    case notTrusted = -67_843
    case noDefaultAuthority = -67_844
    case rejectedForm = -67_845
    case requestLost = -67_846
    case requestRejected = -67_847
    case unsupportedAddressType = -67_848
    case unsupportedService = -67_849
    case invalidTupleGroup = -67_850
    case invalidBaseACLs = -67_851
    case invalidTupleCredendtials = -67_852
    case invalidEncoding = -67_853
    case invalidValidityPeriod = -67_854
    case invalidRequestor = -67_855
    case requestDescriptor = -67_856
    case invalidBundleInfo = -67_857
    case invalidCRLIndex = -67_858
    case noFieldValues = -67_859
    case unsupportedFieldFormat = -67_860
    case unsupportedIndexInfo = -67_861
    case unsupportedLocality = -67_862
    case unsupportedNumAttributes = -67_863
    case unsupportedNumIndexes = -67_864
    case unsupportedNumRecordTypes = -67_865
    case fieldSpecifiedMultiple = -67_866
    case incompatibleFieldFormat = -67_867
    case invalidParsingModule = -67_868
    case databaseLocked = -67_869
    case datastoreIsOpen = -67_870
    case missingValue = -67_871
    case unsupportedQueryLimits = -67_872
    case unsupportedNumSelectionPreds = -67_873
    case unsupportedOperator = -67_874
    case invalidDBLocation = -67_875
    case invalidAccessRequest = -67_876
    case invalidIndexInfo = -67_877
    case invalidNewOwner = -67_878
    case invalidModifyMode = -67_879
    case missingRequiredExtension = -67_880
    case extendedKeyUsageNotCritical = -67_881
    case timestampMissing = -67_882
    case timestampInvalid = -67_883
    case timestampNotTrusted = -67_884
    case timestampServiceNotAvailable = -67_885
    case timestampBadAlg = -67_886
    case timestampBadRequest = -67_887
    case timestampBadDataFormat = -67_888
    case timestampTimeNotAvailable = -67_889
    case timestampUnacceptedPolicy = -67_890
    case timestampUnacceptedExtension = -67_891
    case timestampAddInfoNotAvailable = -67_892
    case timestampSystemFailure = -67_893
    case signingTimeMissing = -67_894
    case timestampRejection = -67_895
    case timestampWaiting = -67_896
    case timestampRevocationWarning = -67_897
    case timestampRevocationNotification = -67_898
    case unexpectedError = -99_999
}

extension Status: RawRepresentable, CustomStringConvertible {
    public init(status: OSStatus) {
        if let mappedStatus = Status(rawValue: status) {
            self = mappedStatus
        } else {
            self = .unexpectedError
        }
    }

    public var description: String {
        switch self {
        case .success:
            "No error."
        case .unimplemented:
            "Function or operation not implemented."
        case .diskFull:
            "The disk is full."
        case .io:
            "I/O error (bummers)"
        case .opWr:
            "file already open with with write permission"
        case .param:
            "One or more parameters passed to a function were not valid."
        case .wrPerm:
            "write permissions error"
        case .allocate:
            "Failed to allocate memory."
        case .userCanceled:
            "User canceled the operation."
        case .badReq:
            "Bad parameter or invalid state for operation."
        case .internalComponent:
            ""
        case .notAvailable:
            "No keychain is available. You may need to restart your computer."
        case .readOnly:
            "This keychain cannot be modified."
        case .authFailed:
            "The user name or passphrase you entered is not correct."
        case .noSuchKeychain:
            "The specified keychain could not be found."
        case .invalidKeychain:
            "The specified keychain is not a valid keychain file."
        case .duplicateKeychain:
            "A keychain with the same name already exists."
        case .duplicateCallback:
            "The specified callback function is already installed."
        case .invalidCallback:
            "The specified callback function is not valid."
        case .duplicateItem:
            "The specified item already exists in the keychain."
        case .itemNotFound:
            "The specified item could not be found in the keychain."
        case .bufferTooSmall:
            "There is not enough memory available to use the specified item."
        case .dataTooLarge:
            "This item contains information which is too large or in a format that cannot be displayed."
        case .noSuchAttr:
            "The specified attribute does not exist."
        case .invalidItemRef:
            "The specified item is no longer valid. It may have been deleted from the keychain."
        case .invalidSearchRef:
            "Unable to search the current keychain."
        case .noSuchClass:
            "The specified item does not appear to be a valid keychain item."
        case .noDefaultKeychain:
            "A default keychain could not be found."
        case .interactionNotAllowed:
            "User interaction is not allowed."
        case .readOnlyAttr:
            "The specified attribute could not be modified."
        case .wrongSecVersion:
            "This keychain was created by a different version of the system software and cannot be opened."
        case .keySizeNotAllowed:
            "This item specifies a key size which is too large."
        case .noStorageModule:
            "A required component (data storage module) could not be loaded. You may need to restart your computer."
        case .noCertificateModule:
            "A required component (certificate module) could not be loaded. You may need to restart your computer."
        case .noPolicyModule:
            "A required component (policy module) could not be loaded. You may need to restart your computer."
        case .interactionRequired:
            "User interaction is required, but is currently not allowed."
        case .dataNotAvailable:
            "The contents of this item cannot be retrieved."
        case .dataNotModifiable:
            "The contents of this item cannot be modified."
        case .createChainFailed:
            "One or more certificates required to validate this certificate cannot be found."
        case .invalidPrefsDomain:
            "The specified preferences domain is not valid."
        case .inDarkWake:
            "In dark wake, no UI possible"
        case .aclNotSimple:
            "The specified access control list is not in standard (simple) form."
        case .policyNotFound:
            "The specified policy cannot be found."
        case .invalidTrustSetting:
            "The specified trust setting is invalid."
        case .noAccessForItem:
            "The specified item has no access control."
        case .invalidOwnerEdit:
            "Invalid attempt to change the owner of this item."
        case .trustNotAvailable:
            "No trust results are available."
        case .unsupportedFormat:
            "Import/Export format unsupported."
        case .unknownFormat:
            "Unknown format in import."
        case .keyIsSensitive:
            "Key material must be wrapped for export."
        case .multiplePrivKeys:
            "An attempt was made to import multiple private keys."
        case .passphraseRequired:
            "Passphrase is required for import/export."
        case .invalidPasswordRef:
            "The password reference was invalid."
        case .invalidTrustSettings:
            "The Trust Settings Record was corrupted."
        case .noTrustSettings:
            "No Trust Settings were found."
        case .pkcs12VerifyFailure:
            "MAC verification failed during PKCS12 import (wrong password?)"
        case .invalidCertificate:
            "This certificate could not be decoded."
        case .notSigner:
            "A certificate was not signed by its proposed parent."
        case .policyDenied:
            "The certificate chain was not trusted due to a policy not accepting it."
        case .invalidKey:
            "The provided key material was not valid."
        case .decode:
            "Unable to decode the provided data."
        case .internal:
            "An internal error occurred in the Security framework."
        case .unsupportedAlgorithm:
            "An unsupported algorithm was encountered."
        case .unsupportedOperation:
            "The operation you requested is not supported by this key."
        case .unsupportedPadding:
            "The padding you requested is not supported."
        case .itemInvalidKey:
            "A string key in dictionary is not one of the supported keys."
        case .itemInvalidKeyType:
            "A key in a dictionary is neither a CFStringRef nor a CFNumberRef."
        case .itemInvalidValue:
            "A value in a dictionary is an invalid (or unsupported) CF type."
        case .itemClassMissing:
            "No kSecItemClass key was specified in a dictionary."
        case .itemMatchUnsupported:
            "The caller passed one or more kSecMatch keys to a function which does not support matches."
        case .useItemListUnsupported:
            "The caller passed in a kSecUseItemList key to a function which does not support it."
        case .useKeychainUnsupported:
            "The caller passed in a kSecUseKeychain key to a function which does not support it."
        case .useKeychainListUnsupported:
            "The caller passed in a kSecUseKeychainList key to a function which does not support it."
        case .returnDataUnsupported:
            "The caller passed in a kSecReturnData key to a function which does not support it."
        case .returnAttributesUnsupported:
            "The caller passed in a kSecReturnAttributes key to a function which does not support it."
        case .returnRefUnsupported:
            "The caller passed in a kSecReturnRef key to a function which does not support it."
        case .returnPersitentRefUnsupported:
            "The caller passed in a kSecReturnPersistentRef key to a function which does not support it."
        case .valueRefUnsupported:
            "The caller passed in a kSecValueRef key to a function which does not support it."
        case .valuePersistentRefUnsupported:
            "The caller passed in a kSecValuePersistentRef key to a function which does not support it."
        case .returnMissingPointer:
            "The caller passed asked for something to be returned but did not pass in a result pointer."
        case .matchLimitUnsupported:
            "The caller passed in a kSecMatchLimit key to a call which does not support limits."
        case .itemIllegalQuery:
            "The caller passed in a query which contained too many keys."
        case .waitForCallback:
            "This operation is incomplete, until the callback is invoked (not an error)."
        case .missingEntitlement:
            "Internal error when a required entitlement isn't present, client has neither application-identifier nor keychain-access-groups entitlements."
        case .upgradePending:
            "Error returned if keychain database needs a schema migration but the device is locked, clients should wait for a device unlock notification and retry the command."
        case .mpSignatureInvalid:
            "Signature invalid on MP message"
        case .otrTooOld:
            "Message is too old to use"
        case .otrIDTooNew:
            "Key ID is too new to use! Message from the future?"
        case .serviceNotAvailable:
            "The required service is not available."
        case .insufficientClientID:
            "The client ID is not correct."
        case .deviceReset:
            "A device reset has occurred."
        case .deviceFailed:
            "A device failure has occurred."
        case .appleAddAppACLSubject:
            "Adding an application ACL subject failed."
        case .applePublicKeyIncomplete:
            "The public key is incomplete."
        case .appleSignatureMismatch:
            "A signature mismatch has occurred."
        case .appleInvalidKeyStartDate:
            "The specified key has an invalid start date."
        case .appleInvalidKeyEndDate:
            "The specified key has an invalid end date."
        case .conversionError:
            "A conversion error has occurred."
        case .appleSSLv2Rollback:
            "A SSLv2 rollback error has occurred."
        case .quotaExceeded:
            "The quota was exceeded."
        case .fileTooBig:
            "The file is too big."
        case .invalidDatabaseBlob:
            "The specified database has an invalid blob."
        case .invalidKeyBlob:
            "The specified database has an invalid key blob."
        case .incompatibleDatabaseBlob:
            "The specified database has an incompatible blob."
        case .incompatibleKeyBlob:
            "The specified database has an incompatible key blob."
        case .hostNameMismatch:
            "A host name mismatch has occurred."
        case .unknownCriticalExtensionFlag:
            "There is an unknown critical extension flag."
        case .noBasicConstraints:
            "No basic constraints were found."
        case .noBasicConstraintsCA:
            "No basic CA constraints were found."
        case .invalidAuthorityKeyID:
            "The authority key ID is not valid."
        case .invalidSubjectKeyID:
            "The subject key ID is not valid."
        case .invalidKeyUsageForPolicy:
            "The key usage is not valid for the specified policy."
        case .invalidExtendedKeyUsage:
            "The extended key usage is not valid."
        case .invalidIDLinkage:
            "The ID linkage is not valid."
        case .pathLengthConstraintExceeded:
            "The path length constraint was exceeded."
        case .invalidRoot:
            "The root or anchor certificate is not valid."
        case .crlExpired:
            "The CRL has expired."
        case .crlNotValidYet:
            "The CRL is not yet valid."
        case .crlNotFound:
            "The CRL was not found."
        case .crlServerDown:
            "The CRL server is down."
        case .crlBadURI:
            "The CRL has a bad Uniform Resource Identifier."
        case .unknownCertExtension:
            "An unknown certificate extension was encountered."
        case .unknownCRLExtension:
            "An unknown CRL extension was encountered."
        case .crlNotTrusted:
            "The CRL is not trusted."
        case .crlPolicyFailed:
            "The CRL policy failed."
        case .idpFailure:
            "The issuing distribution point was not valid."
        case .smimeEmailAddressesNotFound:
            "An email address mismatch was encountered."
        case .smimeBadExtendedKeyUsage:
            "The appropriate extended key usage for SMIME was not found."
        case .smimeBadKeyUsage:
            "The key usage is not compatible with SMIME."
        case .smimeKeyUsageNotCritical:
            "The key usage extension is not marked as critical."
        case .smimeNoEmailAddress:
            "No email address was found in the certificate."
        case .smimeSubjAltNameNotCritical:
            "The subject alternative name extension is not marked as critical."
        case .sslBadExtendedKeyUsage:
            "The appropriate extended key usage for SSL was not found."
        case .ocspBadResponse:
            "The OCSP response was incorrect or could not be parsed."
        case .ocspBadRequest:
            "The OCSP request was incorrect or could not be parsed."
        case .ocspUnavailable:
            "OCSP service is unavailable."
        case .ocspStatusUnrecognized:
            "The OCSP server did not recognize this certificate."
        case .endOfData:
            "An end-of-data was detected."
        case .incompleteCertRevocationCheck:
            "An incomplete certificate revocation check occurred."
        case .networkFailure:
            "A network failure occurred."
        case .ocspNotTrustedToAnchor:
            "The OCSP response was not trusted to a root or anchor certificate."
        case .recordModified:
            "The record was modified."
        case .ocspSignatureError:
            "The OCSP response had an invalid signature."
        case .ocspNoSigner:
            "The OCSP response had no signer."
        case .ocspResponderMalformedReq:
            "The OCSP responder was given a malformed request."
        case .ocspResponderInternalError:
            "The OCSP responder encountered an internal error."
        case .ocspResponderTryLater:
            "The OCSP responder is busy, try again later."
        case .ocspResponderSignatureRequired:
            "The OCSP responder requires a signature."
        case .ocspResponderUnauthorized:
            "The OCSP responder rejected this request as unauthorized."
        case .ocspResponseNonceMismatch:
            "The OCSP response nonce did not match the request."
        case .codeSigningBadCertChainLength:
            "Code signing encountered an incorrect certificate chain length."
        case .codeSigningNoBasicConstraints:
            "Code signing found no basic constraints."
        case .codeSigningBadPathLengthConstraint:
            "Code signing encountered an incorrect path length constraint."
        case .codeSigningNoExtendedKeyUsage:
            "Code signing found no extended key usage."
        case .codeSigningDevelopment:
            "Code signing indicated use of a development-only certificate."
        case .resourceSignBadCertChainLength:
            "Resource signing has encountered an incorrect certificate chain length."
        case .resourceSignBadExtKeyUsage:
            "Resource signing has encountered an error in the extended key usage."
        case .trustSettingDeny:
            "The trust setting for this policy was set to Deny."
        case .invalidSubjectName:
            "An invalid certificate subject name was encountered."
        case .unknownQualifiedCertStatement:
            "An unknown qualified certificate statement was encountered."
        case .mobileMeRequestQueued:
            "The MobileMe request will be sent during the next connection."
        case .mobileMeRequestRedirected:
            "The MobileMe request was redirected."
        case .mobileMeServerError:
            "A MobileMe server error occurred."
        case .mobileMeServerNotAvailable:
            "The MobileMe server is not available."
        case .mobileMeServerAlreadyExists:
            "The MobileMe server reported that the item already exists."
        case .mobileMeServerServiceErr:
            "A MobileMe service error has occurred."
        case .mobileMeRequestAlreadyPending:
            "A MobileMe request is already pending."
        case .mobileMeNoRequestPending:
            "MobileMe has no request pending."
        case .mobileMeCSRVerifyFailure:
            "A MobileMe CSR verification failure has occurred."
        case .mobileMeFailedConsistencyCheck:
            "MobileMe has found a failed consistency check."
        case .notInitialized:
            "A function was called without initializing CSSM."
        case .invalidHandleUsage:
            "The CSSM handle does not match with the service type."
        case .pvcReferentNotFound:
            "A reference to the calling module was not found in the list of authorized callers."
        case .functionIntegrityFail:
            "A function address was not within the verified module."
        case .internalError:
            "An internal error has occurred."
        case .memoryError:
            "A memory error has occurred."
        case .invalidData:
            "Invalid data was encountered."
        case .mdsError:
            "A Module Directory Service error has occurred."
        case .invalidPointer:
            "An invalid pointer was encountered."
        case .selfCheckFailed:
            "Self-check has failed."
        case .functionFailed:
            "A function has failed."
        case .moduleManifestVerifyFailed:
            "A module manifest verification failure has occurred."
        case .invalidGUID:
            "An invalid GUID was encountered."
        case .invalidHandle:
            "An invalid handle was encountered."
        case .invalidDBList:
            "An invalid DB list was encountered."
        case .invalidPassthroughID:
            "An invalid passthrough ID was encountered."
        case .invalidNetworkAddress:
            "An invalid network address was encountered."
        case .crlAlreadySigned:
            "The certificate revocation list is already signed."
        case .invalidNumberOfFields:
            "An invalid number of fields were encountered."
        case .verificationFailure:
            "A verification failure occurred."
        case .unknownTag:
            "An unknown tag was encountered."
        case .invalidSignature:
            "An invalid signature was encountered."
        case .invalidName:
            "An invalid name was encountered."
        case .invalidCertificateRef:
            "An invalid certificate reference was encountered."
        case .invalidCertificateGroup:
            "An invalid certificate group was encountered."
        case .tagNotFound:
            "The specified tag was not found."
        case .invalidQuery:
            "The specified query was not valid."
        case .invalidValue:
            "An invalid value was detected."
        case .callbackFailed:
            "A callback has failed."
        case .aclDeleteFailed:
            "An ACL delete operation has failed."
        case .aclReplaceFailed:
            "An ACL replace operation has failed."
        case .aclAddFailed:
            "An ACL add operation has failed."
        case .aclChangeFailed:
            "An ACL change operation has failed."
        case .invalidAccessCredentials:
            "Invalid access credentials were encountered."
        case .invalidRecord:
            "An invalid record was encountered."
        case .invalidACL:
            "An invalid ACL was encountered."
        case .invalidSampleValue:
            "An invalid sample value was encountered."
        case .incompatibleVersion:
            "An incompatible version was encountered."
        case .privilegeNotGranted:
            "The privilege was not granted."
        case .invalidScope:
            "An invalid scope was encountered."
        case .pvcAlreadyConfigured:
            "The PVC is already configured."
        case .invalidPVC:
            "An invalid PVC was encountered."
        case .emmLoadFailed:
            "The EMM load has failed."
        case .emmUnloadFailed:
            "The EMM unload has failed."
        case .addinLoadFailed:
            "The add-in load operation has failed."
        case .invalidKeyRef:
            "An invalid key was encountered."
        case .invalidKeyHierarchy:
            "An invalid key hierarchy was encountered."
        case .addinUnloadFailed:
            "The add-in unload operation has failed."
        case .libraryReferenceNotFound:
            "A library reference was not found."
        case .invalidAddinFunctionTable:
            "An invalid add-in function table was encountered."
        case .invalidServiceMask:
            "An invalid service mask was encountered."
        case .moduleNotLoaded:
            "A module was not loaded."
        case .invalidSubServiceID:
            "An invalid subservice ID was encountered."
        case .attributeNotInContext:
            "An attribute was not in the context."
        case .moduleManagerInitializeFailed:
            "A module failed to initialize."
        case .moduleManagerNotFound:
            "A module was not found."
        case .eventNotificationCallbackNotFound:
            "An event notification callback was not found."
        case .inputLengthError:
            "An input length error was encountered."
        case .outputLengthError:
            "An output length error was encountered."
        case .privilegeNotSupported:
            "The privilege is not supported."
        case .deviceError:
            "A device error was encountered."
        case .attachHandleBusy:
            "The CSP handle was busy."
        case .notLoggedIn:
            "You are not logged in."
        case .algorithmMismatch:
            "An algorithm mismatch was encountered."
        case .keyUsageIncorrect:
            "The key usage is incorrect."
        case .keyBlobTypeIncorrect:
            "The key blob type is incorrect."
        case .keyHeaderInconsistent:
            "The key header is inconsistent."
        case .unsupportedKeyFormat:
            "The key header format is not supported."
        case .unsupportedKeySize:
            "The key size is not supported."
        case .invalidKeyUsageMask:
            "The key usage mask is not valid."
        case .unsupportedKeyUsageMask:
            "The key usage mask is not supported."
        case .invalidKeyAttributeMask:
            "The key attribute mask is not valid."
        case .unsupportedKeyAttributeMask:
            "The key attribute mask is not supported."
        case .invalidKeyLabel:
            "The key label is not valid."
        case .unsupportedKeyLabel:
            "The key label is not supported."
        case .invalidKeyFormat:
            "The key format is not valid."
        case .unsupportedVectorOfBuffers:
            "The vector of buffers is not supported."
        case .invalidInputVector:
            "The input vector is not valid."
        case .invalidOutputVector:
            "The output vector is not valid."
        case .invalidContext:
            "An invalid context was encountered."
        case .invalidAlgorithm:
            "An invalid algorithm was encountered."
        case .invalidAttributeKey:
            "A key attribute was not valid."
        case .missingAttributeKey:
            "A key attribute was missing."
        case .invalidAttributeInitVector:
            "An init vector attribute was not valid."
        case .missingAttributeInitVector:
            "An init vector attribute was missing."
        case .invalidAttributeSalt:
            "A salt attribute was not valid."
        case .missingAttributeSalt:
            "A salt attribute was missing."
        case .invalidAttributePadding:
            "A padding attribute was not valid."
        case .missingAttributePadding:
            "A padding attribute was missing."
        case .invalidAttributeRandom:
            "A random number attribute was not valid."
        case .missingAttributeRandom:
            "A random number attribute was missing."
        case .invalidAttributeSeed:
            "A seed attribute was not valid."
        case .missingAttributeSeed:
            "A seed attribute was missing."
        case .invalidAttributePassphrase:
            "A passphrase attribute was not valid."
        case .missingAttributePassphrase:
            "A passphrase attribute was missing."
        case .invalidAttributeKeyLength:
            "A key length attribute was not valid."
        case .missingAttributeKeyLength:
            "A key length attribute was missing."
        case .invalidAttributeBlockSize:
            "A block size attribute was not valid."
        case .missingAttributeBlockSize:
            "A block size attribute was missing."
        case .invalidAttributeOutputSize:
            "An output size attribute was not valid."
        case .missingAttributeOutputSize:
            "An output size attribute was missing."
        case .invalidAttributeRounds:
            "The number of rounds attribute was not valid."
        case .missingAttributeRounds:
            "The number of rounds attribute was missing."
        case .invalidAlgorithmParms:
            "An algorithm parameters attribute was not valid."
        case .missingAlgorithmParms:
            "An algorithm parameters attribute was missing."
        case .invalidAttributeLabel:
            "A label attribute was not valid."
        case .missingAttributeLabel:
            "A label attribute was missing."
        case .invalidAttributeKeyType:
            "A key type attribute was not valid."
        case .missingAttributeKeyType:
            "A key type attribute was missing."
        case .invalidAttributeMode:
            "A mode attribute was not valid."
        case .missingAttributeMode:
            "A mode attribute was missing."
        case .invalidAttributeEffectiveBits:
            "An effective bits attribute was not valid."
        case .missingAttributeEffectiveBits:
            "An effective bits attribute was missing."
        case .invalidAttributeStartDate:
            "A start date attribute was not valid."
        case .missingAttributeStartDate:
            "A start date attribute was missing."
        case .invalidAttributeEndDate:
            "An end date attribute was not valid."
        case .missingAttributeEndDate:
            "An end date attribute was missing."
        case .invalidAttributeVersion:
            "A version attribute was not valid."
        case .missingAttributeVersion:
            "A version attribute was missing."
        case .invalidAttributePrime:
            "A prime attribute was not valid."
        case .missingAttributePrime:
            "A prime attribute was missing."
        case .invalidAttributeBase:
            "A base attribute was not valid."
        case .missingAttributeBase:
            "A base attribute was missing."
        case .invalidAttributeSubprime:
            "A subprime attribute was not valid."
        case .missingAttributeSubprime:
            "A subprime attribute was missing."
        case .invalidAttributeIterationCount:
            "An iteration count attribute was not valid."
        case .missingAttributeIterationCount:
            "An iteration count attribute was missing."
        case .invalidAttributeDLDBHandle:
            "A database handle attribute was not valid."
        case .missingAttributeDLDBHandle:
            "A database handle attribute was missing."
        case .invalidAttributeAccessCredentials:
            "An access credentials attribute was not valid."
        case .missingAttributeAccessCredentials:
            "An access credentials attribute was missing."
        case .invalidAttributePublicKeyFormat:
            "A public key format attribute was not valid."
        case .missingAttributePublicKeyFormat:
            "A public key format attribute was missing."
        case .invalidAttributePrivateKeyFormat:
            "A private key format attribute was not valid."
        case .missingAttributePrivateKeyFormat:
            "A private key format attribute was missing."
        case .invalidAttributeSymmetricKeyFormat:
            "A symmetric key format attribute was not valid."
        case .missingAttributeSymmetricKeyFormat:
            "A symmetric key format attribute was missing."
        case .invalidAttributeWrappedKeyFormat:
            "A wrapped key format attribute was not valid."
        case .missingAttributeWrappedKeyFormat:
            "A wrapped key format attribute was missing."
        case .stagedOperationInProgress:
            "A staged operation is in progress."
        case .stagedOperationNotStarted:
            "A staged operation was not started."
        case .verifyFailed:
            "A cryptographic verification failure has occurred."
        case .querySizeUnknown:
            "The query size is unknown."
        case .blockSizeMismatch:
            "A block size mismatch occurred."
        case .publicKeyInconsistent:
            "The public key was inconsistent."
        case .deviceVerifyFailed:
            "A device verification failure has occurred."
        case .invalidLoginName:
            "An invalid login name was detected."
        case .alreadyLoggedIn:
            "The user is already logged in."
        case .invalidDigestAlgorithm:
            "An invalid digest algorithm was detected."
        case .invalidCRLGroup:
            "An invalid CRL group was detected."
        case .certificateCannotOperate:
            "The certificate cannot operate."
        case .certificateExpired:
            "An expired certificate was detected."
        case .certificateNotValidYet:
            "The certificate is not yet valid."
        case .certificateRevoked:
            "The certificate was revoked."
        case .certificateSuspended:
            "The certificate was suspended."
        case .insufficientCredentials:
            "Insufficient credentials were detected."
        case .invalidAction:
            "The action was not valid."
        case .invalidAuthority:
            "The authority was not valid."
        case .verifyActionFailed:
            "A verify action has failed."
        case .invalidCertAuthority:
            "The certificate authority was not valid."
        case .invaldCRLAuthority:
            "The CRL authority was not valid."
        case .invalidCRLEncoding:
            "The CRL encoding was not valid."
        case .invalidCRLType:
            "The CRL type was not valid."
        case .invalidCRL:
            "The CRL was not valid."
        case .invalidFormType:
            "The form type was not valid."
        case .invalidID:
            "The ID was not valid."
        case .invalidIdentifier:
            "The identifier was not valid."
        case .invalidIndex:
            "The index was not valid."
        case .invalidPolicyIdentifiers:
            "The policy identifiers are not valid."
        case .invalidTimeString:
            "The time specified was not valid."
        case .invalidReason:
            "The trust policy reason was not valid."
        case .invalidRequestInputs:
            "The request inputs are not valid."
        case .invalidResponseVector:
            "The response vector was not valid."
        case .invalidStopOnPolicy:
            "The stop-on policy was not valid."
        case .invalidTuple:
            "The tuple was not valid."
        case .multipleValuesUnsupported:
            "Multiple values are not supported."
        case .notTrusted:
            "The trust policy was not trusted."
        case .noDefaultAuthority:
            "No default authority was detected."
        case .rejectedForm:
            "The trust policy had a rejected form."
        case .requestLost:
            "The request was lost."
        case .requestRejected:
            "The request was rejected."
        case .unsupportedAddressType:
            "The address type is not supported."
        case .unsupportedService:
            "The service is not supported."
        case .invalidTupleGroup:
            "The tuple group was not valid."
        case .invalidBaseACLs:
            "The base ACLs are not valid."
        case .invalidTupleCredendtials:
            "The tuple credentials are not valid."
        case .invalidEncoding:
            "The encoding was not valid."
        case .invalidValidityPeriod:
            "The validity period was not valid."
        case .invalidRequestor:
            "The requestor was not valid."
        case .requestDescriptor:
            "The request descriptor was not valid."
        case .invalidBundleInfo:
            "The bundle information was not valid."
        case .invalidCRLIndex:
            "The CRL index was not valid."
        case .noFieldValues:
            "No field values were detected."
        case .unsupportedFieldFormat:
            "The field format is not supported."
        case .unsupportedIndexInfo:
            "The index information is not supported."
        case .unsupportedLocality:
            "The locality is not supported."
        case .unsupportedNumAttributes:
            "The number of attributes is not supported."
        case .unsupportedNumIndexes:
            "The number of indexes is not supported."
        case .unsupportedNumRecordTypes:
            "The number of record types is not supported."
        case .fieldSpecifiedMultiple:
            "Too many fields were specified."
        case .incompatibleFieldFormat:
            "The field format was incompatible."
        case .invalidParsingModule:
            "The parsing module was not valid."
        case .databaseLocked:
            "The database is locked."
        case .datastoreIsOpen:
            "The data store is open."
        case .missingValue:
            "A missing value was detected."
        case .unsupportedQueryLimits:
            "The query limits are not supported."
        case .unsupportedNumSelectionPreds:
            "The number of selection predicates is not supported."
        case .unsupportedOperator:
            "The operator is not supported."
        case .invalidDBLocation:
            "The database location is not valid."
        case .invalidAccessRequest:
            "The access request is not valid."
        case .invalidIndexInfo:
            "The index information is not valid."
        case .invalidNewOwner:
            "The new owner is not valid."
        case .invalidModifyMode:
            "The modify mode is not valid."
        case .missingRequiredExtension:
            "A required certificate extension is missing."
        case .extendedKeyUsageNotCritical:
            "The extended key usage extension was not marked critical."
        case .timestampMissing:
            "A timestamp was expected but was not found."
        case .timestampInvalid:
            "The timestamp was not valid."
        case .timestampNotTrusted:
            "The timestamp was not trusted."
        case .timestampServiceNotAvailable:
            "The timestamp service is not available."
        case .timestampBadAlg:
            "An unrecognized or unsupported Algorithm Identifier in timestamp."
        case .timestampBadRequest:
            "The timestamp transaction is not permitted or supported."
        case .timestampBadDataFormat:
            "The timestamp data submitted has the wrong format."
        case .timestampTimeNotAvailable:
            "The time source for the Timestamp Authority is not available."
        case .timestampUnacceptedPolicy:
            "The requested policy is not supported by the Timestamp Authority."
        case .timestampUnacceptedExtension:
            "The requested extension is not supported by the Timestamp Authority."
        case .timestampAddInfoNotAvailable:
            "The additional information requested is not available."
        case .timestampSystemFailure:
            "The timestamp request cannot be handled due to system failure."
        case .signingTimeMissing:
            "A signing time was expected but was not found."
        case .timestampRejection:
            "A timestamp transaction was rejected."
        case .timestampWaiting:
            "A timestamp transaction is waiting."
        case .timestampRevocationWarning:
            "A timestamp authority revocation warning was issued."
        case .timestampRevocationNotification:
            "A timestamp authority revocation notification was issued."
        case .unexpectedError:
            "Unexpected error has occurred."
        }
    }
}

// swiftlint:enable type_body_length line_length file_length
