
// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;



/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/interfaces/draft-IERC1822.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// File: @openzeppelin/contracts/proxy/beacon/IBeacon.sol


// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// File: @openzeppelin/contracts/utils/StorageSlot.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}

// File: @openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol


// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;




/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.20;




/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// File: @openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;



/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.20;


/**
 * @dev Interface that must be implemented by smart contracts in order to receive
 * ERC-1155 token transfers.
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// File: @openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.20;





/**
 * @dev Simple implementation of `IERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 */
abstract contract ERC1155HolderUpgradeable is Initializable, ERC165Upgradeable, IERC1155Receiver {
    function __ERC1155Holder_init() internal onlyInitializing {
    }

    function __ERC1155Holder_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

// File: ProfitOrg/marketPlace.sol


pragma solidity ^0.8.20;







interface MintingContract{

    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address);
    function getFiscalSponsor(address _organizationAddress) external view returns (bool,uint256, address, address);
}


contract Marketplace is 
    Initializable, 
    ERC1155HolderUpgradeable ,
    OwnableUpgradeable, 
    UUPSUpgradeable {


    MintingContract public mintingContract;

    
    uint256 public listId;
    uint256 public adminFeePercentage;
    address public mintingContractAddress;

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
 
    function initialize(address _mintingContract, address _ownerAddress) initializer public {

        adminFeePercentage = 250; 
        mintingContractAddress = _mintingContract;
        mintingContract = MintingContract(_mintingContract);

        __ERC1155Holder_init();
        __Ownable_init(_ownerAddress);
        __UUPSUpgradeable_init();
       
    }

     struct List {

        bool listed;
        bool nftClaimed;
        bool fixedPrice;
        uint256 serviceFeePercentage;
        uint256 price;
        uint256 tokenId;
        uint256 noOfCopies;
        address nftOwner;
        address newOwner;
        address nftAddress;
        uint256 listingEndTime;      
        uint256 listingStartTime;

    }

    struct DonationInfo{

        uint256 noOfOrgazisations;
        address[10] organizations;
        uint256[10] donatePercentages;
    }

    mapping (uint256 => List) public listing;
    mapping (uint256 => DonationInfo) public donationInfo;
    mapping(address => uint256) public defaultFiscalFee;

    event SetFiscalFee(address fiscalAddress, uint256 feePercentage);
    event plateFarmFeePercentage(uint256 _serviceFeePercentage,address _owner);
    event CancelList(address _listerAddress, uint256 _listingID, bool _isListed);
    event Edited (uint256 _initialPrice,uint256 _listStartTime,uint256 _listEndTime);
    event Bided( address _currentBidder, uint256 _bidAmount, uint256 _previousBidAmount); 
    event SoldNft(address _from,uint256 indexed _tokenId,address indexed _nftAddress,address _to,uint256 _noOfCopirs);
    event FeeInfo(uint256 fiscalFee, uint256 royaltyFee,uint256 indexed serviceFee,uint256 indexed donationFee, uint256 indexed amountSendToSeller);
    event Listed(uint256 _listId,uint256 _tokenId, uint256 _noOfCopies, uint256 _initialPrices);
    

    error notListed(bool listed);
    error invalidFee(uint256 fee);
    error zeroValue(uint256 value);
    error onAuction(bool onAuction);
    error ownerCantBuy(address owner);
    error bidStarted(address newOwner);
    error alreadyClaimed(bool claimed);
    error wrongTokenId(uint256 wrongId);
    error transferFailed(bool transfer);
    error onFixedPrice(bool onfixedPrice);
    error wrongListingId(uint256 listingid);
    error selectOrganization(bool selected);
    error zeroPercentage(uint256 percentage);
    error wrongNoOfCopies(uint256 noOfcopies);
    error wrongAddress(address contractAddres);
    error initialPriceZero(uint256 initialPrice);
    error wrongFiscalSponsor(address fiscalSponsor);
    error invalidFiscalPercentage(uint256 fiscalFee);
    error NotAuthorizedError(address callingAddress);
    error worngOrganizationlength(uint256 organizationLength);
    error invalidTimeStamp(uint256 startTime, uint256 endTime);
    error invalidDonationPercentage(uint256 donationPercentage);
    error InvalidServiceFeePercentage(uint256 servicePercentage);
    error lengthDontMatch(uint256 organizationLength, uint256 percentagesLength);

    //--List item for list--------------------------------------------------------------------/

    function listForUsers(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        uint256 _tokenId,
        uint256 _noOfCopies,
        uint256 _serviceFee,
        address _nftAddress,
        address[] memory _organizations,
        uint256[] memory _donatePercentages
    ) external checkOrganizations( _organizations,_donatePercentages) {

        if(_initialPrice <= 0){
            revert initialPriceZero(_initialPrice);
        }
        
        if(_tokenId <= 0){
            revert wrongTokenId(_tokenId);
        }

        if(_noOfCopies <= 0){
            revert wrongNoOfCopies(_noOfCopies);
        }

        listId++;
        
        setListingInfo(_tokenId,_noOfCopies,_initialPrice,_listStartTime,_listEndTime,_nftAddress,_serviceFee);    
        setDonationInfo(listId, _organizations, _donatePercentages);

        if(_nftAddress != mintingContractAddress){

            setMintingAddress( _tokenId, _noOfCopies,  listId,  _nftAddress);
        }else{
            setMintingAddress( _tokenId, _noOfCopies,  listId,  mintingContractAddress); 
        }

        emit Listed(
            listId,
            _tokenId, 
            _noOfCopies,
            _initialPrice
        );
    }

   
    function listForOrganizations(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        uint256 _serviceFee,
        address _fiscalSponsor
    ) external checkFiscalSponsor(_fiscalSponsor){
        
        if(_initialPrice <= 0){
            revert initialPriceZero(_initialPrice);
        }
        
        if(_tokenId <= 0){
            revert wrongTokenId(_tokenId);
        }

        if(_noOfCopies <= 0){
            revert wrongNoOfCopies(_noOfCopies);
        }


        listId++;

        setListingInfo(_tokenId,_noOfCopies,_initialPrice,_listStartTime,_listEndTime,_nftAddress, _serviceFee);
        

        if(_nftAddress != mintingContractAddress){

            setMintingAddress( _tokenId, _noOfCopies,  listId,  _nftAddress);
        }else{

            setMintingAddress( _tokenId, _noOfCopies,  listId,  mintingContractAddress); 
        }

        emit Listed(
            listId,
            _tokenId, 
            _noOfCopies,
            _initialPrice
        );

   }

    function editList(
        uint256 _listId, 
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        uint256 _serviceFee ) external checkSell( _listId) {

        if(block.timestamp < listing[_listId].listingStartTime || block.timestamp > listing[_listId].listingEndTime){

            revert invalidTimeStamp(listing[_listId].listingStartTime,listing[_listId].listingEndTime );
        }

        if(msg.sender != listing[_listId].nftOwner){
            revert NotAuthorizedError(listing[_listId].nftOwner);
        }

        if(_listStartTime != 0 && _listEndTime != 0){

            if(listing[_listId].newOwner != address(0)){
                revert bidStarted(listing[_listId].newOwner);
            }
        }


        setListingInfo(
            
            listing[_listId].tokenId,
            listing[_listId].noOfCopies,
            _initialPrice,
            _listStartTime,
            _listEndTime,
            listing[_listId].nftAddress,
            _serviceFee
        );
        
        emit Edited (
            listing[_listId].price,
            listing[_listId].listingStartTime,
            listing[_listId].listingEndTime
        );

    }

  
    // Buy Fixed Price---------------------------------------------------------------------------------------------------
    function BuyFixedPriceItem(uint256 _listId) payable external checkSell(_listId)  { 
        
        if(msg.value !=  listing[_listId].price){
            revert invalidFee(msg.value);
        }
        if(!listing[_listId].fixedPrice){
            revert onAuction(listing[_listId].fixedPrice);
        }
        
        if(msg.sender == listing[_listId].nftOwner){
            revert ownerCantBuy(listing[_listId].nftOwner);
        }

        listing[_listId].newOwner = msg.sender;
        
        uint256 serviceFee;

        if (listing[_listId].serviceFeePercentage != 0){
            
             serviceFee = calulateFee(listing[_listId].price, listing[_listId].serviceFeePercentage);
        }else{

             serviceFee = calulateFee(listing[_listId].price, adminFeePercentage);
        }

        uint256 donationFee;

        if(donationInfo[_listId].noOfOrgazisations > 0){

           donationFee =  donationFeeTransfer(_listId); 
        }


        (bool _haveSponsor,,,)  = mintingContract.getFiscalSponsor(listing[_listId].nftOwner);
        
        uint256 fiscalFee;
        
        if(_haveSponsor){
             fiscalFee =  sendFiscalFee(_listId,address(0),0);
        }
        
        uint256 royaltyFee =  sendRoyalityFee(_listId);
        uint256 amountSendToSeller = listing[_listId].price - (serviceFee + donationFee + fiscalFee + royaltyFee);
        
        transferFundsInEth(payable (owner()) ,serviceFee);

        transferFundsInEth(payable(listing[_listId].nftOwner) , amountSendToSeller);
        
        listing[_listId].nftClaimed = true;

        transferNft(
            listing[_listId].nftAddress,
            address(this),
            listing[_listId].newOwner, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        );

        emit SoldNft(
            address(this),
            listing[_listId].tokenId,
            listing[_listId].nftAddress,
            listing[_listId].newOwner,
            listing[_listId].noOfCopies);

        emit FeeInfo(
            fiscalFee,
            royaltyFee,
            serviceFee,
            donationFee,
            amountSendToSeller);
    }


    function startBid( uint256 _listId)  external payable checkSell(_listId)  {

        if(listing[_listId].fixedPrice){
            revert onFixedPrice(listing[_listId].fixedPrice);
        }
        
        if(msg.value <=  0 || msg.value < listing[_listId].price){
            revert invalidFee(msg.value);
        } 
        
        if(block.timestamp < listing[_listId].listingStartTime || block.timestamp > listing[_listId].listingEndTime){
            revert invalidTimeStamp(listing[_listId].listingStartTime,listing[_listId].listingEndTime );
        } 

        if(msg.sender == listing[_listId].nftOwner){
            revert ownerCantBuy(listing[_listId].nftOwner);
        }
        

        uint256 _currentBidAmount = listing[_listId].price;
        address  _currentBidder = listing[_listId].newOwner;

        if(_currentBidAmount > 0 && _currentBidder != address(0)){
            transferFundsInEth(payable(_currentBidder), _currentBidAmount);
        }


        listing[_listId].price = msg.value;
        listing[_listId].newOwner = msg.sender;


        emit Bided(

            listing[_listId].newOwner,
            listing[_listId].price,
            _currentBidAmount
            );

    }
   

    function endAuction(uint256 _listId) external checkSell(_listId)  {

        if(listing[_listId].fixedPrice){
            revert onFixedPrice(listing[_listId].fixedPrice);
        }

        if(msg.sender != listing[_listId].nftOwner && msg.sender != listing[_listId].newOwner){
             revert NotAuthorizedError(msg.sender);
        }


        if(block.timestamp < listing[_listId].listingEndTime){
            revert invalidTimeStamp(listing[_listId].listingStartTime,listing[_listId].listingEndTime);
        }
        

        uint256 serviceFee;

        if (listing[_listId].serviceFeePercentage != 0){
            
             serviceFee = calulateFee(listing[_listId].price, listing[_listId].serviceFeePercentage);
        }else{

             serviceFee = calulateFee(listing[_listId].price, adminFeePercentage);
        }

        uint256 donationFee;

        if(donationInfo[_listId].noOfOrgazisations > 0){
            donationFee =  donationFeeTransfer(_listId);
        }

        (bool _haveSponsor,,,)  = mintingContract.getFiscalSponsor(listing[_listId].nftOwner);
        
        uint256 fiscalFee;
        
        if(_haveSponsor){
             fiscalFee =  sendFiscalFee(_listId,address(0),0);
        }

        uint256 royaltyFee =  sendRoyalityFee(_listId);
        uint256 amountSendToSeller = listing[_listId].price - (serviceFee + donationFee + fiscalFee + royaltyFee);
        

        transferFundsInEth(payable(owner()) ,serviceFee);

        transferFundsInEth(payable(listing[_listId].nftOwner) , amountSendToSeller);

        listing[_listId].nftClaimed = true;

        transferNft(
            listing[_listId].nftAddress,
            address(this),
            listing[_listId].newOwner, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        ); 

        emit SoldNft(
            address(this),
            listing[_listId].tokenId,
            listing[_listId].nftAddress,
            listing[_listId].newOwner,
            listing[_listId].noOfCopies);

        emit FeeInfo(
            fiscalFee,
            royaltyFee,
            serviceFee,
            donationFee,
            amountSendToSeller);     


    }

    function cancellListingForlist(uint256 _listingID) external {
        
        if(msg.sender != listing[_listingID].nftOwner){
             revert NotAuthorizedError(msg.sender);
        }

        if(listing[_listingID].nftClaimed){
            revert alreadyClaimed(listing[_listingID].nftClaimed);
        }

       if(listing[_listingID].listingStartTime != 0 && listing[_listingID].listingEndTime != 0){

            if(listing[_listingID].newOwner != address(0)){
                revert bidStarted(listing[_listingID].newOwner);
            }
        }
        
        transferNft(
            listing[_listingID].nftAddress,
            address(this),
            listing[_listingID].nftOwner, 
            listing[_listingID].tokenId, 
            listing[_listingID].noOfCopies
        );

        setCancelList(_listingID);

        emit CancelList(msg.sender, _listingID, listing[_listingID].listed);

    }

    function setPlatFormServiceFeePercentage(uint256 _serviceFeePercentage) external onlyOwner{

        if( _serviceFeePercentage <= 0  ||  _serviceFeePercentage > 3000){
            revert InvalidServiceFeePercentage(_serviceFeePercentage);
        }

        adminFeePercentage = _serviceFeePercentage;
        
        emit plateFarmFeePercentage(adminFeePercentage,msg.sender);
    }


    function setDonationInfo(uint256 _priceId,address[] memory _organizations,uint256 [] memory _donatePercentages) private {

        for(uint256 i=0; i < _organizations.length; i++){
            
            if(_organizations[i] != address(0)){
                donationInfo[_priceId].organizations[i] = _organizations[i];
                donationInfo[_priceId].donatePercentages[i] = _donatePercentages[i];
                donationInfo[_priceId].noOfOrgazisations += 1;
            }
        }
    }

     function setListingInfo(
        uint256 _tokenId,
        uint256 _noOfCopies,
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        address _nftAddress,
        uint256 _serviceFee
        ) 
        
        private checkForList (
            _initialPrice,
            _listStartTime,
            _listEndTime,
            _tokenId,
            _noOfCopies,
            _nftAddress) 
        {

        if(_listStartTime == 0 && _listEndTime == 0){
            listing[listId].fixedPrice  =  true;
        }

        listing[listId].listed = true;
        listing[listId].tokenId = _tokenId;
        listing[listId].noOfCopies = _noOfCopies;
        listing[listId].price = _initialPrice;
        listing[listId].listingStartTime = _listStartTime;
        listing[listId].listingEndTime = _listEndTime;
        listing[listId].nftOwner = msg.sender;
        listing[listId].serviceFeePercentage = _serviceFee;
    }

    function donationFeeTransfer(uint256 _listId) private returns (uint256) {

        uint256 totalDonationAmount = 0;

        for (uint256 i = 0; i < donationInfo[_listId].noOfOrgazisations; i++) {
           
            if ( donationInfo[_listId].organizations[i] != address(0)) {
               
                uint256 donationAmount = calulateFee(listing[_listId].price,  donationInfo[_listId].donatePercentages[i]);
                
                (bool _haveSponsor,,,)  = mintingContract.getFiscalSponsor(donationInfo[_listId].organizations[i]);
        
                 uint256 _fiscalFee;
        
                    if(_haveSponsor){
                         _fiscalFee = sendFiscalFee(0,donationInfo[_listId].organizations[i],donationAmount);
                    }
                uint256 transferDonationAmount = donationAmount - _fiscalFee;
               
                transferFundsInEth(payable(donationInfo[_listId].organizations[i]), transferDonationAmount);
                totalDonationAmount += donationAmount;
            }
        }

        return totalDonationAmount;
    }

     function  sendFiscalFee(uint256 _listId,address organizationAddress, uint256 _feeAmount) private returns (uint256){

        uint256 fiscalFee;

        address _nftOwner = (_listId != 0 && organizationAddress == address(0) && _feeAmount == 0) 
                    ? listing[_listId].nftOwner 
                    : organizationAddress;

        (,
            uint256 _fiscalSponsorPercentage,
            address _fiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(_nftOwner);

            if(_fiscalSponsorPercentage == 0){

                _fiscalSponsorPercentage = defaultFiscalFee[_fiscalSponser];

                if(_fiscalSponsorPercentage == 0){

                    _fiscalSponsorPercentage = 1000; // 10%
                }
            }

        uint256 _amount = (_listId != 0 && _feeAmount == 0) ? listing[_listId].price : _feeAmount;

        fiscalFee = calulateFee(_amount, _fiscalSponsorPercentage);
        transferFundsInEth(payable(_fiscalSponser),fiscalFee);

        return fiscalFee;
    }

    function  sendRoyalityFee(uint256 _listId) private returns (uint256){

        uint256 royaltyFee;
  
        if(mintingContractAddress == listing[_listId].nftAddress){
            
            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(listing[_listId].tokenId);
            
            royaltyFee = calulateFee(listing[_listId].price, _royaltyPercentage);
            transferFundsInEth(payable(_royaltyReciver),royaltyFee); 
        }

        return royaltyFee;
    }

    function setMintingAddress(uint256 _tokenId,uint256 _noOfCopies, uint256 priceId, address setAddress) private {

        listing[priceId].nftAddress = setAddress;

        transferNft(
            setAddress,
            msg.sender,
            address(this), 
            _tokenId, 
            _noOfCopies
        );

    }

    function transferNft(
        address _nftAddress,
        address _from, 
        address _to, 
        uint256 _tokenId,  
        uint256 _noOfcopies
    ) private {

         IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                _from,
                _to,
                _tokenId,
                _noOfcopies,
                '0x00'
            );

    }

    function setCancelList(uint256 _listingID) private {

        listing[_listingID].fixedPrice = false;
        listing[_listingID].listed = false;
        listing[_listingID].tokenId = 0;
        listing[_listingID].noOfCopies = 0;
        listing[_listingID].price = 0;
        listing[_listingID].listingEndTime = 0;
        listing[_listingID].listingStartTime = 0;
        listing[_listingID].nftAddress = address(0);
        listing[_listingID].nftOwner = address(0);

    }

    

    function calulateFee(uint256 _salePrice , uint256 _serviceFeePercentage) private pure returns(uint256){
        
        if(_salePrice == 0){
            revert zeroValue(_salePrice);
        }

        if(_serviceFeePercentage == 0){
            revert zeroPercentage(_serviceFeePercentage);
        }

        uint256 serviceFee = (_salePrice * _serviceFeePercentage) / (10000);
        
        return serviceFee;
    }


    function transferFundsInEth(address payable _recipient, uint256 _amount) private {

        (bool success, ) = _recipient.call{value: _amount}("");
        
        if(!success){
            revert transferFailed(success);
        }

    }


    function setFiscalSponsorPercentage(uint256 _fiscalSponsorPercentage) external {
        
        if(_fiscalSponsorPercentage < 100  || _fiscalSponsorPercentage > 1000){
            revert invalidFiscalPercentage(_fiscalSponsorPercentage);
        }
        
        defaultFiscalFee[msg.sender] = _fiscalSponsorPercentage;

        emit SetFiscalFee(msg.sender, _fiscalSponsorPercentage);
    }


    modifier checkOrganizations(address[] memory _organizations,uint256[] memory _donatePercentages){

        if(_organizations.length <= 0 && _organizations.length > 10){
            revert worngOrganizationlength(_organizations.length);
        }

        if(_organizations.length != _donatePercentages.length){
            revert lengthDontMatch(_organizations.length,_donatePercentages.length);
        }
        
        bool atleastOne;
        for(uint i=0; i < _organizations.length; i++){
            if(_organizations[i] != address(0)){

                if(_donatePercentages[i] < 500){
                    revert invalidDonationPercentage(_donatePercentages[i]);
                }

                atleastOne = true;
            }
        }

        if(!atleastOne){
            revert selectOrganization(atleastOne);
        }
        _;
    }


    modifier checkForList (
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress
    ){
        if(_initialPrice <= 0){
            revert initialPriceZero(_initialPrice);
        }
        
        if(_tokenId <= 0){
            revert wrongTokenId(_tokenId);
        }

        if(_noOfCopies <= 0){
            revert wrongNoOfCopies(_noOfCopies);
        }
        
        if(_nftAddress == address(0)){
            revert wrongAddress(_nftAddress);
        } 
        
        if (_listStartTime != 0 && _listEndTime != 0 ){

            if(_listStartTime <= block.timestamp && _listEndTime < _listStartTime){
                revert invalidTimeStamp(_listStartTime,_listEndTime);
            }
        }
        _;        
    }
    
    modifier checkSell(uint256 _listId) {

        if(_listId <= 0){
            revert wrongListingId(_listId);
        }

        if(!listing[_listId].listed){
            revert notListed(listing[_listId].listed);
        }

        if(listing[_listId].nftClaimed){
            revert alreadyClaimed(listing[_listId].nftClaimed);
        }
        _;
    }

    modifier checkFiscalSponsor(address _fiscalSponsor) {
        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _previousFiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);
        
        if(_haveSponsor){
            if(_fiscalSponsor != _previousFiscalSponser){
                revert wrongFiscalSponsor(_fiscalSponsor);
            }
            // require(_fiscalSponsorPercentage != 0, "Your Fiscal Sponsor didnt set fee Yet!");
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {} 


}

// 0x0000000000000000000000000000000000000000

// org1 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
// org2 = 0x583031D1113aD414F02576BD6afaBfb302140225
// org3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// fiscl = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C
// fiscal  = 0xdDb68Efa4Fdc889cca414C0a7AcAd3C5Cc08A8C5

//  mint :0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8

//  nft = 0x3c725134d74D5c45B4E4ABd2e5e2a109b5541288