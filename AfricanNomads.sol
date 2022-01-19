//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AfricanNomads is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public maxTokens = 100;
    uint256 public genesisTokens = 100;

    //seed investors
    address public WG = 0x41538872240Ef02D6eD9aC45cf4Ff864349D51ED;

    address public MULTISIG = 0xECd16C277F739613cE71C989E5b81045C7AEe962;

    bool public pausedSale = true;

    uint256 public fee = 10;

    string public baseURI;

    mapping(uint256 => bool) public minted; 
    mapping(uint256 => uint256) public price; //facilitate pricing by piece

    mapping(address => uint256[]) public benefactorToTokens; //stores all tokens that the benefactor HAS been benefactor to.
    mapping(uint256 => address) public tokensToBenefactor; //takes priority to above mapping
    // ? why 2 mappings? To avoid having to remove elements from benefactorsToTokens, but require a 2 way mapping to enumerate quickly. 

    constructor() ERC721("AfrikanNomads", "AN") {}

    modifier onlyBenefactor(uint256 tokenId) {
        require(tokensToBenefactor[tokenId] == msg.sender);
        _;
    }
    modifier unpausedSale() {
        require(!pausedSale, "sale is paused");
        _;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function mint(uint256 _id) public payable nonReentrant() unpausedSale {
        require(!minted[_id], "already minted");
        require(_id < maxTokens, "out of range");
        require(tokensToBenefactor[_id] != address(0), "Token has no benefactor");
        require(msg.value >= price[_id], "no price paid");
        require(price[_id] > 0, "This NFT is not listed or has no set price");

        minted[_id] = true;
        payable(tokensToBenefactor[_id]).transfer(msg.value.div(100).mul(100 - fee));
        _safeMint(msg.sender, _id);
    }

    function benefactorOf(uint256 _id) public view returns (address) {
        return tokensToBenefactor[_id];
    }

    function benefactorSetPrice(uint256 _newPrice, uint256 tokenId) public nonReentrant() onlyBenefactor(tokenId) {
        require(tokenId < maxTokens, "Token out of range");
        require(_newPrice >= .1 ether, "Price too low ;)");
        price[tokenId] = _newPrice;
    }

    function benefactorSetBenefactor(address _newBenefactor, uint256 tokenId) public nonReentrant() onlyBenefactor(tokenId) {
        require(tokenId < maxTokens, "Token out of range");
        tokensToBenefactor[tokenId] = _newBenefactor;
    }

    function ownerAddBenefactors(address[] memory _address, uint256[] memory tokenIds) public onlyOwner {
        require(_address.length == tokenIds.length, "arrays do not match");
        for(uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] < maxTokens, "Token out of range");
            tokensToBenefactor[tokenIds[i]] = _address[i];
            benefactorToTokens[_address[i]].push(i);
        }
    }

    function updateFees(uint256 _newFee) public onlyOwner {
        require(_newFee <= 10, "Fee greater than 10%");
        fee = _newFee;
    }

    function updateMaxTokens(uint256 _newMaxTokens) public onlyOwner { //facilitate expanding supply
        maxTokens = _newMaxTokens;
    }
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function ownerSetPrices(uint256 _newPrice, uint256[] memory tokenIds) public nonReentrant() onlyOwner {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            setPrice(_newPrice, tokenIds[i]);
        }
    }

    function setPrice(uint256 _newPrice, uint256 tokenId) private {
        require(tokenId < maxTokens, "Token out of range");
        require(_newPrice >= .1 ether, "Price too low ;)");
        price[tokenId] = _newPrice;
    }

    function togglePause() public nonReentrant onlyOwner {
        pausedSale = !pausedSale;
    }

    function withdraw() public nonReentrant() onlyOwner {
        payable(WG).transfer(address(this).balance.div(4));
        payable(MULTISIG).transfer(address(this).balance);
    }
}
