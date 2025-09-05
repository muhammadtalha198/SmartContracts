// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AlvaraOracle is AccessControl {
    using ECDSA for bytes32;
    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");

    struct PriceData {
        uint128 price;     // WETH per token, scaled 1e18
        uint8 decimals;    // token decimals
        uint64 updatedAt;  // last update time
    }

    mapping(address => PriceData) public prices;
    uint256 public maxAge = 120;           // 2 minutes
    uint256 public maxDeviationBps = 100;  // 1% slippage allowed

    // EIP-712 typed-data config
    mapping(address => uint256) public userNonces;
    
    address public authorizedSigner;
    bytes32 private DOMAIN_SEPARATOR;
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("AlvaraOracle");
    bytes32 private constant VERSION_HASH = keccak256("1");
    // PriceBatch(bytes32 tokensHash,bytes32 pricesHash,bytes32 decimalsHash,uint256 deadline,address feeder,uint256 nonce)
    bytes32 private constant PRICE_BATCH_TYPEHASH = keccak256("PriceBatch(bytes32 tokensHash,bytes32 pricesHash,bytes32 decimalsHash,uint256 deadline,address feeder,uint256 nonce)");

    event PriceUpdated(address token, uint128 price, uint8 decimals);
    event PriceDeviationHigh(address token, uint256 expectedAmount, uint256 actualAmount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEEDER_ROLE, admin);
        authorizedSigner = admin;
        uint256 chainId;
        assembly { chainId := chainid() }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                NAME_HASH,
                VERSION_HASH,
                chainId,
                address(this)
            )
        );
    }

    // --- Feeder functions ---
    function setPrice(address token, uint128 price, uint8 decimals) external onlyRole(FEEDER_ROLE) {
        prices[token] = PriceData(price, decimals, uint64(block.timestamp));
        emit PriceUpdated(token, price, decimals);
    }



    /// @notice EIP-712 signed batch update by authorized signer
    function setPricesBatchSigned(
        address[] calldata tokens,
        uint128[] calldata priceList,
        uint8[] calldata decimalsList,
        uint256 deadline,
        address feeder,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(msg.sender == authorizedSigner, "Caller not authorizedSigner");
        require(tokens.length == priceList.length && tokens.length == decimalsList.length, "Length mismatch");
        require(deadline >= block.timestamp, "Deadline passed");
        require(nonce == userNonces[feeder], "Invalid nonce");

        _verifyPriceBatchSignature(tokens, priceList, decimalsList, deadline, feeder, nonce, signature);
        _updatePricesBatch(tokens, priceList, decimalsList);
        _consumeNonce(feeder, nonce);
    }

    function _verifyPriceBatchSignature(
        address[] calldata tokens,
        uint128[] calldata priceList,
        uint8[] calldata decimalsList,
        uint256 deadline,
        address feeder,
        uint256 nonce,
        bytes calldata signature
    ) private view {
        // Hash dynamic arrays
        bytes32 tokensHash = keccak256(abi.encode(tokens));
        bytes32 pricesHash = keccak256(abi.encode(priceList));
        bytes32 decimalsHash = keccak256(abi.encode(decimalsList));

        // Build struct hash and digest
        bytes32 structHash = keccak256(
            abi.encode(
                PRICE_BATCH_TYPEHASH,
                tokensHash,
                pricesHash,
                decimalsHash,
                deadline,
                feeder,
                nonce
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        require(digest.recover(signature) == authorizedSigner, "Invalid signature");
    }

    function _updatePricesBatch(
        address[] calldata tokens,
        uint128[] calldata priceList,
        uint8[] calldata decimalsList
    ) private {
        uint64 nowTs = uint64(block.timestamp);
        for (uint256 i = 0; i < tokens.length; i++) {
            prices[tokens[i]] = PriceData(priceList[i], decimalsList[i], nowTs);
            emit PriceUpdated(tokens[i], priceList[i], decimalsList[i]);
        }
    }

    function _consumeNonce(address feeder, uint256 nonce) private {
        unchecked { userNonces[feeder] = nonce + 1; }
        emit NonceUpdated(feeder, userNonces[feeder]);
    }

    function getPrice(address token) external view returns (PriceData memory) {
        return prices[token];
    }

    function isFresh(address token) public view returns (bool) {
        return block.timestamp - prices[token].updatedAt <= maxAge;
    }

    // --- Validation functions for post-validation in basket/factory contracts ---
    /// @notice Validate after WETH -> Token swap
    /// @param tokenOut token being received
    /// @param wethIn amount of WETH spent (wei)
    /// @param actualOut amount of tokens received (smallest units)
    function ValidatePriceOracle_WETHtoToken(address tokenOut, uint256 wethIn, uint256 actualOut) external {
        PriceData memory d = prices[tokenOut];
        require(d.updatedAt != 0, "No price");
        require(isFresh(tokenOut), "Stale price");

        uint256 expectedOut = (wethIn * (10 ** d.decimals)) / uint256(d.price);

        uint256 diff = expectedOut > actualOut ? expectedOut - actualOut : actualOut - expectedOut;
        uint256 deviationBps = (diff * 10_000) / expectedOut;

        if (deviationBps > maxDeviationBps) {
            emit PriceDeviationHigh(tokenOut, expectedOut, actualOut);
        }
    }

    /// @notice Validate after Token -> WETH swap
    /// @param tokenIn token being sold
    /// @param tokenInAmount amount of tokens spent (smallest units)
    /// @param actualWethOut WETH actually received (wei)
    function ValidatePriceOracle_TokenToWETH(address tokenIn, uint256 tokenInAmount, uint256 actualWethOut) external {
        PriceData memory d = prices[tokenIn];
        require(d.updatedAt != 0, "No price");
        require(isFresh(tokenIn), "Stale price");

        uint256 expectedWethOut = (tokenInAmount * uint256(d.price)) / (10 ** d.decimals);

        uint256 diff = expectedWethOut > actualWethOut ? expectedWethOut - actualWethOut : actualWethOut - expectedWethOut;
        uint256 deviationBps = (diff * 10_000) / expectedWethOut;

        if (deviationBps > maxDeviationBps) {
            emit PriceDeviationHigh(tokenIn, expectedWethOut, actualWethOut);
        }
    }


    // Admin setters
    function setMaxAge(uint256 _maxAge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxAge = _maxAge;
    }

    function setMaxDeviation(uint256 _bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxDeviationBps = _bps;
    }

    // --- EIP-712 admin helpers ---
    function updateAuthorizedSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newSigner != address(0), "Invalid signer");
        authorizedSigner = newSigner;
        emit AuthorizedSignerUpdated(newSigner);
    }

    function getCurrentNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }

    event AuthorizedSignerUpdated(address indexed newSigner);
    event NonceUpdated(address indexed user, uint256 newNonce);
}
