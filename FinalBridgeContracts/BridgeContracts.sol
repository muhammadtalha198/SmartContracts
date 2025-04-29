/**
 *Submitted for verification at testnet.bscscan.com on 2025-04-09
*/

// File: Context.sol


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
abstract contract Context {
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
// File: Ownable.sol


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
abstract contract Ownable is Context {
    address private _owner;

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
    constructor(address initialOwner) {
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
        return _owner;
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
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
// File: Ownable2Step.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}
// File: Util.sol

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//


pragma solidity ^0.8.9;

/// @notice reverse the byte order of the uint256 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint256(uint256 input) pure returns (uint256 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
        | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

    // swap 2-byte long pairs
    v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
        | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

    // swap 4-byte long pairs
    v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
        | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

    // swap 8-byte long pairs
    v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
        | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

    // swap 16-byte long pairs
    v = (v >> 128) | (v << 128);
}

/// @notice reverse the byte order of the uint32 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint32(uint32 input) pure returns (uint32 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

    // swap 2-byte long pairs
    v = (v >> 16) | (v << 16);
}

/// @notice reverse the byte order of the uint16 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint16(uint16 input) pure returns (uint16 v) {
    v = input;

    // swap bytes
    v = (v >> 8) | ((v & 0x00FF) << 8);
}
// File: IRiscZeroVerifier.sol

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//


pragma solidity ^0.8.9;


/// @notice A receipt attesting to the execution of a guest program.
/// @dev A receipt contains two parts: a seal and a claim. The seal is a zero-knowledge proof
/// attesting to knowledge of a zkVM execution resulting in the claim. The claim is a set of public
/// outputs for the execution. Crucially, the claim includes the journal and the image ID. The
/// image ID identifies the program that was executed, and the journal is the public data written
/// by the program. Note that this struct only contains the claim digest, as can be obtained with
/// the `digest()` function on `ReceiptClaimLib`.
struct Receipt {
    bytes seal;
    bytes32 claimDigest;
}

/// @notice Public claims about a zkVM guest execution, such as the journal committed to by the guest.
/// @dev Also includes important information such as the exit code and the starting and ending system
/// state (i.e. the state of memory). `ReceiptClaim` is a "Merkle-ized struct" supporting
/// partial openings of the underlying fields from a hash commitment to the full structure.
struct ReceiptClaim {
    /// @notice Digest of the SystemState just before execution has begun.
    bytes32 preStateDigest;
    /// @notice Digest of the SystemState just after execution has completed.
    bytes32 postStateDigest;
    /// @notice The exit code for the execution.
    ExitCode exitCode;
    /// @notice A digest of the input to the guest.
    /// @dev This field is currently unused and must be set to the zero digest.
    bytes32 input;
    /// @notice Digest of the Output of the guest, including the journal
    /// and assumptions set during execution.
    bytes32 output;
}

library ReceiptClaimLib {
    using OutputLib for Output;
    using SystemStateLib for SystemState;

    bytes32 constant TAG_DIGEST = sha256("risc0.ReceiptClaim");

    // Define a constant to ensure hashing is done at compile time. Can't use the
    // SystemStateLib.digest method here because the Solidity compiler complains.
    bytes32 constant SYSTEM_STATE_ZERO_DIGEST = 0xa3acc27117418996340b84e5a90f3ef4c49d22c79e44aad822ec9c313e1eb8e2;

    /// @notice Construct a ReceiptClaim from the given imageId and journalDigest.
    ///         Returned ReceiptClaim will represent a successful execution of the zkVM, running
    ///         the program committed by imageId and resulting in the journal specified by
    ///         journalDigest.
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    /// @dev Input hash and postStateDigest are set to all-zeros (i.e. no committed input, or
    ///      final memory state), the exit code is (Halted, 0), and there are no assumptions
    ///      (i.e. the receipt is unconditional).
    function ok(bytes32 imageId, bytes32 journalDigest) internal pure returns (ReceiptClaim memory) {
        return ReceiptClaim(
            imageId,
            SYSTEM_STATE_ZERO_DIGEST,
            ExitCode(SystemExitCode.Halted, 0),
            bytes32(0),
            Output(journalDigest, bytes32(0)).digest()
        );
    }

    function digest(ReceiptClaim memory claim) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                claim.input,
                claim.preStateDigest,
                claim.postStateDigest,
                claim.output,
                // data
                uint32(claim.exitCode.system) << 24,
                uint32(claim.exitCode.user) << 24,
                // down.length
                uint16(4) << 8
            )
        );
    }
}

/// @notice Commitment to the memory state and program counter (pc) of the zkVM.
/// @dev The "pre" and "post" fields of the ReceiptClaim are digests of the system state at the
///      start are stop of execution. Programs are loaded into the zkVM by creating a memory image
///      of the loaded program, and creating a system state for initializing the zkVM. This is
///      known as the "image ID".
struct SystemState {
    /// @notice Program counter.
    uint32 pc;
    /// @notice Root hash of a merkle tree which confirms the integrity of the memory image.
    bytes32 merkle_root;
}

library SystemStateLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.SystemState");

    function digest(SystemState memory state) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                state.merkle_root,
                // data
                reverseByteOrderUint32(state.pc),
                // down.length
                uint16(1) << 8
            )
        );
    }
}

/// @notice Exit condition indicated by the zkVM at the end of the guest execution.
/// @dev Exit codes have a "system" part and a "user" part. Semantically, the system part is set to
/// indicate the type of exit (e.g. halt, pause, or system split) and is directly controlled by the
/// zkVM. The user part is an exit code, similar to exit codes used in Linux, chosen by the guest
/// program to indicate additional information (e.g. 0 to indicate success or 1 to indicate an
/// error).
struct ExitCode {
    SystemExitCode system;
    uint8 user;
}

/// @notice Exit condition indicated by the zkVM at the end of the execution covered by this proof.
/// @dev
/// `Halted` indicates normal termination of a program with an interior exit code returned from the
/// guest program. A halted program cannot be resumed.
///
/// `Paused` indicates the execution ended in a paused state with an interior exit code set by the
/// guest program. A paused program can be resumed such that execution picks up where it left
/// of, with the same memory state.
///
/// `SystemSplit` indicates the execution ended on a host-initiated system split. System split is
/// mechanism by which the host can temporarily stop execution of the execution ended in a system
/// split has no output and no conclusions can be drawn about whether the program will eventually
/// halt. System split is used in continuations to split execution into individually provable segments.
enum SystemExitCode {
    Halted,
    Paused,
    SystemSplit
}

/// @notice Output field in the `ReceiptClaim`, committing to a claimed journal and assumptions list.
struct Output {
    /// @notice Digest of the journal committed to by the guest execution.
    bytes32 journalDigest;
    /// @notice Digest of the ordered list of `ReceiptClaim` digests corresponding to the
    /// calls to `env::verify` and `env::verify_integrity`.
    /// @dev Verifying the integrity of a `Receipt` corresponding to a `ReceiptClaim` with a
    /// non-empty assumptions list does not guarantee unconditionally any of the claims over the
    /// guest execution (i.e. if the assumptions list is non-empty, then the journal digest cannot
    /// be trusted to correspond to a genuine execution). The claims can be checked by additional
    /// verifying a `Receipt` for every digest in the assumptions list.
    bytes32 assumptionsDigest;
}

library OutputLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.Output");

    function digest(Output memory output) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                output.journalDigest,
                output.assumptionsDigest,
                // down.length
                uint16(2) << 8
            )
        );
    }
}

/// @notice Error raised when cryptographic verification of the zero-knowledge proof fails.
error VerificationFailed();

/// @notice Verifier interface for RISC Zero receipts of execution.
interface IRiscZeroVerifier {
    /// @notice Verify that the given seal is a valid RISC Zero proof of execution with the
    ///     given image ID and journal digest. Reverts on failure.
    /// @dev This method additionally ensures that the input hash is all-zeros (i.e. no
    /// committed input), the exit code is (Halted, 0), and there are no assumptions (i.e. the
    /// receipt is unconditional).
    /// @param seal The encoded cryptographic proof (i.e. SNARK).
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    function verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) external view;

    /// @notice Verify that the given receipt is a valid RISC Zero receipt, ensuring the `seal` is
    /// valid a cryptographic proof of the execution with the given `claim`. Reverts on failure.
    /// @param receipt The receipt to be verified.
    function verifyIntegrity(Receipt calldata receipt) external view;
}
// File: RiscZeroVerifierRouter.sol

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//


pragma solidity ^0.8.9;



/// @notice Router for IRiscZeroVerifier, allowing multiple implementations to be accessible behind a single address.
contract RiscZeroVerifierRouter is IRiscZeroVerifier, Ownable2Step {
    /// @notice Mapping from 4-byte verifier selector to verifier contracts.
    ///         Used to route receipts to verifiers that are able to check the receipt.
    mapping(bytes4 => IRiscZeroVerifier) public verifiers;

    /// @notice Value of an entry that has never been set.
    IRiscZeroVerifier internal constant UNSET = IRiscZeroVerifier(address(0));
    /// @notice A "tombstone" value used to mark verifier entries that have been removed from the mapping.
    IRiscZeroVerifier internal constant TOMBSTONE = IRiscZeroVerifier(address(1));

    /// @notice Error raised when attempting to verify a receipt with a selector that is not
    ///         registered on this router. Generally, this indicates a version mismatch where the
    ///         prover generated a receipt with version of the zkVM that does not match any
    ///         registered version on this router contract.
    error SelectorUnknown(bytes4 selector);
    /// @notice Error raised when attempting to add a verifier for a selector that is already registered.
    error SelectorInUse(bytes4 selector);
    /// @notice Error raised when attempting to verify a receipt with a selector that has been
    ///         removed, or attempting to add a new verifier with a selector that was previously
    ///         registered and then removed.
    error SelectorRemoved(bytes4 selector);

    constructor(address admin) Ownable(admin) {}

    /// @notice Adds a verifier to the router, such that it can receive receipt verification calls.
    function addVerifier(bytes4 selector, IRiscZeroVerifier verifier) external onlyOwner {
        if (verifiers[selector] == TOMBSTONE) {
            revert SelectorRemoved({selector: selector});
        }
        if (verifiers[selector] != UNSET) {
            revert SelectorInUse({selector: selector});
        }
        verifiers[selector] = verifier;
    }

    /// @notice Removes verifier from the router, such that it can not receive verification calls.
    ///         Removing a selector sets it to the tombstone value. It can never be set to any
    ///         other value, and can never be reused for a new verifier, in order to enforce the
    ///         property that each selector maps to at most one implementation across time.
    function removeVerifier(bytes4 selector) external onlyOwner {
        // Simple check to reduce the chance of accidents.
        // NOTE: If there ever _is_ a reason to remove a selector that has never been set, the owner
        // can call addVerifier with the tombstone address.
        if (verifiers[selector] == UNSET) {
            revert SelectorUnknown({selector: selector});
        }
        verifiers[selector] = TOMBSTONE;
    }

    /// @notice Get the associatied verifier, reverting if the selector is unknown or removed.
    function getVerifier(bytes4 selector) public view returns (IRiscZeroVerifier) {
        IRiscZeroVerifier verifier = verifiers[selector];
        if (verifier == UNSET) {
            revert SelectorUnknown({selector: selector});
        }
        if (verifier == TOMBSTONE) {
            revert SelectorRemoved({selector: selector});
        }
        return verifier;
    }

    /// @notice Get the associatied verifier, reverting if the selector is unknown or removed.
    function getVerifier(bytes calldata seal) public view returns (IRiscZeroVerifier) {
        // Use the first 4 bytes of the seal at the selector to look up in the mapping.
        return getVerifier(bytes4(seal[0:4]));
    }

    /// @inheritdoc IRiscZeroVerifier
    function verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) external view {
        getVerifier(seal).verify(seal, imageId, journalDigest);
    }
    
    function _verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) internal view {
        getVerifier(seal).verify(seal, imageId, journalDigest);
    }
    
    function verifyWithJournal(bytes calldata seal, bytes32 imageId, bytes calldata journal) external view {
        getVerifier(seal).verify(seal, imageId, sha256(journal));
    }

    /// @inheritdoc IRiscZeroVerifier
    function verifyIntegrity(Receipt calldata receipt) external view {
        getVerifier(receipt.seal).verifyIntegrity(receipt);
    }
}


// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Quantova} from "./token.sol";

contract Bridge is Ownable {

    
    Quantova public qToken;
    RiscZeroVerifierRouter public verifierRouter;
    
    bytes32 public  IMAGE_ID;
    uint64 public outwardNonce;
    uint256[] public inwardNonce;
    uint256 public lastInwardNonce;
    bytes32 public lastFinalizedHash;
    

    struct RemittanceRecord {
        bool claimed;
        bool processed;
        uint256 amount;
        address beneficiary;

    }

    // Transfer data structure
    struct Transfer {
        uint256 nonce;
        address beneficiary;
        uint256 amount;
    }


    mapping(uint256 => RemittanceRecord) public outwardTransfers;
    mapping(uint256 => RemittanceRecord) public inwardClaims;

    event OutboundTransferInitiated(uint64 indexed nonce, address sender, address beneficiary, uint256 amount);
    event ClaimNonceRecord(uint256 indexed nonce, address beneficiary, uint256 amount, uint256 timestamp);
    event ProcessedTransaction(bytes32 indexed lastFinalizedHash, bytes32 indexed latestFinalizedHash, uint256 count);
    event NonceClaimed(uint256 indexed nonce, address claimer, uint256 amount, uint256 timestamp);
    event VerifierChanged(address oldVerifier, address newVerifier);
    event TokenContractChanged(address oldToken, address newToken);
    event VerificationSuccess(bytes32 indexed imageId, bytes32 journalHash);
    event VerificationFaild(bytes32 indexed imageId, string reason);

    error InvalidHashSequence();
    error InvalidHashLength();
    error BatchAlreadyProcessed();
    error NotOwner(address caller);
    error ZeroAmount(uint256 amount);
    error InvalidImageId(bytes32 _imageId);
    error NonceDoesNotExist(bool processed);
    error NonceAlreadyClaimed(bool claimed);
    error TransferAlreadyProcessed(uint256 nonce);
    error InvalidBeneficiary(address beneficiary);
    error InvalidTokenAddress(address tokenAddress);
    error InvalidVerifierAddress(address verifierAddress);
    error NonceSequenceViolation(uint256 expected, uint256 actual);


    constructor(address verifierAddress, address tokenAddress, bytes32 _imageId,address initialOwner) Ownable(initialOwner) {

        if (verifierAddress == address(0)) revert InvalidVerifierAddress(verifierAddress);
        if (tokenAddress == address(0)) revert InvalidTokenAddress(tokenAddress);
        if (_imageId == bytes32(0)) revert InvalidImageId(_imageId);

        verifierRouter = RiscZeroVerifierRouter(verifierAddress);
        qToken = Quantova(tokenAddress);
        IMAGE_ID = _imageId;

    }

    function transferOut(address beneficiary, uint256 amount) external {
        
        if (amount == 0) revert ZeroAmount(amount);
        if (beneficiary == address(0)) revert InvalidBeneficiary(beneficiary);
        
        
        outwardNonce++;
        uint64 currentNonce = outwardNonce;
        outwardTransfers[currentNonce].amount = amount;
        outwardTransfers[currentNonce].beneficiary = beneficiary;

        qToken.burnFrom(msg.sender, amount);
        
        emit OutboundTransferInitiated(currentNonce, msg.sender, beneficiary, amount);
    }


    function bridgeWithVerificationDebug(bytes calldata seal, bytes calldata journal, bytes calldata postStateJournal) external {
        try verifierRouter.verifyWithJournal(seal, IMAGE_ID, journal) {
            _processVerifiedTransaction(postStateJournal);
            emit VerificationSuccess(IMAGE_ID, sha256(journal));
        } catch Error(string memory reason) {
            emit VerificationFaild(IMAGE_ID, reason);
        } catch (bytes memory) {
            emit VerificationFaild(IMAGE_ID, "Low-level verification error");
        }
    }


    function _processVerifiedTransaction(bytes calldata journal) private {
        
        (bytes memory lastFinalizedHashBytes, Transfer[] memory transfers, bytes memory latestFinalizedHashBytes) = abi.decode(journal, (bytes, Transfer[], bytes));
        
        if (lastFinalizedHashBytes.length != 32 || lastFinalizedHashBytes.length != 32) {
            revert InvalidHashLength();
        }
        
        bytes32 _lastFinalizedHash = abi.decode(lastFinalizedHashBytes, (bytes32));
        bytes32 _latestFinalizedHash = abi.decode(latestFinalizedHashBytes, (bytes32));

        if (_latestFinalizedHash == lastFinalizedHash) revert BatchAlreadyProcessed();
        
        if (_latestFinalizedHash != bytes32(0)) {
            if (_lastFinalizedHash != lastFinalizedHash) revert InvalidHashSequence();

        }

        if (transfers.length > 0) {

            for (uint256 i = 0; i < transfers.length; i++) {

                uint256 expected = lastInwardNonce + 1;
                uint256 actual = transfers[i].nonce;

                if (actual != expected) {
                    revert NonceSequenceViolation(expected, actual);
                }
                
                Transfer memory transfer = transfers[i];
                
                if (i > 0) {
                    if (transfer.nonce != transfers[i-1].nonce + 1) {
                        revert NonceSequenceViolation(transfers[i-1].nonce, transfer.nonce);
                    }
                }

                if (inwardClaims[transfer.nonce].processed){
                    revert TransferAlreadyProcessed(transfer.nonce);
                }
                
                inwardClaims[transfer.nonce].processed = true;
                
                inwardClaims[transfer.nonce].amount = transfer.amount;
                inwardClaims[transfer.nonce].beneficiary = transfer.beneficiary;
                inwardNonce.push(transfer.nonce);
                
                emit ClaimNonceRecord(transfer.nonce, transfer.beneficiary, transfer.amount, block.timestamp);
            }
        }

        lastFinalizedHash =_latestFinalizedHash;
        emit ProcessedTransaction(_lastFinalizedHash, _latestFinalizedHash, transfers.length);
    }

    function claim(uint256 nonce) external {
        
        if (!inwardClaims[nonce].processed){
            revert NonceDoesNotExist(inwardClaims[nonce].processed);  
        }

        if (inwardClaims[nonce].claimed){  
            revert NonceAlreadyClaimed(inwardClaims[nonce].claimed);
        }
                
        inwardClaims[nonce].processed = true;
        qToken.mint(inwardClaims[nonce].beneficiary, inwardClaims[nonce].amount);

        emit NonceClaimed(nonce, inwardClaims[nonce].beneficiary, inwardClaims[nonce].amount, block.timestamp);
    }

    function setVerifier(address newVerifier) external {
        
        if (msg.sender != owner()) {
            revert NotOwner(msg.sender);
        }

        if (newVerifier == address(0)) {
            revert InvalidVerifierAddress(newVerifier);
        }

        address oldVerifier = address(verifierRouter);
        verifierRouter = RiscZeroVerifierRouter(newVerifier);
        
        emit VerifierChanged(oldVerifier, newVerifier);
    }

    function setTokenContract(address newToken) external {
       
        if (msg.sender != owner()) {
            revert NotOwner(msg.sender);
        }

        if (newToken == address(0)) {
            revert InvalidTokenAddress(newToken);
        }

        address oldToken = address(qToken); // store the old qToken contract address

        qToken = Quantova(newToken);

        emit TokenContractChanged(oldToken, newToken);
    }

    function getinwardNonceCount() external view returns (uint256) {
        return inwardNonce.length;
    }
}
