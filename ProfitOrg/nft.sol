
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract MyToken is Initializable, ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;

    struct MinterInfo{
       
        string _tokenURIs;
        uint256 royaltyPercentage;
        address royaltyReceiver;
    }

    struct FiscalSponsor {
        
        bool haveFiscalSponsor;
        uint256 fiscalSponsorPercentage;
        address fiscalSponsor;
        address fiscalSponsorOf;
    }

    mapping (uint256 => MinterInfo) public minterInfo;
    mapping (address => FiscalSponsor) public fiscalSponsorInfo;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public _allowances;

    event SetFiscalFee(address fiscalAddress, uint256 feePercentage);
    event ApprovalAmount(address _owner, address _spender, uint256 _amount);
    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);
    event ChangeFiscalSponser(address organizationAddress, address  _fiscalSponsorAddress);
    event SpendAllowance(address _owner, address _spender,  uint256 nftId, uint256 allowedAmount);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        
        string memory _name,
        string memory _symbol,
        address _initialOwner
    ) initializer public {

        name = _name;
        symbol = _symbol;

        __ERC1155_init("");
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

     function mint( 
        uint256 _noOfCopies,
        string memory _uri, 
        uint256 _royaltyFeePercentage, 
        address _fiscalSponsor
        
        ) external  returns(uint256) {

        
        require(bytes(_uri).length > 0, "tokenuri cannot be empty");
        require(_noOfCopies > 0, "_noOfCopies cannot be zero");
        require(_royaltyFeePercentage > 0  && _royaltyFeePercentage <= 3000 , "_royaltyFeePercentage must be between 1 to 30   ");

        tokenId++;

        if(_fiscalSponsor != address(0)){
            fiscalSponsorInfo[msg.sender].haveFiscalSponsor = true;
            fiscalSponsorInfo[msg.sender].fiscalSponsorOf = msg.sender;
        }
        
        _mint(msg.sender, tokenId, _noOfCopies, "0x00");
        _setURI(tokenId, _uri);
       
        minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage;
        minterInfo[tokenId].royaltyReceiver = msg.sender;
        fiscalSponsorInfo[msg.sender].fiscalSponsor = _fiscalSponsor;
        
        emit Mints(msg.sender, tokenId, _noOfCopies, _uri);

        return tokenId;
    }


    function mintBatch(
        uint256 noOfTokens, 
        uint256[] memory _noOfCopies,
        string[] memory _tokenUris,
        uint256[] memory _royaltyFeePercentage, 
        address _fiscalSponsor
    
    ) external  returns (uint256 [] memory) {
        
        require(_tokenUris.length > 0, "tokenUris cannot be empty"); 
        require(_noOfCopies.length > 0, "amounts cannot be empty"); 
        require(_tokenUris.length == _noOfCopies.length &&
                 _noOfCopies.length == noOfTokens,"Array lengths must match");

        if(_fiscalSponsor != address(0)){
            fiscalSponsorInfo[msg.sender].haveFiscalSponsor = true;
            fiscalSponsorInfo[msg.sender].fiscalSponsorOf = msg.sender;
        }
        
        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
            require(_royaltyFeePercentage[i] > 0 && _royaltyFeePercentage[i] < 1600 , 
                "_royaltyFeePercentage must be between 0 to 16");
            
            tokenId++;

            tokenids[i]= tokenId;
            _setURI(tokenId, _tokenUris[i]);

            minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage[i];
            minterInfo[tokenId].royaltyReceiver = msg.sender;
        }
        
        fiscalSponsorInfo[msg.sender].fiscalSponsor = _fiscalSponsor;

        _mintBatch(msg.sender, tokenids, _noOfCopies, "0x00");

        emit BatchMints(msg.sender, tokenids, _noOfCopies, _tokenUris);

        return tokenids;
    }

    function changeFiscalSponsor(address _fiscalSponsorAddress) external {
        
        require(fiscalSponsorInfo[msg.sender].haveFiscalSponsor,"must have a fiscal sponsor!");

        fiscalSponsorInfo[msg.sender].fiscalSponsorOf = msg.sender;
        fiscalSponsorInfo[msg.sender].fiscalSponsor = _fiscalSponsorAddress;

        emit ChangeFiscalSponser(msg.sender, _fiscalSponsorAddress);
    }

    function setFiscalSponsorPercentage(address organizationAddress,uint256 _fiscalSponsorPercentage) external {
        
        require(_fiscalSponsorPercentage >= 100  && _fiscalSponsorPercentage <= 5000, 
            "_fiscalSponsorPercentage must be between 1 to 50%");
        
        require(fiscalSponsorInfo[organizationAddress].fiscalSponsor == msg.sender,
            "Only fiscal sponser can set the fee.");

        fiscalSponsorInfo[organizationAddress].fiscalSponsorPercentage = _fiscalSponsorPercentage;

        emit SetFiscalFee(msg.sender, _fiscalSponsorPercentage);
    }
    

    function _setURI(uint256 _tokenId,string memory newuri) private {
       minterInfo[_tokenId]._tokenURIs = newuri;
    }
    
    function uri(uint256 _tokenId) public view override returns (string memory) {

        string memory currentBaseURI = minterInfo[_tokenId]._tokenURIs;
        return string(abi.encodePacked(currentBaseURI));
    }

    function approveAmount(address _spender, uint256 id, uint256 amount) external {
       
        require(_spender != address(0), "ERC1155: approve to the zero address");
        require(amount <= balanceOf(msg.sender, id), "you donot have sufficent amount of balance.");

        _allowances[msg.sender][_spender][id] += amount;
        
        emit ApprovalAmount(msg.sender, _spender,  _allowances[msg.sender][_spender][id]);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual override {
        
        address sender = _msgSender(); 
        
        if ((from != sender && !isApprovedForAll(from, sender) && value > _allowances[from][msg.sender][id])) {
            
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        
        if(from != sender && !isApprovedForAll(from, sender)){
            _spendAllowance(from,sender, id,value);
        }
       
        _safeTransferFrom(from, to, id, value, data);
    }

    function _spendAllowance(address _owner, address _spender,  uint256 id, uint256 value) private  {
       
        _allowances[_owner][_spender][id] -= value;
        emit SpendAllowance(_owner,_spender,id, _allowances[_owner][_spender][id]);
    }


    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address){
        
        return (
            minterInfo[_tokenId].royaltyPercentage,
            minterInfo[_tokenId].royaltyReceiver
        );
    }

    function getFiscalSponsor(address _organizationAddress) external view returns (bool,uint256, address, address){
        
        return (
            fiscalSponsorInfo[_organizationAddress].haveFiscalSponsor,
            fiscalSponsorInfo[_organizationAddress].fiscalSponsorPercentage,
            fiscalSponsorInfo[_organizationAddress].fiscalSponsor,
            fiscalSponsorInfo[_organizationAddress].fiscalSponsorOf
        );
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

}

