//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */


interface AfricanNomads is IERC721 {
    function benefactorOf(uint256 _id) external view returns (address);
} 


abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @dev Contract module which provides access control
 *
 * the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * mapped to 
 * `onlyOwner`
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }
    

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract AfricanNomadsMarket is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint;

    AfricanNomads africanNomadsContract;  

    uint256 public platformFee = 25;
    uint256 public artistFee = 75;
    uint256 public basisPoints = 1000;
    uint256 public maxTokens = 100;

    struct Offer {
        bool isForSale;
        uint index;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;
    }

    struct Bid {
        bool hasBid;
        uint index;
        address bidder;
        uint value;
    }

    mapping (uint => Offer) public saleOffers;

    mapping (uint => Bid) public bids;

    // A record of pending ETH withdrawls by address
    mapping (address => uint) public pendingWithdrawals;

    event Offered(uint indexed index, uint minValue, address indexed toAddress);
    event BidEntered(uint indexed index, uint value, address indexed fromAddress);
    event BidWithdrawn(uint indexed index, uint value, address indexed fromAddress);
    event Bought(uint indexed index, uint value, address indexed fromAddress, address indexed toAddress);
    event RemovedFromSale(uint indexed index);

    /* Initializes contract with an instance of AfrikanNomads contract, and sets deployer as owner */
    constructor(address initialAddress) {
        AfricanNomads(initialAddress).balanceOf(address(this));
        setAfricanNomadsContract(initialAddress);
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    /* Returns the contract address currently being used */
    function contractAddress() public view returns (address) {
      return address(africanNomadsContract);
    }


    function setAfricanNomadsContract(address newContract) public onlyOwner {
      africanNomadsContract = AfricanNomads(newContract);
    }

    function setPlatformFee(uint256 newFee) public onlyOwner {
        platformFee = newFee;
    }

    function setArtistFee(uint256 newFee) public onlyOwner {
        artistFee = newFee;
    }

    function setBasisPoints(uint256 newBasisPoints) public onlyOwner {
        require(newBasisPoints > 0, "WTF");
        basisPoints = newBasisPoints;
    }

    function setMaxTokens(uint256 newMaxTokens) public onlyOwner {
        maxTokens = newMaxTokens;
    }

    function removeFromSale(uint index) public nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        if (africanNomadsContract.ownerOf(index) != msg.sender) revert('you are not the owner of this token');
        saleOffers[index] = Offer(false, index, msg.sender, 0, address(0x0));
        emit RemovedFromSale(index);
    }

    function offerForSale(uint index, uint minSalePriceInWei) public whenNotPaused nonReentrant()  {
        if (index >= maxTokens) revert('token index not valid');
        if (minSalePriceInWei == 0) revert('Cannot set for price of 0');
        if (africanNomadsContract.ownerOf(index) != msg.sender) revert('you are not the owner of this token');
        saleOffers[index] = Offer(true, index, msg.sender, minSalePriceInWei, address(0x0));
        africanNomadsContract.approve(address(this), index);
        emit Offered(index, minSalePriceInWei, address(0x0));
    }

    function offerForSaleToAddress(uint index, uint minSalePriceInWei, address toAddress) public whenNotPaused nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        if (minSalePriceInWei == 0) revert('Cannot set for price of 0');
        if (africanNomadsContract.ownerOf(index) != msg.sender) revert('you are not the owner of this token');
        saleOffers[index] = Offer(true, index, msg.sender, minSalePriceInWei, toAddress);
        africanNomadsContract.approve(address(this), index);

        emit Offered(index, minSalePriceInWei, toAddress);
    }
    

    function buy(uint index) payable public whenNotPaused nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        Offer memory offer = saleOffers[index];
        if (!offer.isForSale) revert('NFT Not for sale'); 
        if (offer.onlySellTo != address(0x0) && offer.onlySellTo != msg.sender) revert();                
        if (msg.value != offer.minValue) revert('not enough ether');          // Didn't send enough ETH
        address seller = offer.seller;
        if (seller == msg.sender) revert('seller == msg.sender');
        if (seller != africanNomadsContract.ownerOf(index)) revert('seller no longer owner');


        saleOffers[index] = Offer(false, index, msg.sender, 0, address(0x0));
        africanNomadsContract.safeTransferFrom(seller, msg.sender, index);

        updateWithdrawals(seller, index, msg.value);

        emit Bought(index, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = bids[index];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            bids[index] = Bid(false, index, address(0x0), 0);
        }
    }

    /* Allows users to retrieve ETH from sales */
    function withdraw(address _user) public nonReentrant() {
        uint amount = pendingWithdrawals[_user];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        require(amount > 0, "nothing to withdraw");
        pendingWithdrawals[_user] = 0;
        payable(_user).transfer(amount);
    }

    function enterBid(uint index) payable public whenNotPaused nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        if (africanNomadsContract.ownerOf(index) == msg.sender) revert('you already own this');
        if (msg.value == 0) revert('cannot enter bid of zero');
        Bid memory existing = bids[index];
        if (msg.value <= existing.value) revert('your bid is too low');
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        bids[index] = Bid(true, index, msg.sender, msg.value);
        emit BidEntered(index, msg.value, msg.sender);
    }

    function acceptBid(uint index, uint minPrice) public whenNotPaused nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        if (africanNomadsContract.ownerOf(index) != msg.sender) revert('you do not own this token');
        address seller = msg.sender;
        Bid memory bid = bids[index];
        if (bid.value == 0) revert('cannot enter bid of zero');
        if (bid.value < minPrice) revert('your bid is too low');

        address bidder = bid.bidder;
        if (seller == bidder) revert('you already own this token');
        saleOffers[index] = Offer(false, index, bidder, 0, address(0x0));
        uint amount = bid.value;
        bids[index] = Bid(false, index, address(0x0), 0);
        africanNomadsContract.safeTransferFrom(msg.sender, bidder, index);

        updateWithdrawals(seller, index, amount);
        emit Bought(index, bid.value, seller, bidder);
    }

    function withdrawBid(uint index) public nonReentrant() {
        if (index >= maxTokens) revert('token index not valid');
        Bid memory bid = bids[index];
        if (bid.bidder != msg.sender) revert('the bidder is not message sender');
        emit BidWithdrawn(index, bid.value, msg.sender);
        uint amount = bid.value;
        bids[index] = Bid(false, index, address(0x0), 0);
        // Refund the bid money
        payable(msg.sender).transfer(amount);
    }

    function updateWithdrawals(address seller, uint tokenIndex, uint amount) private {

        uint256 txPlatformFee = amount.div(basisPoints).mul(platformFee);
        uint256 txArtistFee = amount.div(basisPoints).mul(artistFee);
        uint256 remainder = amount - txPlatformFee - txArtistFee;
        pendingWithdrawals[seller] += remainder;
        pendingWithdrawals[africanNomadsContract.benefactorOf(tokenIndex)] += txArtistFee;
        pendingWithdrawals[owner()] += txPlatformFee;
    }

}
