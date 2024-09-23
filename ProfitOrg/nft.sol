
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

    address public contratAddress;
    


    event SetFiscalFee(address fiscalAddress, uint256 feePercentage);
    event ContractAddress(address ownerAddress, address contractAddress);
    event ApprovalAmount(address _owner, address _spender, uint256 _amount);
    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);
    event ChangeFiscalSponser(address organizationAddress, address  _fiscalSponsorAddress);
    event SpendAllowance(address _owner, address _spender,  uint256 nftId, uint256 allowedAmount);


    error noFiscalSponsor();
    error ArrayLengthMismatch();
    error emptyUri(uint256 uriLength);
    error zeroCopies(uint256 noOfCopies);
    error NotAuthorized(address passAddress);
    error invalidAddress(address passAddress);
    error zeroAddress(address spenderAddress);
    error insufficientBalance(uint256  balance);
    error onlyFiscalSponsor(address fiscalAddress);
    error invalidPercentage(uint256 feePeerccentage);
    error invalidAddresses(address organizationAddreess, address fiscalAddress);
    
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
        
        if(bytes(_uri).length <= 0){

            revert emptyUri(bytes(_uri).length);
        }
        if(_noOfCopies <= 0){

            revert zeroCopies(_noOfCopies);
        }
        if(_royaltyFeePercentage <= 0  || _royaltyFeePercentage > 3000){

            revert invalidPercentage(_royaltyFeePercentage);
        }
        

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

         if(_tokenUris.length <= 0){

            revert emptyUri(_tokenUris.length);
        }
        if(_noOfCopies.length <= 0){

            revert zeroCopies(_noOfCopies.length);
        }

        if (_tokenUris.length != _noOfCopies.length || _noOfCopies.length != noOfTokens) {
            revert ArrayLengthMismatch();
        }
        

        if(_fiscalSponsor != address(0)){
            fiscalSponsorInfo[msg.sender].haveFiscalSponsor = true;
            fiscalSponsorInfo[msg.sender].fiscalSponsorOf = msg.sender;
        }
        
        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {

            if(_royaltyFeePercentage[i] <= 0  || _royaltyFeePercentage[i] > 3000){

                revert invalidPercentage(_royaltyFeePercentage[i]);
            }
             
            
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

        if(!fiscalSponsorInfo[msg.sender].haveFiscalSponsor){
            revert noFiscalSponsor();
        }

        fiscalSponsorInfo[msg.sender].fiscalSponsorOf = msg.sender;
        fiscalSponsorInfo[msg.sender].fiscalSponsor = _fiscalSponsorAddress;

        emit ChangeFiscalSponser(msg.sender, _fiscalSponsorAddress);
    }

    function setFiscalSponsorPercentage(address organizationAddress,uint256 _fiscalSponsorPercentage) external {
        
        if(_fiscalSponsorPercentage <= 0  || _fiscalSponsorPercentage > 5000){
            revert invalidPercentage(_fiscalSponsorPercentage);
        }
        
        if(fiscalSponsorInfo[organizationAddress].fiscalSponsor != msg.sender){
            revert onlyFiscalSponsor(fiscalSponsorInfo[organizationAddress].fiscalSponsor);
        }

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
        
        if(_spender == address(0)){
            revert zeroAddress(_spender);
        }
        if(amount > balanceOf(msg.sender, id)){
            revert insufficientBalance(balanceOf(msg.sender, id));
        }

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

    function setFiscalSponsor(address _organizationAddress, address _fiscalSponsor) external  onlyContract(){

        if(_organizationAddress == address(0) || _fiscalSponsor == address(0)){
            revert invalidAddresses (_organizationAddress,_fiscalSponsor);
        }

        fiscalSponsorInfo[_organizationAddress].fiscalSponsorOf = _organizationAddress;
        fiscalSponsorInfo[_organizationAddress].fiscalSponsor = _fiscalSponsor;

        emit ChangeFiscalSponser(msg.sender, _fiscalSponsor);
    }



    function setContractAddress(address _contractAddress) external onlyOwner {
        
        if(_contractAddress == address(0)){
            revert invalidAddress(_contractAddress);
        }
        
        contratAddress = _contractAddress;

        emit ContractAddress(msg.sender, contratAddress);

    }
 

    modifier onlyContract(){
        if(msg.sender != contratAddress){
            revert NotAuthorized(msg.sender);
        }
        _;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

}

