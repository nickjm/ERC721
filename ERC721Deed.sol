pragma solidity ^0.4.18;

import "./ERC721.sol";
import "./ERC721Metadata.sol";
import "./ERC721Enumerable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title ERC721Deed
 * @author nickjm
 * @dev Implements the full ERC721 Specification according to most recent draft at time of development.
 * Implementation inspired by OpenZeppelin's implementation of the previous draft of ERC721
 * (https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/ERC721/ERC721Token.sol)
 * The documenation for most of these functions are defined at the interface level. Besides a couple project
 * specific details, this implementation is completely separate from children, which makes sense;
 * Deeds are separate from the actual assets they pertain to, per the philosophy of ERC721.
 *
 * CAVEATS: Four external functions have been made public so that inheriting functions can retrieve that data and
 * private Deed state can be left private.
 */
contract ERC721Deed is ERC721, ERC721Metadata, ERC721Enumerable {

    using SafeMath for uint256;

    // Price of approving an address to take a deed
    uint256 private constant approveTax = 0;

    // Price of taking ownership of a deed
    uint256 private constant takeOwnershipTax = 0;

    // Total amount of deeds
    uint256 private totalDeeds;

    // Total number of owners
    uint256 private totalOwners;

    // Mapping from deed ID to owner
    mapping (uint256 => address) private deedOwner;

    // Mapping from deed ID to approved address
    mapping (uint256 => address) private deedApprovals;

    // Mapping from owner to list of owned deed IDs
    mapping (address => uint256[]) private ownedDeeds;

    // Mapping from deed ID to index of the owner deeds list
    mapping(uint256 => uint256) private ownedDeedsIndex;

    bytes4 internal constant INTERFACE_SIGNATURE_ERC165 = // 0x01ffc9a7
        bytes4(keccak256('supportsInterface(bytes4)'));

    bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = // 0xda671b9b
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('countOfDeeds()')) ^
        bytes4(keccak256('countOfDeedsByOwner(address)')) ^
        bytes4(keccak256('deedOfOwnerByIndex(address,uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('takeOwnership(uint256)'));

    bytes4 internal constant INTERFACE_SIGNATURE_ERC721Metadata = // 0x2a786f11
        bytes4(keccak256('name()')) ^
        bytes4(keccak256('symbol()')) ^
        bytes4(keccak256('deedUri(uint256)'));

    bytes4 internal constant INTERFACE_SIGNATURE_ERC721Enumerable = // 0xa5e86824
        bytes4(keccak256('deedByIndex()')) ^
        bytes4(keccak256('countOfOwners()')) ^
        bytes4(keccak256('ownerByIndex(uint256)'));

    event Transfer(address indexed from, address indexed to, uint256 indexed deedId);

    event Approval(address indexed owner, address indexed approved, uint256 indexed deedId);

    /**
    * @dev Guarantees msg.sender is owner of the given deed
    * @param _deedId uint256 ID of the deed to validate its ownership belongs to msg.sender
    */
    modifier onlyOwnerOf(uint256 _deedId) {
        require(ownerOf(_deedId) == msg.sender);
        _;
    }

    modifier notOwnerOf(uint256 _deedId) {
        require(ownerOf(_deedId) == msg.sender);
        _;
    }

    modifier validDeed(uint256 _deedId) {
        require(_deedId < countOfDeeds());
        _;
    }

    modifier costs(uint256 _amount) {
        require(msg.value >= _amount);
        _;
    }

    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return (
            (_interfaceID == INTERFACE_SIGNATURE_ERC165)
            || (_interfaceID == INTERFACE_SIGNATURE_ERC721)
            || (_interfaceID == INTERFACE_SIGNATURE_ERC721Metadata)
            || (_interfaceID == INTERFACE_SIGNATURE_ERC721Enumerable)
        );
    }

    function name() public pure returns (string _deedName) {
        _deedName = "ERC721Deed";
    }

    function symbol() public pure returns (string _deedSymbol) {
        _deedSymbol = "721";
    }

    function deedName(uint256 _deedId) public pure returns (string _deedName) {
        _deedName = bytes32ToString(bytes32(_deedId));
    }

    function deedUri(uint256 _deedId) external view returns (string _deedUri);

    /**
    * @dev Gets the list of deeds owned by a given address
    * @param _owner address to query the deeds of
    * @return uint256[] representing the list of deeds owned by the passed address
    */
    function deedsOf(address _owner) public view returns (uint256[]) {
      return ownedDeeds[_owner];
    }

    // ERC721 Specifies external `ownerOf` -- chaging to public for principle's sake

    function ownerOf(uint256 _deedId) public view returns (address _owner) {
        address owner = deedOwner[_deedId];
        require(owner != address(0));
        return owner;
    }

    // ERC721 Specifies external `countOfDeeds` -- chaging to public for principle's sake

    function countOfDeeds() public view returns (uint256 _count) {
        _count = totalDeeds;
    }

    // ERC721 Specifies external `countOfDeedsByOwner` -- chaging to public for principle's sake

    function countOfDeedsByOwner(address _owner) public view returns (uint256 _count) {
        _count = ownedDeeds[_owner].length;
    }

    // ERC721 Specifies external `deedOfOwnerByIndex` -- chaging to public for principle's sake

    function deedOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256 _deedId) {
        _deedId = ownedDeeds[_owner][_index];
    }

    function approve(address _to, uint256 _deedId) external payable costs(approveTax) onlyOwnerOf(_deedId) {
        address owner = ownerOf(_deedId);
        require(_to != owner);
        if (approvedFor(_deedId) != 0 || _to != 0) {
          deedApprovals[_deedId] = _to;
          Approval(owner, _to, _deedId);
        }
    }

    function takeOwnership(uint256 _deedId) external payable costs(takeOwnershipTax){
        require(isApprovedFor(msg.sender, _deedId));
        clearApprovalAndTransfer(ownerOf(_deedId), msg.sender, _deedId);
    }

    function deedByIndex(uint256 _index) external view returns (uint256 _deedId) {
        // This project uses continuous indices for identification
        _deedId = _index;
    }

    function countOfOwners() external view returns (uint256 _count) {
        _count = totalOwners;
    }

    function ownerByIndex(uint256 _index) external view returns (address _owner) {
        // TODO maybe leave it to child to implement
    }

    /**
     * @dev Gets the approved address to take ownership of a given deed ID
     * @param _deedId uint256 ID of the deed to query the approval of
     * @return address currently approved to take ownership of the given deed ID
     */
    function approvedFor(uint256 _deedId) public view returns (address) {
        return deedApprovals[_deedId];
    }

    /**
    * @dev Mint deed function
    * @param _to The address that will own the minted deed
    * @param _deedId uint256 ID of the deed to be minted by the msg.sender
    */
    function _mint(address _to, uint256 _deedId) internal {
        require(_to != address(0));
        addDeed(_to, _deedId);
        Transfer(0x0, _to, _deedId);
    }

    /**
    * @dev Burns a specific deed
    * @param _deedId uint256 ID of the deed being burned by the msg.sender
    */
    function _burn(uint256 _deedId) onlyOwnerOf(_deedId) internal {
        if (approvedFor(_deedId) != 0) {
            clearApproval(msg.sender, _deedId);
        }
        removeDeed(msg.sender, _deedId);
        Transfer(msg.sender, 0x0, _deedId);
    }

    /**
     * @dev Tells whether the msg.sender is approved for the given deed ID or not
     * This function is not private so it can be extended in further implementations like the operatable ERC721
     * @param _owner address of the owner to query the approval of
     * @param _deedId uint256 ID of the deed to query the approval of
     * @return bool whether the msg.sender is approved for the given deed ID or not
     */
    function isApprovedFor(address _owner, uint256 _deedId) internal view returns (bool) {
        return approvedFor(_deedId) == _owner;
    }

    /**
    * @dev Internal function to clear current approval and transfer the ownership of a given deed ID
    * @param _from address which you want to send deeds from
    * @param _to address which you want to transfer the deed to
    * @param _deedId uint256 ID of the deed to be transferred
    */
    function clearApprovalAndTransfer(address _from, address _to, uint256 _deedId) internal {
        require(_to != address(0));
        require(_to != ownerOf(_deedId));
        require(ownerOf(_deedId) == _from);

        clearApproval(_from, _deedId);
        removeDeed(_from, _deedId);
        addDeed(_to, _deedId);
        Transfer(_from, _to, _deedId);
    }

    /**
    * @dev Internal function to clear current approval of a given deed ID
    * @param _deedId uint256 ID of the deed to be transferred
    */
    function clearApproval(address _owner, uint256 _deedId) private {
        require(ownerOf(_deedId) == _owner);
        deedApprovals[_deedId] = 0;
        Approval(_owner, 0, _deedId);
    }

    /**
    * @dev Internal function to add a deed ID to the list of a given address
    * @param _to address representing the new owner of the given deed ID
    * @param _deedId uint256 ID of the deed to be added to the deeds list of the given address
    */
    function addDeed(address _to, uint256 _deedId) private {
        require(deedOwner[_deedId] == address(0));
        deedOwner[_deedId] = _to;
        uint256 length = countOfDeedsByOwner(_to);
        // If address is new owner, increment owner count
        if (length == 0) {
            totalOwners = totalOwners.add(1);
        }
        ownedDeeds[_to].push(_deedId);
        ownedDeedsIndex[_deedId] = length;
        totalDeeds = totalDeeds.add(1);
    }

    /**
    * @dev Internal function to remove a deed ID from the list of a given address
    * @param _from address representing the previous owner of the given deed ID
    * @param _deedId uint256 ID of the deed to be removed from the deeds list of the given address
    */
    function removeDeed(address _from, uint256 _deedId) private {
        require(ownerOf(_deedId) == _from);

        uint256 deedIndex = ownedDeedsIndex[_deedId];
        uint256 lastDeedIndex = countOfDeedsByOwner(_from).sub(1);
        uint256 lastDeed = ownedDeeds[_from][lastDeedIndex];

        deedOwner[_deedId] = 0;
        ownedDeeds[_from][deedIndex] = lastDeed;
        ownedDeeds[_from][lastDeedIndex] = 0;
        // Note that this will handle single-element arrays. In that case, both deedIndex and lastDeedIndex are going to
        // be zero. Then we can make sure that we will remove _deedId from the ownedDeeds list since we are first swapping
        // the lastDeed to the first position, and then dropping the element placed in the last position of the list

        ownedDeeds[_from].length--;
        ownedDeedsIndex[_deedId] = 0;
        ownedDeedsIndex[lastDeed] = deedIndex;
        totalDeeds = totalDeeds.sub(1);

        // If address no longer holds any deeds, decrement owner count
        if (countOfDeedsByOwner(_from) == 0) {
            totalOwners = totalOwners.sub(1);
        }
    }

    function bytes32ToString (bytes32 data) private pure returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j<32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }
}
