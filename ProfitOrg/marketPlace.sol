// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";


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

    event Bided( address _currentBidder, uint256 _bidAmount, uint256 _previousBidAmount); 
    event CancelList(address _listerAddress, uint256 _listingID, bool _isListed);
    event plateFarmFeePercentage(uint256 _serviceFeePercentage,address _owner);
    event Edited (uint256 _initialPrice,uint256 _listStartTime,uint256 _listEndTime);
    event SoldNft(address _from,uint256 indexed _tokenId,address indexed _nftAddress,address _to,uint256 _noOfCopirs);
    event FeeInfo(uint256 fiscalFee, uint256 royaltyFee,uint256 indexed serviceFee,uint256 indexed donationFee, uint256 indexed amountSendToSeller);
    event Listed(uint256 _listId,uint256 _tokenId, uint256 _noOfCopies, uint256 _initialPrices);
    event SetFiscalFee(address fiscalAddress, uint256 feePercentage);
    

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